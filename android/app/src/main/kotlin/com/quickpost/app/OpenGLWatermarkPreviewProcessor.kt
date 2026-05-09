package com.quickpost.app

import android.content.Context
import android.graphics.*
import android.media.MediaPlayer
import android.opengl.*
import android.util.Log
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.atomic.AtomicBoolean

class OpenGLWatermarkPreviewProcessor(
    private val context: Context,
    private val textureEntry: TextureRegistry.SurfaceTextureEntry
) {
    companion object {
        private const val TAG = "GLWatermarkPreview"
    }

    private var renderThread: RenderThread? = null
    private val isRunning = AtomicBoolean(false)
    
    // UI Parameters
    private var params: Map<String, Any?> = emptyMap()
    private val paramsLock = Object()

    fun start(videoPath: String) {
        if (isRunning.get()) return
        isRunning.set(true)
        renderThread = RenderThread(videoPath).apply { start() }
    }

    fun updateParams(newParams: Map<String, Any?>) {
        synchronized(paramsLock) {
            params = newParams
        }
    }

    fun release() {
        isRunning.set(false)
        renderThread?.join(1000)
        textureEntry.release()
    }

    private inner class RenderThread(private val videoPath: String) : Thread("GLPreviewThread") {
        private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
        private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
        private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

        private var mediaPlayer: MediaPlayer? = null
        private var oesTexId = 0
        private var videoSurfaceTexture: SurfaceTexture? = null
        private var videoSurface: Surface? = null
        @Volatile private var frameAvailable = false
        private val frameSyncObject = Object()
        
        // Output dimensions match the Flutter Texture size we want (e.g., 1080x1920)
        private var outWidth = 1080
        private var outHeight = 1920

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
                
                float mask = 1.0 - smoothstep(0.0, 1.0, d);
                
                if (uBorderWidth > 0.0) {
                    float borderMask = smoothstep(-uBorderWidth - 1.0, -uBorderWidth, d) * (1.0 - smoothstep(-1.0, 0.0, d));
                    color.rgb = mix(color.rgb, uBorderColor, borderMask);
                }
                
                gl_FragColor = vec4(color.rgb * uAlpha * mask, color.a * uAlpha * mask);
            }
        """.trimIndent()

        private val QUAD_COORDS = floatArrayOf(-1f, -1f, 0f, 1f, -1f, 0f, -1f, 1f, 0f, 1f, 1f, 0f)
        private val TEX_COORDS = floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f)

        private val vertexBuffer: FloatBuffer = ByteBuffer.allocateDirect(QUAD_COORDS.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(QUAD_COORDS); position(0) }
        private val texCoordBuffer: FloatBuffer = ByteBuffer.allocateDirect(TEX_COORDS.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(TEX_COORDS); position(0) }

        private var programOES = 0
        private var videoW = 1080f
        private var videoH = 1920f

        override fun run() {
            try {
                initEGL()
                initGL()
                setupMediaPlayer()

                val texMatrix = FloatArray(16)
                while (isRunning.get()) {
                    val hasFrame = synchronized(frameSyncObject) {
                        if (!frameAvailable) {
                            frameSyncObject.wait(50) // Wait for frame or timeout
                        }
                        if (frameAvailable) {
                            frameAvailable = false
                            true
                        } else false
                    }

                    if (hasFrame) {
                        videoSurfaceTexture?.updateTexImage()
                        videoSurfaceTexture?.getTransformMatrix(texMatrix)
                        
                        // Grab current params safely
                        val currentParams = synchronized(paramsLock) { params }
                        
                        drawScene(texMatrix, currentParams)
                        
                        EGL14.eglSwapBuffers(eglDisplay, eglSurface)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Render thread error", e)
            } finally {
                mediaPlayer?.release()
                videoSurface?.release()
                videoSurfaceTexture?.release()
                releaseEGL()
            }
        }

        private fun setupMediaPlayer() {
            val texs = IntArray(1)
            GLES20.glGenTextures(1, texs, 0)
            oesTexId = texs[0]
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTexId)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

            videoSurfaceTexture = SurfaceTexture(oesTexId)
            videoSurfaceTexture?.setOnFrameAvailableListener {
                synchronized(frameSyncObject) {
                    frameAvailable = true
                    frameSyncObject.notifyAll()
                }
            }
            videoSurface = Surface(videoSurfaceTexture)

            mediaPlayer = MediaPlayer().apply {
                setDataSource(videoPath)
                setSurface(videoSurface)
                isLooping = true
                prepare()
                
                videoW = videoWidth.toFloat()
                if (videoW <= 0f) videoW = 1080f
                videoH = videoHeight.toFloat()
                if (videoH <= 0f) videoH = 1920f
                
                start()
            }
        }

        private fun drawScene(texMatrix: FloatArray, p: Map<String, Any?>) {
            // Sync EGL buffer size with Flutter's true rotated video dimensions
            val pVideoW = (p["videoW"] as? Number)?.toInt() ?: 1080
            val pVideoH = (p["videoH"] as? Number)?.toInt() ?: 1920
            
            if (outWidth != pVideoW || outHeight != pVideoH) {
                outWidth = pVideoW
                outHeight = pVideoH
                textureEntry.surfaceTexture().setDefaultBufferSize(outWidth, outHeight)
            }
            
            GLES20.glViewport(0, 0, outWidth, outHeight)
            
            val bgColorStr = p["bgColor"] as? String ?: "#000000"
            val bgColor = try { Color.parseColor(bgColorStr) } catch (e: Exception) { Color.BLACK }
            GLES20.glClearColor(Color.red(bgColor)/255f, Color.green(bgColor)/255f, Color.blue(bgColor)/255f, 1.0f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

            GLES20.glEnable(GLES20.GL_BLEND)
            GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
            
            // Temporary video MVP logic
            // Since our EGL buffer matches the video aspect ratio, aspectIn == aspectOut.
            // This ensures 1:1 mapping without EGL squishing.
            val aspectIn = pVideoW.toFloat() / pVideoH.toFloat()
            val aspectOut = outWidth.toFloat() / outHeight.toFloat()
            val sY = if (aspectIn > aspectOut) aspectOut / aspectIn else 1.0f
            val sX = if (aspectIn < aspectOut) aspectIn / aspectOut else 1.0f
            
            val videoY = (p["videoY"] as? Number)?.toFloat() ?: 0.5f
            val videoScale = (p["videoScale"] as? Number)?.toFloat() ?: 1.0f
            val videoMvp = FloatArray(16)
            android.opengl.Matrix.setIdentityM(videoMvp, 0)
            
            val glVideoY = (0.5f - videoY) * 2f * (1.0f - sY)
            android.opengl.Matrix.translateM(videoMvp, 0, 0f, glVideoY, 0f)
            android.opengl.Matrix.scaleM(videoMvp, 0, sX * videoScale, sY * videoScale, 1.0f)

            drawOESTexture(
                texId = oesTexId,
                texMat = texMatrix,
                mvp = videoMvp,
                alpha = 1.0f,
                width = outWidth * sX,
                height = outHeight * sY,
                radius = 0f, // TODO: map from p["videoRadius"]
                borderWidth = 0f,
                borderColor = "#000000"
            )
            
            GLES20.glDisable(GLES20.GL_BLEND)
        }

        private fun drawOESTexture(texId: Int, texMat: FloatArray, mvp: FloatArray, alpha: Float, width: Float, height: Float, radius: Float, borderWidth: Float, borderColor: String) {
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
            GLES20.glUniform3f(GLES20.glGetUniformLocation(programOES, "uBorderColor"), Color.red(color)/255f, Color.green(color)/255f, Color.blue(color)/255f)

            GLES20.glActiveTexture(GLES20.GL_TEXTURE0); GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texId)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        }

        private fun initEGL() {
            eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (eglDisplay == EGL14.EGL_NO_DISPLAY) throw RuntimeException("eglGetDisplay failed")

            val version = IntArray(2)
            if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) throw RuntimeException("eglInitialize failed")

            val attribList = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_NONE
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfigs = IntArray(1)
            EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, configs.size, numConfigs, 0)

            val contextAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
            eglContext = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, contextAttribs, 0)
            if (eglContext == EGL14.EGL_NO_CONTEXT) throw RuntimeException("eglCreateContext failed")

            // Set the default buffer size for the output SurfaceTexture so it's not 0x0
            textureEntry.surfaceTexture().setDefaultBufferSize(outWidth, outHeight)

            // Create window surface using Flutter's texture registry surface
            val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
            eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, configs[0], textureEntry.surfaceTexture(), surfaceAttribs, 0)
            if (eglSurface == EGL14.EGL_NO_SURFACE) throw RuntimeException("eglCreateWindowSurface failed")

            if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
                throw RuntimeException("eglMakeCurrent failed")
            }
        }

        private fun initGL() {
            val v = GLES20.glCreateShader(GLES20.GL_VERTEX_SHADER).apply { GLES20.glShaderSource(this, VERTEX_SHADER); GLES20.glCompileShader(this) }
            val f = GLES20.glCreateShader(GLES20.GL_FRAGMENT_SHADER).apply { GLES20.glShaderSource(this, FRAGMENT_SHADER_OES); GLES20.glCompileShader(this) }
            programOES = GLES20.glCreateProgram().apply { GLES20.glAttachShader(this, v); GLES20.glAttachShader(this, f); GLES20.glLinkProgram(this) }
        }

        private fun releaseEGL() {
            if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                if (eglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, eglSurface)
                if (eglContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(eglDisplay, eglContext)
                EGL14.eglReleaseThread()
                EGL14.eglTerminate(eglDisplay)
            }
            eglDisplay = EGL14.EGL_NO_DISPLAY
            eglContext = EGL14.EGL_NO_CONTEXT
            eglSurface = EGL14.EGL_NO_SURFACE
        }
    }
}
