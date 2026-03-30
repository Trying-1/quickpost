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
        void main() {
            gl_FragColor = texture2D(sTexture, vTexCoord);
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
    private var textureId = 0
    private var surfaceTexture: SurfaceTexture? = null

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
            val outputWidth = if (rotation == 90 || rotation == 270) cropH else cropW
            val outputHeight = if (rotation == 90 || rotation == 270) cropW else cropH
            
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
                        renderFrame(inputWidth, inputHeight, cropX, cropY, cropW, cropH, rotation, isFlipped, finalW, finalH)
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
        outW: Int, outH: Int
    ) {
        GLES20.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program)
        
        val mvpMatrix = FloatArray(16)
        val texMatrix = FloatArray(16)
        Matrix.setIdentityM(mvpMatrix, 0)
        Matrix.setIdentityM(texMatrix, 0)
        
        surfaceTexture?.getTransformMatrix(texMatrix)

        // --- THE MAGIC: CROP SAMPLING ---
        // Normalized coordinates (0.0 to 1.0)
        // Note: Android Y is top-down, but GLES Y is bottom-up.
        // SurfaceTexture already provides a matrix that handles Y-flip usually.
        // To apply CROP, we need to apply it IN FRONT of the ST matrix.
        
        val cropMatrix = FloatArray(16)
        Matrix.setIdentityM(cropMatrix, 0)
        
        val nX = cX.toFloat() / inW.toFloat()
        val nY = 1.0f - (cY.toFloat() + cH.toFloat()) / inH.toFloat() // Convert top-down to bottom-up
        val nW = cW.toFloat() / inW.toFloat()
        val nH = cH.toFloat() / inH.toFloat()
        
        Matrix.translateM(cropMatrix, 0, nX, nY, 0f)
        Matrix.scaleM(cropMatrix, 0, nW, nH, 1f)
        
        val finalTexMatrix = FloatArray(16)
        Matrix.multiplyMM(finalTexMatrix, 0, texMatrix, 0, cropMatrix, 0)

        // --- TRANSFORMATION: ROTATION & FLIP ---
        if (flip) {
            Matrix.scaleM(mvpMatrix, 0, -1f, 1f, 1f)
        }
        Matrix.rotateM(mvpMatrix, 0, rot.toFloat(), 0f, 0f, 1f)

        val posHandle = GLES20.glGetAttribLocation(program, "aPosition")
        val texHandle = GLES20.glGetAttribLocation(program, "aTexCoord")
        val mvpHandle = GLES20.glGetUniformLocation(program, "uMVPMatrix")
        val stHandle = GLES20.glGetUniformLocation(program, "uTexMatrix")

        GLES20.glEnableVertexAttribArray(posHandle)
        GLES20.glVertexAttribPointer(posHandle, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texHandle)
        GLES20.glVertexAttribPointer(texHandle, 2, GLES20.GL_FLOAT, false, 0, textureBuffer)
        
        GLES20.glUniformMatrix4fv(mvpHandle, 1, false, mvpMatrix, 0)
        GLES20.glUniformMatrix4fv(stHandle, 1, false, finalTexMatrix, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
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

    private fun cleanup(dec: MediaCodec?, enc: MediaCodec?, ext: MediaExtractor?, mux: MediaMuxer?) {
        try { dec?.stop(); dec?.release() } catch (_: Exception) {}
        try { enc?.stop(); enc?.release() } catch (_: Exception) {}
        try { ext?.release() } catch (_: Exception) {}
        try { mux?.stop(); mux?.release() } catch (_: Exception) {}
    }
}
