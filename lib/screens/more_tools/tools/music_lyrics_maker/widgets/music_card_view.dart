import 'dart:io';
import 'package:flutter/material.dart';
import '../models/music_card_model.dart';

/// Pixel-perfect Music Player & Lyrics Card Renderer with zero-overflow proportional scaling.
/// Renders as a full canvas (4:5, 1:1, 9:16) or standalone card for video overlays.
class MusicCardView extends StatelessWidget {
  final MusicCardPost post;
  final VoidCallback? onEditRequested;

  const MusicCardView({
    super.key,
    required this.post,
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bool isStory = post.ratio == MusicCardRatio.story9x16;
    final bool isSquare = post.ratio == MusicCardRatio.square1x1;
    const double refWidth = 380.0;

    if (post.ratio == MusicCardRatio.cardOnly) {
      return GestureDetector(
        onTap: onEditRequested,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: refWidth,
              child: _buildCardContainer(isStandalone: true),
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: post.ratio.ratio,
      child: GestureDetector(
        onTap: onEditRequested,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Backdrop (Custom Wallpaper or Gradient Preset)
              _buildBackdrop(),

              // 2. Subtle Dark Vignette
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),

              // 3. Proportional Centered Floating Music Card (Zero-Overflow Guaranteed)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isStory ? 20 : (isSquare ? 14 : 16),
                    vertical: isStory ? 24 : 12,
                  ),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: refWidth,
                      child: _buildCardContainer(isStandalone: false),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Backdrop Layer ───
  Widget _buildBackdrop() {
    if (post.customWallpaperPath != null && File(post.customWallpaperPath!).existsSync()) {
      return Image.file(
        File(post.customWallpaperPath!),
        fit: BoxFit.cover,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: post.backdrop.colors,
        ),
      ),
    );
  }

  // ─── The Main Music Player Card ───
  Widget _buildCardContainer({required bool isStandalone}) {
    final theme = post.playerTheme;
    final isSquare = post.ratio == MusicCardRatio.square1x1;

    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: EdgeInsets.all(isSquare ? 14 : 18),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorder, width: 1.2),
        boxShadow: isStandalone
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Art + Song & Artist Info Row
          _buildCoverAndInfoRow(),

          const SizedBox(height: 12),

          // Waveform or Audio Indicator
          if (post.showWaveform) _buildWaveformBars(),

          const SizedBox(height: 10),

          // Progress Timeline Bar & Timestamps
          _buildScrubberTimeline(),

          // Media Controls (Previous, Play/Pause, Next)
          if (post.showControls) ...[
            const SizedBox(height: 6),
            _buildControlsRow(),
          ],

          // Optional Synced Lyrics / Quote Section
          if (post.showLyrics) ...[
            const SizedBox(height: 12),
            Divider(color: theme.cardBorder, height: 1),
            const SizedBox(height: 10),
            _buildLyricsSection(),
          ],
        ],
      ),
    );
  }

  // ─── Cover Art & Info Header ───
  Widget _buildCoverAndInfoRow() {
    final theme = post.playerTheme;
    final isSquare = post.ratio == MusicCardRatio.square1x1;
    final double artSize = isSquare ? 58 : 68;

    return Row(
      children: [
        // Album Art Square
        Container(
          width: artSize,
          height: artSize,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: post.albumArtPath != null && File(post.albumArtPath!).existsSync()
              ? Image.file(File(post.albumArtPath!), fit: BoxFit.cover)
              : Center(
                  child: Icon(Icons.music_note_rounded, color: theme.accentColor, size: 28),
                ),
        ),
        const SizedBox(width: 14),

        // Song Title & Artist
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.songTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.primaryText,
                  fontSize: isSquare ? 15 : 16.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 3),
              Text(
                post.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.secondaryText,
                  fontSize: isSquare ? 12 : 13,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),

        // Like Heart Button
        Icon(
          post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: post.isLiked ? theme.accentColor : theme.secondaryText,
          size: 22,
        ),
      ],
    );
  }

  // ─── Animated-Style Equalizer Waveform ───
  Widget _buildWaveformBars() {
    final theme = post.playerTheme;
    const barHeights = [14.0, 22.0, 8.0, 26.0, 18.0, 10.0, 24.0, 16.0, 28.0, 12.0, 20.0, 15.0, 25.0, 9.0, 18.0, 22.0, 11.0, 27.0, 14.0, 19.0];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(barHeights.length, (i) {
        final h = barHeights[i];
        final isActive = (i / barHeights.length) <= post.progressPercent;

        return Container(
          width: 3.5,
          height: h * 0.75,
          margin: const EdgeInsets.symmetric(horizontal: 2.2),
          decoration: BoxDecoration(
            color: isActive ? theme.accentColor : theme.secondaryText.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  // ─── Scrubber Timeline Bar ───
  Widget _buildScrubberTimeline() {
    final theme = post.playerTheme;

    return Column(
      children: [
        // Track Bar
        Container(
          width: double.infinity,
          height: 4,
          decoration: BoxDecoration(
            color: theme.secondaryText.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: post.progressPercent.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Time indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              post.currentTime,
              style: TextStyle(color: theme.secondaryText, fontSize: 11, fontFamily: 'monospace'),
            ),
            Text(
              post.totalDuration,
              style: TextStyle(color: theme.secondaryText, fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Playback Controls Row ───
  Widget _buildControlsRow() {
    final theme = post.playerTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Icon(Icons.shuffle_rounded, size: 18, color: theme.secondaryText),
        Icon(Icons.skip_previous_rounded, size: 28, color: theme.primaryText),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.accentColor.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.pause_rounded, size: 26, color: Colors.white),
        ),
        Icon(Icons.skip_next_rounded, size: 28, color: theme.primaryText),
        Icon(Icons.repeat_rounded, size: 18, color: theme.secondaryText),
      ],
    );
  }

  // ─── Synced Lyrics / Quote Section ───
  Widget _buildLyricsSection() {
    final theme = post.playerTheme;
    final lyrics = [post.lyricsLine1, post.lyricsLine2, post.lyricsLine3];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_quote_rounded, size: 14, color: theme.accentColor),
            const SizedBox(width: 4),
            Text(
              'LYRICS HIGHLIGHT',
              style: TextStyle(
                color: theme.accentColor,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...List.generate(lyrics.length, (index) {
          final line = lyrics[index];
          if (line.isEmpty) return const SizedBox.shrink();
          final isActive = index == post.activeLyricIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Text(
              line,
              style: TextStyle(
                color: isActive ? theme.primaryText : theme.secondaryText.withValues(alpha: 0.55),
                fontSize: isActive ? 13.5 : 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                height: 1.35,
                fontFamily: 'Poppins',
              ),
            ),
          );
        }),
      ],
    );
  }
}
