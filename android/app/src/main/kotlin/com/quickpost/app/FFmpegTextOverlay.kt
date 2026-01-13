package com.quickpost.app

import android.content.Context
import android.util.Log

class FFmpegTextOverlay(private val context: Context) {

    private var isNativeLoaded: Boolean = false

    init {
        try {
            System.loadLibrary("myffmpeg")
            isNativeLoaded = true
            Log.i(TAG, "myffmpeg library loaded successfully")
        } catch (e: UnsatisfiedLinkError) {
            isNativeLoaded = false
            Log.e(TAG, "Failed to load myffmpeg library", e)
        }
    }

    external fun nativeAddTextToVideo(
        inputPath: String,
        outputPath: String,
        text: String,
        x: Int,
        y: Int,
        fontSize: Int,
        fontColor: String,
        boxColor: String,
        position: String,
        fontPath: String,
        preset: String,
        crf: Int,
    ): Int

    fun addTextToVideo(
        inputPath: String,
        outputPath: String,
        text: String,
        x: Int,
        y: Int,
        fontSize: Int,
        fontColor: String,
        boxColor: String,
        position: String,
        fontPath: String,
        preset: String,
        crf: Int,
    ): Int {
        Log.i(TAG, "addTextToVideo called: input=$inputPath, output=$outputPath")

        if (!isNativeLoaded) {
            Log.e(TAG, "Native library not loaded, aborting addTextToVideo")
            // Return non-zero error code so caller can surface a friendly error
            return -999
        }

        return nativeAddTextToVideo(
            inputPath,
            outputPath,
            text,
            x,
            y,
            fontSize,
            fontColor,
            boxColor,
            position,
            fontPath,
            preset,
            crf,
        )
    }

    companion object {
        private const val TAG = "FFmpegTextOverlay"
    }
}
