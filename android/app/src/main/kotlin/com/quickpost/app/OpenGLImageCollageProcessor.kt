package com.quickpost.app

import android.content.Context
import android.graphics.*
import android.opengl.*
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * GPU-accelerated Image Collage Processor.
 * Renders multiple images to a high-resolution grid using OpenGL ES 2.0.
 */
class OpenGLImageCollageProcessor(private val context: Context) {

    companion object {
        private const val TAG = "GLImageCollage"
    }

    // ── Shaders ─────────────────────────────────────────────────────

    private val VERTEX_SHADER = """
        attribute vec4 aPosition;
        attribute vec2 aTexCoord;
        varying vec2 vTexCoord;
        uniform mat4 uMVPMatrix;
        void main() {
            gl_Position = uMVPMatrix * aPosition;
            vTexCoord = aTexCoord;
        }
    """.trimIndent()

    private val FRAGMENT_SHADER = """
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D sTexture;
        uniform float uAlpha;
        uniform float uSaturation; // 0.0 to 2.0
        uniform float uBrightness; // -1.0 to 1.0
        uniform float uBlur; // sigma
        uniform vec2 uCellSize; // cell width, height in pixels
        uniform vec2 uCellCenter; // cell center in pixels (GL coords, 0,0 at bottom-left)
        uniform float uRadius; // radius in pixels
        uniform float uFlippedH; // 0.0 or 1.0
        uniform float uFlippedV; // 0.0 or 1.0
        
        float roundedBoxSDF(vec2 p, vec2 b, float r) {
            vec2 d = abs(p) - b + vec2(r);
            return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
        }

        void main() {
            // Use gl_FragCoord to find distance from the STATIC cell center
            vec2 p = gl_FragCoord.xy - uCellCenter;
            float dist = roundedBoxSDF(p, uCellSize * 0.5, uRadius);
            
            // Smoothly clip corners (Anti-aliasing)
            float smoothing = 1.0; 
            float alpha = 1.0 - smoothstep(-smoothing, 0.0, dist);
            
            if (alpha <= 0.0) {
                discard;
            }
            
            // Mirror UVs if needed
            vec2 uv = vTexCoord;
            if (uFlippedH > 0.5) uv.x = 1.0 - uv.x;
            if (uFlippedV > 0.5) uv.y = 1.0 - uv.y;
            
            vec4 color;
            if (uBlur > 0.1) {
                // Resolution-aware spread calculation
                // Spread is calculated in UV space [0,1] based on the pixel blur sigma and cell size
                vec2 spread = (uBlur * 0.5) / uCellSize; 
                color = texture2D(sTexture, uv) * 0.25;
                color += texture2D(sTexture, uv + vec2(spread.x, 0.0)) * 0.15;
                color += texture2D(sTexture, uv + vec2(-spread.x, 0.0)) * 0.15;
                color += texture2D(sTexture, uv + vec2(0.0, spread.y)) * 0.15;
                color += texture2D(sTexture, uv + vec2(0.0, -spread.y)) * 0.15;
                color += texture2D(sTexture, uv + spread) * 0.0375;
                color += texture2D(sTexture, uv - spread) * 0.0375;
                color += texture2D(sTexture, uv + vec2(spread.x, -spread.y)) * 0.0375;
                color += texture2D(sTexture, uv + vec2(-spread.x, spread.y)) * 0.0375;
            } else {
                color = texture2D(sTexture, uv);
            }
            
            // Apply Brightness
            color.rgb += uBrightness;
            
            // Apply Saturation
            float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
            vec3 grayscale = vec3(luminance);
            vec3 saturatedColor = mix(grayscale, color.rgb, uSaturation);
            
            gl_FragColor = vec4(saturatedColor, color.a * uAlpha * alpha);
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

    data class CollageItem(
        val path: String,
        val x: Float,      // Pixels from top-left
        val y: Float,      // Pixels from top-left
        val width: Float,  // Pixels
        val height: Float, // Pixels
        val matrix: FloatArray, // 16 elements from TransformationController
        val saturation: Float, // 0.0 to 2.0
        val brightness: Float, // -1.0 to 1.0
        val blur: Float, // sigma
        val radius: Float, // corner radius in pixels
        val flippedH: Boolean,
        val flippedV: Boolean,
        val gap: Float // pixels
    )

    fun renderCollage(
        items: List<CollageItem>,
        outWidth: Int,
        outHeight: Int,
        canvasWidth: Float,
        canvasHeight: Float,
        bgColor: Int,
        showEdgeSpacing: Boolean,
        outputPath: String
    ): Boolean {
        Log.d(TAG, "Starting collage render: ${outWidth}x${outHeight} (Canvas: ${canvasWidth}x${canvasHeight})")
        
        try {
            initEGL(outWidth, outHeight)
            initGL()

            GLES20.glViewport(0, 0, outWidth, outHeight)
            val r = Color.red(bgColor) / 255f
            val g = Color.green(bgColor) / 255f
            val b = Color.blue(bgColor) / 255f
            GLES20.glClearColor(r, g, b, 1.0f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

            GLES20.glEnable(GLES20.GL_BLEND)
            GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
            GLES20.glEnable(GLES20.GL_SCISSOR_TEST)

            for (item in items) {
                if (item.path.isEmpty() || !File(item.path).exists()) continue

                // Apply Gap with Edge Spacing awareness
                val gap = item.gap
                val epsilon = 2f // Tolerance for floating point edge detection
                
                val isLeft = item.x < epsilon
                val isTop = item.y < epsilon
                val isRight = (item.x + item.width) > (canvasWidth - epsilon)
                val isBottom = (item.y + item.height) > (canvasHeight - epsilon)

                val leftGap = if (isLeft && !showEdgeSpacing) 0f else gap / 2f
                val topGap = if (isTop && !showEdgeSpacing) 0f else gap / 2f
                val rightGap = if (isRight && !showEdgeSpacing) 0f else gap / 2f
                val bottomGap = if (isBottom && !showEdgeSpacing) 0f else gap / 2f

                val iWidth = (item.width - leftGap - rightGap).coerceAtLeast(1f)
                val iHeight = (item.height - topGap - bottomGap).coerceAtLeast(1f)
                val iX = item.x + leftGap
                val iY = item.y + topGap

                // 0. Setup Scissor Box for this cell
                // GL scissor uses window coordinates: (0,0) is bottom-left, units in pixels
                val sWidth = (iWidth / canvasWidth * outWidth).toInt()
                val sHeight = (iHeight / canvasHeight * outHeight).toInt()
                val sX = (iX / canvasWidth * outWidth).toInt()
                // Flip Y because Flutter is top-down, GL is bottom-up
                val sY = outHeight - ((iY + iHeight) / canvasHeight * outHeight).toInt()
                
                GLES20.glScissor(sX, sY, sWidth, sHeight)
                
                val bmp = decodeSampledBitmap(item.path, outWidth / 2) ?: continue
                val texId = loadTexture(bmp)
                
                // 1. Calculate the normalized coordinates of the cell within the Flutter canvas space
                val scaleX = iWidth / canvasWidth
                val scaleY = iHeight / canvasHeight
                
                // Center of the cell in GL units
                val cellCenterX = (iX + iWidth / 2f) / canvasWidth * 2f - 1f
                val cellCenterY = 1f - (iY + iHeight / 2f) / canvasHeight * 2f
                
                val bmpW = bmp.width.toFloat()
                val bmpH = bmp.height.toFloat()
                val bmpAspect = bmpW / bmpH
                val cellAspect = iWidth / iHeight

                // 2. BoxFit.cover logic: 
                // We want the image to fill the cell entirely, cropping the excess.
                var baseScaleX = 1f
                var baseScaleY = 1f

                if (bmpAspect > cellAspect) {
                    // Image is wider than cell -> scale by height to fill, crop sides
                    baseScaleX = bmpAspect / cellAspect
                } else {
                    // Image is taller than cell -> scale by width to fill, crop top/bottom
                    baseScaleY = cellAspect / bmpAspect
                }

                // 3. Setup MVP
                // We start with the full canvas space [-1, 1]
                val itemMvp = FloatArray(16)
                android.opengl.Matrix.setIdentityM(itemMvp, 0)
                
                // Move to cell center in GL canvas
                android.opengl.Matrix.translateM(itemMvp, 0, cellCenterX, cellCenterY, 0f)
                
                // 4. Apply User Transformation (Pan + Zoom)
                // Flutter translation (item.matrix[12/13]) is relative to cell top-left.
                // OpenGL quad is centered at (0,0).
                // Image center in cell = s * w/2 + tx
                // Offset from cell center = tx + (s-1)*w/2
                val fScale = item.matrix[0]
                val txOffset = item.matrix[12] + (fScale - 1f) * iWidth / 2f
                val tyOffset = item.matrix[13] + (fScale - 1f) * iHeight / 2f
                
                android.opengl.Matrix.translateM(itemMvp, 0, (txOffset / canvasWidth) * 2f, -(tyOffset / canvasHeight) * 2f, 0f)
                
                // 5. Build the final scale: CellSize * BoxFit.cover * UserScale
                android.opengl.Matrix.scaleM(itemMvp, 0, scaleX * baseScaleX * fScale, scaleY * baseScaleY * fScale, 1f)
                
                // 6. Calculate pixel dimensions and center for the shader's SDF (Fragment-Space Static Clipping)
                val exportCellW = iWidth / canvasWidth * outWidth
                val exportCellH = iHeight / canvasHeight * outHeight
                
                // Static pixel-center for the cell (GL coords: 0,0 is bottom-left)
                val pixelCellCenterX = (iX + iWidth / 2f) / canvasWidth * outWidth
                val pixelCellCenterY = outHeight - (iY + iHeight / 2f) / canvasHeight * outHeight
                
                // Pass width/height/saturation/brightness/blur/center/radius/mirroring to shader
                drawTexture(texId, itemMvp, exportCellW, exportCellH, pixelCellCenterX, pixelCellCenterY, item.radius, item.saturation, item.brightness, item.blur, item.flippedH, item.flippedV)
                
                GLES20.glDeleteTextures(1, intArrayOf(texId), 0)
                bmp.recycle()
            }

            GLES20.glDisable(GLES20.GL_BLEND)
            
            // Read pixels
            saveToFile(outWidth, outHeight, outputPath)
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Render failed: ${e.message}")
            return false
        } finally {
            releaseEGL()
        }
    }

    private fun initEGL(width: Int, height: Int) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        EGL14.eglInitialize(eglDisplay, version, 0, version, 1)

        val configAttribs = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_DEPTH_SIZE, 0,
            EGL14.EGL_STENCIL_SIZE, 0,
            EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        EGL14.eglChooseConfig(eglDisplay, configAttribs, 0, configs, 0, 1, numConfigs, 0)
        val config = configs[0]

        val contextAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(eglDisplay, config, EGL14.EGL_NO_CONTEXT, contextAttribs, 0)

        val pbufferAttribs = intArrayOf(EGL14.EGL_WIDTH, width, EGL14.EGL_HEIGHT, height, EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreatePbufferSurface(eglDisplay, config, pbufferAttribs, 0)

        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun initGL() {
        program = createProgram(VERTEX_SHADER, FRAGMENT_SHADER)
        GLES20.glUseProgram(program)
    }

    private fun createProgram(vSource: String, fSource: String): Int {
        val vs = loadShader(GLES20.GL_VERTEX_SHADER, vSource)
        val fs = loadShader(GLES20.GL_FRAGMENT_SHADER, fSource)
        val p = GLES20.glCreateProgram()
        GLES20.glAttachShader(p, vs)
        GLES20.glAttachShader(p, fs)
        GLES20.glLinkProgram(p)
        return p
    }

    private fun loadShader(type: Int, source: String): Int {
        val s = GLES20.glCreateShader(type)
        GLES20.glShaderSource(s, source)
        GLES20.glCompileShader(s)
        return s
    }

    private fun loadTexture(bitmap: Bitmap): Int {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        return textures[0]
    }

    private fun drawTexture(texId: Int, mvp: FloatArray, cellW: Float, cellH: Float, centerX: Float, centerY: Float, radius: Float, saturation: Float, brightness: Float, blur: Float, flippedH: Boolean, flippedV: Boolean) {
        GLES20.glUseProgram(program)
        val posHandle = GLES20.glGetAttribLocation(program, "aPosition")
        val texHandle = GLES20.glGetAttribLocation(program, "aTexCoord")
        val mvpHandle = GLES20.glGetUniformLocation(program, "uMVPMatrix")
        val alphaHandle = GLES20.glGetUniformLocation(program, "uAlpha")
        val sizeHandle = GLES20.glGetUniformLocation(program, "uCellSize")
        val centerHandle = GLES20.glGetUniformLocation(program, "uCellCenter")
        val radiusHandle = GLES20.glGetUniformLocation(program, "uRadius")
        val saturationHandle = GLES20.glGetUniformLocation(program, "uSaturation")
        val brightnessHandle = GLES20.glGetUniformLocation(program, "uBrightness")
        val blurHandle = GLES20.glGetUniformLocation(program, "uBlur")
        val flipHHandle = GLES20.glGetUniformLocation(program, "uFlippedH")
        val flipVHandle = GLES20.glGetUniformLocation(program, "uFlippedV")

        GLES20.glEnableVertexAttribArray(posHandle)
        GLES20.glVertexAttribPointer(posHandle, 3, GLES20.GL_FLOAT, false, 12, vertexBuffer)

        GLES20.glEnableVertexAttribArray(texHandle)
        GLES20.glVertexAttribPointer(texHandle, 2, GLES20.GL_FLOAT, false, 8, texCoordBuffer)

        GLES20.glUniformMatrix4fv(mvpHandle, 1, false, mvp, 0)
        GLES20.glUniform1f(alphaHandle, 1.0f)
        GLES20.glUniform2f(sizeHandle, cellW, cellH)
        GLES20.glUniform2f(centerHandle, centerX, centerY)
        GLES20.glUniform1f(radiusHandle, radius)
        GLES20.glUniform1f(saturationHandle, saturation)
        GLES20.glUniform1f(brightnessHandle, brightness)
        GLES20.glUniform1f(blurHandle, blur)
        GLES20.glUniform1f(flipHHandle, if (flippedH) 1.0f else 0.0f)
        GLES20.glUniform1f(flipVHandle, if (flippedV) 1.0f else 0.0f)

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(posHandle)
        GLES20.glDisableVertexAttribArray(texHandle)
    }

    private fun saveToFile(width: Int, height: Int, path: String) {
        val buffer = ByteBuffer.allocateDirect(width * height * 4)
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        GLES20.glReadPixels(0, 0, width, height, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buffer)
        
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        buffer.rewind()
        bitmap.copyPixelsFromBuffer(buffer)
        
        // Flip vertically
        val androidMatrix = android.graphics.Matrix()
        androidMatrix.postScale(1f, -1f, width / 2f, height / 2f)
        val flipped = Bitmap.createBitmap(bitmap, 0, 0, width, height, androidMatrix, false)
        
        val file = File(path)
        FileOutputStream(file).use { 
            flipped.compress(Bitmap.CompressFormat.JPEG, 95, it)
        }
        bitmap.recycle()
        flipped.recycle()
    }

    private fun decodeSampledBitmap(path: String, reqWidth: Int): Bitmap? {
        val options = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
            BitmapFactory.decodeFile(path, this)
            inSampleSize = calculateInSampleSize(this, reqWidth, reqWidth)
            inJustDecodeBounds = false
        }
        return BitmapFactory.decodeFile(path, options)
    }

    private fun calculateInSampleSize(options: BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
        val (height: Int, width: Int) = options.outHeight to options.outWidth
        var inSampleSize = 1
        if (height > reqHeight || width > reqWidth) {
            val halfHeight: Int = height / 2
            val halfWidth: Int = width / 2
            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }

    private fun releaseEGL() {
        if (eglDisplay !== EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(eglDisplay, eglSurface)
            EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglReleaseThread()
            EGL14.eglTerminate(eglDisplay)
        }
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        eglSurface = EGL14.EGL_NO_SURFACE
    }
}
