package com.quickpost.app

import android.content.Context
import android.graphics.*
import android.media.*
import android.opengl.*
import android.util.Log
import android.view.Surface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * GPU-accelerated video watermark overlay processor.
 */
class OpenGLWatermarkProcessor(private val context: Context) {

    companion object {
        private const val TAG = "GLWatermark"
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 1
        private const val DEFAULT_BITRATE = 6_000_000
        private const val TIMEOUT_US = 10_000L
    }

    @Volatile
    private var isCanceled = false

    fun cancel() {
        isCanceled = true
        Log.d(TAG, "Cancellation requested")
    }

    interface ProgressCallback {
        fun onProgress(progress: Double)
        fun onStep(step: String)
    }

    // ── Shaders ─────────────────────────────────────────────────────

    private val VERTEX_SHADER = """
        uniform mat4 uMVPMatrix;
        uniform mat4 uTexMatrix;
        attribute vec4 aPosition;
        attribute vec4 aTexCoord;
        varying vec2 vTexCoord;
        void main() {
            gl_Position = uMVPMatrix * aPosition;
            vTexCoord = (uTexMatrix * aTexCoord).xy;
        }
    """.trimIndent()

    private val FRAGMENT_SHADER_OES = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        varying vec2 vTexCoord;
        uniform samplerExternalOES sTexture;
        uniform float uAlpha;
        uniform vec2 uSize;
        uniform float uRadius;
        uniform vec3 uBorderColor;
        uniform float uBorderWidth;

        float roundedRect(vec2 p, vec2 b, float r) {
            vec2 d = abs(p - b) - (b - r);
            return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
        }

        void main() {
            vec4 color = texture2D(sTexture, vTexCoord);
            
            vec2 p = vTexCoord * uSize;
            float d = roundedRect(p, uSize * 0.5, uRadius);
            
            // Main clip mask: 1.0 inside (d < 0), 0.0 outside (d > 0)
            float mask = 1.0 - smoothstep(0.0, 1.0, d);
            
            if (uBorderWidth > 0.0) {
                // Border mask: 1.0 when -uBorderWidth < d < 0
                float borderMask = smoothstep(-uBorderWidth - 1.0, -uBorderWidth, d) * (1.0 - smoothstep(-1.0, 0.0, d));
                color.rgb = mix(color.rgb, uBorderColor, borderMask);
            }
            
            gl_FragColor = vec4(color.rgb * uAlpha * mask, color.a * uAlpha * mask);
        }
    """.trimIndent()

    private val FRAGMENT_SHADER_2D = """
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D sTexture;
        uniform float uAlpha;
        uniform float uBrightness;
        uniform float uSaturation;

        vec3 applySaturation(vec3 rgb, float saturation) {
            float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
            return mix(vec3(luma), rgb, saturation);
        }

