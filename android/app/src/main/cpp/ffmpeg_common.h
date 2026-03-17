#ifndef FFMPEG_COMMON_H
#define FFMPEG_COMMON_H

#include <jni.h>

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavfilter/avfilter.h>
#include <libavutil/avutil.h>
#include <libavutil/opt.h>
}

#include <android/log.h>

#define LOG_TAG "myffmpeg"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Shared FFmpeg context structure
struct FFmpegContext {
    AVFormatContext* ifmt_ctx;
    AVFormatContext* ofmt_ctx;
    AVCodecContext* dec_ctx;
    AVCodecContext* enc_ctx;
    const AVCodec* decoder;
    const AVCodec* encoder;
    AVStream* out_stream;
    AVStream* audio_out_stream;
    int video_stream_idx;
    int audio_stream_idx;
    AVRational video_time_base;
};

// Initialize FFmpeg context
int ffmpeg_init_context(FFmpegContext* ctx);

// Open input file and find streams
int ffmpeg_open_input(FFmpegContext* ctx, const char* input_file);

// Setup video decoder
int ffmpeg_setup_decoder(FFmpegContext* ctx);

// Setup output format and encoder
int ffmpeg_setup_encoder(FFmpegContext* ctx, const char* output_file, 
                         const char* preset, int crf, int added_height);

// Setup audio stream passthrough
int ffmpeg_setup_audio_passthrough(FFmpegContext* ctx);

// Cleanup FFmpeg context
void ffmpeg_cleanup(FFmpegContext* ctx);

// Release JNI strings
void ffmpeg_release_jni_strings(JNIEnv* env, 
                                jstring inputPath, const char* input_file,
                                jstring outputPath, const char* output_file,
                                jstring text, const char* overlay_text,
                                jstring fontColor, const char* text_color_raw,
                                jstring boxColor, const char* box_color_raw,
                                jstring position, const char* position_raw,
                                jstring fontPath, const char* font,
                                jstring preset, const char* preset_str);

#endif // FFMPEG_COMMON_H
