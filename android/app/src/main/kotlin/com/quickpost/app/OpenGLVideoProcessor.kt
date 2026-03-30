package com.quickpost.app

import android.content.Context
import android.graphics.SurfaceTexture
import android.media.*
import android.opengl.*
import android.util.Log
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * GPU-accelerated video processor using OpenGL ES + MediaCodec hardware pipeline.
 *
 * Pipeline:
 *   Input Video → MediaCodec Decoder → SurfaceTexture (OES texture on GPU)
 *                                            ↓
 *                                   OpenGL ES Render (blur bg, scale, corners, fade, stroke)
 *                                            ↓
 *                                   MediaCodec Encoder Input Surface (hardware encode)
 *                                            ↓
 *                                   MediaMuxer → Output .mp4
 *
 * Everything stays on GPU — no CPU-side pixel copies.
 */
class OpenGLVideoProcessor(private val context: Context) {

    companion object {
        private const val TAG = "OpenGLVideoProcessor"
        private const val OUTPUT_WIDTH = 1080
        private const val OUTPUT_HEIGHT = 1920
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 1
        private const val DEFAULT_BITRATE = 6_000_000
        private const val TIMEOUT_US = 10_000L
    }

    interface ProgressCallback {
        fun onProgress(progress: Double)
        fun onStep(step: String)
    }

    // ── Shader sources ──────────────────────────────────────────────

    // Draws an external OES texture (from SurfaceTexture / decoder)
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

    // OES fragment shader – samples from decoded video frame
    private val FRAGMENT_SHADER_OES = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        varying vec2 vTexCoord;
        uniform samplerExternalOES sTexture;
        uniform float uAlpha;
        void main() {
            vec4 color = texture2D(sTexture, vTexCoord);
            gl_FragColor = vec4(color.rgb * uAlpha, color.a * uAlpha);
        }
    """.trimIndent()

    // 2D fragment shader – samples from FBO texture (for blur pass / compositing)
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
            
            // Apply Saturation
            rgb = applySaturation(rgb, uSaturation);
            
            // Apply Brightness
            rgb = rgb * uBrightness;
            
            gl_FragColor = vec4(rgb * uAlpha, color.a * uAlpha);
        }
    """.trimIndent()

    // Horizontal box blur
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

    // Vertical box blur
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

    // Compositing shader: draws the foreground frame with rounded corners + stroke
    // Works in pixel coordinates for precision
    private val FRAGMENT_SHADER_COMPOSITE = """
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D sTexture;
        uniform float uAlpha;
        
        // Rect of the image in NDC-mapped pixel coords
        uniform vec2 uRectCenter;    // center in pixels
        uniform vec2 uRectHalfSize;  // half-size in pixels
        uniform float uCornerRadius; // in pixels
        uniform float uStrokeWidth;  // in pixels
        uniform vec4 uStrokeColor;
        uniform vec2 uOutputSize;    // output resolution
        uniform int uEnableCorners;
        uniform int uEnableStroke;
        
        float roundedBoxSDF(vec2 p, vec2 b, float r) {
            vec2 d = abs(p) - b + vec2(r);
            return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
        }
        
        void main() {
            vec4 texColor = texture2D(sTexture, vTexCoord);
            
            // Convert tex coord to pixel position
            vec2 pixelPos = vTexCoord * uOutputSize;
            vec2 p = pixelPos - uRectCenter;
            
            if (uEnableCorners == 0 && uEnableStroke == 0) {
                gl_FragColor = vec4(texColor.rgb * uAlpha, texColor.a * uAlpha);
                return;
            }
            
            float radius = uCornerRadius;
            float dist = roundedBoxSDF(p, uRectHalfSize, radius);
            
            // Anti-aliasing
            float aa = 1.0;
            
            if (uEnableStroke == 1 && uStrokeWidth > 0.0) {
                // Outside outer rounded rect = transparent (show bg)
                float outerHalf = uStrokeWidth * 0.5;
                float outerDist = roundedBoxSDF(p, uRectHalfSize + vec2(outerHalf), radius + outerHalf);
                float outerMask = 1.0 - smoothstep(-aa, aa, outerDist);
                
                // Inside inner rounded rect = show image
                float innerDist = roundedBoxSDF(p, uRectHalfSize - vec2(outerHalf), max(radius - outerHalf, 0.0));
                float innerMask = 1.0 - smoothstep(-aa, aa, innerDist);
                
                // Compose: bg outside, stroke ring, image inside
                vec4 result = vec4(0.0); // transparent = show bg underneath
                result = mix(result, vec4(uStrokeColor.rgb * uAlpha, uStrokeColor.a * uAlpha), outerMask);  // stroke
                result = mix(result, vec4(texColor.rgb * uAlpha, texColor.a * uAlpha), innerMask);           // image
                gl_FragColor = result;
            } else {
                // Just rounded corners, no stroke
                float mask = 1.0 - smoothstep(-aa, aa, dist);
                gl_FragColor = vec4(texColor.rgb * uAlpha, texColor.a * uAlpha * mask);
            }
        }
    """.trimIndent()

    // Quad geometry
    private val QUAD_COORDS = floatArrayOf(
        -1f, -1f, 0f,
         1f, -1f, 0f,
        -1f,  1f, 0f,
         1f,  1f, 0f
    )
    private val QUAD_TEX_COORDS = floatArrayOf(
        0f, 0f,
        1f, 0f,
        0f, 1f,
        1f, 1f
    )

    private lateinit var vertexBuffer: FloatBuffer
    private lateinit var texCoordBuffer: FloatBuffer

    // GL handles
    private var programOES = 0
    private var program2D = 0
    private var programBlurH = 0
    private var programBlurV = 0
    private var programComposite = 0

    // FBO for offscreen rendering passes
    private var fboA = 0
    private var fboTexA = 0
    private var fboB = 0
    private var fboTexB = 0
    private var fboC = 0
    private var fboTexC = 0

    // EGL
    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    // Muxer state (must persist across drainEncoder calls)
    private var muxerTrackIndex = -1
    private var muxerStarted = false

    // Frame sync
    private val frameSyncObject = Object()
    private var frameAvailable = false

    // ── Public entry point ──────────────────────────────────────────

