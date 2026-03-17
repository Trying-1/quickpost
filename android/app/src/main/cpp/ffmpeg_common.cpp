#include "ffmpeg_common.h"
#include <jni.h>

int ffmpeg_init_context(FFmpegContext* ctx) {
    if (!ctx) return -1;
    
    ctx->ifmt_ctx = nullptr;
    ctx->ofmt_ctx = nullptr;
    ctx->dec_ctx = nullptr;
    ctx->enc_ctx = nullptr;
    ctx->decoder = nullptr;
    ctx->encoder = nullptr;
    ctx->out_stream = nullptr;
    ctx->audio_out_stream = nullptr;
    ctx->video_stream_idx = -1;
    ctx->audio_stream_idx = -1;
    ctx->video_time_base = {1, 30}; // Default fallback
    
    return 0;
}

int ffmpeg_open_input(FFmpegContext* ctx, const char* input_file) {
    if (!ctx || !input_file) return -1;
    
    if (avformat_open_input(&ctx->ifmt_ctx, input_file, nullptr, nullptr) < 0) {
        LOGE("Cannot open input file: %s", input_file);
        return -1;
    }
    
    if (avformat_find_stream_info(ctx->ifmt_ctx, nullptr) < 0) {
        LOGE("Cannot find stream info");
        return -2;
    }
    
    // Find video stream
    for (unsigned int i = 0; i < ctx->ifmt_ctx->nb_streams; i++) {
        if (ctx->ifmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            ctx->video_stream_idx = i;
            break;
        }
    }
    
    if (ctx->video_stream_idx < 0) {
        LOGE("No video stream found");
        return -3;
    }
    
    LOGI("Found video stream at index %d", ctx->video_stream_idx);
    
    // Cache the input video stream time_base
    ctx->video_time_base = ctx->ifmt_ctx->streams[ctx->video_stream_idx]->time_base;
    if (ctx->video_time_base.num <= 0 || ctx->video_time_base.den <= 0) {
        ctx->video_time_base.num = 1;
        ctx->video_time_base.den = 30;
    }
    
    // Find audio stream
    for (unsigned int i = 0; i < ctx->ifmt_ctx->nb_streams; i++) {
        if (ctx->ifmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            ctx->audio_stream_idx = i;
            break;
        }
    }
    
    if (ctx->audio_stream_idx >= 0) {
        LOGI("Found audio stream at index %d", ctx->audio_stream_idx);
    }
    
    return 0;
}

int ffmpeg_setup_decoder(FFmpegContext* ctx) {
    if (!ctx || ctx->video_stream_idx < 0) return -1;
    
    ctx->decoder = avcodec_find_decoder(
        ctx->ifmt_ctx->streams[ctx->video_stream_idx]->codecpar->codec_id);
    if (!ctx->decoder) {
        LOGE("Decoder not found");
        return -4;
    }
    
    ctx->dec_ctx = avcodec_alloc_context3(ctx->decoder);
    if (!ctx->dec_ctx) {
        LOGE("Cannot allocate decoder context");
        return -5;
    }
    
    avcodec_parameters_to_context(ctx->dec_ctx, 
                                   ctx->ifmt_ctx->streams[ctx->video_stream_idx]->codecpar);
    if (avcodec_open2(ctx->dec_ctx, ctx->decoder, nullptr) < 0) {
        LOGE("Cannot open decoder");
        return -6;
    }
    
    return 0;
}

