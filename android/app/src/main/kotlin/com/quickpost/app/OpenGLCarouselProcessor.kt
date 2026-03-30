package com.quickpost.app

import android.content.Context
import android.graphics.*
import android.media.*
import android.opengl.*
import android.util.Log
import android.view.Surface
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * GPU-accelerated Carousel Processor.
 *
 * Processes a sequence of images/slides into a single MP4 video using OpenGL ES.
 * Each slide can have its own background color, text overlay, and transformations.
 */
class OpenGLCarouselProcessor(private val context: Context) {

    companion object {
        private const val TAG = "GLCarousel"
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 1
        private const val DEFAULT_BITRATE = 8_000_000
        private const val TIMEOUT_US = 10_000L
    }

    interface ProgressCallback {
        fun onProgress(progress: Double)
        fun onStep(step: String)
    }

    // ── Shaders ─────────────────────────────────────────────────────

    private val VERTEX_SHADER = """
        uniform mat4 uMVPMatrix;
        attribute vec4 aPosition;
        attribute vec4 aTexCoord;
        varying vec2 vTexCoord;
        void main() {
            gl_Position = uMVPMatrix * aPosition;
            vTexCoord = aTexCoord.xy;
        }
    """.trimIndent()

    private val FRAGMENT_SHADER = """
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D sTexture;
        uniform float uAlpha;
        void main() {
            vec4 color = texture2D(sTexture, vTexCoord);
            gl_FragColor = vec4(color.rgb, color.a * uAlpha);
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
        0f, 1f,
        1f, 1f,
        0f, 0f,
        1f, 0f
    )

    private val vertexBuffer: FloatBuffer = ByteBuffer.allocateDirect(QUAD_COORDS.size * 4)
        .order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(QUAD_COORDS); position(0) }
    private val texCoordBuffer: FloatBuffer = ByteBuffer.allocateDirect(TEX_COORDS.size * 4)
        .order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(TEX_COORDS); position(0) }

    // ── GL state ────────────────────────────────────────────────────

    private var program = 0
    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    // ── Font Management ─────────────────────────────────────────────

    private data class FontEntry(val family: String, val weight: Int?, val style: String?, val asset: String)
    private val typefaceCache = mutableMapOf<String, Typeface>()
    private val fontManifestCache = mutableListOf<FontEntry>()
    private var fontManifestLoaded = false

    private fun loadFontManifest() {
        if (fontManifestLoaded) return
        fontManifestLoaded = true
        try {
            val jsonStream = context.assets.open("flutter_assets/FontManifest.json")
            val jsonString = jsonStream.bufferedReader().use { it.readText() }
            val jsonArray = JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                val familyObj = jsonArray.getJSONObject(i)
                val family = familyObj.optString("family", "")
                val fontsArray = familyObj.optJSONArray("fonts")
                if (fontsArray != null) {
                    for (j in 0 until fontsArray.length()) {
                        val fontObj = fontsArray.getJSONObject(j)
                        val asset = fontObj.optString("asset", "")
                        val weight = if (fontObj.has("weight")) fontObj.getInt("weight") else null
                        val style = fontObj.optString("style", null)
                        if (asset.isNotEmpty()) {
                            fontManifestCache.add(FontEntry(family, weight, style, asset))
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load FontManifest.json", e)
        }
    }

    private fun getCustomTypeface(family: String, weight: Int, isItalic: Boolean): Typeface? {
        loadFontManifest()
        val cacheKey = "$family-$weight-$isItalic"
        if (typefaceCache.containsKey(cacheKey)) return typefaceCache[cacheKey]

        val familyMatches = fontManifestCache.filter { it.family == family || it.family.endsWith("/$family") }
        if (familyMatches.isEmpty()) return null

        var bestMatch = familyMatches.first()
        for (match in familyMatches) {
            val matchStyle = match.style ?: "normal"
            val styleMatches = (isItalic && matchStyle == "italic") || (!isItalic && matchStyle != "italic")
            val weightMatches = match.weight == weight
            
            if (styleMatches && weightMatches) {
                bestMatch = match
                break
            } else if (styleMatches && match.weight == null && weight == 400) {
                bestMatch = match
                break
            } else if (styleMatches) {
                bestMatch = match
            }
        }

        return try {
            val tf = Typeface.createFromAsset(context.assets, "flutter_assets/" + bestMatch.asset)
            typefaceCache[cacheKey] = tf
            tf
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load typeface from asset: ${bestMatch.asset}", e)
            null
        }
    }

    // ── Processing ──────────────────────────────────────────────────

    fun processCarousel(
        slides: List<Map<String, Any?>>,
        outputWidth: Int,
        outputHeight: Int,
        durationPerSlide: Double,
        outputFile: File,
        callback: ProgressCallback
    ): Boolean {
        Log.d(TAG, "Starting Carousel Process: ${slides.size} slides, ${outputWidth}x${outputHeight}")
        
        val totalSlides = slides.size
        val totalDurationS = totalSlides * durationPerSlide
        val totalFrames = (totalDurationS * FRAME_RATE).toInt()
        val framesPerSlide = (durationPerSlide * FRAME_RATE).toInt()

        // 1. Setup Encoder
        val encoderFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, outputWidth, outputHeight).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, DEFAULT_BITRATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        }
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(encoderFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val inputSurface = encoder.createInputSurface()
        encoder.start()

        // 2. Setup EGL/GL
        initEGL(inputSurface)
        initGL()

        // 3. Setup Muxer
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var muxerTrackIndex = -1
        var muxerStarted = false
        val bufferInfo = MediaCodec.BufferInfo()

        try {
            var currentFrame = 0
            val mvpMatrix = FloatArray(16)
            android.opengl.Matrix.setIdentityM(mvpMatrix, 0)

            for (i in 0 until totalSlides) {
                val slide = slides[i]
                callback.onStep("Processing slide ${i + 1} of $totalSlides")
                
                // Render slide to a bitmap once
                val slideBitmap = renderSlideToBitmap(slide, outputWidth, outputHeight)
                val texId = loadBitmapTexture(slideBitmap)
                slideBitmap.recycle()

                for (f in 0 until framesPerSlide) {
                    val ptsNs = currentFrame.toLong() * 1_000_000_000L / FRAME_RATE
                    
                    GLES20.glViewport(0, 0, outputWidth, outputHeight)
                    GLES20.glClearColor(0f, 0f, 0f, 1f)
                    GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

                    drawTexture(texId, mvpMatrix, 1.0f)

                    EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, ptsNs)
                    EGL14.eglSwapBuffers(eglDisplay, eglSurface)

                    // Drain encoder
                    muxerTrackIndex = drainEncoder(encoder, muxer, bufferInfo, muxerTrackIndex, muxerStarted)
                    if (muxerTrackIndex >= 0) muxerStarted = true

                    currentFrame++
                    if (currentFrame % 10 == 0) {
                        callback.onProgress(currentFrame.toDouble() / totalFrames)
                    }
                }
                GLES20.glDeleteTextures(1, intArrayOf(texId), 0)
            }

            encoder.signalEndOfInputStream()
            drainEncoder(encoder, muxer, bufferInfo, muxerTrackIndex, muxerStarted, true)

        } catch (e: Exception) {
            Log.e(TAG, "Carousel processing failed", e)
            return false
        } finally {
            cleanup(encoder, inputSurface, muxer, muxerStarted)
            releaseEGL()
        }

        return true
    }

    /**
     * GPU-accelerated image generation for carousel slides.
     * Returns list of saved image paths.
     */
    fun processCarouselImages(
        slides: List<Map<String, Any?>>,
        width: Int,
        height: Int,
        callback: ProgressCallback
    ): List<String> {
        Log.d(TAG, "Starting GPU Image Process: ${slides.size} slides")
        
        val resultPaths = mutableListOf<String>()
        
        // Setup EGL for offscreen rendering (Pbuffer)
        initEGLOffscreen(width, height)
        initGL()

        try {
            val mvpMatrix = FloatArray(16)
            android.opengl.Matrix.setIdentityM(mvpMatrix, 0)

            for (i in 0 until slides.size) {
                val slide = slides[i]
                callback.onStep("Rendering image ${i + 1} of ${slides.size}...")
                
                val slideBitmap = renderSlideToBitmap(slide, width, height)
                val texId = loadBitmapTexture(slideBitmap)
                slideBitmap.recycle()

                GLES20.glViewport(0, 0, width, height)
                GLES20.glClearColor(0f, 0f, 0f, 1f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

                drawTexture(texId, mvpMatrix, 1.0f)
                
                // Capture GPU frame to bitmap
                val capturedBitmap = captureFrame(width, height)
                
                // Save to gallery
                val fileName = "QuickPost_Image_${System.currentTimeMillis()}_$i.png"
                val savedPath = saveBitmapToGallery(capturedBitmap, fileName)
                if (savedPath != null) resultPaths.add(savedPath)
                
                capturedBitmap.recycle()
                GLES20.glDeleteTextures(1, intArrayOf(texId), 0)
                
                callback.onProgress((i + 1).toDouble() / slides.size)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Image processing failed", e)
        } finally {
            releaseEGL()
        }

        return resultPaths
    }

    private fun captureFrame(width: Int, height: Int): Bitmap {
        val buffer = ByteBuffer.allocateDirect(width * height * 4)
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        GLES20.glPixelStorei(GLES20.GL_PACK_ALIGNMENT, 1)
        GLES20.glReadPixels(0, 0, width, height, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buffer)
        
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        buffer.rewind()
        bitmap.copyPixelsFromBuffer(buffer)
        
        // GL origin is bottom-left, Bitmap origin is top-left. Flip it.
        val matrix = android.graphics.Matrix()
        matrix.preScale(1f, -1f)
        return Bitmap.createBitmap(bitmap, 0, 0, width, height, matrix, true).apply {
            bitmap.recycle()
        }
    }

    private fun saveBitmapToGallery(bitmap: Bitmap, fileName: String): String? {
        val outDir = File(context.getExternalFilesDir(null), "exports")
        if (!outDir.exists()) outDir.mkdirs()
        val file = File(outDir, fileName)
        
        return try {
            file.outputStream().use { 
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) 
            }
            file.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save bitmap", e)
            null
        }
    }

    private fun renderSlideToBitmap(params: Map<String, Any?>, width: Int, height: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // 1. Background Color
        val bgColorStr = params["bgColor"] as? String ?: "#000000"
        canvas.drawColor(Color.parseColor(bgColorStr))

        // 2. Image (if exists)
        val imagePath = params["imagePath"] as? String
        if (imagePath != null && File(imagePath).exists()) {
            val options = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
            val imgBitmap = BitmapFactory.decodeFile(imagePath, options)
            if (imgBitmap != null) {
                // 1. Calculate Initial Center-Crop
                val canvasRatio = width.toFloat() / height.toFloat()
                val imageRatio = imgBitmap.width.toFloat() / imgBitmap.height.toFloat()
                var baseScale: Float
                var baseDx = 0f
                var baseDy = 0f

                if (imageRatio > canvasRatio) {
                    baseScale = height.toFloat() / imgBitmap.height.toFloat()
                    baseDx = (width - imgBitmap.width * baseScale) * 0.5f
                } else {
                    baseScale = width.toFloat() / imgBitmap.width.toFloat()
                    baseDy = (height - imgBitmap.height * baseScale) * 0.5f
                }

                // 2. Apply Manual Scaling/Positioning from Flutter
                val zoom = (params["imageZoom"] as? Number)?.toFloat() ?: 1.0f
                val offX = (params["imageOffsetX"] as? Number)?.toFloat() ?: 0f
                val offY = (params["imageOffsetY"] as? Number)?.toFloat() ?: 0f

                val matrix = android.graphics.Matrix()
                // a. Base fit
                matrix.postScale(baseScale, baseScale)
                matrix.postTranslate(baseDx, baseDy)
                // b. User zoom (pivot on center)
                matrix.postScale(zoom, zoom, width / 2f, height / 2f)
                // c. User pan
                matrix.postTranslate(offX * width, offY * height)

                canvas.drawBitmap(imgBitmap, matrix, Paint(Paint.FILTER_BITMAP_FLAG))
                imgBitmap.recycle()
            }
        }

        // 3. Text Overlay
        val text = params["text"] as? String ?: ""
        if (text.isNotEmpty()) {
            val textColor = Color.parseColor(params["textColor"] as? String ?: "#FFFFFF")
            // Responsive font size based on height
            val fontSize = height * 0.06f 
            val fontPath = params["fontPath"] as? String
            val fontWeight = (params["fontWeight"] as? Number)?.toInt() ?: 400
            val fontItalic = params["fontItalic"] as? Boolean ?: false
            
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = textColor
                this.textSize = fontSize
                this.textAlign = Paint.Align.CENTER
            }
            
            if (!fontPath.isNullOrEmpty()) {
                val customTypeface = getCustomTypeface(fontPath, fontWeight, fontItalic)
                if (customTypeface != null) {
                    paint.typeface = customTypeface
                } else {
                    val style = if (fontItalic && fontWeight >= 700) Typeface.BOLD_ITALIC
                                else if (fontItalic) Typeface.ITALIC
                                else if (fontWeight >= 700) Typeface.BOLD
                                else Typeface.NORMAL
                    paint.typeface = Typeface.create(fontPath, style)
                }
            }

            val lines = text.split("\n")
            val padding = width * 0.05f // 5% horizontal padding
            val alignX = (params["textAlignX"] as? Number)?.toFloat() ?: 0f
            val alignY = (params["textAlignY"] as? Number)?.toFloat() ?: 0f
            
            val lineHeight = fontSize * 1.25f
            val totalHeight = lines.size * lineHeight
            
            // Base vertical center position adjusted by Y alignment
            val centerY = (height / 2f) + (alignY * (height / 2f - totalHeight / 2f - padding))
            
            for (index in lines.indices) {
                val line = lines[index]
                // baseline calculation for this line
                val lineY = centerY - (totalHeight / 2f) + (index * lineHeight) + (fontSize * 0.8f)
                
                // Measure line width to calculate exact horizontal center for this alignment
                val bounds = Rect()
                paint.getTextBounds(line, 0, line.length, bounds)
                val lineTranslateX = alignX * (width / 2f - bounds.width() / 2f - padding)
                val lineX = (width / 2f) + lineTranslateX

                // A. Layer 1: Glow Effect (Bottom-most)
                val enableGlow = params["enableGlow"] as? Boolean ?: false
                if (enableGlow) {
                    val glowColor = Color.parseColor(params["glowColor"] as? String ?: "#FFFFFF")
                    val glowRadius = (params["glowRadius"] as? Number)?.toFloat() ?: 10f
                    val glowPaint = Paint(paint).apply {
                        color = glowColor
                        maskFilter = BlurMaskFilter(glowRadius, BlurMaskFilter.Blur.NORMAL)
                    }
                    canvas.drawText(line, lineX, lineY, glowPaint)
                }

                // B. Layer 2: Shadow Effect (Middle)
                val enableShadow = params["enableShadow"] as? Boolean ?: false
                if (enableShadow) {
                    val sColor = Color.parseColor(params["shadowColor"] as? String ?: "#88000000")
                    val blur = (params["shadowBlur"] as? Number)?.toFloat() ?: 4f
                    val dx = (params["shadowOffsetX"] as? Number)?.toFloat() ?: 2f
                    val dy = (params["shadowOffsetY"] as? Number)?.toFloat() ?: 2f
                    val shadowPaint = Paint(paint).apply {
                        setShadowLayer(blur, dx, dy, sColor)
                    }
                    canvas.drawText(line, lineX, lineY, shadowPaint)
                }

                // C. Layer 3: Main Text (Top-most)
                canvas.drawText(line, lineX, lineY, paint)
            }
        }

        return bitmap
    }

    // ── GL Helpers (Standard Boilerplate) ──────────────────────────

    private fun initEGL(surface: Surface) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        EGL14.eglInitialize(eglDisplay, null, 0, null, 0)
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        val attribs = intArrayOf(
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT, EGL14.EGL_NONE
        )
        EGL14.eglChooseConfig(eglDisplay, attribs, 0, configs, 0, 1, numConfigs, 0)
        eglContext = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, configs[0], surface, intArrayOf(EGL14.EGL_NONE), 0)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun initEGLOffscreen(width: Int, height: Int) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        EGL14.eglInitialize(eglDisplay, null, 0, null, 0)
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        val attribs = intArrayOf(
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT, EGL14.EGL_NONE
        )
        EGL14.eglChooseConfig(eglDisplay, attribs, 0, configs, 0, 1, numConfigs, 0)
        eglContext = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
        
        val pbufferAttribs = intArrayOf(
            EGL14.EGL_WIDTH, width,
            EGL14.EGL_HEIGHT, height,
            EGL14.EGL_NONE
        )
        eglSurface = EGL14.eglCreatePbufferSurface(eglDisplay, configs[0], pbufferAttribs, 0)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun initGL() {
        program = createProgram(VERTEX_SHADER, FRAGMENT_SHADER)
    }

    private fun createProgram(vs: String, fs: String): Int {
        val vShader = compileShader(GLES20.GL_VERTEX_SHADER, vs)
        val fShader = compileShader(GLES20.GL_FRAGMENT_SHADER, fs)
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, vShader)
        GLES20.glAttachShader(prog, fShader)
        GLES20.glLinkProgram(prog)
        return prog
    }

    private fun compileShader(type: Int, src: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, src)
        GLES20.glCompileShader(shader)
        return shader
    }

    private fun loadBitmapTexture(bm: Bitmap): Int {
        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bm, 0)
        return tex[0]
    }

    private fun drawTexture(texId: Int, mvp: FloatArray, alpha: Float) {
        GLES20.glUseProgram(program)
        val posHandle = GLES20.glGetAttribLocation(program, "aPosition")
        val texHandle = GLES20.glGetAttribLocation(program, "aTexCoord")
        val mvpHandle = GLES20.glGetUniformLocation(program, "uMVPMatrix")
        val alphaHandle = GLES20.glGetUniformLocation(program, "uAlpha")

        GLES20.glEnableVertexAttribArray(posHandle)
        GLES20.glVertexAttribPointer(posHandle, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texHandle)
        GLES20.glVertexAttribPointer(texHandle, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        GLES20.glUniformMatrix4fv(mvpHandle, 1, false, mvp, 0)
        GLES20.glUniform1f(alphaHandle, alpha)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun drainEncoder(encoder: MediaCodec, muxer: MediaMuxer, info: MediaCodec.BufferInfo, track: Int, started: Boolean, eos: Boolean = false): Int {
        var mTrack = track
        var mStarted = started
        if (eos) encoder.signalEndOfInputStream()
        while (true) {
            val outIdx = encoder.dequeueOutputBuffer(info, TIMEOUT_US)
            if (outIdx == MediaCodec.INFO_TRY_AGAIN_LATER) { if (!eos) break else continue }
            if (outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                mTrack = muxer.addTrack(encoder.outputFormat)
                muxer.start()
                mStarted = true
                continue
            }
            if (outIdx < 0) continue
            val buffer = encoder.getOutputBuffer(outIdx) ?: continue
            if (info.size != 0 && mStarted) {
                buffer.position(info.offset)
                buffer.limit(info.offset + info.size)
                muxer.writeSampleData(mTrack, buffer, info)
            }
            encoder.releaseOutputBuffer(outIdx, false)
            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
        }
        return mTrack
    }

    private fun releaseEGL() {
        EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
        EGL14.eglDestroySurface(eglDisplay, eglSurface)
        EGL14.eglDestroyContext(eglDisplay, eglContext)
        EGL14.eglTerminate(eglDisplay)
    }

    private fun cleanup(encoder: MediaCodec, surface: Surface, muxer: MediaMuxer, started: Boolean) {
        try { if (started) muxer.stop() } catch (_: Exception) {}
        muxer.release()
        encoder.stop()
        encoder.release()
        surface.release()
    }
}
