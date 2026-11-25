package com.quickpost.app

import android.content.Context
import android.graphics.*
import android.media.*
import android.opengl.*
import android.util.Log
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * GPU-accelerated video text overlay processor.
 *
 * Pipeline:
 *   Input Video → MediaCodec HW Decoder → SurfaceTexture (OES texture)
 *                                               ↓
 *                                    OpenGL ES: video frame + text bitmap overlay
 *                                               ↓
 *                                    MediaCodec HW Encoder (Surface input)
 *                                               ↓
 *                                    MediaMuxer → Output .mp4
 *
 * Text is rendered once to a Bitmap via Android Canvas, uploaded as a GL texture,
 * and alpha-blended over each video frame on the GPU.
 */
class OpenGLTextOverlayProcessor(private val context: Context) {

    companion object {
        private const val TAG = "GLTextOverlay"
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 1
        private const val DEFAULT_BITRATE = 6_000_000
        private const val TIMEOUT_US = 10_000L
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
        void main() {
            vec4 color = texture2D(sTexture, vTexCoord);
            gl_FragColor = vec4(color.rgb * uAlpha, color.a * uAlpha);
        }
    """.trimIndent()

    private val FRAGMENT_SHADER_2D = """
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D sTexture;
        uniform float uAlpha;
        void main() {
            vec4 color = texture2D(sTexture, vTexCoord);
            gl_FragColor = vec4(color.rgb * uAlpha, color.a * uAlpha);
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

    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    // Frame sync
    private val frameSyncObject = Object()
    @Volatile private var frameAvailable = false

    // Muxer state
    private var muxerTrackIndex = -1
    private var muxerStarted = false
    private var muxedFrameCount = 0

    // ── Public entry point ──────────────────────────────────────────

    fun processVideoWithText(
        videoPath: String,
        outputFile: File,
        textParams: Map<String, Any?>,
        callback: ProgressCallback
    ): Int {
        Log.d(TAG, "═══ processVideoWithText START ═══")
        Log.d(TAG, "  video=$videoPath")

        // Parse text params
        val text = textParams["text"] as? String ?: ""
        val x = textParams["x"] as? Int ?: 0
        val y = textParams["y"] as? Int ?: 0
        val fontSize = textParams["fontSize"] as? Int ?: 40
        val fontColor = textParams["fontColor"] as? String ?: "#FFFFFF"
        val fontPath = textParams["fontPath"] as? String ?: ""
        val showShadow = textParams["showShadow"] as? Boolean ?: false
        val shadowColor = textParams["shadowColor"] as? String ?: "#000000"
        val shadowX = textParams["shadowX"] as? Int ?: 2
        val shadowY = textParams["shadowY"] as? Int ?: 2
        val boxColor = textParams["boxColor"] as? String ?: "#FFFFFF"
        val boxOpacity = (textParams["boxOpacity"] as? Number)?.toFloat() ?: 0f
        val textOpacity = (textParams["textOpacity"] as? Number)?.toFloat() ?: 1f
        val lineHeight = (textParams["lineHeight"] as? Number)?.toFloat() ?: 1.2f
        val hAlign = textParams["hAlign"] as? String ?: "center"
        val hPadding = (textParams["horizontalPadding"] as? Number)?.toFloat() ?: 20f
        val vPadding = (textParams["verticalPadding"] as? Number)?.toFloat() ?: 15f

        // 1. Open input video
        val extractor = MediaExtractor()
        extractor.setDataSource(videoPath)

        var videoTrackIndex = -1
        var audioTrackIndex = -1
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("video/") && videoTrackIndex < 0) videoTrackIndex = i
            if (mime.startsWith("audio/") && audioTrackIndex < 0) audioTrackIndex = i
        }
        if (videoTrackIndex < 0) {
            Log.e(TAG, "No video track found")
            extractor.release()
            return 0
        }
        extractor.selectTrack(videoTrackIndex)
        val inputFormat = extractor.getTrackFormat(videoTrackIndex)
        val inputWidth = inputFormat.getInteger(MediaFormat.KEY_WIDTH)
        val inputHeight = inputFormat.getInteger(MediaFormat.KEY_HEIGHT)
        val videoDurationUs = if (inputFormat.containsKey(MediaFormat.KEY_DURATION))
            inputFormat.getLong(MediaFormat.KEY_DURATION) else 0L
        val effectiveDuration = ((videoDurationUs / 1_000_000).toInt()).coerceAtLeast(1)
        val totalFrames = effectiveDuration * FRAME_RATE
        Log.d(TAG, "  Input: ${inputWidth}x${inputHeight}, duration=${effectiveDuration}s, hasAudio=${audioTrackIndex >= 0}")

        // 2. Decoder → SurfaceTexture → OES texture
        val oesTexId = createOESTexture()
        val surfaceTexture = SurfaceTexture(oesTexId)
        surfaceTexture.setDefaultBufferSize(inputWidth, inputHeight)
        val decoderSurface = Surface(surfaceTexture)

        surfaceTexture.setOnFrameAvailableListener {
            synchronized(frameSyncObject) {
                frameAvailable = true
                frameSyncObject.notifyAll()
            }
        }

        val decoder = MediaCodec.createDecoderByType(
            inputFormat.getString(MediaFormat.KEY_MIME) ?: MediaFormat.MIMETYPE_VIDEO_AVC
        )
        decoder.configure(inputFormat, decoderSurface, null, 0)
        decoder.start()

        var targetBitrate = (0.10 * FRAME_RATE * inputWidth * inputHeight).toInt()
        val fileLength = java.io.File(videoPath).length()
        val durationSecs = videoDurationUs / 1000000.0
        if (durationSecs > 0) {
            val inputBitrate = (fileLength * 8.0 / durationSecs).toInt()
            val maxAllowed = (inputBitrate * 1.5).toInt().coerceAtLeast(500_000)
            if (targetBitrate > maxAllowed) {
                targetBitrate = maxAllowed
            }
        }
        if (targetBitrate > 8_000_000) targetBitrate = 8_000_000
        if (targetBitrate < 500_000) targetBitrate = 500_000

        val encoderFormat = MediaFormat.createVideoFormat(
            MediaFormat.MIMETYPE_VIDEO_AVC, inputWidth, inputHeight
        ).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, targetBitrate)
            setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR)
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        }
        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(encoderFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val encoderSurface = encoder.createInputSurface()
        encoder.start()

        // 4. EGL + GL init
        initEGL(encoderSurface)
        initGL()

        // 5. Render text to bitmap → GL texture
        val textBitmap = renderTextBitmap(
            text, x, y, inputWidth, inputHeight,
            fontSize, fontColor, fontPath,
            showShadow, shadowColor, shadowX, shadowY,
            boxColor, boxOpacity, textOpacity, lineHeight, hAlign,
            hPadding, vPadding
        )
        val flippedBitmap = flipBitmapVertically(textBitmap)
        val textTexId = loadBitmapTexture(flippedBitmap)
        textBitmap.recycle()
        flippedBitmap.recycle()

        // 6. Muxer
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        muxerTrackIndex = -1
        muxerStarted = false
        muxedFrameCount = 0
        val bufferInfo = MediaCodec.BufferInfo()

        val texMatrix = FloatArray(16)
        val mvpMatrix = FloatArray(16)
        android.opengl.Matrix.setIdentityM(mvpMatrix, 0)
        val identityMvp = FloatArray(16)
        android.opengl.Matrix.setIdentityM(identityMvp, 0)

        callback.onStep("Processing video text overlay with GPU...")
        var frameIndex = 0
        var inputDone = false
        var decoderDone = false

        try {
            while (!decoderDone) {
                // Feed decoder
                if (!inputDone) {
                    val inBufIdx = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (inBufIdx >= 0) {
                        val inputBuffer = decoder.getInputBuffer(inBufIdx) ?: continue
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(inBufIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inBufIdx, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                // Drain decoder
                val outBufIdx = decoder.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                if (outBufIdx >= 0) {
                    val render = bufferInfo.size > 0
                    decoder.releaseOutputBuffer(outBufIdx, render)

                    if (render) {
                        awaitNewFrame()
                        surfaceTexture.updateTexImage()
                        surfaceTexture.getTransformMatrix(texMatrix)

                        val presentationTimeNs = (frameIndex.toLong() * 1_000_000_000L / FRAME_RATE)

                        // Render: video + text overlay
                        GLES20.glViewport(0, 0, inputWidth, inputHeight)

                        // Draw video frame
                        drawOESTexture(oesTexId, texMatrix, mvpMatrix, 1.0f)

                        // Alpha-blend text overlay
                        GLES20.glEnable(GLES20.GL_BLEND)
                        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                        draw2DTexture(textTexId, identityMvp, 1.0f)
                        GLES20.glDisable(GLES20.GL_BLEND)

                        EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, presentationTimeNs)
                        EGL14.eglSwapBuffers(eglDisplay, eglSurface)

                        drainEncoder(encoder, muxer, bufferInfo, false)
                        frameIndex++

                        if (frameIndex % 30 == 0 || frameIndex <= 3) {
                            val progress = if (totalFrames > 0) frameIndex.toDouble() / totalFrames else 0.0
                            callback.onProgress(progress.coerceIn(0.0, 1.0))
                        }
                    }

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        decoderDone = true
                    }
                }
            }

            encoder.signalEndOfInputStream()
            drainEncoder(encoder, muxer, bufferInfo, true)
            Log.d(TAG, "  Rendered $frameIndex frames, muxed=$muxedFrameCount")

        } catch (e: Exception) {
            Log.e(TAG, "✗ EXCEPTION in processVideoWithText", e)
            throw e
        } finally {
            callback.onProgress(1.0)
            GLES20.glDeleteTextures(1, intArrayOf(textTexId), 0)
            cleanup(encoder, encoderSurface, extractor, decoder, decoderSurface)
            surfaceTexture.release()
            GLES20.glDeleteTextures(1, intArrayOf(oesTexId), 0)
            releaseEGL()
            try { if (muxerStarted) muxer.stop() } catch (_: Exception) {}
            muxer.release()
        }

        // Merge audio from source video
        if (audioTrackIndex >= 0) {
            Log.d(TAG, "  Source has audio track, merging...")
            try {
                val tempFile = File(outputFile.parentFile, "temp_textoverlay_${System.currentTimeMillis()}.mp4")
                outputFile.renameTo(tempFile)
                val merger = FFmpegTextOverlay(context)
                val mergeRet = merger.nativeMergeAudioVideo(
                    tempFile.absolutePath, videoPath, outputFile.absolutePath, effectiveDuration
                )
                if (mergeRet == 0) {
                    Log.d(TAG, "  Audio merge successful")
                } else {
                    Log.e(TAG, "  Audio merge failed: $mergeRet, keeping video-only")
                    tempFile.renameTo(outputFile)
                }
                if (tempFile.exists()) tempFile.delete()
            } catch (e: Exception) {
                Log.e(TAG, "Audio merge failed", e)
            }
        }

        Log.d(TAG, "═══ processVideoWithText COMPLETE: ${outputFile.absolutePath} (${outputFile.length()} bytes) ═══")
        return effectiveDuration
    }

    // ── Text Rendering ──────────────────────────────────────────────

    private fun renderTextBitmap(
        text: String, x: Int, y: Int, videoWidth: Int, videoHeight: Int,
        fontSize: Int, fontColor: String, fontPath: String,
        showShadow: Boolean, shadowColor: String, shadowX: Int, shadowY: Int,
        boxColor: String, boxOpacity: Float, textOpacity: Float,
        lineHeight: Float, hAlign: String,
        padX: Float, padY: Float
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(videoWidth, videoHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val textPaint = android.text.TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = fontSize.toFloat()
            color = safeParseColor(fontColor)
            alpha = (textOpacity * 255).toInt()
        }

        if (fontPath.isNotEmpty() && File(fontPath).exists()) {
            try {
                textPaint.typeface = Typeface.createFromFile(fontPath)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load font: $fontPath", e)
            }
        }

        if (showShadow) {
            textPaint.setShadowLayer(2f, shadowX.toFloat(), shadowY.toFloat(), safeParseColor(shadowColor))
        }

        val alignment = when (hAlign.lowercase()) {
            "left" -> android.text.Layout.Alignment.ALIGN_NORMAL
            "right" -> android.text.Layout.Alignment.ALIGN_OPPOSITE
            else -> android.text.Layout.Alignment.ALIGN_CENTER
        }

        // 1. Initial layout to measure
        val maxWidth = (videoWidth * 0.95f).toInt().coerceAtLeast(100)
        
        val staticLayout = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            android.text.StaticLayout.Builder.obtain(text, 0, text.length, textPaint, maxWidth)
                .setAlignment(alignment)
                .setLineSpacing(0f, lineHeight)
                .setIncludePad(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            android.text.StaticLayout(text, textPaint, maxWidth, alignment, lineHeight, 0f, true)
        }

        // Find the tight width across all lines
        var maxLineWidth = 0f
        for (i in 0 until staticLayout.lineCount) {
            maxLineWidth = maxOf(maxLineWidth, staticLayout.getLineWidth(i))
        }
        val layoutHeight = staticLayout.height
        val effectiveWidth = maxLineWidth.toInt()

        // 2. Clear and render with tight box
        if (boxOpacity > 0.01f) {
            val boxPaint = Paint().apply {
                color = safeParseColor(boxColor)
                alpha = (boxOpacity * 255).toInt()
                style = Paint.Style.FILL
            }
            val left = x - maxLineWidth / 2f - padX
            val top = y - layoutHeight / 2f - padY
            val right = x + maxLineWidth / 2f + padX
            val bottom = y + layoutHeight / 2f + padY
            
            canvas.drawRoundRect(left, top, right, bottom, 12f, 12f, boxPaint)
        }

        // Draw the StaticLayout centered at (x, y)
        canvas.save()
        // Since StaticLayout aligns text within its 'maxWidth', we center the entire maxWidth box
        // to ensure the alignment (center/left/right) relative to the center point x works as expected.
        canvas.translate(x - maxWidth / 2f, y - layoutHeight / 2f)
        staticLayout.draw(canvas)
        canvas.restore()

        Log.d(TAG, "  Text bitmap: ${videoWidth}x${videoHeight}, layoutSize=${maxWidth}x${layoutHeight}, effectiveWidth=${maxLineWidth.toInt()}")
        return bitmap
    }




    private fun safeParseColor(hex: String): Int {
        return try {
            Color.parseColor(if (hex.startsWith("#")) hex else "#$hex")
        } catch (_: Exception) {
            Color.WHITE
        }
    }

    // ── EGL Setup ───────────────────────────────────────────────────

    private fun initEGL(surface: Surface) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        EGL14.eglInitialize(eglDisplay, version, 0, version, 1)

        val configAttribs = intArrayOf(
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT, EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<android.opengl.EGLConfig>(1)
        val numConfigs = IntArray(1)
        EGL14.eglChooseConfig(eglDisplay, configAttribs, 0, configs, 0, 1, numConfigs, 0)

        val contextAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, contextAttribs, 0)

        val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, configs[0], surface, surfaceAttribs, 0)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
        Log.d(TAG, "  EGL initialized")
    }

    private fun releaseEGL() {
        EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
        if (eglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, eglSurface)
        if (eglContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(eglDisplay, eglContext)
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) EGL14.eglTerminate(eglDisplay)
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        eglSurface = EGL14.EGL_NO_SURFACE
    }

    // ── GL Setup ────────────────────────────────────────────────────

    private fun initGL() {
        programOES = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_OES)
        program2D = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_2D)
        Log.d(TAG, "  GL programs compiled: OES=$programOES, 2D=$program2D")
    }

    private fun createProgram(vertexSrc: String, fragmentSrc: String): Int {
        val vs = compileShader(GLES20.GL_VERTEX_SHADER, vertexSrc)
        val fs = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentSrc)
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, vs)
        GLES20.glAttachShader(prog, fs)
        GLES20.glLinkProgram(prog)
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
            Log.e(TAG, "Shader compile error: $log")
            GLES20.glDeleteShader(shader)
            return 0
        }
        return shader
    }

    // ── Texture helpers ─────────────────────────────────────────────

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

    private fun loadBitmapTexture(bitmap: Bitmap): Int {
        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        return tex[0]
    }

    private fun flipBitmapVertically(src: Bitmap): Bitmap {
        val matrix = android.graphics.Matrix()
        matrix.preScale(1f, -1f)
        return Bitmap.createBitmap(src, 0, 0, src.width, src.height, matrix, true)
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

    private fun draw2DTexture(texId: Int, mvpMatrix: FloatArray, alpha: Float) {
        GLES20.glUseProgram(program2D)
        val posLoc = GLES20.glGetAttribLocation(program2D, "aPosition")
        val texLoc = GLES20.glGetAttribLocation(program2D, "aTexCoord")
        val mvpLoc = GLES20.glGetUniformLocation(program2D, "uMVPMatrix")
        val texMatLoc = GLES20.glGetUniformLocation(program2D, "uTexMatrix")
        val alphaLoc = GLES20.glGetUniformLocation(program2D, "uAlpha")

        val identity = FloatArray(16)
        android.opengl.Matrix.setIdentityM(identity, 0)

        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texLoc)
        GLES20.glVertexAttribPointer(texLoc, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)
        GLES20.glUniformMatrix4fv(mvpLoc, 1, false, mvpMatrix, 0)
        GLES20.glUniformMatrix4fv(texMatLoc, 1, false, identity, 0)
        GLES20.glUniform1f(alphaLoc, alpha)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(posLoc)
        GLES20.glDisableVertexAttribArray(texLoc)
    }

    // ── Encoder drain ───────────────────────────────────────────────

    private fun drainEncoder(encoder: MediaCodec, muxer: MediaMuxer, bufferInfo: MediaCodec.BufferInfo, endOfStream: Boolean) {
        val timeoutUs = if (endOfStream) 5000L else 0L
        while (true) {
            val idx = encoder.dequeueOutputBuffer(bufferInfo, timeoutUs)
            if (idx == MediaCodec.INFO_TRY_AGAIN_LATER) break
            if (idx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                if (!muxerStarted) {
                    muxerTrackIndex = muxer.addTrack(encoder.outputFormat)
                    muxer.start()
                    muxerStarted = true
                    Log.d(TAG, "  Muxer started, track=$muxerTrackIndex")
                }
                continue
            }
            if (idx < 0) continue

            val outBuf = encoder.getOutputBuffer(idx) ?: continue
            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                encoder.releaseOutputBuffer(idx, false)
                continue
            }
            if (bufferInfo.size > 0 && muxerStarted) {
                outBuf.position(bufferInfo.offset)
                outBuf.limit(bufferInfo.offset + bufferInfo.size)
                muxer.writeSampleData(muxerTrackIndex, outBuf, bufferInfo)
                muxedFrameCount++
            }
            encoder.releaseOutputBuffer(idx, false)
            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
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

    // ── Cleanup ─────────────────────────────────────────────────────

    private fun cleanup(
        encoder: MediaCodec, encoderSurface: Surface,
        extractor: MediaExtractor, decoder: MediaCodec, decoderSurface: Surface
    ) {
        try { decoder.stop() } catch (_: Exception) {}
        try { decoder.release() } catch (_: Exception) {}
        try { decoderSurface.release() } catch (_: Exception) {}
        try { encoder.stop() } catch (_: Exception) {}
        try { encoder.release() } catch (_: Exception) {}
        try { encoderSurface.release() } catch (_: Exception) {}
        try { extractor.release() } catch (_: Exception) {}
    }
}
