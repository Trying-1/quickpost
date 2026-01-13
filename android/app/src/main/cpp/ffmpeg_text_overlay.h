#ifndef FFMPEG_TEXT_OVERLAY_H
#define FFMPEG_TEXT_OVERLAY_H

#include "ffmpeg_common.h"

extern "C" {
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/pixdesc.h>
#include <libavutil/opt.h>
}

// Text overlay specific context
struct TextOverlayContext {
    FFmpegContext ffmpeg_ctx;
    
    // Filter graph components
    AVFilterGraph* filter_graph;
    AVFilterContext* buffersrc_ctx;
    AVFilterContext* buffersink_ctx;
    
    // Frame processing
    AVPacket* pkt;
    AVFrame* frame;
    AVFrame* filt_frame;
    AVPacket* enc_pkt;
    int frame_count;
};

// Initialize text overlay context
int text_overlay_init_context(TextOverlayContext* ctx);

// Setup filter graph for text overlay
int text_overlay_setup_filter(TextOverlayContext* ctx,
                              const char* overlay_text,
                              const char* text_color,
                              const char* box_color,
                              const char* position,
                              const char* font,
                              int fontSize);

// Process video frames with text overlay
int text_overlay_process_frames(TextOverlayContext* ctx, const char* output_file);

// Cleanup text overlay context
void text_overlay_cleanup(TextOverlayContext* ctx);

#endif // FFMPEG_TEXT_OVERLAY_H
