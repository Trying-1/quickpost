#include <jni.h>
#include <string>
#include "ffmpeg_common.h"
extern "C" {
#include <libavfilter/buffersrc.h>
#include <libavfilter/buffersink.h>
#include <libavutil/opt.h>
}
#include "android/log.h"

// LOG_TAG is already defined in ffmpeg_common.h as "myffmpeg"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

struct VideoCropContext {
    FFmpegContext ffmpeg_ctx;
    AVFilterGraph* filter_graph;
    AVFilterContext* buffersrc_ctx;
    AVFilterContext* buffersink_ctx;
    AVPacket* pkt;
    AVFrame* frame;
    AVFrame* filt_frame;
    AVPacket* enc_pkt;
    int frame_count;
};

static int crop_init_context(VideoCropContext* ctx) {
    if (!ctx) return -1;
    ffmpeg_init_context(&ctx->ffmpeg_ctx);
    ctx->filter_graph = nullptr;
    ctx->buffersrc_ctx = nullptr;
    ctx->buffersink_ctx = nullptr;
    ctx->pkt = nullptr;
    ctx->frame = nullptr;
    ctx->filt_frame = nullptr;
    ctx->enc_pkt = nullptr;
    ctx->frame_count = 0;
    return 0;
}

static void crop_cleanup(VideoCropContext* ctx) {
    if (!ctx) return;
    if (ctx->pkt) av_packet_free(&ctx->pkt);
    if (ctx->frame) av_frame_free(&ctx->frame);
    if (ctx->filt_frame) av_frame_free(&ctx->filt_frame);
    if (ctx->enc_pkt) av_packet_free(&ctx->enc_pkt);
    if (ctx->filter_graph) {
        avfilter_graph_free(&ctx->filter_graph);
        ctx->buffersrc_ctx = nullptr;
        ctx->buffersink_ctx = nullptr;
    }
    ffmpeg_cleanup(&ctx->ffmpeg_ctx);
}

static int crop_setup_filter(VideoCropContext* ctx, int x, int y, int width, int height, int rotation, int isFlipped) {
    if (!ctx) return -1;
    AVCodecContext* dec_ctx = ctx->ffmpeg_ctx.dec_ctx;
    if (!dec_ctx) {
        LOGE("Decoder context not initialized");
        return -1;
    }

    char filter_str[512];
    std::string rot_filter = "";
    if (rotation == 90) rot_filter = ",transpose=1";
    else if (rotation == 180) rot_filter = ",transpose=2,transpose=2";
    else if (rotation == 270) rot_filter = ",transpose=2";

    std::string flip_filter = "";
    if (isFlipped) flip_filter = ",hflip";

    snprintf(filter_str, sizeof(filter_str), "crop=w=%d:h=%d:x=%d:y=%d%s%s", width, height, x, y, rot_filter.c_str(), flip_filter.c_str());
    LOGI("Crop filter: %s", filter_str);

    ctx->filter_graph = avfilter_graph_alloc();
    if (!ctx->filter_graph) {
        LOGE("Cannot allocate filter graph");
        return -1;
    }

    const AVFilter* buffersrc  = avfilter_get_by_name("buffer");
    const AVFilter* buffersink = avfilter_get_by_name("buffersink");
    if (!buffersrc || !buffersink) {
        LOGE("Required filters not found");
        return -1;
    }

    AVRational tb = ctx->ffmpeg_ctx.video_time_base;
    AVRational sar = dec_ctx->sample_aspect_ratio;
    if (sar.num <= 0 || sar.den <= 0) {
        sar.num = 1;
        sar.den = 1;
    }

    char args[512];
    snprintf(args, sizeof(args),
             "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             dec_ctx->width, dec_ctx->height, dec_ctx->pix_fmt,
             tb.num, tb.den,
             sar.num, sar.den);

    int ret = avfilter_graph_create_filter(&ctx->buffersrc_ctx, buffersrc, "in", args, nullptr, ctx->filter_graph);
    if (ret < 0) {
        LOGE("Cannot create buffer source, error=%d", ret);
        return ret;
    }

    ret = avfilter_graph_create_filter(&ctx->buffersink_ctx, buffersink, "out", nullptr, nullptr, ctx->filter_graph);
    if (ret < 0) {
        LOGE("Cannot create buffer sink, error=%d", ret);
        return ret;
    }

    AVFilterInOut* inputs  = avfilter_inout_alloc();
    AVFilterInOut* outputs = avfilter_inout_alloc();

    outputs->name       = av_strdup("in");
    outputs->filter_ctx = ctx->buffersrc_ctx;
    outputs->pad_idx    = 0;
    outputs->next       = nullptr;

    inputs->name       = av_strdup("out");
    inputs->filter_ctx = ctx->buffersink_ctx;
    inputs->pad_idx    = 0;
    inputs->next       = nullptr;

    ret = avfilter_graph_parse_ptr(ctx->filter_graph, filter_str, &inputs, &outputs, nullptr);
    if (ret < 0) {
        LOGE("Cannot parse filter graph, error=%d", ret);
        avfilter_inout_free(&inputs);
        avfilter_inout_free(&outputs);
        return ret;
    }

    ret = avfilter_graph_config(ctx->filter_graph, nullptr);
    if (ret < 0) {
        LOGE("Cannot configure filter graph, error=%d", ret);
        avfilter_inout_free(&inputs);
        avfilter_inout_free(&outputs);
        return ret;
    }

    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);

    return 0;
}

