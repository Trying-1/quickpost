import 'dart:io';
import 'package:flutter/material.dart';
import '../models/flip_clock_model.dart';

/// Pixel-perfect Retro Flip Clock & Event Countdown Canvas with zero-overflow proportional containment.
/// Features authentic split-flap mechanical cards, central hinge slits, top/bottom gradient cards,
/// milestone countdown progress bars, and high-contrast backdrops.
class FlipClockCanvasView extends StatelessWidget {
  final FlipClockPost post;
  final VoidCallback? onEditRequested;

  const FlipClockCanvasView({
    super.key,
    required this.post,
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bool isStory = post.ratio == FlipClockRatio.story9x16;
    final bool isSquare = post.ratio == FlipClockRatio.square1x1;
    const double refWidth = 380.0;
    final double refHeight = isStory
        ? (380.0 * 16 / 9)
        : (isSquare ? 380.0 : (380.0 * 5 / 4));

    if (post.ratio == FlipClockRatio.clockOnly) {
      return GestureDetector(
        onTap: onEditRequested,
        child: Container(
          decoration: BoxDecoration(
            color: post.transparentBg ? Colors.transparent : post.theme.canvasBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: refWidth,
              child: _buildFlipClockCard(isStandalone: true),
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
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Backdrop (Gradient or Custom Wallpaper)
              _buildBackdrop(),

              // 2. Subtle Dark Vignette
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),

              // 3. Proportional Centered Floating Flip Clock (Zero-Overflow Guaranteed)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isStory ? 20 : (isSquare ? 12 : 16),
                    vertical: isStory ? 24 : (isSquare ? 12 : 16),
                  ),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: refWidth,
                      height: refHeight,
                      child: _buildFullCanvasLayout(isStory: isStory, isSquare: isSquare),
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

  // ─── Full Canvas Layout ───
  Widget _buildFullCanvasLayout({required bool isStory, required bool isSquare}) {
    return Column(
      mainAxisAlignment: isStory ? MainAxisAlignment.spaceBetween : MainAxisAlignment.spaceEvenly,
      children: [
        // Top Header: Badge & Event Titles
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status / AM-PM Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: post.theme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: post.theme.accentColor.withValues(alpha: 0.6), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: post.theme.accentColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    post.amPmBadge.toUpperCase(),
                    style: TextStyle(
                      color: post.theme.accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Main Event Title
            Text(
              post.eventTitle.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSquare ? 17 : 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontFamily: 'Poppins',
                shadows: [
                  Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Event Subtitle
            if (post.eventSubtitle.isNotEmpty)
              Text(
                post.eventSubtitle.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: post.theme.labelColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  fontFamily: 'Poppins',
                ),
              ),
          ],
        ),

        // Center Flip Clock Cards
        _buildFlipClockCard(isStandalone: false),

        // Bottom Progress Bar & Watermark
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.showProgressBar) ...[
              Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: post.theme.canvasBg.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          post.progressLabel.toUpperCase(),
                          style: TextStyle(color: post.theme.labelColor, fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                        ),
                        Text(
                          '${(post.progressPercent * 100).round()}%',
                          style: TextStyle(color: post.theme.accentColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: post.progressPercent.clamp(0.0, 1.0),
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(post.theme.accentColor),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Watermark Handle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                post.creatorHandle,
                style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Flip Clock Split-Flap Cards Row ───
  Widget _buildFlipClockCard({required bool isStandalone}) {
    final theme = post.theme;
    final bool show4 = post.showUnit4;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: show4 ? 8 : 12, vertical: 14),
      decoration: BoxDecoration(
        color: theme.canvasBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFlapUnit(post.unit1Value, post.unit1Label, theme, isCompact: show4),
          _buildColonSeparator(theme),
          _buildFlapUnit(post.unit2Value, post.unit2Label, theme, isCompact: show4),
          _buildColonSeparator(theme),
          _buildFlapUnit(post.unit3Value, post.unit3Label, theme, isCompact: show4),
          if (show4) ...[
            _buildColonSeparator(theme),
            _buildFlapUnit(post.unit4Value, post.unit4Label, theme, isCompact: true),
          ],
        ],
      ),
    );
  }

  // ─── Single Mechanical Split-Flap Digit Tile ───
  Widget _buildFlapUnit(String value, String label, FlipClockTheme theme, {required bool isCompact}) {
    final double cardWidth = isCompact ? 68.0 : 84.0;
    final double cardHeight = isCompact ? 84.0 : 100.0;
    final double fontSize = isCompact ? 40.0 : 50.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Split Card Container
        Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Top Half Card
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: cardHeight / 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.tileBgTop,
                    border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1.2)),
                  ),
                ),
              ),

              // Bottom Half Card
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: cardHeight / 2,
                child: Container(
                  color: theme.tileBgBottom,
                ),
              ),

              // Full Split Digit Typography
              Center(
                child: Text(
                  value,
                  style: TextStyle(
                    color: theme.digitColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    height: 1.0,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),

              // Center Mechanical Slit with Left & Right Notches
              Center(
                child: Container(
                  height: 1.5,
                  color: theme.dividerColor,
                ),
              ),

              // Left Hinge Notch
              Positioned(
                left: 0,
                top: (cardHeight / 2) - 3,
                child: Container(
                  width: 3.5,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3)),
                  ),
                ),
              ),

              // Right Hinge Notch
              Positioned(
                right: 0,
                top: (cardHeight / 2) - 3,
                child: Container(
                  width: 3.5,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Unit Label (DAYS, HOURS, MINS)
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: theme.labelColor,
            fontSize: isCompact ? 9 : 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  // ─── Flap Separator Dots ───
  Widget _buildColonSeparator(FlipClockTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: theme.accentColor, shape: BoxShape.circle),
          ),
          const SizedBox(height: 12),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: theme.accentColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

