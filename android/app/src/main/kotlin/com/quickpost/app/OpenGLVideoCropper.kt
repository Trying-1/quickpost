package com.quickpost.app

import android.content.Context
import android.graphics.*
import android.media.*
import android.opengl.*
import android.opengl.Matrix
import android.util.Log
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * GPU-accelerated video cropper and transformer (Rotation/Flip).
 */
class OpenGLVideoCropper(private val context: Context) {

    companion object {
        private const val TAG = "GLCropper"
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 1
        private const val DEFAULT_BITRATE = 8_000_000
        private const val TIMEOUT_US = 10_000L
    }

    private var isCanceled = false

    fun cancel() {
        isCanceled = true
    }

    interface ProgressCallback {
        fun onProgress(progress: Double)
    }

    // --- Shaders ---
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

    private val FRAGMENT_SHADER = """
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

    private val vertexData = floatArrayOf(
        -1.0f, -1.0f, 0.0f,
         1.0f, -1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f,
         1.0f,  1.0f, 0.0f
    )
    private val textureData = floatArrayOf(
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f
    )

    private var vertexBuffer: FloatBuffer = ByteBuffer.allocateDirect(vertexData.size * 4)
        .order(ByteOrder.nativeOrder()).asFloatBuffer().put(vertexData).apply { position(0) }
    private var textureBuffer: FloatBuffer = ByteBuffer.allocateDirect(textureData.size * 4)
        .order(ByteOrder.nativeOrder()).asFloatBuffer().put(textureData).apply { position(0) }

    private var eglDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface = EGL14.EGL_NO_SURFACE
    private var program = 0
    private var program2D = 0
    private var programBlurH = 0
    private var programBlurV = 0
    private var textureId = 0
    private var surfaceTexture: SurfaceTexture? = null

    private var fboA = 0
    private var fboTexA = 0
    private var fboB = 0
    private var fboTexB = 0
    private var bgImageTexId = 0

    private val frameSyncObject = Object()
    private var frameAvailable = false

    fun processVideo(
        inputPath: String,
        outputPath: String,
        cropX: Int,
        cropY: Int,
        cropW: Int,
        cropH: Int,
        rotation: Int,
        isFlipped: Boolean,
        fillEnabled: Boolean = false,
        bgColor: String = "#000000",
        bgImagePath: String? = null,
        bgBlur: Float = 10.0f,
        bgImageBlur: Float = 0.0f,
        bgBrightness: Float = 1.0f,
        bgSaturation: Float = 1.0f,
        bgOpacity: Float = 0.0f,
        callback: ProgressCallback? = null
    ): Boolean {
        Log.d(TAG, "Starting OpenGL Crop: $inputPath -> $outputPath")
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var decoder: MediaCodec? = null
        var encoder: MediaCodec? = null
        
        try {
            extractor.setDataSource(inputPath)
            val videoTrackIndex = selectVideoTrack(extractor)
            if (videoTrackIndex < 0) return false
            extractor.selectTrack(videoTrackIndex)
            val format = extractor.getTrackFormat(videoTrackIndex)
            val duration = format.getLong(MediaFormat.KEY_DURATION)
            val inputWidth = format.getInteger(MediaFormat.KEY_WIDTH)
            val inputHeight = format.getInteger(MediaFormat.KEY_HEIGHT)

            // 1. Prepare Encoder
            val rawW = if (rotation == 90 || rotation == 270) cropH else cropW
            val rawH = if (rotation == 90 || rotation == 270) cropW else cropH
            
            // If fillEnabled, output 1080x1920 (centered crop)
            val outputWidth = if (fillEnabled) 1080 else rawW
            val outputHeight = if (fillEnabled) 1920 else rawH
            
            // Align to 2 for H264
            val finalW = if (outputWidth % 2 != 0) outputWidth - 1 else outputWidth
            val finalH = if (outputHeight % 2 != 0) outputHeight - 1 else outputHeight

            val outFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, finalW, finalH)
            outFormat.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            outFormat.setInteger(MediaFormat.KEY_BIT_RATE, DEFAULT_BITRATE)
            outFormat.setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            outFormat.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)

            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            encoder.configure(outFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            val inputSurface = encoder.createInputSurface()
            encoder.start()

            // 2. Prepare EGL & Shaders
            initEGL(inputSurface)
            initGL()
            
            // Load Background Image if provided
            bgImageTexId = 0
            if (fillEnabled && !bgImagePath.isNullOrEmpty()) {
                val file = File(bgImagePath)
                if (file.exists()) {
                    val bitmap = BitmapFactory.decodeFile(bgImagePath)
                    if (bitmap != null) {
                        val flipped = flipBitmapVertically(bitmap)
                        val originalTex = loadBitmapTexture(flipped)
                        
                        if (bgImageBlur > 0f) {
                            // Setup FBOs for one-time blur
                            initFBOs(1080, 1920) // standard output size
                            
                            // 1. Draw to FBO A (Aspect Fill logic here too if needed, but let's keep it simple for now)
                            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
                            GLES20.glViewport(0, 0, 1080, 1920)
                            val identity = FloatArray(16); Matrix.setIdentityM(identity, 0)
                            draw2DTexture(originalTex, identity, 1.0f)
                            
                            // 2. Blur A -> B -> A
                            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboB)
                            drawBlurH(fboTexA, bgImageBlur, 1080)
                            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
                            drawBlurV(fboTexB, bgImageBlur, 1920)
                            
                            // 3. Save result to a new persistent texture
                            bgImageTexId = create2DTexture(1080, 1920)
                            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
                            // Use glCopyTexSubImage2D to copy from FBO A to our new texture
                            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, bgImageTexId)
                            GLES20.glCopyTexSubImage2D(GLES20.GL_TEXTURE_2D, 0, 0, 0, 0, 0, 1080, 1920)
                            
                            // Cleanup temp original texture
                            GLES20.glDeleteTextures(1, intArrayOf(originalTex), 0)
                        } else {
                            bgImageTexId = originalTex
                        }
                        bitmap.recycle(); flipped.recycle()
                    }
                }
            }
            
            if (fillEnabled) {
                initFBOs(1080, 1920)
            }

            program = createProgram(VERTEX_SHADER, FRAGMENT_SHADER)
            textureId = createTexture()
            surfaceTexture = SurfaceTexture(textureId).apply {
                setOnFrameAvailableListener { synchronized(frameSyncObject) { frameAvailable = true; frameSyncObject.notifyAll() } }
            }
            val decodeSurface = Surface(surfaceTexture)

            // 3. Prepare Decoder
            decoder = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            decoder.configure(format, decodeSurface, null, 0)
            decoder.start()

            // 4. Prepare Muxer
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var muxerTrackIndex = -1
            var muxerStarted = false

            // --- Main Processing Loop ---
            val bufferInfo = MediaCodec.BufferInfo()
            var decodeDone = false
            var encodeDone = false
            var framesProcessed = 0L

            // 5. Handle Audio Track (Pre-Muxer)
            val audioTrackIndex = selectAudioTrack(extractor)
            var muxerAudioTrackIndex = -1
            var audioDone = audioTrackIndex < 0
            val audioExtractor = if (!audioDone) {
                MediaExtractor().apply { setDataSource(inputPath); selectTrack(audioTrackIndex) }
            } else null

            while (!encodeDone && !isCanceled) {
                // Feed Decoder (Video)
                if (!decodeDone) {
                    val inputBufIdx = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (inputBufIdx >= 0) {
                        val inputBuf = decoder.getInputBuffer(inputBufIdx)!!
                        val sampleSize = extractor.readSampleData(inputBuf, 0)
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(inputBufIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            decodeDone = true
                        } else {
                            decoder.queueInputBuffer(inputBufIdx, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                // Drain Decoder -> Render -> Feed Encoder
                val outBufIdx = decoder.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                if (outBufIdx >= 0) {
                    val doRender = bufferInfo.size != 0
                    decoder.releaseOutputBuffer(outBufIdx, doRender)
                    if (doRender) {
                        awaitNewFrame()
                        surfaceTexture?.updateTexImage()
                        renderFrame(inputWidth, inputHeight, cropX, cropY, cropW, cropH, rotation, isFlipped, finalW, finalH, fillEnabled, bgColor, bgImageTexId, bgBlur, bgBrightness, bgSaturation, bgOpacity)
                        EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, bufferInfo.presentationTimeUs * 1000)
                        EGL14.eglSwapBuffers(eglDisplay, eglSurface)
                        framesProcessed++
                        callback?.onProgress(bufferInfo.presentationTimeUs.toDouble() / duration.toDouble())
                    }
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        encoder.signalEndOfInputStream()
                    }
                }

                // Drain Encoder -> Muxer
                val encBufIdx = encoder.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                if (encBufIdx >= 0) {
                    val encodedData = encoder.getOutputBuffer(encBufIdx)!!
                    if (muxerTrackIndex == -1) {
                        muxerTrackIndex = muxer.addTrack(encoder.outputFormat)
                        if (audioExtractor != null) {
                            muxerAudioTrackIndex = muxer.addTrack(audioExtractor.getTrackFormat(audioTrackIndex))
                        }
                        muxer.start()
                        muxerStarted = true
                    }
                    if (bufferInfo.size != 0 && muxerStarted) {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(muxerTrackIndex, encodedData, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(encBufIdx, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) encodeDone = true
                }
            }

            // --- Audio Muxing Pass ---
            if (!isCanceled && audioExtractor != null && muxerStarted) {
                val audioBuffer = ByteBuffer.allocateDirect(1024 * 1024)
                val audioInfo = MediaCodec.BufferInfo()
                while (true) {
                    audioInfo.offset = 0
                    audioInfo.size = audioExtractor.readSampleData(audioBuffer, 0)
                    if (audioInfo.size < 0) break
                    audioInfo.presentationTimeUs = audioExtractor.sampleTime
                    audioInfo.flags = audioExtractor.sampleFlags
                    muxer.writeSampleData(muxerAudioTrackIndex, audioBuffer, audioInfo)
                    audioExtractor.advance()
                }
                audioExtractor.release()
            }

            return !isCanceled
        } catch (e: Exception) {
            Log.e(TAG, "Process failed: ${e.message}", e)
            return false
        } finally {
            cleanup(decoder, encoder, extractor, muxer)
            releaseGL()
        }
    }

    private fun renderFrame(
        inW: Int, inH: Int, 
        cX: Int, cY: Int, cW: Int, cH: Int, 
        rot: Int, flip: Boolean,
        outW: Int, outH: Int,
        fillEnabled: Boolean,
        bgColorHex: String,
        bgImgTexId: Int,
        bgBlur: Float,
        bgBrightness: Float,
        bgSaturation: Float,
        bgOpacity: Float
    ) {
        val stMatrix = FloatArray(16)
        surfaceTexture?.getTransformMatrix(stMatrix)

        val bgColor = Color.parseColor(bgColorHex)
        val bgR = Color.red(bgColor) / 255f
        val bgG = Color.green(bgColor) / 255f
        val bgB = Color.blue(bgColor) / 255f

        if (fillEnabled) {
            // --- 1. PREPARE BLURRED BACKGROUND ---
            // Draw FULL OES frame to FBO A with "Aspect Fill"
            GLES20.glViewport(0, 0, 1080, 1920)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

            val bgMvp = FloatArray(16)
            Matrix.setIdentityM(bgMvp, 0)
            val aspectIn = inW.toFloat() / inH.toFloat()
            val aspectOut = 1080f / 1920f
            if (aspectIn > aspectOut) {
                Matrix.scaleM(bgMvp, 0, aspectIn / aspectOut, 1.0f, 1.0f)
            } else {
                Matrix.scaleM(bgMvp, 0, 1.0f, aspectOut / aspectIn, 1.0f)
            }
            drawOESTexture(textureId, stMatrix, bgMvp, 1.0f)

            // Multi-pass blur
            if (bgBlur > 0f) {
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboB)
                drawBlurH(fboTexA, bgBlur, 1080)
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
                drawBlurV(fboTexB, bgBlur, 1920)
            }
            
            // --- 2. COMPOSITE TO SCREEN ---
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            GLES20.glViewport(0, 0, outW, outH)
            GLES20.glClearColor(bgR, bgG, bgB, 1.0f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

            GLES20.glEnable(GLES20.GL_BLEND)
            GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)

            // Draw Background Image if any
            if (bgImgTexId != 0) {
                val identity = FloatArray(16); Matrix.setIdentityM(identity, 0)
                draw2DTexture(bgImgTexId, identity, 1.0f, bgBrightness, bgSaturation)
            }

            // Draw blurred background video
            if (bgOpacity > 0f) {
                val identity = FloatArray(16); Matrix.setIdentityM(identity, 0)
                draw2DTexture(fboTexA, identity, bgOpacity, bgBrightness, bgSaturation) 
            }
            
            GLES20.glDisable(GLES20.GL_BLEND)
        } else {
            GLES20.glViewport(0, 0, outW, outH)
            GLES20.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        }

        // --- 3. DRAW FOREGROUND (CROPPED VIDEO) ---
        val mvpMatrix = FloatArray(16)
        val texMatrix = FloatArray(16)
        Matrix.setIdentityM(mvpMatrix, 0)
        Matrix.setIdentityM(texMatrix, 0)

        if (fillEnabled) {
            val rawW = if (rot == 90 || rot == 270) cH else cW
            val rawH = if (rot == 90 || rot == 270) cW else cH
            val aspectIn = rawW.toFloat() / rawH.toFloat()
            val aspectOut = outW.toFloat() / outH.toFloat()
            if (aspectIn > aspectOut) {
                Matrix.scaleM(mvpMatrix, 0, 1.0f, aspectOut / aspectIn, 1.0f)
            } else {
                Matrix.scaleM(mvpMatrix, 0, aspectIn / aspectOut, 1.0f, 1.0f)
            }
        }

        // Apply Crop to TexMatrix
        val cropMatrix = FloatArray(16)
        Matrix.setIdentityM(cropMatrix, 0)
        val nX = cX.toFloat() / inW.toFloat()
        val nY = 1.0f - (cY.toFloat() + cH.toFloat()) / inH.toFloat()
        val nW = cW.toFloat() / inW.toFloat()
        val nH = cH.toFloat() / inH.toFloat()
        Matrix.translateM(cropMatrix, 0, nX, nY, 0f)
        Matrix.scaleM(cropMatrix, 0, nW, nH, 1f)
        Matrix.multiplyMM(texMatrix, 0, stMatrix, 0, cropMatrix, 0)

        // Rotation & Flip
        if (flip) Matrix.scaleM(mvpMatrix, 0, -1f, 1f, 1f)
        Matrix.rotateM(mvpMatrix, 0, -rot.toFloat(), 0f, 0f, 1f)

        drawOESTexture(textureId, texMatrix, mvpMatrix, 1.0f)
    }

    private fun selectVideoTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            if (extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)!!.startsWith("video/")) return i
        }
        return -1
    }

    private fun selectAudioTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            if (extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)!!.startsWith("audio/")) return i
        }
        return -1
    }

    private fun awaitNewFrame() {
        synchronized(frameSyncObject) { while (!frameAvailable) frameSyncObject.wait(500); frameAvailable = false }
    }

    private fun initEGL(surface: Surface) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val ver = IntArray(2); EGL14.eglInitialize(eglDisplay, ver, 0, ver, 1)
        val config = arrayOfNulls<EGLConfig>(1)
        val num = IntArray(1)
        val attr = intArrayOf(
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT, EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT, EGL14.EGL_NONE
        )
        EGL14.eglChooseConfig(eglDisplay, attr, 0, config, 0, 1, num, 0)
        eglContext = EGL14.eglCreateContext(eglDisplay, config[0], EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, config[0], surface, intArrayOf(EGL14.EGL_NONE), 0)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun createTexture(): Int {
        val tex = IntArray(1); GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, tex[0])
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        return tex[0]
    }

    private fun createProgram(v: String, f: String): Int {
        val vs = GLES20.glCreateShader(GLES20.GL_VERTEX_SHADER).apply { GLES20.glShaderSource(this, v); GLES20.glCompileShader(this) }
        val fs = GLES20.glCreateShader(GLES20.GL_FRAGMENT_SHADER).apply { GLES20.glShaderSource(this, f); GLES20.glCompileShader(this) }
        return GLES20.glCreateProgram().apply { GLES20.glAttachShader(this, vs); GLES20.glAttachShader(this, fs); GLES20.glLinkProgram(this) }
    }

    private fun releaseGL() {
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(eglDisplay, eglSurface)
            EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglTerminate(eglDisplay)
        }
        eglDisplay = EGL14.EGL_NO_DISPLAY; eglContext = EGL14.EGL_NO_CONTEXT; eglSurface = EGL14.EGL_NO_SURFACE
    }

    private fun initGL() {
        program2D = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_2D)
        programBlurH = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_BLUR_H)
        programBlurV = createProgram(VERTEX_SHADER, FRAGMENT_SHADER_BLUR_V)
    }

    private fun drawOESTexture(texId: Int, stMatrix: FloatArray, mvpMatrix: FloatArray, alpha: Float) {
        GLES20.glUseProgram(program)
        val posHandle = GLES20.glGetAttribLocation(program, "aPosition")
        val texHandle = GLES20.glGetAttribLocation(program, "aTexCoord")
        val mvpHandle = GLES20.glGetUniformLocation(program, "uMVPMatrix")
        val stHandle = GLES20.glGetUniformLocation(program, "uTexMatrix")
        val alphaHandle = GLES20.glGetUniformLocation(program, "uAlpha")

        GLES20.glEnableVertexAttribArray(posHandle)
        GLES20.glVertexAttribPointer(posHandle, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texHandle)
        GLES20.glVertexAttribPointer(texHandle, 2, GLES20.GL_FLOAT, false, 0, textureBuffer)

        GLES20.glUniformMatrix4fv(mvpHandle, 1, false, mvpMatrix, 0)
        GLES20.glUniformMatrix4fv(stHandle, 1, false, stMatrix, 0)
        GLES20.glUniform1f(alphaHandle, alpha)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun initFBOs(width: Int, height: Int) {
        if (fboA != 0) return
        val fbos = IntArray(2); GLES20.glGenFramebuffers(2, fbos, 0)
        fboA = fbos[0]; fboB = fbos[1]
        
        fboTexA = create2DTexture(width, height)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboA)
        GLES20.glFramebufferTexture2D(GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0, GLES20.GL_TEXTURE_2D, fboTexA, 0)
        
        fboTexB = create2DTexture(width, height)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboB)
        GLES20.glFramebufferTexture2D(GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0, GLES20.GL_TEXTURE_2D, fboTexB, 0)
        
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
    }

    private fun draw2DTexture(texId: Int, mvpMatrix: FloatArray, alpha: Float, brightness: Float = 1.0f, saturation: Float = 1.0f) {
        GLES20.glUseProgram(program2D)
        val posHandle = GLES20.glGetAttribLocation(program2D, "aPosition")
        val texHandle = GLES20.glGetAttribLocation(program2D, "aTexCoord")
        val mvpHandle = GLES20.glGetUniformLocation(program2D, "uMVPMatrix")
        val texMatHandle = GLES20.glGetUniformLocation(program2D, "uTexMatrix")
        val samplerHandle = GLES20.glGetUniformLocation(program2D, "sTexture")
        val alphaHandle = GLES20.glGetUniformLocation(program2D, "uAlpha")
        val brightHandle = GLES20.glGetUniformLocation(program2D, "uBrightness")
        val satHandle = GLES20.glGetUniformLocation(program2D, "uSaturation")
        
        val iden = FloatArray(16); Matrix.setIdentityM(iden, 0)

        GLES20.glEnableVertexAttribArray(posHandle)
        GLES20.glVertexAttribPointer(posHandle, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texHandle)
        GLES20.glVertexAttribPointer(texHandle, 2, GLES20.GL_FLOAT, false, 0, textureBuffer)

        GLES20.glUniformMatrix4fv(mvpHandle, 1, false, mvpMatrix, 0)
        GLES20.glUniformMatrix4fv(texMatHandle, 1, false, iden, 0)
        GLES20.glUniform1i(samplerHandle, 0)
        GLES20.glUniform1f(alphaHandle, alpha)
        GLES20.glUniform1f(brightHandle, brightness)
        GLES20.glUniform1f(satHandle, saturation)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun drawBlurH(texId: Int, scale: Float, width: Int) {
        GLES20.glUseProgram(programBlurH)
        val posHandle = GLES20.glGetAttribLocation(programBlurH, "aPosition")
        val texHandle = GLES20.glGetAttribLocation(programBlurH, "aTexCoord")
        val twHandle = GLES20.glGetUniformLocation(programBlurH, "uTexelWidth")
        val iden = FloatArray(16); Matrix.setIdentityM(iden, 0)

        GLES20.glEnableVertexAttribArray(posHandle)
        GLES20.glVertexAttribPointer(posHandle, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texHandle)
        GLES20.glVertexAttribPointer(texHandle, 2, GLES20.GL_FLOAT, false, 0, textureBuffer)

        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(programBlurH, "uMVPMatrix"), 1, false, iden, 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(programBlurH, "uTexMatrix"), 1, false, iden, 0)
        GLES20.glUniform1f(twHandle, scale / width.toFloat())

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun drawBlurV(texId: Int, scale: Float, height: Int) {
        GLES20.glUseProgram(programBlurV)
        val posHandle = GLES20.glGetAttribLocation(programBlurV, "aPosition")
        val texHandle = GLES20.glGetAttribLocation(programBlurV, "aTexCoord")
        val thHandle = GLES20.glGetUniformLocation(programBlurV, "uTexelHeight")
        val iden = FloatArray(16); Matrix.setIdentityM(iden, 0)

        GLES20.glEnableVertexAttribArray(posHandle)
        GLES20.glVertexAttribPointer(posHandle, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texHandle)
        GLES20.glVertexAttribPointer(texHandle, 2, GLES20.GL_FLOAT, false, 0, textureBuffer)

        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(programBlurV, "uMVPMatrix"), 1, false, iden, 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(programBlurV, "uTexMatrix"), 1, false, iden, 0)
        GLES20.glUniform1f(thHandle, scale / height.toFloat())

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun loadBitmapTexture(bitmap: Bitmap): Int {
        val tex = IntArray(1); GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        return tex[0]
    }

    private fun create2DTexture(width: Int, height: Int): Int {
        val tex = IntArray(1); GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, width, height, 0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        return tex[0]
    }

    private fun flipBitmapVertically(src: Bitmap): Bitmap {
        val matrix = android.graphics.Matrix(); matrix.postScale(1f, -1f)
        return Bitmap.createBitmap(src, 0, 0, src.width, src.height, matrix, true)
    }

    private fun cleanup(dec: MediaCodec?, enc: MediaCodec?, ext: MediaExtractor?, mux: MediaMuxer?) {
        try { dec?.stop(); dec?.release() } catch (_: Exception) {}
        try { enc?.stop(); enc?.release() } catch (_: Exception) {}
        try { ext?.release() } catch (_: Exception) {}
        try { mux?.stop(); mux?.release() } catch (_: Exception) {}
        
        // Clean up FBOs
        if (fboA != 0) {
            GLES20.glDeleteFramebuffers(2, intArrayOf(fboA, fboB), 0)
            GLES20.glDeleteTextures(2, intArrayOf(fboTexA, fboTexB), 0)
        }
        if (bgImageTexId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(bgImageTexId), 0)
            bgImageTexId = 0
        }
    }
}