static int crop_process(VideoCropContext* ctx, const char* output_file) {
    if (!ctx || !output_file) return -1;

    FFmpegContext* ff = &ctx->ffmpeg_ctx;
    AVCodecContext* dec_ctx = ff->dec_ctx;
    AVCodecContext* enc_ctx = ff->enc_ctx;
    AVFormatContext* ifmt_ctx = ff->ifmt_ctx;
    AVFormatContext* ofmt_ctx = ff->ofmt_ctx;

    if (!(ofmt_ctx->oformat->flags & AVFMT_NOFILE)) {
        if (avio_open(&ofmt_ctx->pb, output_file, AVIO_FLAG_WRITE) < 0) {
            LOGE("Cannot open output file");
            return -1;
        }
    }

    if (avformat_write_header(ofmt_ctx, nullptr) < 0) {
        LOGE("Cannot write header");
        return -1;
    }

    ctx->pkt = av_packet_alloc();
    ctx->frame = av_frame_alloc();
    ctx->filt_frame = av_frame_alloc();
    if (!ctx->pkt || !ctx->frame || !ctx->filt_frame) {
        LOGE("Cannot allocate frame/packet");
        return -1;
    }

    while (av_read_frame(ifmt_ctx, ctx->pkt) >= 0) {
        if (ff->audio_stream_idx >= 0 && ctx->pkt->stream_index == ff->audio_stream_idx) {
            if (ff->audio_out_stream) {
                av_packet_rescale_ts(ctx->pkt,
                                     ifmt_ctx->streams[ff->audio_stream_idx]->time_base,
                                     ff->audio_out_stream->time_base);
                ctx->pkt->stream_index = ff->audio_out_stream->index;
                av_interleaved_write_frame(ofmt_ctx, ctx->pkt);
            }
            av_packet_unref(ctx->pkt);
            continue;
        }

        if (ctx->pkt->stream_index != ff->video_stream_idx) {
            av_packet_unref(ctx->pkt);
            continue;
        }

        if (avcodec_send_packet(dec_ctx, ctx->pkt) < 0) {
            LOGE("Error sending packet to decoder");
            av_packet_unref(ctx->pkt);
            continue;
        }

        while (avcodec_receive_frame(dec_ctx, ctx->frame) == 0) {
            if (av_buffersrc_add_frame_flags(ctx->buffersrc_ctx, ctx->frame, AV_BUFFERSRC_FLAG_KEEP_REF) < 0) {
                LOGE("Error feeding frame to filter");
                break;
            }

            while (av_buffersink_get_frame(ctx->buffersink_ctx, ctx->filt_frame) >= 0) {
                ctx->filt_frame->pict_type = AV_PICTURE_TYPE_NONE;

                if (avcodec_send_frame(enc_ctx, ctx->filt_frame) < 0) {
                    LOGE("Error sending frame to encoder");
                    av_frame_unref(ctx->filt_frame);
                    break;
                }

                ctx->enc_pkt = av_packet_alloc();
                while (avcodec_receive_packet(enc_ctx, ctx->enc_pkt) == 0) {
                    ctx->enc_pkt->stream_index = ff->out_stream->index;
                    av_packet_rescale_ts(ctx->enc_pkt, enc_ctx->time_base, ff->out_stream->time_base);
                    av_interleaved_write_frame(ofmt_ctx, ctx->enc_pkt);
                    av_packet_unref(ctx->enc_pkt);
                }
                av_packet_free(&ctx->enc_pkt);
                av_frame_unref(ctx->filt_frame);
            }
        }

        av_packet_unref(ctx->pkt);
        ctx->frame_count++;
        if (ctx->frame_count % 30 == 0) {
            LOGI("Processed %d frames", ctx->frame_count);
        }
    }

    avcodec_send_frame(enc_ctx, nullptr);
    ctx->enc_pkt = av_packet_alloc();
    while (avcodec_receive_packet(enc_ctx, ctx->enc_pkt) == 0) {
        ctx->enc_pkt->stream_index = ff->out_stream->index;
        av_packet_rescale_ts(ctx->enc_pkt, enc_ctx->time_base, ff->out_stream->time_base);
        av_interleaved_write_frame(ofmt_ctx, ctx->enc_pkt);
        av_packet_unref(ctx->enc_pkt);
    }
    av_packet_free(&ctx->enc_pkt);

    av_write_trailer(ofmt_ctx);
    LOGI("Video crop completed. Total frames: %d", ctx->frame_count);
    return 0;
}