        void main() {
            vec4 color = texture2D(sTexture, vTexCoord);
            vec3 rgb = color.rgb;
            rgb = applySaturation(rgb, uSaturation);
            rgb = rgb * uBrightness;
            gl_FragColor = vec4(rgb * uAlpha, color.a * uAlpha);
        }
    """.trimIndent()

    private val FRAGMENT_SHADER_BLUR_H = """
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D sTexture;
        uniform float uTexelWidth;
        void main() {
            vec4 sum = vec4(0.0);
            for (int i = -4; i <= 4; i++) {
                sum += texture2D(sTexture, vTexCoord + vec2(float(i) * uTexelWidth, 0.0));
            }
            gl_FragColor = sum / 9.0;
        }
    """.trimIndent()

    private val FRAGMENT_SHADER_BLUR_V = """
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D sTexture;
        uniform float uTexelHeight;
        void main() {
            vec4 sum = vec4(0.0);
            for (int i = -4; i <= 4; i++) {
                sum += texture2D(sTexture, vTexCoord + vec2(0.0, float(i) * uTexelHeight));
            }
            gl_FragColor = sum / 9.0;
        }
    """.trimIndent()


    // ── Geometry ─────────────────────────────────────────────────────

    private val QUAD_COORDS = floatArrayOf(
        -1f, -1f, 0f,
         1f, -1f, 0f,
        -1f,  1f, 0f,
         1f,  1f, 0f
    )
    private val TEX_COORDS = floatArrayOf(
        0f, 0f,
        1f, 0f,
        0f, 1f,
        1f, 1f
    )

    private val vertexBuffer: FloatBuffer = ByteBuffer.allocateDirect(QUAD_COORDS.size * 4)
        .order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(QUAD_COORDS); position(0) }
    private val texCoordBuffer: FloatBuffer = ByteBuffer.allocateDirect(TEX_COORDS.size * 4)
        .order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(TEX_COORDS); position(0) }

    // ── GL state ────────────────────────────────────────────────────

    private var programOES = 0
    private var program2D = 0
    private var programBlurH = 0
    private var programBlurV = 0

    private var fboA = 0
    private var fboTexA = 0
    private var fboB = 0
    private var fboTexB = 0

    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    @Volatile private var frameAvailable = false
    private val frameSyncObject = Object()

    private var muxerTrackIndex = -1
    private var muxerStarted = false
    private var muxedFrameCount = 0

    private var patchTopTexId = 0
    private var patchBottomTexId = 0
    private var patches: List<Patch> = emptyList()

    data class Patch(
        val x: Float,
        val y: Float,
        val width: Float,
        val height: Float,
        val color: String,
        val opacity: Float,
        val radius: Float,
        val isTop: Boolean = true
    )

    data class TextOverlay(
        val text: String,
        val x: Float,
        val y: Float,
        val fontSize: Float,
        val color: String,
        val fontPath: String,
        val showShadow: Boolean,
        val shadowColor: String,
        val shadowBlur: Float,
        val shadowOffsetX: Float,
        val shadowOffsetY: Float,
        val textAlign: String,
        val maxWidth: Float,
        val anchor: String,
        val scale: Float,
        val lineHeight: Float,
        val letterSpacing: Float,
        val wordSpacing: Float
    )

    data class ImageOverlay(
        val path: String,
        val x: Float,
        val y: Float,
        val scale: Float,
        val opacity: Float,
        val rotation: Float
    )

    // ── Public entry point ──────────────────────────────────────────

    fun processVideoWithWatermark(
        videoPath: String,
        outputFile: File,
        params: Map<String, Any?>,
        callback: ProgressCallback
    ): Int {
        Log.d(TAG, "═══ processVideoWithWatermark START ═══")
        callback.onStep("Analyzing video tracks...")
        Log.d(TAG, "Phase 1: Analysis - videoPath: $videoPath")
        
        // Extract basic params
        val fullScreen = params["fullScreen"] as? Boolean ?: false
        val bgColorStr = params["bgColor"] as? String ?: "#000000"
        val bgColor = try { Color.parseColor(bgColorStr) } catch (e: Exception) { Color.BLACK }

        val x = (params["x"] as? Number)?.toInt() ?: 100
        val y = (params["y"] as? Number)?.toInt() ?: 100
        
        val bgImagePath = params["bgImagePath"] as? String ?: ""
        val bgBrightness = (params["bgBrightness"] as? Number)?.toFloat() ?: 1.0f
        val bgSaturation = (params["bgSaturation"] as? Number)?.toFloat() ?: 1.0f
        val bgBlur = (params["bgBlur"] as? Number)?.toFloat() ?: 0f
        val videoY = (params["videoY"] as? Number)?.toFloat() ?: 0.5f
        val videoScale = (params["videoScale"] as? Number)?.toFloat() ?: 1.0f
        
        // Video Shadow parameters
        val showVideoShadow = params["showVideoShadow"] as? Boolean ?: false
        val videoShadowColorStr = params["videoShadowColor"] as? String ?: "#000000"
        val videoShadowBlur = (params["videoShadowBlur"] as? Number)?.toFloat() ?: 10f
        val videoShadowSpread = (params["videoShadowSpread"] as? Number)?.toFloat() ?: 0f
        val videoShadowOffsetX = (params["videoShadowOffsetX"] as? Number)?.toFloat() ?: 0f
        val videoShadowOffsetY = (params["videoShadowOffsetY"] as? Number)?.toFloat() ?: 0f

        // 1. Open input video
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(videoPath)
        } catch (e: Exception) {
             Log.e(TAG, "Failed to set data source: ${e.message}")
             throw Exception("Invalid video source or format")
        }

        var videoTrackIndex = -1
        var audioTrackIndex = -1
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            Log.d(TAG, "Track $i: $mime")
            if (mime.startsWith("video/") && videoTrackIndex < 0) videoTrackIndex = i
            if (mime.startsWith("audio/") && audioTrackIndex < 0) audioTrackIndex = i
        }
        if (videoTrackIndex < 0) {
            Log.e(TAG, "No video track found!")
            throw Exception("No valid video track found in selected file")
        }
        
        extractor.selectTrack(videoTrackIndex)
        val inputFormat = extractor.getTrackFormat(videoTrackIndex)
        val inputWidth = inputFormat.getInteger(MediaFormat.KEY_WIDTH)
        val inputHeight = inputFormat.getInteger(MediaFormat.KEY_HEIGHT)
        Log.d(TAG, "Input Dimensions: $inputWidth x $inputHeight")

        // Output dimensions: Must be multiples of 16 for some hardware encoders (like MTK) to avoid silent failures
        var outW = if (fullScreen) 1080 else inputWidth
        var outH = if (fullScreen) 1920 else inputHeight
        
        // Align to 16
        outW = (outW + 15) / 16 * 16
        outH = (outH + 15) / 16 * 16
        
        val outWidth = outW
        val outHeight = outH
        Log.d(TAG, "Output Dimensions (Aligned): $outWidth x $outHeight")

        val videoDurationUs = if (inputFormat.containsKey(MediaFormat.KEY_DURATION))
            inputFormat.getLong(MediaFormat.KEY_DURATION) else 0L
        val effectiveDuration = ((videoDurationUs / 1_000_000).toInt()).coerceAtLeast(1)
        val totalFrames = effectiveDuration * FRAME_RATE
        Log.d(TAG, "Total expected frames: $totalFrames (Duration: ${videoDurationUs/1000}ms)")
        
        val patchList = params["patches"] as? List<Map<String, Any?>> ?: emptyList()
        patches = patchList.map { p ->
            Patch(
                x = (p["x"] as? Number)?.toFloat() ?: 0f,
                y = (p["y"] as? Number)?.toFloat() ?: 0f,
                width = (p["width"] as? Number)?.toFloat() ?: 100f,
                height = (p["height"] as? Number)?.toFloat() ?: 100f,
                color = p["color"] as? String ?: "#000000",
                opacity = (p["opacity"] as? Number)?.toFloat() ?: 1.0f,
                radius = (p["radius"] as? Number)?.toFloat() ?: 0f,
                isTop = p["isTop"] as? Boolean ?: true
            )
        }

        val textOverlayList = params["textOverlays"] as? List<Map<String, Any?>> ?: emptyList()
        val textOverlays = textOverlayList.map { t ->
            TextOverlay(
                text = t["text"] as? String ?: "",
                x = (t["x"] as? Number)?.toFloat() ?: 0f,
                y = (t["y"] as? Number)?.toFloat() ?: 0f,
                fontSize = (t["fontSize"] as? Number)?.toFloat() ?: 40f,
                color = t["color"] as? String ?: "#FFFFFF",
                fontPath = t["fontPath"] as? String ?: "",
                showShadow = t["showShadow"] as? Boolean ?: true,
                shadowColor = t["shadowColor"] as? String ?: "#000000",
                shadowBlur = (t["shadowBlur"] as? Number)?.toFloat() ?: 8f,
                shadowOffsetX = (t["shadowOffsetX"] as? Number)?.toFloat() ?: 2f,
                shadowOffsetY = (t["shadowOffsetY"] as? Number)?.toFloat() ?: 2f,
                textAlign = t["textAlign"] as? String ?: "center",
                maxWidth = (t["maxWidth"] as? Number)?.toFloat() ?: 800f,
                anchor = t["anchor"] as? String ?: "center",
                scale = (t["scale"] as? Number)?.toFloat() ?: 1.0f,
                lineHeight = (t["lineHeight"] as? Number)?.toFloat() ?: 1.2f,
                letterSpacing = (t["letterSpacing"] as? Number)?.toFloat() ?: 0.0f,
                wordSpacing = (t["wordSpacing"] as? Number)?.toFloat() ?: 0.0f
            )
        }

        // --- Parse Image Overlays ---
        val imageOverlayList = params["imageOverlays"] as? List<Map<String, Any?>> ?: emptyList()
        val imageOverlays = imageOverlayList.map { o ->
            ImageOverlay(
                path = o["path"] as? String ?: "",
                x = (o["x"] as? Number)?.toFloat() ?: 0f,
                y = (o["y"] as? Number)?.toFloat() ?: 0f,
                scale = (o["scale"] as? Number)?.toFloat() ?: 0.2f,
                opacity = (o["opacity"] as? Number)?.toFloat() ?: 1.0f,
                rotation = (o["rotation"] as? Number)?.toFloat() ?: 0f
            )
        }.filter { it.path.isNotEmpty() && File(it.path).exists() }

        // --- Pre-load GIF if exists ---
        val profileImagePath = params["profileImagePath"] as? String ?: ""
        var movie: Movie? = null
        if (profileImagePath.lowercase().endsWith(".gif") && profileImagePath.isNotEmpty()) {
            val f = File(profileImagePath)
            if (f.exists()) movie = Movie.decodeFile(profileImagePath)
        }

        // 2. Encoder Setup
        Log.d(TAG, "Phase 2: Encoder Setup")
        callback.onStep("Configuring encoder...")
        val encoderFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, outWidth, outHeight).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, DEFAULT_BITRATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        }
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(encoderFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val encoderSurface = encoder.createInputSurface()
        encoder.start()
        Log.d(TAG, "Encoder started: ${encoder.name}")

        // 3. EGL + GL
        callback.onStep("Initializing graphics engine...")
        Log.d(TAG, "Phase 3: GPU Initialization")
        initEGL(encoderSurface)
        initGL(outWidth, outHeight)
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val bufferInfo = MediaCodec.BufferInfo()
        val encoderBufferInfo = MediaCodec.BufferInfo()

        // 4. Decoder Setup (requires EGL context for SurfaceTexture)
        Log.d(TAG, "Phase 4: Decoder Setup")
        callback.onStep("Preparing video decoder...")
        val oesTexId = createOESTexture()
        val surfaceTexture = SurfaceTexture(oesTexId)
        surfaceTexture.setDefaultBufferSize(inputWidth, inputHeight)
        surfaceTexture.setOnFrameAvailableListener {
            synchronized(frameSyncObject) { frameAvailable = true; frameSyncObject.notifyAll() }
        }
        val decoderSurface = Surface(surfaceTexture)
        val decoder = MediaCodec.createDecoderByType(inputFormat.getString(MediaFormat.KEY_MIME)!!)
        decoder.configure(inputFormat, decoderSurface, null, 0)
        decoder.start()
        Log.d(TAG, "Decoder started: ${decoder.name}")

        val watermarkResult = renderWatermarkBitmap(params, 0, movie, outWidth)
        var watermarkTexId = loadBitmapTexture(flipBitmapVertically(watermarkResult.bitmap))
        
        // Store box dims for positioning
        val boxW = watermarkResult.boxWidth
        val boxH = watermarkResult.boxHeight
        watermarkResult.bitmap.recycle()

        // --- Video Shadow Texture ---
        var videoShadowTexId = 0
        val videoShadowMvp = FloatArray(16)
        var shadowBmpW = 0f
        var shadowBmpH = 0f

        if (showVideoShadow) {
            // Calculate effective video dimensions in outWidth/outHeight space
            val aspectIn = inputWidth.toFloat() / inputHeight.toFloat()
            val aspectOut = outWidth.toFloat() / outHeight.toFloat()
            val sY = if (aspectIn > aspectOut) aspectOut / aspectIn else 1.0f
            val sX = if (aspectIn < aspectOut) aspectIn / aspectOut else 1.0f
            
            val effVideoW = outWidth * sX
            val effVideoH = outHeight * sY
            
            // Scale blur and spread to match visual proportion (reference width 360)
            val shadowScale = outWidth / 360f
            val scaledBlur = videoShadowBlur * shadowScale
            val scaledSpread = videoShadowSpread * shadowScale
            
            val radiusScale = outWidth / 360f
            val scaledRadius = (params["videoRadius"] as? Number)?.toFloat() ?: 0f
            val shadowResult = renderVideoShadowBitmap(effVideoW, effVideoH, videoShadowColorStr, scaledBlur, scaledSpread, scaledRadius * radiusScale)
            videoShadowTexId = loadBitmapTexture(flipBitmapVertically(shadowResult.bitmap))
            shadowBmpW = shadowResult.fullWidth
            shadowBmpH = shadowResult.fullHeight
            
            // Calculate Shadow MVP
            android.opengl.Matrix.setIdentityM(videoShadowMvp, 0)
            
            // Initial translation for video centering
            val glVideoY = (0.5f - videoY) * 2f * (1.0f - sY)
            
            // Apply User Offsets (convert pixels to NDC)
            val glShadowOffsetX = (videoShadowOffsetX / outWidth.toFloat()) * 2f
            val glShadowOffsetY = -(videoShadowOffsetY / outHeight.toFloat()) * 2f
            
            android.opengl.Matrix.translateM(videoShadowMvp, 0, glShadowOffsetX, glVideoY + glShadowOffsetY, 0f)
            android.opengl.Matrix.scaleM(videoShadowMvp, 0, (shadowBmpW / outWidth.toFloat()) * videoScale, (shadowBmpH / outHeight.toFloat()) * videoScale, 1.0f)
            
            shadowResult.bitmap.recycle()
        }

        // Patch textures (shared for all patches render)
        patchTopTexId = createEmptyTexture(outWidth, outHeight)
        patchBottomTexId = createEmptyTexture(outWidth, outHeight)
        
        val bottomPatches = patches.filter { !it.isTop }
        val topPatches = patches.filter { it.isTop }
        
        if (bottomPatches.isNotEmpty()) updatePatchTexture(patchBottomTexId, bottomPatches, emptyList(), outWidth, outHeight)
        if (topPatches.isNotEmpty() || textOverlays.isNotEmpty()) updatePatchTexture(patchTopTexId, topPatches, textOverlays, outWidth, outHeight)

        // --- Pre-load Image Overlay Textures ---
        data class OverlayRuntime(val overlay: ImageOverlay, val texId: Int, val movie: Movie?, val bitmapW: Int, val bitmapH: Int)
        val overlayRuntimes = mutableListOf<OverlayRuntime>()
        for (ol in imageOverlays) {
            val f = File(ol.path)
            if (ol.path.lowercase().endsWith(".gif")) {
                val m = Movie.decodeFile(ol.path)
                if (m != null && m.width() > 0) {
                    // Render first frame as initial texture
                    val bmp = Bitmap.createBitmap(m.width(), m.height(), Bitmap.Config.ARGB_8888)
                    val c = Canvas(bmp)
                    m.setTime(0)
                    m.draw(c, 0f, 0f)
                    val texId = loadBitmapTexture(flipBitmapVertically(bmp))
                    overlayRuntimes.add(OverlayRuntime(ol, texId, m, m.width(), m.height()))
                    bmp.recycle()
                }
            } else {
                val bmp = BitmapFactory.decodeFile(ol.path)
                if (bmp != null) {
                    val texId = loadBitmapTexture(flipBitmapVertically(bmp))
                    overlayRuntimes.add(OverlayRuntime(ol, texId, null, bmp.width, bmp.height))
                    bmp.recycle()
                }
            }
        }

        var bgTexId = 0
        val bgMvp = FloatArray(16)
        android.opengl.Matrix.setIdentityM(bgMvp, 0)
        
        if (bgImagePath.isNotEmpty() && File(bgImagePath).exists()) {
            val bgBitmap = BitmapFactory.decodeFile(bgImagePath)
            if (bgBitmap != null) {
                bgTexId = loadBitmapTexture(flipBitmapVertically(bgBitmap))
                
                // Calculate Aspect Fill (Crop) for Background
                val fillScale = maxOf(outWidth.toFloat() / bgBitmap.width, outHeight.toFloat() / bgBitmap.height)
                android.opengl.Matrix.scaleM(bgMvp, 0, (bgBitmap.width * fillScale) / outWidth, (bgBitmap.width * fillScale * (bgBitmap.height.toFloat()/bgBitmap.width.toFloat())) / outHeight, 1f)
                
                if (bgBlur > 0) {
                    val blurScale = (bgBlur / 10.0f).coerceIn(0.5f, 8.0f)
                    val passes = (bgBlur / 10.0f).toInt().coerceIn(1, 5)
                    
                    GLES20.glViewport(0, 0, outWidth, outHeight)
                    // Initial draw to FBO A
                    GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
                    GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                    draw2DTexture(bgTexId, bgMvp, 1.0f)
                    
                    for (i in 0 until passes) {
                        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboB)
                        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                        drawBlurH(fboTexA, blurScale, outWidth)
                        
                        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
                        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                        drawBlurV(fboTexB, blurScale, outHeight)
                    }
                    GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
                    // Now use fboTexA as the background texture, with identity MVP since it's already sized/cropped
                    bgTexId = fboTexA
                    android.opengl.Matrix.setIdentityM(bgMvp, 0)
                }
                bgBitmap.recycle()
            }
        }

        // 5. Main Loop
        callback.onStep("Encoding video frames...")
        Log.d(TAG, "Phase 6: Processing Loop")
        val texMatrix = FloatArray(16)
        
        // Calculate Centering for Video
        val videoMvp = FloatArray(16)
        android.opengl.Matrix.setIdentityM(videoMvp, 0)
        if (fullScreen) {
             val aspectIn = inputWidth.toFloat() / inputHeight.toFloat()
             val aspectOut = outWidth.toFloat() / outHeight.toFloat()
             
             // 1. Calculate Scales
             val sY = if (aspectIn > aspectOut) aspectOut / aspectIn else 1.0f
             val sX = if (aspectIn < aspectOut) aspectIn / aspectOut else 1.0f

             // 2. Calculate Vertical Position (videoY: 0.0 top, 0.5 center, 1.0 bottom)
             // Math: (0.5 - videoY) * 2 matches Flutter Alignment. We multiply by (1 - sY) 
             // to restrict translation within the available "slack" space.
             val glVideoY = (0.5f - videoY) * 2f * (1.0f - sY)

             // 3. Apply Transformations: Translate FIRST, then Scale
             // This ensures translation is in NDC space relative to the canvas, not the video's fitted size.
             android.opengl.Matrix.translateM(videoMvp, 0, 0f, glVideoY, 0f)
             android.opengl.Matrix.scaleM(videoMvp, 0, sX * videoScale, sY * videoScale, 1.0f)
        } else {
             android.opengl.Matrix.scaleM(videoMvp, 0, videoScale, videoScale, 1.0f)
        }

        val identityMvp = FloatArray(16)
        android.opengl.Matrix.setIdentityM(identityMvp, 0)
        
        // Calculate Watermark MVP (Position and Scale relative to -1..1 coordinates)
        val watermarkMvp = FloatArray(16)
        android.opengl.Matrix.setIdentityM(watermarkMvp, 0)
        
        // OpenGL coords are -1 to 1. (0,0) is center.
        // x,y are in outWidth/outHeight pixels (0,0 is top-left).
        val glX = (x.toFloat() / outWidth.toFloat()) * 2f - 1f
        val glY = (1f - (y.toFloat() / outHeight.toFloat())) * 2f - 1f // Flip Y for GL
        
        android.opengl.Matrix.translateM(watermarkMvp, 0, glX, glY, 0f)
        android.opengl.Matrix.scaleM(watermarkMvp, 0, boxW / outWidth.toFloat(), boxH / outHeight.toFloat(), 1.0f)

        var frameIndex = 0
        var inputDone = false
        var decoderDone = false
        var lastStepTime = 0L
        isCanceled = false // Reset for new run

        try {
            while (!decoderDone) {
                if (isCanceled) {
                    Log.d(TAG, "Processing loop CANCELED by user")
                    throw Exception("Processing Canceled")
                }
                if (!inputDone) {
                    val idx = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (idx >= 0) {
                        val buf = decoder.getInputBuffer(idx) ?: continue
                        val size = extractor.readSampleData(buf, 0)
                        if (size < 0) {
                            Log.d(TAG, "Input EOS reached")
                            decoder.queueInputBuffer(idx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(idx, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outIdx = decoder.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                if (outIdx >= 0) {
                    val render = bufferInfo.size > 0
                    decoder.releaseOutputBuffer(outIdx, render)
                    if (render) {
                        awaitNewFrame()
                        surfaceTexture.updateTexImage()
                        surfaceTexture.getTransformMatrix(texMatrix)
                        
                        GLES20.glViewport(0, 0, outWidth, outHeight)
                        GLES20.glClearColor(Color.red(bgColor)/255f, Color.green(bgColor)/255f, Color.blue(bgColor)/255f, 1.0f)
                        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

                        // 1. Draw Background Image if available
                        if (bgTexId != 0) {
                            draw2DTexture(bgTexId, bgMvp, 1.0f, bgBrightness, bgSaturation)
                        }

                        GLES20.glEnable(GLES20.GL_BLEND)
                        GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA) // Premultiplied alpha for Android bitmaps

                        // 2. Draw Patches (Bottom/Background layer)
                        if (patchBottomTexId != 0 && patches.any { !it.isTop }) {
                           draw2DTexture(patchBottomTexId, identityMvp, 1.0f)
                        }

                        // 3. Draw Video Shadow
                        if (videoShadowTexId != 0) {
                            GLES20.glEnable(GLES20.GL_BLEND)
                            // Use premultiplied alpha blending for Android Bitmaps
                            GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                            draw2DTexture(videoShadowTexId, videoShadowMvp, 1.0f)
                        }

                        // 4. Draw Video Frame (OES)
                        GLES20.glEnable(GLES20.GL_BLEND)
                        GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                        
                        // Calculate effective dimensions for the shader's corner radius math
                        val aspectIn = inputWidth.toFloat() / inputHeight.toFloat()
                        val aspectOut = outWidth.toFloat() / outHeight.toFloat()
                        val sY = if (aspectIn > aspectOut) aspectOut / aspectIn else 1.0f
                        val sX = if (aspectIn < aspectOut) aspectIn / aspectOut else 1.0f
                        val vW = outWidth * sX
                        val vH = outHeight * sY
                        val rawRadius = (params["videoRadius"] as? Number)?.toFloat() ?: 0f
                        val radiusScale = outWidth / 360f
                        val vRadius = rawRadius * radiusScale
                        val vBorderWidth = (params["videoBorderWidth"] as? Number)?.toFloat() ?: 0f
                        val vBorderColor = params["videoBorderColor"] as? String ?: "#000000"
                        
                        val borderScale = outWidth / 360f
                        val scaledBorderWidth = vBorderWidth * borderScale

                        drawOESTexture(oesTexId, texMatrix, videoMvp, 1.0f, vW, vH, vRadius, scaledBorderWidth, vBorderColor)

                        // If GIF, re-render only the small box and update texture
                        if (movie != null && movie.duration() > 0) {
                            val timeMs = (frameIndex.toLong() * 1000 / FRAME_RATE).toInt() % movie.duration()
                            val gifResult = renderWatermarkBitmap(params, timeMs, movie, outWidth)
                            val fGif = flipBitmapVertically(gifResult.bitmap)
                            updateBitmapTexture(watermarkTexId, fGif)
                            gifResult.bitmap.recycle()
                            fGif.recycle()
                        }

                        // Premultiplied alpha for bitmap-sourced overlays (patches + watermark)
                        GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                        
                        // 4. Draw Patches (Top/Overlay layer) and Text Overlays
                        if (patchTopTexId != 0 && (patches.any { it.isTop } || textOverlays.isNotEmpty())) {
                            draw2DTexture(patchTopTexId, identityMvp, 1.0f)
                        }

                        // 5. Draw Watermark
                        if (params["type"] as? String != "none") {
                            draw2DTexture(watermarkTexId, watermarkMvp, 1.0f)
                        }

                        // 6. Draw Image Overlays
                        for (rt in overlayRuntimes) {
                            // Update GIF frame if animated
                            if (rt.movie != null && rt.movie.duration() > 0) {
                                val timeMs = (frameIndex.toLong() * 1000 / FRAME_RATE).toInt() % rt.movie.duration()
                                val bmp = Bitmap.createBitmap(rt.movie.width(), rt.movie.height(), Bitmap.Config.ARGB_8888)
                                val c = Canvas(bmp)
                                rt.movie.setTime(timeMs)
                                rt.movie.draw(c, 0f, 0f)
                                val f = flipBitmapVertically(bmp)
                                updateBitmapTexture(rt.texId, f)
                                bmp.recycle(); f.recycle()
                            }
                            // Compute MVP
                            val overlayMvp = FloatArray(16)
                            android.opengl.Matrix.setIdentityM(overlayMvp, 0)
                            val glOx = (rt.overlay.x / outWidth.toFloat()) * 2f - 1f
                            val glOy = (1f - (rt.overlay.y / outHeight.toFloat())) * 2f - 1f
                            android.opengl.Matrix.translateM(overlayMvp, 0, glOx, glOy, 0f)
                            // Rotation (degrees -> radians)
                            if (rt.overlay.rotation != 0f) {
                                android.opengl.Matrix.rotateM(overlayMvp, 0, -rt.overlay.rotation, 0f, 0f, 1f)
                            }
                            // Scale: overlay.scale is the fraction of output width the image should span
                            val imgAspect = rt.bitmapW.toFloat() / rt.bitmapH.toFloat()
                            val scaleW = rt.overlay.scale
                            val scaleH = (scaleW * outWidth.toFloat() / imgAspect) / outHeight.toFloat()
                            android.opengl.Matrix.scaleM(overlayMvp, 0, scaleW, scaleH, 1f)
                            draw2DTexture(rt.texId, overlayMvp, rt.overlay.opacity)
                        }

                        GLES20.glDisable(GLES20.GL_BLEND)

                        val pts = bufferInfo.presentationTimeUs * 1000L
                        EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, pts)
                        val swapOk = EGL14.eglSwapBuffers(eglDisplay, eglSurface)
                        if (!swapOk) {
                            Log.e(TAG, "eglSwapBuffers failed! err: ${EGL14.eglGetError()} at frame $frameIndex")
                        }
                        drainEncoder(encoder, muxer, encoderBufferInfo, false)
                        frameIndex++
                        if (frameIndex % 60 == 0) {
                            callback.onProgress(frameIndex.toDouble() / totalFrames)
                            val now = System.currentTimeMillis()
                            if (now - lastStepTime > 3000) {
                                callback.onStep("Rendering frame $frameIndex...")
                                Log.d(TAG, "Processing progress: $frameIndex / $totalFrames")
                                lastStepTime = now
                            }
                        }
                    }
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        Log.d(TAG, "Decoder EOS reached")
                        decoderDone = true
                    }
                }
            }
            callback.onStep("Muxing video tracks...")
            Log.d(TAG, "Phase 7: Final Muxing")
            encoder.signalEndOfInputStream()
            drainEncoder(encoder, muxer, encoderBufferInfo, true)
        } catch (e: Exception) {
            Log.e(TAG, "Processing loop failed: ${e.message}")
            e.printStackTrace()
            throw e
        } finally {
            val overlayTexIds = overlayRuntimes.map { it.texId }.toIntArray()
            cleanup(encoder, encoderSurface, extractor, decoder, decoderSurface, muxer, oesTexId, watermarkTexId, bgTexId, patchTopTexId, patchBottomTexId, videoShadowTexId, *overlayTexIds)
            releaseEGL()
            surfaceTexture.release()
        }

        // 6. Merge audio from source
        if (audioTrackIndex >= 0) {
            callback.onStep("Merging original audio...")
            Log.d(TAG, "Phase 8: Audio Merging")
            val tempFile = File(outputFile.parentFile, "temp_watermark_${System.currentTimeMillis()}.mp4")
            
            if (!outputFile.renameTo(tempFile)) {
                 Log.e(TAG, "Failed to rename pure video to temp file for audio merging!")
                 // Try copying instead if renameTo fails (cross-partition bounds)
                 outputFile.copyTo(tempFile, overwrite = true)
                 outputFile.delete()
            }
            
            var mergeRet = -1
            try {
                mergeRet = FFmpegTextOverlay(context).nativeMergeAudioVideo(tempFile.absolutePath, videoPath, outputFile.absolutePath, effectiveDuration)
                Log.d(TAG, "Audio merge returned code: $mergeRet")
            } catch (e: Exception) {
                Log.e(TAG, "Audio merge exception: ${e.message}")
            }

            if (mergeRet != 0 || !outputFile.exists() || outputFile.length() == 0L) {
                Log.e(TAG, "Audio merge failed (code $mergeRet). Salvaging video-only file.")
                if (outputFile.exists()) outputFile.delete()
                tempFile.renameTo(outputFile)
            } else {
                tempFile.delete()
            }
        }
        Log.d(TAG, "═══ processVideoWithWatermark FINISHED ═══")
        return effectiveDuration
    }

    // ── Watermark Drawing ───────────────────────────────────────────

    class WatermarkResult(val bitmap: Bitmap, val boxWidth: Float, val boxHeight: Float)

    private fun renderWatermarkBitmap(params: Map<String, Any?>, timeMs: Int, movieIn: Movie? = null, targetWidth: Int = 1080): WatermarkResult {
        val type = params["type"] as? String ?: "profile"
        val showBox = params["showBox"] as? Boolean ?: true
        val boxColorStr = params["boxColor"] as? String ?: "#000000"
        val boxOpacity = (params["boxOpacity"] as? Number)?.toFloat() ?: 0.3f
        val watermarkScale = params["watermarkScale"] as? Float ?: 1.0f
        val boxRadius = ((params["boxRadius"] as? Number)?.toFloat() ?: 12f) * watermarkScale

        val username = params["username"] as? String ?: "Username"
        val handle = params["handle"] as? String ?: "@handle"
        val imagePath = params["profileImagePath"] as? String ?: ""
        val textColorStr = params["textColor"] as? String ?: "#000000"
        val accentColorStr = params["accentColor"] as? String ?: "#AAAAAA"
        val fontSize = ((params["fontSize"] as? Number)?.toFloat() ?: 36f) * watermarkScale
        val usernameSize = ((params["usernameSize"] as? Number)?.toFloat() ?: 36f) * watermarkScale
        val handleSize = ((params["handleSize"] as? Number)?.toFloat() ?: 30f) * watermarkScale
        val iconSize = ((params["iconSize"] as? Number)?.toFloat() ?: 100f) * watermarkScale
        val storyRingWidth = ((params["storyRingWidth"] as? Number)?.toFloat() ?: 5f) * watermarkScale
        val fontPath = params["fontPath"] as? String ?: ""
        val showUsernameShadow = params["showUsernameShadow"] as? Boolean ?: false
        val usernameShadowColorStr = params["usernameShadowColor"] as? String ?: "#000000"
        val usernameShadowBlurRaw = ((params["usernameShadowBlur"] as? Number)?.toFloat() ?: 4f) * watermarkScale
        val showHandleShadow = params["showHandleShadow"] as? Boolean ?: false
        val handleShadowColorStr = params["handleShadowColor"] as? String ?: "#000000"
        val handleShadowBlurRaw = ((params["handleShadowBlur"] as? Number)?.toFloat() ?: 4f) * watermarkScale
        val showIconShadow = params["showIconShadow"] as? Boolean ?: false
        val iconShadowColorStr = params["iconShadowColor"] as? String ?: "#000000"
        val iconShadowBlurRaw = ((params["iconShadowBlur"] as? Number)?.toFloat() ?: 4f) * watermarkScale

        val usernameShadowOffsetXRaw = ((params["usernameShadowOffsetX"] as? Number)?.toFloat() ?: 1f) * watermarkScale
        val usernameShadowOffsetYRaw = ((params["usernameShadowOffsetY"] as? Number)?.toFloat() ?: 1f) * watermarkScale
        val handleShadowOffsetXRaw = ((params["handleShadowOffsetX"] as? Number)?.toFloat() ?: 1f) * watermarkScale
        val handleShadowOffsetYRaw = ((params["handleShadowOffsetY"] as? Number)?.toFloat() ?: 1f) * watermarkScale
        val iconShadowOffsetXRaw = ((params["iconShadowOffsetX"] as? Number)?.toFloat() ?: 1.5f) * watermarkScale
        val iconShadowOffsetYRaw = ((params["iconShadowOffsetY"] as? Number)?.toFloat() ?: 1.5f) * watermarkScale

        // Correction factors: Flutter's Shadow.blurRadius (sigma) produces a tighter blur than
        // Android's setShadowLayer radius. Apply 0.5x to blur and 0.75x to offsets to match Flutter.
        val blurFactor = 0.5f
        val offsetFactor = 0.75f
        val usernameShadowBlur = usernameShadowBlurRaw * blurFactor
        val handleShadowBlur = handleShadowBlurRaw * blurFactor
        val iconShadowBlur = iconShadowBlurRaw * blurFactor
        val usernameShadowOffsetX = usernameShadowOffsetXRaw * offsetFactor
        val usernameShadowOffsetY = usernameShadowOffsetYRaw * offsetFactor
        val handleShadowOffsetX = handleShadowOffsetXRaw * offsetFactor
        val handleShadowOffsetY = handleShadowOffsetYRaw * offsetFactor
        val iconShadowOffsetX = iconShadowOffsetXRaw * offsetFactor
        val iconShadowOffsetY = iconShadowOffsetYRaw * offsetFactor
        val handleFontPath = params["handleFontPath"] as? String ?: ""

        val textPaint = android.text.TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor(textColorStr)
            textSize = usernameSize
            style = Paint.Style.FILL
        }
        val handlePaint = android.text.TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor(accentColorStr)
            textSize = handleSize
            style = Paint.Style.FILL
        }

        if (fontPath.isNotEmpty() && File(fontPath).exists()) {
             try { 
                 textPaint.typeface = Typeface.createFromFile(fontPath) 
                 Log.d(TAG, "Successfully loaded username typeface from: $fontPath")
             } catch (e: Exception) {
                 Log.e(TAG, "Failed to load username typeface from $fontPath: ${e.message}")
             }
        } else {
             Log.w(TAG, "Username fontPath is empty or file does not exist: $fontPath")
        }

        if (handleFontPath.isNotEmpty() && File(handleFontPath).exists()) {
             try { 
                 handlePaint.typeface = Typeface.createFromFile(handleFontPath) 
                 Log.d(TAG, "Successfully loaded handle typeface from: $handleFontPath")
             } catch (e: Exception) {
                 Log.e(TAG, "Failed to load handle typeface from $handleFontPath: ${e.message}")
             }
        } else if (fontPath.isNotEmpty() && File(fontPath).exists()) {
             try { 
                 handlePaint.typeface = Typeface.createFromFile(fontPath) 
                 Log.d(TAG, "Fallback: Loaded handle typeface from username fontPath")
             } catch (_: Exception) {}
        }

        // 1. Prepare Content & Icon
        var contentWidth = 0f
        var contentHeight = 0f
        var iconBitmap: Bitmap? = null
        var movie: Movie? = movieIn
        
        val isGif = imagePath.lowercase().endsWith(".gif")
        if (movie == null && imagePath.isNotEmpty() && File(imagePath).exists()) {
            if (isGif) {
                movie = Movie.decodeFile(imagePath)
            } else {
                iconBitmap = BitmapFactory.decodeFile(imagePath)
            }
        }

        val basePadding = fontSize * 0.4f
        val maxBlur = maxOf(if (showUsernameShadow) usernameShadowBlur else 0f, 
                            maxOf(if (showHandleShadow) handleShadowBlur else 0f, 
                                  if (showIconShadow) iconShadowBlur else 0f))
        val maxOffset = maxOf(
            maxOf(if (showUsernameShadow) kotlin.math.abs(usernameShadowOffsetX) else 0f, 
                  if (showUsernameShadow) kotlin.math.abs(usernameShadowOffsetY) else 0f),
            maxOf(if (showHandleShadow) kotlin.math.abs(handleShadowOffsetX) else 0f, 
                  if (showHandleShadow) kotlin.math.abs(handleShadowOffsetY) else 0f),
            maxOf(if (showIconShadow) kotlin.math.abs(iconShadowOffsetX) else 0f, 
                  if (showIconShadow) kotlin.math.abs(iconShadowOffsetY) else 0f)
        )
        val extraPadding = (maxBlur * 2.5f + maxOffset + 5f).coerceAtLeast(0f)
        val padding = basePadding + extraPadding

        when (type) {
            "profile", "profile_vertical", "profile_dots" -> {
                val showStoryRing = params["showStoryRing"] as? Boolean ?: false
                val isVerified = params["isVerified"] as? Boolean ?: false
                
                val verifiedBadgeColor = params["verifiedBadgeColor"] as? String ?: "#1DA1F2"
                val verifiedBadgeAttachTo = params["verifiedBadgeAttachTo"] as? String ?: "handle"
                
                if (iconBitmap != null) {
                    iconBitmap = getCircularBitmap(iconBitmap, iconSize.toInt())
                } else if (movie != null && movie.width() > 0 && movie.height() > 0) {
                    val temp = Bitmap.createBitmap(iconSize.toInt(), iconSize.toInt(), Bitmap.Config.ARGB_8888)
                    val tc = Canvas(temp)
                    movie.setTime(timeMs)
                    val s = iconSize / minOf(movie.width(), movie.height()).toFloat()
                    tc.scale(s, s)
                    // Center the frame in the temp bitmap
                    val dx = (iconSize / s - movie.width()) / 2f
                    val dy = (iconSize / s - movie.height()) / 2f
                    movie.draw(tc, dx, dy)
                    iconBitmap = getCircularBitmap(temp, iconSize.toInt())
                    temp.recycle()
                }

                val verifiedBadgeSize = fontSize * 0.9f
                val verifiedGap = if (isVerified) verifiedBadgeSize * 0.5f else 0f
                val nameW = textPaint.measureText(username)
                val handleW = handlePaint.measureText(handle)
                
                val usernameWithBadgeW = if (isVerified && verifiedBadgeAttachTo == "username") nameW + verifiedBadgeSize + verifiedGap else nameW
                val handleWithBadgeW = if (isVerified && verifiedBadgeAttachTo == "handle") handleW + verifiedBadgeSize + verifiedGap else handleW
                
                val textW = maxOf(usernameWithBadgeW, handleWithBadgeW)
                
                val ringExtra = if (showStoryRing) storyRingWidth * 2.2f else 0f
                val iconW = if (iconBitmap != null || (movie != null && movie.width() > 0)) iconSize + ringExtra else 0f
                
                if (type == "profile_vertical") {
                    contentWidth = maxOf(iconW, textW)
                    contentHeight = iconW + (if (iconW > 0) 12f else 0f) + (usernameSize + handleSize + 12f)
                } else if (type == "profile_dots") {
                    val scale = (params["watermarkScale"] as? Number)?.toFloat() ?: 1.0f
                    contentWidth = (targetWidth * scale) - (padding * 2) 
                    contentHeight = maxOf(iconW, maxOf(usernameSize, handleSize) * 2.3f)
                } else {
                    val gap = if (iconW > 0) 24f else 0f
                    contentWidth = iconW + gap + textW
                    contentHeight = maxOf(iconW, maxOf(usernameSize, handleSize) * 2.3f)
                }
            }
            "text" -> {
                contentWidth = textPaint.measureText(username)
                contentHeight = fontSize
            }
            "image" -> {
                if (iconBitmap != null) {
                    val aspect = iconBitmap.width.toFloat() / iconBitmap.height.toFloat()
                    if (aspect > 1f) {
                        contentWidth = iconSize; contentHeight = iconSize / aspect
                    } else {
                        contentWidth = iconSize * aspect; contentHeight = iconSize
                    }
                } else if (movie != null && movie.width() > 0) {
                    val aspect = movie.width().toFloat() / movie.height().toFloat()
                    if (aspect > 1f) {
                        contentWidth = iconSize; contentHeight = iconSize / aspect
                    } else {
                        contentWidth = iconSize * aspect; contentHeight = iconSize
                    }
                } else {
                    contentWidth = iconSize; contentHeight = iconSize
                }
            }
        }

        
        val boxW = contentWidth + (padding * 2)
        val boxH = contentHeight + (padding * 2)

        // CREATE SMALL BITMAP instead of full video size
        val bitmap = Bitmap.createBitmap(boxW.toInt().coerceAtLeast(1), boxH.toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // 2. Draw Box
        if (showBox) {
            val boxPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            val baseColor = Color.parseColor(boxColorStr)
            boxPaint.color = Color.argb((boxOpacity * 255).toInt(), Color.red(baseColor), Color.green(baseColor), Color.blue(baseColor))
            canvas.drawRoundRect(extraPadding, extraPadding, extraPadding + contentWidth + basePadding * 2, extraPadding + contentHeight + basePadding * 2, boxRadius, boxRadius, boxPaint)
        }

        // 3. Draw Content
        canvas.save()
        canvas.translate(padding, padding)
        
        when (type) {
            "profile", "profile_vertical", "profile_dots" -> {
                val showStoryRing = params["showStoryRing"] as? Boolean ?: false
                val isVerified = params["isVerified"] as? Boolean ?: false
                val verifiedBadgeColor = params["verifiedBadgeColor"] as? String ?: "#1DA1F2"
                val verifiedBadgeAttachTo = params["verifiedBadgeAttachTo"] as? String ?: "handle"
                val isVertical = type == "profile_vertical"
                val hasDots = type == "profile_dots"
                
                var curX = 0f
                var curY = 0f
                
                val ringExtra = if (showStoryRing) fontSize * 0.45f else 0f
                val iconW = if (iconBitmap != null) iconSize + ringExtra else 0f
                
                if (iconBitmap != null) {
                    val iconCenter = iconW / 2f
                    val iconDrawX = if (isVertical) (contentWidth / 2f) - iconCenter else 0f
                    val iconDrawY = if (isVertical) 0f else (contentHeight / 2f) - iconCenter
                    
                    if (showStoryRing) {
                        val storyRingColorStr = params["storyRingColor"] as? String ?: "gradient"
                        val ringP = Paint(Paint.ANTI_ALIAS_FLAG)
                        ringP.style = Paint.Style.STROKE
                        ringP.strokeWidth = storyRingWidth
                        
                        if (storyRingColorStr == "gradient") {
                            val colors = intArrayOf(
                                Color.parseColor("#FCAF45"),
                                Color.parseColor("#F56040"),
                                Color.parseColor("#E1306C"),
                                Color.parseColor("#C13584"),
                                Color.parseColor("#FCAF45")
                            )
                            val shader = SweepGradient(iconDrawX + iconCenter, iconDrawY + iconCenter, colors, null)
                            ringP.shader = shader
                        } else {
                            try {
                                ringP.color = Color.parseColor(storyRingColorStr)
                            } catch (e: Exception) {
                                ringP.color = Color.parseColor("#FCAF45") // Fallback
                            }
                        }
                        // Draw ring exactly around iconSize
                        canvas.drawCircle(iconDrawX + iconCenter, iconDrawY + iconCenter, (iconSize + ringP.strokeWidth) / 2f, ringP)
                    }
                    
                    if (showIconShadow) {
                        val iconShadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color = Color.parseColor(iconShadowColorStr)
                            setShadowLayer(iconShadowBlur.coerceAtLeast(0.1f), iconShadowOffsetX, iconShadowOffsetY, color)
                        }
                        canvas.drawCircle(iconDrawX + iconCenter, iconDrawY + iconCenter, iconSize / 2f, iconShadowPaint)
                    }

                    val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
                    canvas.drawBitmap(iconBitmap, iconDrawX + (iconCenter - iconSize/2f), iconDrawY + (iconCenter - iconSize/2f), iconPaint)
                    
                    if (isVertical) curY = iconW + 12f else curX = iconW + 24f
                }
                
                val fm = textPaint.fontMetrics
                val verifiedBadgeSize = fontSize * 0.85f
                val verifiedGap = if (isVerified) fontSize * 0.3f else 0f
                val nameW = textPaint.measureText(username)
                val handleW = handlePaint.measureText(handle)
                
                if (isVertical) {
                    // Centered text for vertical
                    val usernameWithBadgeW = if (isVerified && verifiedBadgeAttachTo == "username") nameW + verifiedBadgeSize + verifiedGap else nameW
                    val handleWithBadgeW = if (isVerified && verifiedBadgeAttachTo == "handle") handleW + verifiedBadgeSize + verifiedGap else handleW
                    
                    val nameStartX = (contentWidth - usernameWithBadgeW) / 2f
                    val nameY = curY - fm.ascent
                    textPaint.clearShadowLayer() 
                    if (showUsernameShadow) {
                        textPaint.setShadowLayer(usernameShadowBlur.coerceAtLeast(0.1f), usernameShadowOffsetX, usernameShadowOffsetY, Color.parseColor(usernameShadowColorStr))
                    }
                    canvas.drawText(username, nameStartX, nameY, textPaint)
                    
                    if (isVerified && verifiedBadgeAttachTo == "username") {
                        drawVerifiedBadge(canvas, nameStartX + nameW + verifiedGap, nameY - (verifiedBadgeSize * 0.75f), verifiedBadgeSize, verifiedBadgeColor)
                    }
                    
                    val handleY = nameY + (fontSize * 1.05f)
                    val handleStartX = (contentWidth - handleWithBadgeW) / 2f
                    handlePaint.clearShadowLayer()
                    if (showHandleShadow) {
                        handlePaint.setShadowLayer(handleShadowBlur.coerceAtLeast(0.1f), handleShadowOffsetX, handleShadowOffsetY, Color.parseColor(handleShadowColorStr))
                    }
                    canvas.drawText(handle, handleStartX, handleY, handlePaint)
                    
                    if (isVerified && verifiedBadgeAttachTo == "handle") {
                        drawVerifiedBadge(canvas, handleStartX + handleW + verifiedGap, handleY - (verifiedBadgeSize * 0.75f), verifiedBadgeSize, verifiedBadgeColor)
                    }
                } else {
                    // Horizontal layout
                    val textBaselineY = (contentHeight / 2f) - ((fm.descent + fm.ascent) / 2f) - (fontSize * 0.5f)
                    textPaint.clearShadowLayer()
                    if (showUsernameShadow) {
                        textPaint.setShadowLayer(usernameShadowBlur.coerceAtLeast(0.1f), usernameShadowOffsetX, usernameShadowOffsetY, Color.parseColor(usernameShadowColorStr))
                    }
                    canvas.drawText(username, curX, textBaselineY, textPaint)
                    
                    if (isVerified && verifiedBadgeAttachTo == "username") {
                        drawVerifiedBadge(canvas, curX + nameW + verifiedGap, textBaselineY - (verifiedBadgeSize * 0.75f), verifiedBadgeSize, verifiedBadgeColor)
                    }
                    
                    val handleY = textBaselineY + handleSize * 1.15f
                    handlePaint.clearShadowLayer()
                    if (showHandleShadow) {
                        handlePaint.setShadowLayer(handleShadowBlur.coerceAtLeast(0.1f), handleShadowOffsetX, handleShadowOffsetY, Color.parseColor(handleShadowColorStr))
                    }
                    canvas.drawText(handle, curX, handleY, handlePaint)
                    
                    if (isVerified && verifiedBadgeAttachTo == "handle") {
                        drawVerifiedBadge(canvas, curX + handleW + verifiedGap, handleY - (verifiedBadgeSize * 0.75f), verifiedBadgeSize, verifiedBadgeColor)
                    }

                    val usernameWithBadgeW = if (isVerified && verifiedBadgeAttachTo == "username") nameW + verifiedBadgeSize + verifiedGap else nameW
                    val handleWithBadgeW = if (isVerified && verifiedBadgeAttachTo == "handle") handleW + verifiedBadgeSize + verifiedGap else handleW
                    val textW = maxOf(usernameWithBadgeW, handleWithBadgeW)

                    if (hasDots) {
                        val dotsX = contentWidth - (fontSize * 0.4f)
                        val dotY = (contentHeight / 2f) + (fontSize * 0.15f)
                        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color = Color.parseColor(accentColorStr)
                        }
                        val dotRadius = fontSize * 0.12f
                        val dotSpacing = fontSize * 0.35f
                        canvas.drawCircle(dotsX - dotSpacing * 2f, dotY, dotRadius, dotPaint)
                        canvas.drawCircle(dotsX - dotSpacing, dotY, dotRadius, dotPaint)
                        canvas.drawCircle(dotsX, dotY, dotRadius, dotPaint)
                    }
                }
            }
            "text" -> {
                val fm = textPaint.fontMetrics
                val textBaselineY = (contentHeight / 2f) - ((fm.descent + fm.ascent) / 2f)
                textPaint.clearShadowLayer()
                if (showUsernameShadow) {
                    textPaint.setShadowLayer(usernameShadowBlur.coerceAtLeast(0.1f), usernameShadowOffsetX, usernameShadowOffsetY, Color.parseColor(usernameShadowColorStr))
                }
                canvas.drawText(username, 0f, textBaselineY, textPaint)
            }
            "image" -> {
                if (iconBitmap != null) {
                    val dest = RectF(0f, 0f, contentWidth, contentHeight)
                    canvas.drawBitmap(iconBitmap, null, dest, null)
                } else if (movie != null && movie.width() > 0) {
                    canvas.save()
                    canvas.scale(contentWidth / movie.width().toFloat(), contentHeight / movie.height().toFloat())
                    movie.setTime(timeMs)
                    movie.draw(canvas, 0f, 0f)
                    canvas.restore()
                }
            }
        }

        iconBitmap?.recycle()
        canvas.restore()
        return WatermarkResult(bitmap, boxW, boxH)
    }

    private fun getCircularBitmap(src: Bitmap, size: Int): Bitmap {
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        
        // Calculate centered square crop and scale
        val srcW = src.width.toFloat()
        val srcH = src.height.toFloat()
        val minDim = minOf(srcW, srcH)
        
        val scale = size / minDim
        val dx = (size - srcW * scale) / 2f
        val dy = (size - srcH * scale) / 2f
        
        val matrix = android.graphics.Matrix()
        matrix.setScale(scale, scale)
        matrix.postTranslate(dx, dy)
        
        // Use BitmapShader for flawless circular rendering
        val shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        shader.setLocalMatrix(matrix)
        
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        paint.shader = shader
        
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        
        return output
    }

    private fun updateBitmapTexture(texId: Int, bitmap: Bitmap) {
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLUtils.texSubImage2D(GLES20.GL_TEXTURE_2D, 0, 0, 0, bitmap)
    }

    private fun createEmptyTexture(w: Int, h: Int): Int {
        val tex = IntArray(1); GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, w, h, 0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        return tex[0]
    }

    private fun updatePatchTexture(texId: Int, patchList: List<Patch>, textList: List<TextOverlay>, w: Int, h: Int) {
        if (patchList.isEmpty() && textList.isEmpty()) return
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        
        for (p in patchList) {
            val baseColor = try { Color.parseColor(p.color) } catch (_: Exception) { Color.BLACK }
            paint.color = Color.argb((p.opacity * 255).toInt(), Color.red(baseColor), Color.green(baseColor), Color.blue(baseColor))
            val rect = RectF(p.x, p.y, p.x + p.width, p.y + p.height)
            if (p.radius > 0) {
                canvas.drawRoundRect(rect, p.radius, p.radius, paint)
            } else {
                canvas.drawRect(rect, paint)
            }
        }
        
        val textPaint = android.text.TextPaint(Paint.ANTI_ALIAS_FLAG)
        for (t in textList) {
            textPaint.color = try { Color.parseColor(t.color) } catch (_: Exception) { Color.WHITE }
            textPaint.textSize = t.fontSize
            
            if (t.showShadow) {
                val shadowColorMapped = try { Color.parseColor(t.shadowColor) } catch (_: Exception) { Color.BLACK }
                textPaint.setShadowLayer(t.shadowBlur, t.shadowOffsetX, t.shadowOffsetY, shadowColorMapped)
            } else {
                textPaint.clearShadowLayer()
            }
            
            if (t.fontPath.isNotEmpty() && File(t.fontPath).exists()) {
                try { textPaint.typeface = Typeface.createFromFile(t.fontPath) } catch (_: Exception) {}
            } else {
                textPaint.typeface = Typeface.DEFAULT
            }
            
            textPaint.letterSpacing = t.letterSpacing
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                textPaint.wordSpacing = t.wordSpacing
            }
            
            val alignment = when (t.textAlign.lowercase()) {
                "left" -> Layout.Alignment.ALIGN_NORMAL
                "right" -> Layout.Alignment.ALIGN_OPPOSITE
                else -> Layout.Alignment.ALIGN_CENTER
            }

            val builder = StaticLayout.Builder.obtain(t.text, 0, t.text.length, textPaint, t.maxWidth.toInt())
                .setAlignment(alignment)
                .setLineSpacing(0f, t.lineHeight)
                .setIncludePad(false)
            
            val staticLayout = builder.build()
            
            // Measure actual content bounding box
            var maxLineWidth = 0f
            for (i in 0 until staticLayout.lineCount) {
                maxLineWidth = maxOf(maxLineWidth, staticLayout.getLineWidth(i))
            }
            
            val startX = when (t.textAlign.lowercase()) {
                "left" -> 0f
                "right" -> t.maxWidth - maxLineWidth
                else -> (t.maxWidth - maxLineWidth) / 2f
            }
            
            val minX = startX
            val maxX = startX + maxLineWidth
            val minY = 0f
            val maxY = staticLayout.height.toFloat()
            
            // Always use center anchoring (matching the simplified UI)
            val offsetX = -(minX + maxX) / 2f
            val offsetY = -(minY + maxY) / 2f
            
            canvas.save()
            canvas.translate(t.x + offsetX, t.y + offsetY)
            staticLayout.draw(canvas)
            canvas.restore()
        }
        
        val flip = flipBitmapVertically(bitmap)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, flip, 0)
        bitmap.recycle(); flip.recycle()
    }

    // ── GL Utilities (OES, Program, etc) ───────────────────────────
    // (Similar to TextOverlay but simplified for single pass)

    private fun drawVerifiedBadge(canvas: Canvas, x: Float, y: Float, size: Float, colorHex: String = "#1DA1F2") {
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        try {
            p.color = Color.parseColor(colorHex)
        } catch (e: Exception) {
            p.color = Color.parseColor("#1DA1F2")
        }
        
        val centerX = x + size / 2f
        val centerY = y + size / 2f
        val radius = size / 2f
        
        // Draw the scalloped/star shape (Meta/IG verified badge)
        val path = Path()
        val points = 24
        val innerRadius = radius * 0.88f
        for (i in 0 until points) {
            val angle = Math.PI * 2 * i / points
            val r = if (i % 2 == 0) radius else innerRadius
            val px = centerX + (r * Math.cos(angle)).toFloat()
            val py = centerY + (r * Math.sin(angle)).toFloat()
            if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
        }
        path.close()
        canvas.drawPath(path, p)
        
        // Draw the white tick
        p.color = Color.WHITE
        p.style = Paint.Style.STROKE
        p.strokeWidth = size * 0.12f
        p.strokeCap = Paint.Cap.ROUND
        p.strokeJoin = Paint.Join.ROUND
        
        val tick = Path()
        tick.moveTo(x + size * 0.28f, y + size * 0.5f)
        tick.lineTo(x + size * 0.45f, y + size * 0.67f)
        tick.lineTo(x + size * 0.72f, y + size * 0.38f)
        canvas.drawPath(tick, p)
    }

    private fun createOESTexture(): Int {
        val tex = IntArray(1); GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, tex[0])
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        return tex[0]
    }

    private fun loadBitmapTexture(bitmap: Bitmap): Int {
        val tex = IntArray(1); GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        return tex[0]
    }

    private fun initGL(w: Int, h: Int) {
        programOES = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_OES)
        program2D = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_2D)
        programBlurH = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_BLUR_H)
        programBlurV = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_BLUR_V)
        createFBOs(w, h)
    }

    private fun createProgram(vs: String, fs: String): Int {
        val v = GLES20.glCreateShader(GLES20.GL_VERTEX_SHADER).apply { GLES20.glShaderSource(this, vs); GLES20.glCompileShader(this) }
        val f = GLES20.glCreateShader(GLES20.GL_FRAGMENT_SHADER).apply { GLES20.glShaderSource(this, fs); GLES20.glCompileShader(this) }
        return GLES20.glCreateProgram().apply { GLES20.glAttachShader(this, v); GLES20.glAttachShader(this, f); GLES20.glLinkProgram(this) }
    }

    private fun drawOESTexture(
        texId: Int, 
        texMat: FloatArray, 
        mvp: FloatArray, 
        alpha: Float, 
        width: Float = 1080f, 
        height: Float = 1920f, 
        radius: Float = 0f,
        borderWidth: Float = 0f,
        borderColor: String = "#FFFFFF"
    ) {
        GLES20.glUseProgram(programOES)
        val pos = GLES20.glGetAttribLocation(programOES, "aPosition")
        val tex = GLES20.glGetAttribLocation(programOES, "aTexCoord")
        GLES20.glEnableVertexAttribArray(pos); GLES20.glVertexAttribPointer(pos, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(tex); GLES20.glVertexAttribPointer(tex, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(programOES, "uMVPMatrix"), 1, false, mvp, 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(programOES, "uTexMatrix"), 1, false, texMat, 0)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(programOES, "uAlpha"), alpha)
        GLES20.glUniform2f(GLES20.glGetUniformLocation(programOES, "uSize"), width, height)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(programOES, "uRadius"), radius)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(programOES, "uBorderWidth"), borderWidth)
        
        val color = try { Color.parseColor(borderColor) } catch (e: Exception) { Color.WHITE }
        GLES20.glUniform3f(GLES20.glGetUniformLocation(programOES, "uBorderColor"), 
            Color.red(color)/255f, Color.green(color)/255f, Color.blue(color)/255f)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0); GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun draw2DTexture(texId: Int, mvp: FloatArray, alpha: Float, brightness: Float = 1.0f, saturation: Float = 1.0f) {
        GLES20.glUseProgram(program2D)
        val pos = GLES20.glGetAttribLocation(program2D, "aPosition")
        val tex = GLES20.glGetAttribLocation(program2D, "aTexCoord")
        GLES20.glEnableVertexAttribArray(pos); GLES20.glVertexAttribPointer(pos, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(tex); GLES20.glVertexAttribPointer(tex, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        val iden = FloatArray(16); android.opengl.Matrix.setIdentityM(iden, 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program2D, "uMVPMatrix"), 1, false, mvp, 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program2D, "uTexMatrix"), 1, false, iden, 0)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program2D, "uAlpha"), alpha)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program2D, "uBrightness"), brightness)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(program2D, "uSaturation"), saturation)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0); GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun drawBlurH(texId: Int, scale: Float, width: Int) {
        GLES20.glUseProgram(programBlurH)
        val pos = GLES20.glGetAttribLocation(programBlurH, "aPosition")
        val tex = GLES20.glGetAttribLocation(programBlurH, "aTexCoord")
        GLES20.glEnableVertexAttribArray(pos); GLES20.glVertexAttribPointer(pos, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(tex); GLES20.glVertexAttribPointer(tex, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        val iden = FloatArray(16); android.opengl.Matrix.setIdentityM(iden, 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(programBlurH, "uMVPMatrix"), 1, false, iden, 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(programBlurH, "uTexMatrix"), 1, false, iden, 0)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(programBlurH, "uTexelWidth"), scale / width.toFloat())
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0); GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun drawBlurV(texId: Int, scale: Float, height: Int) {
        GLES20.glUseProgram(programBlurV)
        val pos = GLES20.glGetAttribLocation(programBlurV, "aPosition")
        val tex = GLES20.glGetAttribLocation(programBlurV, "aTexCoord")
        GLES20.glEnableVertexAttribArray(pos); GLES20.glVertexAttribPointer(pos, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(tex); GLES20.glVertexAttribPointer(tex, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        val iden = FloatArray(16); android.opengl.Matrix.setIdentityM(iden, 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(programBlurV, "uMVPMatrix"), 1, false, iden, 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(programBlurV, "uTexMatrix"), 1, false, iden, 0)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(programBlurV, "uTexelHeight"), scale / height.toFloat())
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0); GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun createFBOs(w: Int, h: Int) {
        val fbos = IntArray(2); GLES20.glGenFramebuffers(2, fbos, 0)
        fboA = fbos[0]; fboB = fbos[1]
        val texs = IntArray(2); GLES20.glGenTextures(2, texs, 0)
        fboTexA = texs[0]; fboTexB = texs[1]
        for (i in 0..1) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texs[i])
            GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, w, h, 0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbos[i])
            GLES20.glFramebufferTexture2D(GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0, GLES20.GL_TEXTURE_2D, texs[i], 0)
        }
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
    }

    private fun destroyFBOs() {
        if (fboA != 0) GLES20.glDeleteFramebuffers(2, intArrayOf(fboA, fboB), 0)
        if (fboTexA != 0) GLES20.glDeleteTextures(2, intArrayOf(fboTexA, fboTexB), 0)
        if (patchTopTexId != 0) GLES20.glDeleteTextures(1, intArrayOf(patchTopTexId), 0)
        if (patchBottomTexId != 0) GLES20.glDeleteTextures(1, intArrayOf(patchBottomTexId), 0)
    }

    private fun initEGL(surface: Surface) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val ver = IntArray(2); EGL14.eglInitialize(eglDisplay, ver, 0, ver, 1)
        val config = arrayOfNulls<android.opengl.EGLConfig>(1)
        val num = IntArray(1)
        val attr = intArrayOf(
            EGL14.EGL_RED_SIZE, 8, 
            EGL14.EGL_GREEN_SIZE, 8, 
            EGL14.EGL_BLUE_SIZE, 8, 
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT, 
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
            EGL14.EGL_NONE
        )
        EGL14.eglChooseConfig(eglDisplay, attr, 0, config, 0, 1, num, 0)
        eglContext = EGL14.eglCreateContext(eglDisplay, config[0], EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, config[0], surface, intArrayOf(EGL14.EGL_NONE), 0)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun releaseEGL() {
        EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
        EGL14.eglDestroySurface(eglDisplay, eglSurface)
        EGL14.eglDestroyContext(eglDisplay, eglContext)
        EGL14.eglTerminate(eglDisplay)
    }

    private fun awaitNewFrame() {
        synchronized(frameSyncObject) { while (!frameAvailable) frameSyncObject.wait(500); frameAvailable = false }
    }

    private fun drainEncoder(encoder: MediaCodec, muxer: MediaMuxer, info: MediaCodec.BufferInfo, eos: Boolean) {
        val timeout = if (eos) 10000L else 0L
        while (true) {
            val idx = encoder.dequeueOutputBuffer(info, timeout)
            if (idx == MediaCodec.INFO_TRY_AGAIN_LATER) {
                if (!eos) break else continue
            }
            if (idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                muxerTrackIndex = muxer.addTrack(encoder.outputFormat)
                muxer.start()
                muxerStarted = true
                Log.d("GLWatermark", "Muxer started with trackIndex: $muxerTrackIndex")
                continue
            }
            if (idx < 0) continue
            val buf = encoder.getOutputBuffer(idx) ?: continue
            if (info.size > 0 && muxerStarted) {
                buf.position(info.offset)
                buf.limit(info.offset + info.size)
                muxer.writeSampleData(muxerTrackIndex, buf, info)
                muxedFrameCount++
            } else if (info.size > 0 && !muxerStarted) {
                Log.e("GLWatermark", "Dropping frame! Muxer not started yet.")
            }
            encoder.releaseOutputBuffer(idx, false)
            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                Log.d("GLWatermark", "Encoder EOS received. Muxed total frames: $muxedFrameCount")
                break
            }
        }
    }

    private fun flipBitmapVertically(src: Bitmap): Bitmap {
        val m = android.graphics.Matrix(); m.preScale(1f, -1f)
        return Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
    }

    private fun cleanup(enc: MediaCodec, encSur: Surface, ext: MediaExtractor, dec: MediaCodec, decSur: Surface, mux: MediaMuxer, vararg texs: Int) {
        try { dec.stop(); dec.release(); decSur.release() } catch (_: Exception) {}
        try { enc.stop(); enc.release(); encSur.release() } catch (_: Exception) {}
        try { ext.release() } catch (_: Exception) {}
        try { if (muxerStarted) mux.stop(); mux.release() } catch (_: Exception) {}
        
        val validTexs = texs.filter { it != 0 }
        if (validTexs.isNotEmpty()) {
            GLES20.glDeleteTextures(validTexs.size, validTexs.toIntArray(), 0)
        }
    }

    class VideoShadowResult(val bitmap: Bitmap, val fullWidth: Float, val fullHeight: Float)

    private fun renderVideoShadowBitmap(
        width: Float, 
        height: Float, 
        colorStr: String, 
        blur: Float, 
        spread: Float,
        radius: Float = 0f
    ): VideoShadowResult {
        // Padding for blur and spread - needs to be generous to avoid clipping
        val padding = (blur * 4 + spread * 2).toInt().coerceAtLeast(40)
        val bmpW = (width + padding).toInt()
        val bmpH = (height + padding).toInt()
        
        val bitmap = Bitmap.createBitmap(bmpW, bmpH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        
        val shadowColor = try { Color.parseColor(colorStr) } catch (e: Exception) { Color.BLACK }
        
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = shadowColor
            style = Paint.Style.FILL
            if (blur > 0) {
                // NORMAL blur provides the softest, most accurate Gaussian falloff.
                maskFilter = BlurMaskFilter(blur.coerceAtLeast(0.1f), BlurMaskFilter.Blur.NORMAL)
            }
        }
        
        // The rect is centered in the bitmap and expanded by 'spread'
        // We use spread/2 because we want to expand by 'spread' in total width/height 
        // (Wait, Flutter's spreadRadius expands by that amount on EACH side)
        // So rect should be expanded by 'spread' on each side.
        val rectX = (bmpW - width) / 2f - spread
        val rectY = (bmpH - height) / 2f - spread
        val shadowRect = RectF(
            rectX,
            rectY,
            rectX + width + spread * 2,
            rectY + height + spread * 2
        )
        
        // Draw twice for density - this solves the "faded" look while keeping the edges soft
        if (radius > 0) {
            canvas.drawRoundRect(shadowRect, radius + spread, radius + spread, paint)
            canvas.drawRoundRect(shadowRect, radius + spread, radius + spread, paint)
        } else {
            canvas.drawRect(shadowRect, paint)
            canvas.drawRect(shadowRect, paint)
        }
        return VideoShadowResult(bitmap, bmpW.toFloat(), bmpH.toFloat())
    }
}
