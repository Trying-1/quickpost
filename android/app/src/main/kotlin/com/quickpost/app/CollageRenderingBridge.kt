package com.quickpost.app

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Bridge between Flutter and OpenGL Collage Processor.
 * Handles MethodChannel calls and decouples logic from MainActivity.
 */
class CollageRenderingBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    private val processor = OpenGLImageCollageProcessor(context)
    private val scope = CoroutineScope(Dispatchers.Main)

    companion object {
        const val CHANNEL_NAME = "com.quickpost.app/collage_renderer"
        
        fun register(messenger: io.flutter.plugin.common.BinaryMessenger, context: Context) {
            val channel = MethodChannel(messenger, CHANNEL_NAME)
            channel.setMethodCallHandler(CollageRenderingBridge(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "renderCollage" -> handleRenderCollage(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleRenderCollage(call: MethodCall, result: MethodChannel.Result) {
        val outWidth = call.argument<Number>("outWidth")?.toInt() ?: 1080
        val outHeight = call.argument<Number>("outHeight")?.toInt() ?: 1080
        val canvasWidth = call.argument<Number>("canvasWidth")?.toFloat() ?: 1080f
        val canvasHeight = call.argument<Number>("canvasHeight")?.toFloat() ?: 1080f
        val bgColor = call.argument<Number>("bgColor")?.toInt() ?: 0xFFFFFFFF.toInt()
        val cornerRadius = (call.argument<Number>("cornerRadius"))?.toFloat() ?: 0f
        val showEdgeSpacing = call.argument<Boolean>("showEdgeSpacing") ?: true
        val outputPath = call.argument<String>("outputPath") ?: ""
        val itemsData = call.argument<List<Map<String, Any>>>("items") ?: emptyList()

        if (outputPath.isEmpty()) {
            result.error("INVALID_PATH", "Output path cannot be empty", null)
            return
        }

        val items = itemsData.map { data ->
            OpenGLImageCollageProcessor.CollageItem(
                path = data["path"] as? String ?: "",
                x = (data["x"] as? Number)?.toFloat() ?: 0f,
                y = (data["y"] as? Number)?.toFloat() ?: 0f,
                width = (data["width"] as? Number)?.toFloat() ?: 0f,
                height = (data["height"] as? Number)?.toFloat() ?: 0f,
                matrix = (data["matrix"] as? List<Double>)?.map { it.toFloat() }?.toFloatArray() ?: FloatArray(16).apply { android.opengl.Matrix.setIdentityM(this, 0) },
                saturation = (data["saturation"] as? Number)?.toFloat() ?: 1.0f,
                brightness = (data["brightness"] as? Number)?.toFloat() ?: 0.0f,
                blur = (data["blur"] as? Number)?.toFloat() ?: 0.0f,
                radius = (data["radius"] as? Number)?.toFloat() ?: 0f,
                flippedH = data["flippedH"] as? Boolean ?: false,
                flippedV = data["flippedV"] as? Boolean ?: false,
                gap = (data["gap"] as? Number)?.toFloat() ?: 0f
            )
        }

        scope.launch {
            val success = withContext(Dispatchers.Default) {
                processor.renderCollage(items, outWidth, outHeight, canvasWidth, canvasHeight, bgColor, showEdgeSpacing, outputPath)
            }
            
            if (success) {
                result.success(outputPath)
            } else {
                result.error("RENDER_FAILED", "OpenGL rendering failed", null)
            }
        }
    }
}
