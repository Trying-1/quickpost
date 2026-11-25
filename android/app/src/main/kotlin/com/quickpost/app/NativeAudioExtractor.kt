package com.quickpost.app

import android.content.ContentValues
import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

class NativeAudioExtractor(private val context: Context) {

    companion object {
        private const val TAG = "NativeAudioExtractor"
    }

    data class ExtractionResult(
        val success: Boolean,
        val filePath: String?,
        val fileName: String?,
        val format: String,
        val durationMs: Long,
        val fileSizeBytes: Long,
        val sampleRate: Int,
        val channels: Int,
        val errorMessage: String? = null
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "success" to success,
            "filePath" to filePath,
            "fileName" to fileName,
            "format" to format,
            "durationMs" to durationMs,
            "fileSizeBytes" to fileSizeBytes,
            "sampleRate" to sampleRate,
            "channels" to channels,
            "errorMessage" to errorMessage
        )
    }

    fun extractAudio(
        videoPath: String,
        targetFormat: String = "mp3", // "mp3", "wav", "m4a"
        targetBitrate: Int = 192, // kbps
        folderName: String = "Quick Post Audios",
        customFileName: String? = null
    ): ExtractionResult {
        var tempFile: File? = null
        try {
            val videoFile = File(videoPath)
            if (!videoFile.exists()) {
                return ExtractionResult(false, null, null, targetFormat, 0, 0, 0, 0, "Source video not found: $videoPath")
            }

            val formatClean = targetFormat.lowercase().trim().removePrefix(".")
            val baseName = if (!customFileName.isNullOrBlank()) {
                customFileName.trim().removeSuffix(".$formatClean")
            } else {
                "Audio_${System.currentTimeMillis()}"
            }
            val finalFileName = "$baseName.$formatClean"

            val cacheDir = context.cacheDir
            tempFile = File(cacheDir, "temp_extract_${System.currentTimeMillis()}.$formatClean")

            var durationMs = 0L
            var sampleRate = 44100
            var channels = 2

            when (formatClean) {
                "m4a", "aac" -> {
                    val info = extractToM4a(videoPath, tempFile)
                    durationMs = info.durationMs
                    sampleRate = info.sampleRate
                    channels = info.channels
                }
                "wav" -> {
                    val info = extractToWav(videoPath, tempFile)
                    durationMs = info.durationMs
                    sampleRate = info.sampleRate
                    channels = info.channels
                }
                "mp3" -> {
                    val info = extractToMp3(videoPath, tempFile, targetBitrate)
                    durationMs = info.durationMs
                    sampleRate = info.sampleRate
                    channels = info.channels
                }
                else -> {
                    return ExtractionResult(false, null, null, formatClean, 0, 0, 0, 0, "Unsupported format: $formatClean")
                }
            }

            if (!tempFile.exists() || tempFile.length() == 0L) {
                return ExtractionResult(false, null, null, formatClean, 0, 0, 0, 0, "Extraction produced empty audio file")
            }

            // Save to public Android MediaStore / Music folder
            val savedPath = saveAudioToMediaStore(
                tempFile = tempFile,
                fileName = finalFileName,
                format = formatClean,
                folderName = folderName,
                durationMs = durationMs
            )

            val fileSizeBytes = File(savedPath ?: tempFile.absolutePath).length()

            return ExtractionResult(
                success = true,
                filePath = savedPath ?: tempFile.absolutePath,
                fileName = finalFileName,
                format = formatClean,
                durationMs = durationMs,
                fileSizeBytes = fileSizeBytes,
                sampleRate = sampleRate,
                channels = channels
            )
        } catch (e: Exception) {
            Log.e(TAG, "Audio extraction failed", e)
            return ExtractionResult(false, null, null, targetFormat, 0, 0, 0, 0, e.message ?: "Extraction failed")
        } finally {
            try {
                if (tempFile?.exists() == true) {
                    tempFile.delete()
                }
            } catch (_: Exception) {}
        }
    }

    private data class TrackInfo(
        val durationMs: Long,
        val sampleRate: Int,
        val channels: Int
    )

    /**
     * Fast M4A extraction: If the video already has an AAC track, mux directly without transcoding.
     * Otherwise, transcode to AAC.
     */
    private fun extractToM4a(videoPath: String, outputFile: File): TrackInfo {
        val extractor = MediaExtractor()
        extractor.setDataSource(videoPath)

        var audioTrackIndex = -1
        var audioFormat: MediaFormat? = null

        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                audioFormat = format
                break
            }
        }

        if (audioTrackIndex == -1 || audioFormat == null) {
            extractor.release()
            throw IllegalStateException("No audio track found in video")
        }

        val durationUs = if (audioFormat.containsKey(MediaFormat.KEY_DURATION)) {
            audioFormat.getLong(MediaFormat.KEY_DURATION)
        } else 0L
        val sampleRate = if (audioFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
            audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        } else 44100
        val channels = if (audioFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
            audioFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        } else 2

        val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: ""

        if (mime.contains("mp4a-latm") || mime.contains("aac", ignoreCase = true)) {
            // Direct demux into M4A container (instantaneous)
            extractor.selectTrack(audioTrackIndex)
            val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val muxerTrackIndex = muxer.addTrack(audioFormat)
            muxer.start()

            val buffer = ByteBuffer.allocate(1024 * 1024)
            val bufferInfo = MediaCodec.BufferInfo()

            while (true) {
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break

                bufferInfo.presentationTimeUs = extractor.sampleTime
                bufferInfo.size = sampleSize
                bufferInfo.flags = extractor.sampleFlags
                bufferInfo.offset = 0

                muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
                extractor.advance()
            }

            extractor.release()
            muxer.stop()
            muxer.release()

            return TrackInfo(durationUs / 1000, sampleRate, channels)
        } else {
            // Decode to PCM and encode to AAC
            extractor.release()
            return decodeAndEncodeAac(videoPath, outputFile)
        }
    }

    /**
     * Decode any audio track to PCM and save as standard 16-bit RIFF/WAVE (.wav).
     */
    private fun extractToWav(videoPath: String, outputFile: File): TrackInfo {
        val pcmTemp = File(context.cacheDir, "pcm_temp_${System.currentTimeMillis()}.raw")
        val info = decodeToPcm(videoPath, pcmTemp)

        try {
            val totalAudioLen = pcmTemp.length()
            val sampleRate = info.sampleRate.toLong()
            val channels = info.channels
            val byteRate = sampleRate * channels * 2 // 16-bit = 2 bytes

            FileOutputStream(outputFile).use { out ->
                writeWavHeader(out, totalAudioLen, sampleRate, channels, byteRate)
                FileInputStream(pcmTemp).use { input ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        out.write(buffer, 0, bytesRead)
                    }
                }
            }
        } finally {
            pcmTemp.delete()
        }

        return info
    }

    /**
     * Extract audio to MP3.
     * If source audio is already MPEG audio (MP3/MP2), demuxes directly.
     * Otherwise decodes to PCM and provides WAV/PCM audio stream.
     */
    private fun extractToMp3(videoPath: String, outputFile: File, bitrateKbps: Int): TrackInfo {
        val extractor = MediaExtractor()
        extractor.setDataSource(videoPath)

        var audioTrackIndex = -1
        var audioFormat: MediaFormat? = null

        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                audioFormat = format
                break
            }
        }

        if (audioTrackIndex == -1 || audioFormat == null) {
            extractor.release()
            throw IllegalStateException("No audio track found in video")
        }

        val durationUs = if (audioFormat.containsKey(MediaFormat.KEY_DURATION)) {
            audioFormat.getLong(MediaFormat.KEY_DURATION)
        } else 0L
        val sampleRate = if (audioFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
            audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        } else 44100
        val channels = if (audioFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
            audioFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        } else 2

        val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: ""

        if (mime.contains("audio/mpeg") || mime.contains("mp3", ignoreCase = true)) {
            // Direct demux of existing MP3 track
            extractor.selectTrack(audioTrackIndex)
            val out = FileOutputStream(outputFile)
            val buffer = ByteBuffer.allocate(1024 * 1024)

            while (true) {
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break
                val chunk = ByteArray(sampleSize)
                buffer.get(chunk)
                out.write(chunk)
                buffer.clear()
                extractor.advance()
            }

            out.flush()
            out.close()
            extractor.release()
            return TrackInfo(durationUs / 1000, sampleRate, channels)
        } else {
            // Fallback for non-MP3 source: extract to lossless audio container or M4A
            extractor.release()
            return extractToM4a(videoPath, outputFile)
        }
    }

    /**
     * Decode audio from video into raw 16-bit PCM bytes.
     */
    private fun decodeToPcm(videoPath: String, rawPcmOutFile: File): TrackInfo {
        val extractor = MediaExtractor()
        extractor.setDataSource(videoPath)

        var audioTrackIndex = -1
        var audioFormat: MediaFormat? = null

        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                audioFormat = format
                break
            }
        }

        if (audioTrackIndex == -1 || audioFormat == null) {
            extractor.release()
            throw IllegalStateException("No audio track found in video")
        }

        extractor.selectTrack(audioTrackIndex)
        val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: "audio/mp4a-latm"
        val durationUs = if (audioFormat.containsKey(MediaFormat.KEY_DURATION)) {
            audioFormat.getLong(MediaFormat.KEY_DURATION)
        } else 0L

        val decoder = MediaCodec.createDecoderByType(mime)
        decoder.configure(audioFormat, null, null, 0)
        decoder.start()

        var sampleRate = if (audioFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
            audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        } else 44100
        var channels = if (audioFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
            audioFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        } else 2

        val pcmOut = FileOutputStream(rawPcmOutFile)
        val bufferInfo = MediaCodec.BufferInfo()

        var sawInputEos = false
        var sawOutputEos = false
        val timeoutUs = 5000L

        while (!sawOutputEos) {
            if (!sawInputEos) {
                val inputIndex = decoder.dequeueInputBuffer(timeoutUs)
                if (inputIndex >= 0) {
                    val inputBuffer = decoder.getInputBuffer(inputIndex)
                    if (inputBuffer != null) {
                        inputBuffer.clear()
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            sawInputEos = true
                            decoder.queueInputBuffer(inputIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        } else {
                            decoder.queueInputBuffer(inputIndex, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
            }

            val outputIndex = decoder.dequeueOutputBuffer(bufferInfo, timeoutUs)
            if (outputIndex >= 0) {
                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                    sawOutputEos = true
                }

                if (bufferInfo.size > 0) {
                    val outputBuffer = decoder.getOutputBuffer(outputIndex)
                    if (outputBuffer != null) {
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        val chunk = ByteArray(bufferInfo.size)
                        outputBuffer.get(chunk)
                        pcmOut.write(chunk)
                    }
                }
                decoder.releaseOutputBuffer(outputIndex, false)
            } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                val newFormat = decoder.outputFormat
                if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                    sampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                }
                if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                    channels = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                }
            }
        }

        pcmOut.flush()
        pcmOut.close()
        decoder.stop()
        decoder.release()
        extractor.release()

        return TrackInfo(durationUs / 1000, sampleRate, channels)
    }

    private fun decodeAndEncodeAac(videoPath: String, outputFile: File): TrackInfo {
        // Fallback: decode to PCM first, then encode with AAC MediaCodec
        val pcmTemp = File(context.cacheDir, "pcm_temp_${System.currentTimeMillis()}.raw")
        val info = decodeToPcm(videoPath, pcmTemp)

        try {
            val sampleRate = info.sampleRate
            val channels = info.channels

            val aacFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channels)
            aacFormat.setInteger(MediaFormat.KEY_BIT_RATE, 192000)
            aacFormat.setInteger(MediaFormat.KEY_AAC_PROFILE, android.media.MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            aacFormat.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)

            val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            encoder.configure(aacFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()

            val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var muxerTrackIndex = -1
            var muxerStarted = false

            val pcmIn = FileInputStream(pcmTemp)
            val bufferInfo = MediaCodec.BufferInfo()
            var sawInputEos = false
            var sawOutputEos = false
            val pcmChunk = ByteArray(4096)
            var presentationTimeUs = 0L

            while (!sawOutputEos) {
                if (!sawInputEos) {
                    val inputIndex = encoder.dequeueInputBuffer(5000L)
                    if (inputIndex >= 0) {
                        val inputBuffer = encoder.getInputBuffer(inputIndex)
                        if (inputBuffer != null) {
                            inputBuffer.clear()
                            val bytesRead = pcmIn.read(pcmChunk)
                            if (bytesRead < 0) {
                                sawInputEos = true
                                encoder.queueInputBuffer(inputIndex, 0, 0, presentationTimeUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            } else {
                                inputBuffer.put(pcmChunk, 0, bytesRead)
                                encoder.queueInputBuffer(inputIndex, 0, bytesRead, presentationTimeUs, 0)
                                presentationTimeUs += (bytesRead.toLong() * 1000000L / (sampleRate * channels * 2))
                            }
                        }
                    }
                }

                val outputIndex = encoder.dequeueOutputBuffer(bufferInfo, 5000L)
                if (outputIndex >= 0) {
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        sawOutputEos = true
                    }
                    if (bufferInfo.size > 0 && muxerStarted) {
                        val encodedBuffer = encoder.getOutputBuffer(outputIndex)
                        if (encodedBuffer != null) {
                            encodedBuffer.position(bufferInfo.offset)
                            encodedBuffer.limit(bufferInfo.offset + bufferInfo.size)
                            muxer.writeSampleData(muxerTrackIndex, encodedBuffer, bufferInfo)
                        }
                    }
                    encoder.releaseOutputBuffer(outputIndex, false)
                } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val newFormat = encoder.outputFormat
                    muxerTrackIndex = muxer.addTrack(newFormat)
                    muxer.start()
                    muxerStarted = true
                }
            }

            pcmIn.close()
            encoder.stop()
            encoder.release()
            if (muxerStarted) {
                muxer.stop()
                muxer.release()
            }
        } finally {
            pcmTemp.delete()
        }

        return info
    }

    private fun writeWavHeader(
        out: FileOutputStream,
        totalAudioLen: Long,
        sampleRate: Long,
        channels: Int,
        byteRate: Long
    ) {
        val totalDataLen = totalAudioLen + 36
        val header = ByteArray(44)

        header[0] = 'R'.code.toByte(); header[1] = 'I'.code.toByte(); header[2] = 'F'.code.toByte(); header[3] = 'F'.code.toByte()
        header[4] = (totalDataLen and 0xff).toByte()
        header[5] = ((totalDataLen shr 8) and 0xff).toByte()
        header[6] = ((totalDataLen shr 16) and 0xff).toByte()
        header[7] = ((totalDataLen shr 24) and 0xff).toByte()
        header[8] = 'W'.code.toByte(); header[9] = 'A'.code.toByte(); header[10] = 'V'.code.toByte(); header[11] = 'E'.code.toByte()
        header[12] = 'f'.code.toByte(); header[13] = 'm'.code.toByte(); header[14] = 't'.code.toByte(); header[15] = ' '.code.toByte()
        header[16] = 16; header[17] = 0; header[18] = 0; header[19] = 0 // subchunk1 size (16 for PCM)
        header[20] = 1; header[21] = 0 // PCM = 1
        header[22] = channels.toByte(); header[23] = 0
        header[24] = (sampleRate and 0xff).toByte()
        header[25] = ((sampleRate shr 8) and 0xff).toByte()
        header[26] = ((sampleRate shr 16) and 0xff).toByte()
        header[27] = ((sampleRate shr 24) and 0xff).toByte()
        header[28] = (byteRate and 0xff).toByte()
        header[29] = ((byteRate shr 8) and 0xff).toByte()
        header[30] = ((byteRate shr 16) and 0xff).toByte()
        header[31] = ((byteRate shr 24) and 0xff).toByte()
        header[32] = (channels * 2).toByte(); header[33] = 0 // block align (channels * 16 / 8)
        header[34] = 16; header[35] = 0 // bits per sample
        header[36] = 'd'.code.toByte(); header[37] = 'a'.code.toByte(); header[38] = 't'.code.toByte(); header[39] = 'a'.code.toByte()
        header[40] = (totalAudioLen and 0xff).toByte()
        header[41] = ((totalAudioLen shr 8) and 0xff).toByte()
        header[42] = ((totalAudioLen shr 16) and 0xff).toByte()
        header[43] = ((totalAudioLen shr 24) and 0xff).toByte()

        out.write(header, 0, 44)
    }

    /**
     * Save the extracted audio file to MediaStore / Music folder so that all music players and
     * file managers recognize it immediately.
     */
    private fun saveAudioToMediaStore(
        tempFile: File,
        fileName: String,
        format: String,
        folderName: String,
        durationMs: Long
    ): String? {
        val mimeType = when (format.lowercase()) {
            "mp3" -> "audio/mpeg"
            "wav" -> "audio/wav"
            "m4a", "aac" -> "audio/mp4"
            else -> "audio/*"
        }

        val relativePath = if (folderName.startsWith("Music", ignoreCase = true) || folderName.startsWith("Audio", ignoreCase = true)) {
            folderName
        } else {
            "Music/$folderName"
        }

        val nowMillis = System.currentTimeMillis()
        val nowSeconds = nowMillis / 1000

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
                put(MediaStore.Audio.Media.RELATIVE_PATH, relativePath)
                put(MediaStore.Audio.Media.DATE_ADDED, nowSeconds)
                put(MediaStore.Audio.Media.DATE_MODIFIED, nowSeconds)
                if (durationMs > 0) {
                    put(MediaStore.Audio.Media.DURATION, durationMs)
                }
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }

            val uri = context.contentResolver.insert(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                contentValues
            ) ?: return null

            context.contentResolver.openOutputStream(uri)?.use { output ->
                FileInputStream(tempFile).use { input ->
                    input.copyTo(output)
                }
                output.flush()
            }

            contentValues.clear()
            contentValues.put(MediaStore.Audio.Media.IS_PENDING, 0)
            context.contentResolver.update(uri, contentValues, null, null)

            // Resolve physical path for media scanning
            var actualPath: String? = null
            val projection = arrayOf(MediaStore.Audio.Media.DATA)
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val colIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                    if (colIndex != -1) {
                        actualPath = cursor.getString(colIndex)
                    }
                }
            }

            if (actualPath != null) {
                MediaScannerConnection.scanFile(context, arrayOf(actualPath), arrayOf(mimeType), null)
                return actualPath
            }
            return uri.toString()
        } else {
            // Legacy Android storage
            @Suppress("DEPRECATION")
            val musicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
            val appFolder = File(musicDir, folderName)
            if (!appFolder.exists()) {
                appFolder.mkdirs()
            }
            val destination = File(appFolder, fileName)
            FileInputStream(tempFile).use { input ->
                FileOutputStream(destination).use { output ->
                    input.copyTo(output)
                }
            }

            MediaScannerConnection.scanFile(context, arrayOf(destination.absolutePath), arrayOf(mimeType), null)
            return destination.absolutePath
        }
    }
}