int ffmpeg_setup_encoder(FFmpegContext* ctx, const char* output_file,
                         const char* preset, int crf, int added_height) {
    if (!ctx || !output_file) return -1;
    
    // Create output format context
    avformat_alloc_output_context2(&ctx->ofmt_ctx, nullptr, nullptr, output_file);
    if (!ctx->ofmt_ctx) {
        LOGE("Cannot create output context");
        return -7;
    }
    
    // Find encoder (use libx264)
    ctx->encoder = avcodec_find_encoder_by_name("libx264");
    if (!ctx->encoder) {
        LOGE("libx264 encoder not found");
        return -8;
    }
    
    if (!ctx->enc_ctx) {
        ctx->enc_ctx = avcodec_alloc_context3(ctx->encoder);
        if (!ctx->enc_ctx) {
            LOGE("Cannot allocate encoder context");
            return -9;
        }
    }
    
    // Set encoder parameters
    int target_width = ctx->dec_ctx->width;
    int target_height = ctx->dec_ctx->height + added_height;

    // Check if dimensions were already hinted (e.g., by cropping)
    // ONLY if enc_ctx was pre-allocated and has valid dimensions
    if (ctx->enc_ctx->width > 0 && ctx->enc_ctx->height > 0 && added_height == 0) {
        target_width = ctx->enc_ctx->width;
        target_height = ctx->enc_ctx->height;
    }

    ctx->enc_ctx->width = target_width;
    ctx->enc_ctx->height = target_height;
    
    // Ensure dimensions are even (required for yuv420p)
    if (ctx->enc_ctx->width % 2 != 0) ctx->enc_ctx->width--;
    if (ctx->enc_ctx->height % 2 != 0) ctx->enc_ctx->height--;
    
    ctx->enc_ctx->sample_aspect_ratio = ctx->dec_ctx->sample_aspect_ratio;
    ctx->enc_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    ctx->enc_ctx->time_base = ctx->video_time_base;
    ctx->enc_ctx->bit_rate = 2000000; // 2 Mbps
    
    // Speed / performance tweaks for x264
    ctx->enc_ctx->thread_count = 0; // auto: use all cores
    const char* effective_preset = (preset && preset[0] != '\0') ? preset : "veryfast";
    av_opt_set(ctx->enc_ctx->priv_data, "preset", effective_preset, 0);
    
    if (crf > 0) {
        av_opt_set_int(ctx->enc_ctx->priv_data, "crf", crf, 0);
    }
    
    if (ctx->ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
        ctx->enc_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
    
    if (avcodec_open2(ctx->enc_ctx, ctx->encoder, nullptr) < 0) {
        LOGE("Cannot open libx264 encoder");
        return -10;
    }
    
    // Create output stream
    ctx->out_stream = avformat_new_stream(ctx->ofmt_ctx, ctx->encoder);
    if (!ctx->out_stream) {
        LOGE("Cannot create output stream");
        return -11;
    }

    if (added_height == 0) {
        // For cropping or simple passthrough, use original time_base
        ctx->out_stream->time_base = ctx->video_time_base;
        ctx->enc_ctx->time_base = ctx->video_time_base;
    } else {
        // For text overlay which might change frame rates or needs a standard TB
        ctx->out_stream->time_base = ctx->enc_ctx->time_base;
    }
    
    avcodec_parameters_from_context(ctx->out_stream->codecpar, ctx->enc_ctx);
    
    return 0;
}

int ffmpeg_setup_audio_passthrough(FFmpegContext* ctx) {
    if (!ctx || ctx->audio_stream_idx < 0) {
        return 0; // No audio stream, not an error
    }
    
    ctx->audio_out_stream = avformat_new_stream(ctx->ofmt_ctx, nullptr);
    if (!ctx->audio_out_stream) {
        LOGE("Cannot create audio output stream");
        return -1;
    }
    
    avcodec_parameters_copy(ctx->audio_out_stream->codecpar,
                            ctx->ifmt_ctx->streams[ctx->audio_stream_idx]->codecpar);
    ctx->audio_out_stream->codecpar->codec_tag = 0;
    ctx->audio_out_stream->time_base = ctx->ifmt_ctx->streams[ctx->audio_stream_idx]->time_base;
    LOGI("Audio stream will be copied as-is to output");
    
    return 0;
}

void ffmpeg_cleanup(FFmpegContext* ctx) {
    if (!ctx) return;
    
    if (ctx->enc_ctx) avcodec_free_context(&ctx->enc_ctx);
    if (ctx->dec_ctx) avcodec_free_context(&ctx->dec_ctx);
    
    if (ctx->ofmt_ctx) {
        if (!(ctx->ofmt_ctx->oformat->flags & AVFMT_NOFILE)) {
            avio_closep(&ctx->ofmt_ctx->pb);
        }
        avformat_free_context(ctx->ofmt_ctx);
    }
    
    if (ctx->ifmt_ctx) avformat_close_input(&ctx->ifmt_ctx);
}

void ffmpeg_release_jni_strings(JNIEnv* env,
                                jstring inputPath, const char* input_file,
                                jstring outputPath, const char* output_file,
                                jstring text, const char* overlay_text,
                                jstring fontColor, const char* text_color_raw,
                                jstring boxColor, const char* box_color_raw,
                                jstring position, const char* position_raw,
                                jstring fontPath, const char* font,
                                jstring preset, const char* preset_str) {
    if (input_file) env->ReleaseStringUTFChars(inputPath, input_file);
    if (output_file) env->ReleaseStringUTFChars(outputPath, output_file);
    if (overlay_text) env->ReleaseStringUTFChars(text, overlay_text);
    if (text_color_raw) env->ReleaseStringUTFChars(fontColor, text_color_raw);
    if (box_color_raw) env->ReleaseStringUTFChars(boxColor, box_color_raw);
    if (position_raw) env->ReleaseStringUTFChars(position, position_raw);
    if (font) env->ReleaseStringUTFChars(fontPath, font);
    if (preset_str) env->ReleaseStringUTFChars(preset, preset_str);
}
