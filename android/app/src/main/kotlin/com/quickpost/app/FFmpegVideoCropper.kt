package com.quickpost.app

import android.content.Context
import android.util.Log

class FFmpegVideoCropper(private val context: Context) {

    external fun nativeCropVideo(
        inputPath: String,
        outputPath: String,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        preset: String,
        crf: Int,
    ): Int

    init {
        try {
            System.loadLibrary("myffmpeg")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to load myffmpeg native library", e)
        }
    }

    fun cropVideosBatch(
        items: List<Map<String, Any>>, 
        preset: String = "veryfast", 
        crf: Int = 23
    ): List<String> {
        val results = mutableListOf<String>()
        for ((index, item) in items.withIndex()) {
            val inputPath = item["inputPath"] as? String ?: continue
            val providedOutputPath = item["outputPath"] as? String
            var x = (item["x"] as? Number)?.toInt() ?: 0
            var y = (item["y"] as? Number)?.toInt() ?: 0
            var width = (item["width"] as? Number)?.toInt() ?: 0
            var height = (item["height"] as? Number)?.toInt() ?: 0

            // Avoid green artifacts / glitches in common H.264 yuv420p pipelines by ensuring
            // crop rectangle is aligned to even pixels.
            if (x % 2 != 0) x -= 1
            if (y % 2 != 0) y -= 1
            if (width % 2 != 0) width -= 1
            if (height % 2 != 0) height -= 1
            if (x < 0) x = 0
            if (y < 0) y = 0

            if (width <= 0 || height <= 0) {
                Log.w(TAG, "Skipping item $index due to invalid crop rect: $width x $height")
                continue
            }

            val outputPath = providedOutputPath
                ?: run {
                    val filename = "QuickPost_Cropped_${System.currentTimeMillis()}_$index.mp4"
                    getVideoOutputPath(filename)
                }

            val ret = nativeCropVideo(
                inputPath,
                outputPath,
                x,
                y,
                width,
                height,
                preset,
                crf,
            )

            if (ret == 0) {
                results.add(outputPath)
            } else {
                Log.e(TAG, "nativeCropVideo failed for $inputPath with code $ret")
            }
        }
        return results
    }

    private fun getVideoOutputPath(filename: String): String {
        // Reuse same logic as MainActivity.getVideoOutputPath but localized here
        val moviesDir = context.getExternalFilesDir(null)
        val outDir = java.io.File(moviesDir, "CroppedVideos")
        if (!outDir.exists()) {
            outDir.mkdirs()
        }
        return java.io.File(outDir, filename).absolutePath
    }

    companion object {
        private const val TAG = "FFmpegVideoCropper"
    }
}
