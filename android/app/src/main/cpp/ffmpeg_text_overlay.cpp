#include "ffmpeg_text_overlay.h"
#include <cstring>
#include <cstdio>

#define BOX_HEIGHT 80
#define TEXT_PADDING_TOP 20

int text_overlay_init_context(TextOverlayContext* ctx) {
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

int text_overlay_setup_filter(TextOverlayContext* ctx,
                              const char* overlay_text,
                              const char* text_color,
                              const char* box_color,
                              const char* position,
                              const char* font,
                              int fontSize) {
    if (!ctx || !overlay_text || !text_color || !box_color || !font) {
        LOGE("Invalid parameters for text overlay filter setup");
        return -1;
    }
    
    AVCodecContext* dec_ctx = ctx->ffmpeg_ctx.dec_ctx;
    if (!dec_ctx) {
        LOGE("Decoder context not initialized");
        return -1;
    }
    
    // Determine if box should be at top or bottom
    bool place_top = true;
    if (position && position[0] != '\0') {
        if (strcasecmp(position, "bottom") == 0) {
            place_top = false;
        }
    }
    
    // Build filter string
    char filter_str[1024];
    if (place_top) {
        snprintf(
            filter_str,
            sizeof(filter_str),
            "pad=w=%d:h=%d:x=0:y=%d:color=%s@1.0,"
            "drawbox=x=0:y=0:w=%d:h=%d:color=%s@1.0:t=fill,"
            "drawtext=fontfile='%s':text='%s':fontcolor=%s:fontsize=%d:x=(w-text_w)/2:y=%d",
            dec_ctx->width,
            dec_ctx->height + BOX_HEIGHT,
            BOX_HEIGHT,
            box_color,
            dec_ctx->width,
            BOX_HEIGHT,
            box_color,
            font,
            overlay_text,
            text_color,
            fontSize,
            TEXT_PADDING_TOP);
    } else {
        // Box at bottom: pad video height, keep original video at top, add box at bottom
        snprintf(
            filter_str,
            sizeof(filter_str),
            "pad=w=%d:h=%d:x=0:y=0:color=%s@1.0,"
            "drawbox=x=0:y=%d:w=%d:h=%d:color=%s@1.0:t=fill,"
            "drawtext=fontfile='%s':text='%s':fontcolor=%s:fontsize=%d:x=(w-text_w)/2:y=%d",
            dec_ctx->width,
            dec_ctx->height + BOX_HEIGHT,
            box_color,
            dec_ctx->height,
            dec_ctx->width,
            BOX_HEIGHT,
            box_color,
            font,
            overlay_text,
            text_color,
            fontSize,
            dec_ctx->height + TEXT_PADDING_TOP);
        
        LOGI("Bottom position: video_height=%d, box_y=%d, text_y=%d, total_height=%d",
             dec_ctx->height, dec_ctx->height, dec_ctx->height + TEXT_PADDING_TOP, 
             dec_ctx->height + BOX_HEIGHT);
    }
    
    LOGI("Filter string: %s", filter_str);
    
    // Create filter graph
    ctx->filter_graph = avfilter_graph_alloc();
    if (!ctx->filter_graph) {
        LOGE("Cannot allocate filter graph");
        return -12;
    }
    
    // Get filter objects
    const AVFilter* buffersrc = avfilter_get_by_name("buffer");
    const AVFilter* buffersink = avfilter_get_by_name("buffersink");
    
    if (!buffersrc || !buffersink) {
        LOGE("Filter not found");
        return -13;
    }
    
    // Create buffer source
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
    
    LOGI("Buffer source args: %s", args);
    
    int ret = avfilter_graph_create_filter(&ctx->buffersrc_ctx, buffersrc, "in", args, nullptr, ctx->filter_graph);
    if (ret < 0) {
        LOGE("Cannot create buffer source, ffmpeg error=%d", ret);
        return ret;
    }
    
    if (avfilter_graph_create_filter(&ctx->buffersink_ctx, buffersink, "out", nullptr, nullptr, ctx->filter_graph) < 0) {
        LOGE("Cannot create buffer sink");
        return -15;
    }
    
    // Parse and add filter
    AVFilterInOut* inputs = avfilter_inout_alloc();
    AVFilterInOut* outputs = avfilter_inout_alloc();
    
    outputs->name = av_strdup("in");
    outputs->filter_ctx = ctx->buffersrc_ctx;
    outputs->pad_idx = 0;
    outputs->next = nullptr;
    
    inputs->name = av_strdup("out");
    inputs->filter_ctx = ctx->buffersink_ctx;
    inputs->pad_idx = 0;
    inputs->next = nullptr;
    
    if (avfilter_graph_parse_ptr(ctx->filter_graph, filter_str, &inputs, &outputs, nullptr) < 0) {
        LOGE("Cannot parse filter graph");
        avfilter_inout_free(&inputs);
        avfilter_inout_free(&outputs);
        return -16;
    }
    
    if (avfilter_graph_config(ctx->filter_graph, nullptr) < 0) {
        LOGE("Cannot configure filter graph");
        avfilter_inout_free(&inputs);
        avfilter_inout_free(&outputs);
        return -17;
    }
    
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    
    return 0;
}

int text_overlay_process_frames(TextOverlayContext* ctx, const char* output_file) {
    if (!ctx || !output_file) return -1;
    
    FFmpegContext* ffmpeg_ctx = &ctx->ffmpeg_ctx;
    AVCodecContext* dec_ctx = ffmpeg_ctx->dec_ctx;
    AVCodecContext* enc_ctx = ffmpeg_ctx->enc_ctx;
    AVFormatContext* ifmt_ctx = ffmpeg_ctx->ifmt_ctx;
    AVFormatContext* ofmt_ctx = ffmpeg_ctx->ofmt_ctx;
    
    // Open output file
    if (!(ofmt_ctx->oformat->flags & AVFMT_NOFILE)) {
        if (avio_open(&ofmt_ctx->pb, output_file, AVIO_FLAG_WRITE) < 0) {
            LOGE("Cannot open output file");
            return -18;
        }
    }
    
    if (avformat_write_header(ofmt_ctx, nullptr) < 0) {
        LOGE("Cannot write header");
        return -19;
    }
    
    // Allocate frame/packet structures
    ctx->pkt = av_packet_alloc();
    ctx->frame = av_frame_alloc();
    ctx->filt_frame = av_frame_alloc();
    
    if (!ctx->pkt || !ctx->frame || !ctx->filt_frame) {
        LOGE("Cannot allocate frame/packet");
        return -20;
    }
    
    // Process frames
    while (av_read_frame(ifmt_ctx, ctx->pkt) >= 0) {
        // Handle audio stream - copy directly without re-encoding
        if (ffmpeg_ctx->audio_stream_idx >= 0 && ctx->pkt->stream_index == ffmpeg_ctx->audio_stream_idx) {
            if (ffmpeg_ctx->audio_out_stream) {
                av_packet_rescale_ts(ctx->pkt, ifmt_ctx->streams[ffmpeg_ctx->audio_stream_idx]->time_base, 
                                     ffmpeg_ctx->audio_out_stream->time_base);
                ctx->pkt->stream_index = ffmpeg_ctx->audio_out_stream->index;
                av_interleaved_write_frame(ofmt_ctx, ctx->pkt);
            }
            av_packet_unref(ctx->pkt);
            continue;
        }
        
        // Handle video stream
        if (ctx->pkt->stream_index != ffmpeg_ctx->video_stream_idx) {
            av_packet_unref(ctx->pkt);
            continue;
        }
        
        if (avcodec_send_packet(dec_ctx, ctx->pkt) < 0) {
            LOGE("Error sending packet to decoder");
            av_packet_unref(ctx->pkt);
            continue;
        }
        
        while (avcodec_receive_frame(dec_ctx, ctx->frame) == 0) {
            // Push frame to filter
            if (av_buffersrc_add_frame_flags(ctx->buffersrc_ctx, ctx->frame, AV_BUFFERSRC_FLAG_KEEP_REF) < 0) {
                LOGE("Error feeding frame to filter");
                break;
            }
            
            // Get filtered frames
            while (av_buffersink_get_frame(ctx->buffersink_ctx, ctx->filt_frame) >= 0) {
                ctx->filt_frame->pict_type = AV_PICTURE_TYPE_NONE;
                
                // Encode frame
                if (avcodec_send_frame(enc_ctx, ctx->filt_frame) < 0) {
                    LOGE("Error sending frame to encoder");
                    av_frame_unref(ctx->filt_frame);
                    break;
                }
                
                ctx->enc_pkt = av_packet_alloc();
                while (avcodec_receive_packet(enc_ctx, ctx->enc_pkt) == 0) {
                    ctx->enc_pkt->stream_index = ffmpeg_ctx->out_stream->index;
                    av_packet_rescale_ts(ctx->enc_pkt, enc_ctx->time_base, ffmpeg_ctx->out_stream->time_base);
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
    
    // Flush encoders
    avcodec_send_frame(enc_ctx, nullptr);
    ctx->enc_pkt = av_packet_alloc();
    while (avcodec_receive_packet(enc_ctx, ctx->enc_pkt) == 0) {
        ctx->enc_pkt->stream_index = 0;
        av_packet_rescale_ts(ctx->enc_pkt, enc_ctx->time_base, ffmpeg_ctx->out_stream->time_base);
        av_interleaved_write_frame(ofmt_ctx, ctx->enc_pkt);
        av_packet_unref(ctx->enc_pkt);
    }
    av_packet_free(&ctx->enc_pkt);
    
    av_write_trailer(ofmt_ctx);
    
    LOGI("Text overlay completed successfully. Total frames: %d", ctx->frame_count);
    
    return 0;
}

void text_overlay_cleanup(TextOverlayContext* ctx) {
    if (!ctx) return;
    
    if (ctx->pkt) av_packet_free(&ctx->pkt);
    if (ctx->frame) av_frame_free(&ctx->frame);
    if (ctx->filt_frame) av_frame_free(&ctx->filt_frame);
    if (ctx->enc_pkt) av_packet_free(&ctx->enc_pkt);
    
    // Free the filter graph, which also frees all contained filter contexts
    if (ctx->filter_graph) {
        avfilter_graph_free(&ctx->filter_graph);
        ctx->buffersrc_ctx = nullptr;
        ctx->buffersink_ctx = nullptr;
    }
    
    ffmpeg_cleanup(&ctx->ffmpeg_ctx);
}