    fun processVideo(
        videoPath: String,
        outputFile: File,
        targetDuration: Int,
        fadeInDurationSeconds: Double,
        settings: Map<String, Any>?,
        qualitySettings: Map<String, Any>?,
        callback: ProgressCallback
    ): Int {
        Log.d(TAG, "═══ processVideo START ═══")
        Log.d(TAG, "  videoPath=$videoPath")
        Log.d(TAG, "  targetDuration=$targetDuration, fadeIn=$fadeInDurationSeconds")

        // 1. Set up encoder (creates the Surface we'll render to)
        val bitrate = getBitrate(qualitySettings)
        Log.d(TAG, "  bitrate=$bitrate")
        val encoderFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, OUTPUT_WIDTH, OUTPUT_HEIGHT).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        }

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(encoderFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val encoderSurface = encoder.createInputSurface()
        encoder.start()
        Log.d(TAG, "  Encoder started, surface valid=${encoderSurface.isValid}")

        // 2. Set up EGL on encoder surface
        initEGL(encoderSurface)
        Log.d(TAG, "  EGL initialized, display=$eglDisplay, context=$eglContext, surface=$eglSurface")

        // 3. Initialize GL resources
        initGL()
        Log.d(TAG, "  GL initialized: programOES=$programOES, program2D=$program2D, fboA=$fboA, fboB=$fboB")

        // 4. Set up decoder
        val extractor = MediaExtractor()
        extractor.setDataSource(videoPath)
        val videoTrackIndex = findVideoTrack(extractor)
        if (videoTrackIndex < 0) {
            Log.e(TAG, "  ✗ No video track found in $videoPath")
            cleanup(encoder, encoderSurface, extractor, null, null)
            return 0
        }
        extractor.selectTrack(videoTrackIndex)
        val inputFormat = extractor.getTrackFormat(videoTrackIndex)
        val inputWidth = inputFormat.getInteger(MediaFormat.KEY_WIDTH)
        val inputHeight = inputFormat.getInteger(MediaFormat.KEY_HEIGHT)
        val videoDurationUs = if (inputFormat.containsKey(MediaFormat.KEY_DURATION)) inputFormat.getLong(MediaFormat.KEY_DURATION) else 0L
        val videoDurationMs = videoDurationUs / 1000
        Log.d(TAG, "  Input: ${inputWidth}x${inputHeight}, durationMs=$videoDurationMs, mime=${inputFormat.getString(MediaFormat.KEY_MIME)}")

        val effectiveDuration = if (targetDuration <= 0) ((videoDurationMs / 1000).toInt()).coerceAtLeast(1) else targetDuration
        val totalFrames = effectiveDuration * FRAME_RATE
        val fadeInFrames = (fadeInDurationSeconds * FRAME_RATE).toInt()
        Log.d(TAG, "  effectiveDuration=${effectiveDuration}s, totalFrames=$totalFrames, fadeInFrames=$fadeInFrames")

        // Decoder outputs to a SurfaceTexture which gives us an OES texture
        val oesTexId = createOESTexture()
        val surfaceTexture = SurfaceTexture(oesTexId)
        surfaceTexture.setDefaultBufferSize(inputWidth, inputHeight)
        val decoderSurface = Surface(surfaceTexture)
        Log.d(TAG, "  OES texture=$oesTexId, decoderSurface valid=${decoderSurface.isValid}")

        val decoder = MediaCodec.createDecoderByType(
            inputFormat.getString(MediaFormat.KEY_MIME) ?: MediaFormat.MIMETYPE_VIDEO_AVC
        )
        decoder.configure(inputFormat, decoderSurface, null, 0)
        decoder.start()
        Log.d(TAG, "  Decoder started")

        // 5. Set up muxer
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        muxerTrackIndex = -1
        muxerStarted = false
        val bufferInfo = MediaCodec.BufferInfo()

        // Settings
        val imageScale = (settings?.get("imageScale") as? Double ?: 0.9).toFloat()
        val useBgBlur = settings?.get("useBackgroundImage") as? Boolean ?: false
        val backgroundBlurRadius = (settings?.get("backgroundBlurRadius") as? Double ?: 20.0).toFloat()
        val roundedCorners = settings?.get("roundedCorners") as? Boolean ?: false
        val cornerRadius = (settings?.get("cornerRadius") as? Double ?: 0.0).toFloat()
        val strokeEnabled = settings?.get("strokeEnabled") as? Boolean ?: false
        val strokeWidth = (settings?.get("strokeWidth") as? Double ?: 0.0).toFloat()
        val strokeColorStr = settings?.get("strokeColor") as? String ?: "#FFFFFF"
        val paddingColorStr = settings?.get("paddingColor") as? String ?: "#000000"
        val fadeWholeVideo = settings?.get("fadeWholeVideo") as? Boolean ?: true
        val backgroundBrightness = (settings?.get("backgroundBrightness") as? Double ?: 1.0).toFloat()
        val backgroundSaturation = (settings?.get("backgroundSaturation") as? Double ?: 1.0).toFloat()
        Log.d(TAG, "  Settings: blur=$useBgBlur/$backgroundBlurRadius, corners=$roundedCorners/$cornerRadius, stroke=$strokeEnabled/$strokeWidth, fadeWhole=$fadeWholeVideo, brightness=$backgroundBrightness, saturation=$backgroundSaturation")

        val bgColor = try {
            android.graphics.Color.parseColor(paddingColorStr)
        } catch (e: Exception) { android.graphics.Color.BLACK }

        val strokeColor = try {
            android.graphics.Color.parseColor(strokeColorStr)
        } catch (e: Exception) { android.graphics.Color.WHITE }


        val texMatrix = FloatArray(16)
        val mvpMatrix = FloatArray(16)
        Matrix.setIdentityM(mvpMatrix, 0)

        // ── Main decode/render/encode loop ──────────────────────────

        var decoderDone = false
        var extractorDone = false
        var frameIndex = 0
        var decodedFrameCount = 0
        var renderedFrameCount = 0
        var encodedFrameCount = 0
        var loopIterations = 0
        frameAvailable = false

        surfaceTexture.setOnFrameAvailableListener {
            synchronized(frameSyncObject) {
                frameAvailable = true
                frameSyncObject.notifyAll()
            }
        }

        callback.onStep("Processing video with GPU...")
        Log.d(TAG, "═══ Entering main loop ═══")

        try {
            while (frameIndex < totalFrames) {
                loopIterations++

                // Feed decoder
                if (!extractorDone) {
                    val inBufIdx = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (inBufIdx >= 0) {
                        val buf = decoder.getInputBuffer(inBufIdx)!!
                        val sampleSize = extractor.readSampleData(buf, 0)
                        if (sampleSize < 0) {
                            // End of source — loop by seeking back to start
                            if (frameIndex < totalFrames) {
                                Log.d(TAG, "  Extractor EOS, seeking to 0 for loop (frameIndex=$frameIndex)")
                                extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                                val loopSample = extractor.readSampleData(buf, 0)
                                if (loopSample < 0) {
                                    Log.w(TAG, "  Loop seek failed, signaling EOS")
                                    decoder.queueInputBuffer(inBufIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                    extractorDone = true
                                } else {
                                    decoder.queueInputBuffer(inBufIdx, 0, loopSample, extractor.sampleTime, 0)
                                    extractor.advance()
                                }
                            } else {
                                decoder.queueInputBuffer(inBufIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                extractorDone = true
                            }
                        } else {
                            decoder.queueInputBuffer(inBufIdx, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                // Drain decoder
                val outBufIdx = decoder.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                if (outBufIdx >= 0) {
                    val render = (bufferInfo.size > 0)
                    decoder.releaseOutputBuffer(outBufIdx, render)
                    decodedFrameCount++

                    if (render) {
                        // Wait for the SurfaceTexture frame to actually arrive
                        awaitNewFrame()
                        surfaceTexture.updateTexImage()
                        surfaceTexture.getTransformMatrix(texMatrix)

                        if (frameIndex < totalFrames) {
                            val alpha = if (frameIndex < fadeInFrames) {
                                frameIndex.toFloat() / fadeInFrames.coerceAtLeast(1).toFloat()
                            } else 1.0f

                            val presentationTimeNs = (frameIndex.toLong() * 1_000_000_000L / FRAME_RATE)

                            // ── Render frame ──
                            renderFrame(
                                oesTexId, texMatrix, mvpMatrix, alpha,
                                inputWidth, inputHeight,
                                useBgBlur, backgroundBlurRadius, roundedCorners, cornerRadius,
                                strokeEnabled, strokeWidth, strokeColor, bgColor,
                                fadeWholeVideo, imageScale,
                                backgroundBrightness, backgroundSaturation
                            )

                            // Check GL errors
                            val glErr = GLES20.glGetError()
                            if (glErr != GLES20.GL_NO_ERROR) {
                                Log.e(TAG, "  ✗ GL error after renderFrame: $glErr (frame $frameIndex)")
                            }

                            EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, presentationTimeNs)
                            val swapOk = EGL14.eglSwapBuffers(eglDisplay, eglSurface)
                            if (!swapOk) {
                                Log.e(TAG, "  ✗ eglSwapBuffers FAILED at frame $frameIndex, eglError=${EGL14.eglGetError()}")
                            }

                            frameIndex++
                            renderedFrameCount++

                            if (frameIndex <= 5 || frameIndex % 30 == 0) {
                                Log.d(TAG, "  ✓ Rendered frame ${frameIndex - 1}, pts=${presentationTimeNs/1000000}ms, alpha=$alpha")
                            }

                            // Drain encoder after each frame render
                            drainEncoder(encoder, muxer, bufferInfo, false)
                        }
                    }

                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        Log.d(TAG, "  Decoder EOS flag received (frameIndex=$frameIndex)")
                        decoderDone = true
                    }
                } else if (outBufIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    Log.d(TAG, "  Decoder output format changed: ${decoder.outputFormat}")
                } else if (outBufIdx == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    // Normal — no frame ready yet
                }

                // If decoder is done but we still need frames (looping), restart
                if (decoderDone && frameIndex < totalFrames) {
                    Log.d(TAG, "  Decoder done, restarting for loop (frameIndex=$frameIndex/$totalFrames)")
                    decoder.flush()
                    extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                    extractorDone = false
                    decoderDone = false
                }

                // Drain encoder (for iterations without a rendered frame)
                drainEncoder(encoder, muxer, bufferInfo, false)

                if (frameIndex % 15 == 0 || frameIndex >= totalFrames) {
                    callback.onProgress(frameIndex.toDouble() / totalFrames)
                }
            }

            Log.d(TAG, "═══ Loop done, signaling encoder EOS ═══")
            Log.d(TAG, "  loopIterations=$loopIterations, decodedFrames=$decodedFrameCount, renderedFrames=$renderedFrameCount")

            // Signal encoder EOS
            encoder.signalEndOfInputStream()
            drainEncoder(encoder, muxer, bufferInfo, true)

            Log.d(TAG, "  encodedFrames=$encodedFrameCount, muxerStarted=$muxerStarted, muxerTrack=$muxerTrackIndex")
        } catch (e: Exception) {
            Log.e(TAG, "✗ EXCEPTION in processVideo", e)
            throw e
        } finally {
            callback.onProgress(1.0)
            Log.d(TAG, "═══ Cleanup ═══")
            Log.d(TAG, "  Output file: ${outputFile.absolutePath}, size=${outputFile.length()} bytes")
            cleanup(encoder, encoderSurface, extractor, decoder, decoderSurface)
            surfaceTexture.release()
            GLES20.glDeleteTextures(1, intArrayOf(oesTexId), 0)
            destroyFBOs()
            releaseEGL()
            try { if (muxerStarted) muxer.stop() } catch (e: Exception) { Log.e(TAG, "muxer stop error", e) }
            muxer.release()
        }

        Log.d(TAG, "═══ processVideo COMPLETE: ${outputFile.absolutePath} (${outputFile.length()} bytes) ═══")
        return effectiveDuration
    }

    // ── Image-to-video entry point ──────────────────────────────────




    fun processImage(
        bitmap: android.graphics.Bitmap,
        outputFile: File,
        durationSeconds: Int,
        fadeInDurationSeconds: Double,
        settings: Map<String, Any>?,
        qualitySettings: Map<String, Any>?,
        callback: ProgressCallback
    ): Int {
        Log.d(TAG, "═══ processImage START ═══")
        Log.d(TAG, "  bitmap=${bitmap.width}x${bitmap.height}, duration=${durationSeconds}s, fadeIn=$fadeInDurationSeconds")

        val bitrate = getBitrate(qualitySettings)
        val encoderFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, OUTPUT_WIDTH, OUTPUT_HEIGHT).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        }

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(encoderFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val encoderSurface = encoder.createInputSurface()
        encoder.start()

        initEGL(encoderSurface)
        initGL()

        // Load bitmap into GL texture with Y-flip
        // Android Bitmap: origin = top-left.  OpenGL: origin = bottom-left.
        // We flip the bitmap before uploading so it renders right-side up.
        val flippedBitmap = flipBitmapVertically(bitmap)
        val imgTexId = loadBitmapTexture(flippedBitmap)
        flippedBitmap.recycle()
        val inputWidth = bitmap.width
        val inputHeight = bitmap.height

        val totalFrames = durationSeconds * FRAME_RATE
        val fadeInFrames = (fadeInDurationSeconds * FRAME_RATE).toInt()

        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        muxerTrackIndex = -1
        muxerStarted = false
        val bufferInfo = MediaCodec.BufferInfo()

        // Settings
        val imageScale = (settings?.get("imageScale") as? Double ?: 0.9).toFloat()
        val useBgBlur = settings?.get("useBackgroundImage") as? Boolean ?: false
        val backgroundBlurRadius = (settings?.get("backgroundBlurRadius") as? Double ?: 20.0).toFloat()
        val roundedCorners = settings?.get("roundedCorners") as? Boolean ?: false
        val cornerRadius = (settings?.get("cornerRadius") as? Double ?: 0.0).toFloat()
        val strokeEnabled = settings?.get("strokeEnabled") as? Boolean ?: false
        val strokeWidth = (settings?.get("strokeWidth") as? Double ?: 0.0).toFloat()
        val strokeColorStr = settings?.get("strokeColor") as? String ?: "#FFFFFF"
        val paddingColorStr = settings?.get("paddingColor") as? String ?: "#000000"
        val fadeWholeVideo = settings?.get("fadeWholeVideo") as? Boolean ?: true
        val backgroundBrightness = (settings?.get("backgroundBrightness") as? Double ?: 1.0).toFloat()
        val backgroundSaturation = (settings?.get("backgroundSaturation") as? Double ?: 1.0).toFloat()

        val bgColor = try {
            android.graphics.Color.parseColor(paddingColorStr)
        } catch (e: Exception) { android.graphics.Color.BLACK }

        val strokeColor = try {
            android.graphics.Color.parseColor(strokeColorStr)
        } catch (e: Exception) { android.graphics.Color.WHITE }

        val mvpMatrix = FloatArray(16)
        Matrix.setIdentityM(mvpMatrix, 0)
        val identityMvp = FloatArray(16)
        Matrix.setIdentityM(identityMvp, 0)

        callback.onStep("Processing image with GPU...")
        Log.d(TAG, "  totalFrames=$totalFrames, fadeInFrames=$fadeInFrames")

        // ── PRE-RENDER: compute background and foreground ONCE ──────
        // This avoids running blur passes + compositing for every frame.
        
        GLES20.glViewport(0, 0, OUTPUT_WIDTH, OUTPUT_HEIGHT)

        // a) Pre-render background into FBO-A
        if (useBgBlur) {
            // First render image center-cropped into FBO-A as blur source
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            
            // Calculate Fill Scale (center-crop)
            val fillScale = maxOf(OUTPUT_WIDTH.toFloat() / inputWidth, OUTPUT_HEIGHT.toFloat() / inputHeight)
            val bgMvp = FloatArray(16)
            Matrix.setIdentityM(bgMvp, 0)
            Matrix.scaleM(bgMvp, 0, (inputWidth * fillScale) / OUTPUT_WIDTH, (inputHeight * fillScale) / OUTPUT_HEIGHT, 1f)
            
            draw2DTexture(imgTexId, bgMvp, 1.0f)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)

            val blurScale = (backgroundBlurRadius / 10.0f).coerceIn(0.5f, 8.0f)
            val blurPasses = (backgroundBlurRadius / 10.0f).toInt().coerceIn(1, 5)

            // Run blur passes
            for (pass in 0 until blurPasses) {
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboB)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                drawBlurH(fboTexA, blurScale)
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)

                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                drawBlurV(fboTexB, blurScale)
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            }
            // fboTexA now has the blurred background
        }

        // b) Pre-render aspect-fit foreground into FBO-B
        val effectiveStroke = if (strokeEnabled) strokeWidth else 0f
        val availW = (OUTPUT_WIDTH.toFloat() - effectiveStroke * 2f) * imageScale
        val availH = (OUTPUT_HEIGHT.toFloat() - effectiveStroke * 2f) * imageScale
        val fitScale = minOf(availW / inputWidth, availH / inputHeight)
        val drawW = inputWidth * fitScale
        val drawH = inputHeight * fitScale
        val scaleX = drawW / OUTPUT_WIDTH
        val scaleY = drawH / OUTPUT_HEIGHT

        val fboMvp = FloatArray(16)
        Matrix.setIdentityM(fboMvp, 0)
        Matrix.scaleM(fboMvp, 0, scaleX, scaleY, 1f)

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboB)
        GLES20.glClearColor(0f, 0f, 0f, 0f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        draw2DTexture(imgTexId, fboMvp, 1.0f)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        // fboTexB now has the aspect-fit foreground

        // c) COMPOSITE: If fadeWholeVideo is true, merge them now into FBO-C
        if (fadeWholeVideo) {
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboC)
            // Draw background (blur or solid)
            if (useBgBlur) {
                draw2DTexture(fboTexA, identityMvp, 1.0f, brightness = backgroundBrightness, saturation = backgroundSaturation)
            } else {
                val r = ((bgColor shr 16) and 0xFF) / 255f
                val g = ((bgColor shr 8) and 0xFF) / 255f
                val b = (bgColor and 0xFF) / 255f
                GLES20.glClearColor(r, g, b, 1.0f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            }

            // Overlay foreground
            GLES20.glEnable(GLES20.GL_BLEND)
            GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
            if (roundedCorners || strokeEnabled) {
                drawComposite(fboTexB, identityMvp, 1.0f, drawW, drawH, cornerRadius, roundedCorners, effectiveStroke, strokeEnabled, strokeColor)
            } else {
                draw2DTexture(fboTexB, identityMvp, 1.0f)
            }
            GLES20.glDisable(GLES20.GL_BLEND)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            // Now fboTexC holds the ENTIRE final frame at 100% opacity
        }

        Log.d(TAG, "  Pre-render done. Starting frame encode loop...")

        // ── FRAME LOOP: just blit cached textures with current alpha ─
        try {
            for (frameIndex in 0 until totalFrames) {
                val alpha = if (frameIndex < fadeInFrames) {
                    frameIndex.toFloat() / fadeInFrames.coerceAtLeast(1).toFloat()
                } else 1.0f

                val presentationTimeNs = (frameIndex.toLong() * 1_000_000_000L / FRAME_RATE)
                GLES20.glViewport(0, 0, OUTPUT_WIDTH, OUTPUT_HEIGHT)

                if (fadeWholeVideo) {
                    // Optimized: Draw the entire pre-rendered frame with one alpha
                    GLES20.glClearColor(0f, 0f, 0f, 1f)
                    GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                    draw2DTexture(fboTexC, identityMvp, alpha)
                } else {
                    // Layered: Background stays static, only foreground fades
                    if (useBgBlur) {
                        GLES20.glClearColor(0f, 0f, 0f, 1f)
                        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                        draw2DTexture(fboTexA, identityMvp, 1.0f, brightness = backgroundBrightness, saturation = backgroundSaturation)
                    } else {
                        val r = ((bgColor shr 16) and 0xFF) / 255f
                        val g = ((bgColor shr 8) and 0xFF) / 255f
                        val b = (bgColor and 0xFF) / 255f
                        GLES20.glClearColor(r, g, b, 1.0f)
                        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                    }

                    GLES20.glEnable(GLES20.GL_BLEND)
                    GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                    if (roundedCorners || strokeEnabled) {
                        drawComposite(fboTexB, identityMvp, alpha, drawW, drawH, cornerRadius, roundedCorners, effectiveStroke, strokeEnabled, strokeColor)
                    } else {
                        draw2DTexture(fboTexB, identityMvp, alpha)
                    }
                    GLES20.glDisable(GLES20.GL_BLEND)
                }

                EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, presentationTimeNs)
                EGL14.eglSwapBuffers(eglDisplay, eglSurface)

                drainEncoder(encoder, muxer, bufferInfo, false)

                if (frameIndex % 15 == 0 || frameIndex == totalFrames - 1) {
                    callback.onProgress((frameIndex + 1).toDouble() / totalFrames)
                }
            }

            encoder.signalEndOfInputStream()
            drainEncoder(encoder, muxer, bufferInfo, true)

            Log.d(TAG, "  Image encode done, muxedFrames=$muxedFrameCount")
        } catch (e: Exception) {
            Log.e(TAG, "✗ EXCEPTION in processImage", e)
            throw e
        } finally {
            callback.onProgress(1.0)
            GLES20.glDeleteTextures(1, intArrayOf(imgTexId), 0)
            destroyFBOs()
            releaseEGL()
            try { encoder.stop() } catch (e: Exception) {}
            encoder.release()
            encoderSurface.release()
            try { if (muxerStarted) muxer.stop() } catch (e: Exception) { Log.e(TAG, "muxer stop", e) }
            muxer.release()
        }

        Log.d(TAG, "═══ processImage COMPLETE: ${outputFile.absolutePath} (${outputFile.length()} bytes) ═══")
        return durationSeconds
    }

    // ── Bitmap Y-flip (Android top-left → OpenGL bottom-left) ───────

    private fun flipBitmapVertically(src: android.graphics.Bitmap): android.graphics.Bitmap {
        val matrix = android.graphics.Matrix()
        matrix.postScale(1f, -1f, src.width / 2f, src.height / 2f)
        return android.graphics.Bitmap.createBitmap(src, 0, 0, src.width, src.height, matrix, true)
    }

    // ── Load bitmap into GL texture ─────────────────────────────────

    private fun loadBitmapTexture(bitmap: android.graphics.Bitmap): Int {
        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        android.opengl.GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        Log.d(TAG, "  Loaded bitmap texture: id=${tex[0]}, ${bitmap.width}x${bitmap.height}")
        return tex[0]
    }



    private fun renderFrame(
        oesTexId: Int, texMatrix: FloatArray, mvpMatrix: FloatArray, alpha: Float,
        inputWidth: Int, inputHeight: Int,
        useBgBlur: Boolean, backgroundBlurRadius: Float, roundedCorners: Boolean, cornerRadius: Float,
        strokeEnabled: Boolean, strokeWidth: Float, strokeColor: Int, bgColor: Int,
        fadeWholeVideo: Boolean, imageScale: Float,
        backgroundBrightness: Float, backgroundSaturation: Float
    ) {
        GLES20.glViewport(0, 0, OUTPUT_WIDTH, OUTPUT_HEIGHT)

        // Step 1: Render decoded frame to FBO-A (blur source)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        
        // Calculate Fill Scale (center-crop) for the background distortion fix
        val fillScale = maxOf(OUTPUT_WIDTH.toFloat() / inputWidth, OUTPUT_HEIGHT.toFloat() / inputHeight)
        val bgMvp = FloatArray(16)
        Matrix.setIdentityM(bgMvp, 0)
        Matrix.scaleM(bgMvp, 0, (inputWidth * fillScale) / OUTPUT_WIDTH, (inputHeight * fillScale) / OUTPUT_HEIGHT, 1f)
        
        drawOESTexture(oesTexId, texMatrix, bgMvp, 1.0f)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)

        // Step 2: Prepare background
        if (useBgBlur) {
            val blurScale = (backgroundBlurRadius / 10.0f).coerceIn(0.5f, 8.0f)
            val blurPasses = (backgroundBlurRadius / 10.0f).toInt().coerceIn(1, 5)
            for (pass in 0 until blurPasses) {
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboB)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                drawBlurH(fboTexA, blurScale)
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)

                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                drawBlurV(fboTexB, blurScale)
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            }
        }

        // Step 3: Prepare foreground (aspect-fit) in FBO-B
        val effectiveStroke = if (strokeEnabled) strokeWidth else 0f
        val availW = (OUTPUT_WIDTH.toFloat() - effectiveStroke * 2f) * imageScale
        val availH = (OUTPUT_HEIGHT.toFloat() - effectiveStroke * 2f) * imageScale
        val fitScale = minOf(availW / inputWidth, availH / inputHeight)
        val drawW = inputWidth * fitScale
        val drawH = inputHeight * fitScale
        val scaleX = drawW / OUTPUT_WIDTH
        val scaleY = drawH / OUTPUT_HEIGHT

        val fboMvp = FloatArray(16)
        Matrix.setIdentityM(fboMvp, 0)
        Matrix.scaleM(fboMvp, 0, scaleX, scaleY, 1f)

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboB)
        GLES20.glClearColor(0f, 0f, 0f, 0f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        drawOESTexture(oesTexId, texMatrix, fboMvp, 1.0f)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)

        // Step 4: Final composite to encoder surface
        val identityMvp = FloatArray(16)
        Matrix.setIdentityM(identityMvp, 0)

        if (fadeWholeVideo) {
            // Render entire composition to FBO-C first at 1.0 alpha
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboC)
            // BG
            if (useBgBlur) {
                draw2DTexture(fboTexA, identityMvp, 1.0f, brightness = backgroundBrightness, saturation = backgroundSaturation)
            } else {
                val r = ((bgColor shr 16) and 0xFF) / 255f
                val g = ((bgColor shr 8) and 0xFF) / 255f
                val b = (bgColor and 0xFF) / 255f
                GLES20.glClearColor(r, g, b, 1.0f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            }
            // FG
            GLES20.glEnable(GLES20.GL_BLEND)
            GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
            if (roundedCorners || strokeEnabled) {
                drawComposite(fboTexB, identityMvp, 1.0f, drawW, drawH, cornerRadius, roundedCorners, effectiveStroke, strokeEnabled, strokeColor)
            } else {
                draw2DTexture(fboTexB, identityMvp, 1.0f)
            }
            GLES20.glDisable(GLES20.GL_BLEND)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)

            // Now draw FBO-C to screen with alpha
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            draw2DTexture(fboTexC, identityMvp, alpha)
        } else {
            // Foreground only fade: draw BG at 1.0, FG at alpha
            if (useBgBlur) {
                GLES20.glClearColor(0f, 0f, 0f, 1f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                draw2DTexture(fboTexA, identityMvp, 1.0f, brightness = backgroundBrightness, saturation = backgroundSaturation)
            } else {
                val r = ((bgColor shr 16) and 0xFF) / 255f
                val g = ((bgColor shr 8) and 0xFF) / 255f
                val b = (bgColor and 0xFF) / 255f
                GLES20.glClearColor(r, g, b, 1.0f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            }
            GLES20.glEnable(GLES20.GL_BLEND)
            GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
            if (roundedCorners || strokeEnabled) {
                drawComposite(fboTexB, identityMvp, alpha, drawW, drawH, cornerRadius, roundedCorners, effectiveStroke, strokeEnabled, strokeColor)
            } else {
                draw2DTexture(fboTexB, identityMvp, alpha)
            }
            GLES20.glDisable(GLES20.GL_BLEND)
        }
    }


    // ── Draw helpers ────────────────────────────────────────────────

    private fun drawOESTexture(texId: Int, texMatrix: FloatArray, mvpMatrix: FloatArray, alpha: Float) {
        GLES20.glUseProgram(programOES)
        val posLoc = GLES20.glGetAttribLocation(programOES, "aPosition")
        val texLoc = GLES20.glGetAttribLocation(programOES, "aTexCoord")
        val mvpLoc = GLES20.glGetUniformLocation(programOES, "uMVPMatrix")
        val texMatLoc = GLES20.glGetUniformLocation(programOES, "uTexMatrix")
        val alphaLoc = GLES20.glGetUniformLocation(programOES, "uAlpha")

        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texLoc)
        GLES20.glVertexAttribPointer(texLoc, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        GLES20.glUniformMatrix4fv(mvpLoc, 1, false, mvpMatrix, 0)
        GLES20.glUniformMatrix4fv(texMatLoc, 1, false, texMatrix, 0)
        GLES20.glUniform1f(alphaLoc, alpha)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(texLoc)
    }

    private fun draw2DTexture(texId: Int, mvpMatrix: FloatArray, alpha: Float, brightness: Float = 1.0f, saturation: Float = 1.0f) {
        GLES20.glUseProgram(program2D)
        val posLoc = GLES20.glGetAttribLocation(program2D, "aPosition")
        val texLoc = GLES20.glGetAttribLocation(program2D, "aTexCoord")
        val mvpLoc = GLES20.glGetUniformLocation(program2D, "uMVPMatrix")
        val texMatLoc = GLES20.glGetUniformLocation(program2D, "uTexMatrix")
        val alphaLoc = GLES20.glGetUniformLocation(program2D, "uAlpha")
        val brightnessLoc = GLES20.glGetUniformLocation(program2D, "uBrightness")
        val saturationLoc = GLES20.glGetUniformLocation(program2D, "uSaturation")

        val identityMat = FloatArray(16)
        Matrix.setIdentityM(identityMat, 0)

        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texLoc)
        GLES20.glVertexAttribPointer(texLoc, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        GLES20.glUniformMatrix4fv(mvpLoc, 1, false, mvpMatrix, 0)
        GLES20.glUniformMatrix4fv(texMatLoc, 1, false, identityMat, 0)
        GLES20.glUniform1f(alphaLoc, alpha)
        GLES20.glUniform1f(brightnessLoc, brightness)
        GLES20.glUniform1f(saturationLoc, saturation)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(texLoc)
    }

    private fun drawBlurH(srcTex: Int, blurScale: Float = 1.0f) {
        GLES20.glUseProgram(programBlurH)
        val posLoc = GLES20.glGetAttribLocation(programBlurH, "aPosition")
        val texLoc = GLES20.glGetAttribLocation(programBlurH, "aTexCoord")
        val mvpLoc = GLES20.glGetUniformLocation(programBlurH, "uMVPMatrix")
        val texMatLoc = GLES20.glGetUniformLocation(programBlurH, "uTexMatrix")
        val texelLoc = GLES20.glGetUniformLocation(programBlurH, "uTexelWidth")

        val identity = FloatArray(16)
        Matrix.setIdentityM(identity, 0)

        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texLoc)
        GLES20.glVertexAttribPointer(texLoc, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        GLES20.glUniformMatrix4fv(mvpLoc, 1, false, identity, 0)
        GLES20.glUniformMatrix4fv(texMatLoc, 1, false, identity, 0)
        GLES20.glUniform1f(texelLoc, blurScale / OUTPUT_WIDTH)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, srcTex)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(texLoc)
    }

    private fun drawBlurV(srcTex: Int, blurScale: Float = 1.0f) {
        GLES20.glUseProgram(programBlurV)
        val posLoc = GLES20.glGetAttribLocation(programBlurV, "aPosition")
        val texLoc = GLES20.glGetAttribLocation(programBlurV, "aTexCoord")
        val mvpLoc = GLES20.glGetUniformLocation(programBlurV, "uMVPMatrix")
        val texMatLoc = GLES20.glGetUniformLocation(programBlurV, "uTexMatrix")
        val texelLoc = GLES20.glGetUniformLocation(programBlurV, "uTexelHeight")

        val identity = FloatArray(16)
        Matrix.setIdentityM(identity, 0)

        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texLoc)
        GLES20.glVertexAttribPointer(texLoc, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        GLES20.glUniformMatrix4fv(mvpLoc, 1, false, identity, 0)
        GLES20.glUniformMatrix4fv(texMatLoc, 1, false, identity, 0)
        GLES20.glUniform1f(texelLoc, blurScale / OUTPUT_HEIGHT)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, srcTex)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(texLoc)
    }

    private fun drawComposite(
        texId: Int, mvpMatrix: FloatArray, alpha: Float,
        drawW: Float, drawH: Float,
        cornerRadius: Float, enableCorners: Boolean,
        strokeWidth: Float, enableStroke: Boolean, strokeColor: Int
    ) {
        GLES20.glUseProgram(programComposite)
        val posLoc = GLES20.glGetAttribLocation(programComposite, "aPosition")
        val texLoc = GLES20.glGetAttribLocation(programComposite, "aTexCoord")
        val mvpLoc = GLES20.glGetUniformLocation(programComposite, "uMVPMatrix")
        val texMatLoc = GLES20.glGetUniformLocation(programComposite, "uTexMatrix")
        val alphaLoc = GLES20.glGetUniformLocation(programComposite, "uAlpha")
        val rectCenterLoc = GLES20.glGetUniformLocation(programComposite, "uRectCenter")
        val rectHalfSizeLoc = GLES20.glGetUniformLocation(programComposite, "uRectHalfSize")
        val cornerRadiusLoc = GLES20.glGetUniformLocation(programComposite, "uCornerRadius")
        val strokeWidthLoc = GLES20.glGetUniformLocation(programComposite, "uStrokeWidth")
        val strokeColorLoc = GLES20.glGetUniformLocation(programComposite, "uStrokeColor")
        val outputSizeLoc = GLES20.glGetUniformLocation(programComposite, "uOutputSize")
        val enableCornersLoc = GLES20.glGetUniformLocation(programComposite, "uEnableCorners")
        val enableStrokeLoc = GLES20.glGetUniformLocation(programComposite, "uEnableStroke")

        val identityMat = FloatArray(16)
        Matrix.setIdentityM(identityMat, 0)

        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texLoc)
        GLES20.glVertexAttribPointer(texLoc, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        GLES20.glUniformMatrix4fv(mvpLoc, 1, false, mvpMatrix, 0)
        GLES20.glUniformMatrix4fv(texMatLoc, 1, false, identityMat, 0)
        GLES20.glUniform1f(alphaLoc, alpha)

        // The scaled quad maps to a centered rect of drawW x drawH pixels.
        // Provide pixel-space coords for the SDF computation.
        val centerX = OUTPUT_WIDTH / 2f
        val centerY = OUTPUT_HEIGHT / 2f
        GLES20.glUniform2f(rectCenterLoc, centerX, centerY)
        GLES20.glUniform2f(rectHalfSizeLoc, drawW / 2f, drawH / 2f)
        GLES20.glUniform1f(cornerRadiusLoc, if (enableCorners) cornerRadius else 0f)
        GLES20.glUniform1f(strokeWidthLoc, if (enableStroke) strokeWidth else 0f)
        GLES20.glUniform2f(outputSizeLoc, OUTPUT_WIDTH.toFloat(), OUTPUT_HEIGHT.toFloat())
        GLES20.glUniform1i(enableCornersLoc, if (enableCorners) 1 else 0)
        GLES20.glUniform1i(enableStrokeLoc, if (enableStroke) 1 else 0)

        // Stroke color (ARGB int → RGBA floats)
        val sr = ((strokeColor shr 16) and 0xFF) / 255f
        val sg = ((strokeColor shr 8) and 0xFF) / 255f
        val sb = (strokeColor and 0xFF) / 255f
        val sa = ((strokeColor shr 24) and 0xFF) / 255f
        GLES20.glUniform4f(strokeColorLoc, sr, sg, sb, if (sa > 0f) sa else 1f)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(texLoc)
    }

    // ── EGL setup ───────────────────────────────────────────────────


    private fun initEGL(surface: Surface) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        EGL14.eglInitialize(eglDisplay, version, 0, version, 1)

        val configAttribs = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
            EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        EGL14.eglChooseConfig(eglDisplay, configAttribs, 0, configs, 0, 1, numConfigs, 0)

        val contextAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(eglDisplay, configs[0]!!, EGL14.EGL_NO_CONTEXT, contextAttribs, 0)

        val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, configs[0]!!, surface, surfaceAttribs, 0)

        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun releaseEGL() {
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            if (eglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, eglSurface)
            if (eglContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglTerminate(eglDisplay)
        }
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        eglSurface = EGL14.EGL_NO_SURFACE
    }

    // ── GL initialization ───────────────────────────────────────────

    private fun initGL() {
        vertexBuffer = ByteBuffer.allocateDirect(QUAD_COORDS.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().put(QUAD_COORDS).also { it.position(0) }
        texCoordBuffer = ByteBuffer.allocateDirect(QUAD_TEX_COORDS.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().put(QUAD_TEX_COORDS).also { it.position(0) }

        programOES = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_OES)
        program2D = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_2D)
        programBlurH = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_BLUR_H)
        programBlurV = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_BLUR_V)
        programComposite = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_COMPOSITE)

        createFBOs()
    }

    private fun createFBOs() {
        val fbos = IntArray(3)
        GLES20.glGenFramebuffers(3, fbos, 0)
        fboA = fbos[0]
        fboB = fbos[1]
        fboC = fbos[2]

        val texs = IntArray(3)
        GLES20.glGenTextures(3, texs, 0)
        fboTexA = texs[0]
        fboTexB = texs[1]
        fboTexC = texs[2]

        for (i in 0 until 3) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texs[i])
            GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, OUTPUT_WIDTH, OUTPUT_HEIGHT, 0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbos[i])
            GLES20.glFramebufferTexture2D(GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0, GLES20.GL_TEXTURE_2D, texs[i], 0)
        }
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
    }

    private fun destroyFBOs() {
        GLES20.glDeleteFramebuffers(3, intArrayOf(fboA, fboB, fboC), 0)
        GLES20.glDeleteTextures(3, intArrayOf(fboTexA, fboTexB, fboTexC), 0)
    }

    private fun createFBOTexture(): Int {
        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, OUTPUT_WIDTH, OUTPUT_HEIGHT, 0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        return tex[0]
    }

    private fun createOESTexture(): Int {
        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, tex[0])
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        return tex[0]
    }

    // ── Shader compilation ──────────────────────────────────────────

    private fun createProgram(vertexSrc: String, fragmentSrc: String): Int {
        val vs = compileShader(GLES20.GL_VERTEX_SHADER, vertexSrc)
        val fs = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentSrc)
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, vs)
        GLES20.glAttachShader(prog, fs)
        GLES20.glLinkProgram(prog)
        val status = IntArray(1)
        GLES20.glGetProgramiv(prog, GLES20.GL_LINK_STATUS, status, 0)
        if (status[0] == 0) {
            val log = GLES20.glGetProgramInfoLog(prog)
            Log.e(TAG, "Program link error: $log")
            GLES20.glDeleteProgram(prog)
            return 0
        }
        return prog
    }

    private fun compileShader(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        val status = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0)
        if (status[0] == 0) {
            val log = GLES20.glGetShaderInfoLog(shader)
            Log.e(TAG, "Shader compile error ($type): $log")
            GLES20.glDeleteShader(shader)
            return 0
        }
        return shader
    }

    private var muxedFrameCount = 0

    private fun drainEncoder(
        encoder: MediaCodec, muxer: MediaMuxer, bufferInfo: MediaCodec.BufferInfo,
        endOfStream: Boolean
    ) {
        var drainCount = 0
        while (true) {
            val outIdx = encoder.dequeueOutputBuffer(bufferInfo, if (endOfStream) TIMEOUT_US else 0)
            when {
                outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (!muxerStarted) {
                        muxerTrackIndex = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        muxerStarted = true
                        Log.d(TAG, "  MUXER: started, track=$muxerTrackIndex, format=${encoder.outputFormat}")
                    } else {
                        Log.w(TAG, "  MUXER: format changed again but muxer already started!")
                    }
                }
                outIdx >= 0 -> {
                    val buf = encoder.getOutputBuffer(outIdx)
                    if (buf != null && bufferInfo.size > 0 && muxerStarted) {
                        muxer.writeSampleData(muxerTrackIndex, buf, bufferInfo)
                        muxedFrameCount++
                        drainCount++
                    } else if (!muxerStarted && bufferInfo.size > 0) {
                        Log.w(TAG, "  MUXER: dropping frame — muxer not started yet! size=${bufferInfo.size}")
                    }
                    encoder.releaseOutputBuffer(outIdx, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        Log.d(TAG, "  ENCODER: EOS received. Total muxed frames=$muxedFrameCount (this drain=$drainCount)")
                        return
                    }
                }
                else -> {
                    if (!endOfStream) return
                    if (outIdx == MediaCodec.INFO_TRY_AGAIN_LATER && endOfStream) {
                        Log.d(TAG, "  ENCODER: TRY_AGAIN during EOS drain, continuing...")
                    }
                    // else keep draining
                }
            }
        }
    }

    // ── Frame sync ──────────────────────────────────────────────────

    private fun awaitNewFrame() {
        synchronized(frameSyncObject) {
            while (!frameAvailable) {
                try {
                    frameSyncObject.wait(500)
                    if (!frameAvailable) {
                        Log.w(TAG, "Frame wait timed out")
                        return
                    }
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    return
                }
            }
            frameAvailable = false
        }
    }

    // ── Utilities ───────────────────────────────────────────────────

    private fun findVideoTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("video/")) return i
        }
        return -1
    }

    private fun getBitrate(qualitySettings: Map<String, Any>?): Int {
        if (qualitySettings == null) return DEFAULT_BITRATE
        val quality = qualitySettings["quality"] as? String ?: "medium"
        val bitrate = when (quality) {
            "low" -> 3_000_000
            "medium" -> 6_000_000
            "high" -> 10_000_000
            "ultra" -> 15_000_000
            else -> DEFAULT_BITRATE
        }
        return bitrate.coerceIn(1_000_000, 20_000_000)
    }

    private fun cleanup(
        encoder: MediaCodec, encoderSurface: Surface,
        extractor: MediaExtractor, decoder: MediaCodec?, decoderSurface: Surface?
    ) {
        try { decoder?.stop() } catch (e: Exception) {}
        try { decoder?.release() } catch (e: Exception) {}
        try { decoderSurface?.release() } catch (e: Exception) {}
        try { encoder.stop() } catch (e: Exception) {}
        try { encoder.release() } catch (e: Exception) {}
        try { encoderSurface.release() } catch (e: Exception) {}
        try { extractor.release() } catch (e: Exception) {}
    }
}