extern "C"
JNIEXPORT jint JNICALL
Java_com_quickpost_app_FFmpegVideoCropper_nativeCropVideo(
        JNIEnv* env,
        jobject /* thisObj */,
        jstring inputPath,
        jstring outputPath,
        jint x,
        jint y,
        jint width,
        jint height,
        jstring preset,
        jint crf,
        jint rotation,
        jint isFlipped) {
    const char* input_file = env->GetStringUTFChars(inputPath, nullptr);
    const char* output_file = env->GetStringUTFChars(outputPath, nullptr);
    const char* preset_str = env->GetStringUTFChars(preset, nullptr);

    LOGI("nativeCropVideo: input=%s output=%s x=%d y=%d w=%d h=%d preset=%s crf=%d rotation=%d flip=%d",
         input_file, output_file, x, y, width, height, preset_str, crf, rotation, isFlipped);

    VideoCropContext ctx{};
    int ret = 0;

    if ((ret = crop_init_context(&ctx)) < 0) goto cleanup;
    if ((ret = ffmpeg_open_input(&ctx.ffmpeg_ctx, input_file)) < 0) goto cleanup;
    if ((ret = ffmpeg_setup_decoder(&ctx.ffmpeg_ctx)) < 0) goto cleanup;

    // Set encoder parameters before setup_encoder
    ctx.ffmpeg_ctx.enc_ctx = avcodec_alloc_context3(avcodec_find_encoder_by_name("libx264"));
    if (!ctx.ffmpeg_ctx.enc_ctx) {
        LOGE("Cannot allocate encoder context for cropping");
        ret = -9;
        goto cleanup;
    }

    // If rotation is 90 or 270, the final dimensions will be swapped
    if (rotation == 90 || rotation == 270) {
        ctx.ffmpeg_ctx.enc_ctx->width = height;
        ctx.ffmpeg_ctx.enc_ctx->height = width;
    } else {
        ctx.ffmpeg_ctx.enc_ctx->width = width;
        ctx.ffmpeg_ctx.enc_ctx->height = height;
    }
    
    if ((ret = ffmpeg_setup_encoder(&ctx.ffmpeg_ctx, output_file, preset_str, crf, 0)) < 0) goto cleanup;
    if ((ret = ffmpeg_setup_audio_passthrough(&ctx.ffmpeg_ctx)) < 0) goto cleanup;
    if ((ret = crop_setup_filter(&ctx, x, y, width, height, rotation, isFlipped)) < 0) goto cleanup;
    if ((ret = crop_process(&ctx, output_file)) < 0) goto cleanup;

cleanup:
    crop_cleanup(&ctx);
    if (input_file) env->ReleaseStringUTFChars(inputPath, input_file);
    if (output_file) env->ReleaseStringUTFChars(outputPath, output_file);
    if (preset_str) env->ReleaseStringUTFChars(preset, preset_str);
    return ret;
}
