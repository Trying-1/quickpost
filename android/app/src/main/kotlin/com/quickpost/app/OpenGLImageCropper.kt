package com.quickpost.app

import android.content.Context
import android.graphics.*
import android.opengl.*
import android.opengl.Matrix
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * GPU-accelerated image cropper and transformer (Rotation/Flip).
 */
class OpenGLImageCropper(private val context: Context) {

    companion object {
        private const val TAG = "GLImageCropper"
    }

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
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D sTexture;
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

    fun processImage(
        inputPath: String,
        outputPath: String,
        cropX: Int,
        cropY: Int,
        cropW: Int,
        cropH: Int,
        rotation: Int,
        isFlipped: Boolean
    ): Boolean {
        Log.d(TAG, "Starting OpenGL Image Crop: $inputPath -> $outputPath")
        
        val bitmap = BitmapFactory.decodeFile(inputPath) ?: return false
        val inW = bitmap.width
        val inH = bitmap.height

        val outW = if (rotation == 90 || rotation == 270) cropH else cropW
        val outH = if (rotation == 90 || rotation == 270) cropW else cropH

        try {
            initEGL(outW, outH)
            program = createProgram(VERTEX_SHADER, FRAGMENT_SHADER)
            val textureId = loadTexture(bitmap)
            bitmap.recycle()

            renderFrame(inW, inH, cropX, cropY, cropW, cropH, rotation, isFlipped, outW, outH, textureId)
            
            // Read pixels back
            val buffer = ByteBuffer.allocateDirect(outW * outH * 4)
            buffer.order(ByteOrder.LITTLE_ENDIAN)
            GLES20.glReadPixels(0, 0, outW, outH, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buffer)
            
            val croppedBitmap = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
            buffer.rewind()
            croppedBitmap.copyPixelsFromBuffer(buffer)
            
            // GLES reads bottom-up, so we need to flip the bitmap vertically
            val flippedBitmap = flipBitmapVertically(croppedBitmap)
            croppedBitmap.recycle()

            FileOutputStream(outputPath).use { out ->
                flippedBitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
            }
            flippedBitmap.recycle()
            
            GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Image Process failed: ${e.message}", e)
            return false
        } finally {
            releaseGL()
        }
    }

    private fun renderFrame(
        inW: Int, inH: Int,
        cX: Int, cY: Int, cW: Int, cH: Int,
        rot: Int, flip: Boolean,
        outW: Int, outH: Int,
        textureId: Int
    ) {
        GLES20.glViewport(0, 0, outW, outH)
        GLES20.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program)

        val mvpMatrix = FloatArray(16)
        val texMatrix = FloatArray(16)
        Matrix.setIdentityM(mvpMatrix, 0)
        Matrix.setIdentityM(texMatrix, 0)

        // Crop transformation (UV coordinates)
        // Image Y is top-down, GLES Texture is bottom-up (but Bitmaps are often uploaded flipped)
        // For static textures, we calculate normalized UVs.
        val nX = cX.toFloat() / inW.toFloat()
        val nY = 1.0f - (cY.toFloat() + cH.toFloat()) / inH.toFloat()
        val nW = cW.toFloat() / inW.toFloat()
        val nH = cH.toFloat() / inH.toFloat()

        Matrix.translateM(texMatrix, 0, nX, nY, 0f)
        Matrix.scaleM(texMatrix, 0, nW, nH, 1f)

        // Transformation (Rotation & Flip)
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
        GLES20.glUniformMatrix4fv(stHandle, 1, false, texMatrix, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    private fun loadTexture(bitmap: Bitmap): Int {
        val tex = IntArray(1); GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        return tex[0]
    }

    private fun initEGL(w: Int, h: Int) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val ver = IntArray(2); EGL14.eglInitialize(eglDisplay, ver, 0, ver, 1)
        val config = arrayOfNulls<android.opengl.EGLConfig>(1)
        val num = IntArray(1)
        val attr = intArrayOf(
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT, EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT, EGL14.EGL_NONE
        )
        EGL14.eglChooseConfig(eglDisplay, attr, 0, config, 0, 1, num, 0)
        eglContext = EGL14.eglCreateContext(eglDisplay, config[0], EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
        
        val pbufferAttr = intArrayOf(EGL14.EGL_WIDTH, w, EGL14.EGL_HEIGHT, h, EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreatePbufferSurface(eglDisplay, config[0], pbufferAttr, 0)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun flipBitmapVertically(src: Bitmap): Bitmap {
        val matrix = android.graphics.Matrix()
        matrix.postScale(1f, -1f)
        return Bitmap.createBitmap(src, 0, 0, src.width, src.height, matrix, true)
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
}
