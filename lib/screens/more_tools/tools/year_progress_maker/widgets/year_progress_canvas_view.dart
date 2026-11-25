import 'dart:io';
import 'package:flutter/material.dart';
import '../models/year_progress_model.dart';

/// Canvas renderer for the Year Progress post.
/// Renders full-canvas graphics with zero overflows across all aspect ratios (1:1, 4:5, 9:16)
/// using a proportional containment architecture.
class YearProgressCanvasView extends StatelessWidget {
  final YearProgressPost post;
  final ValueChanged<int>? onDayTapped;

  const YearProgressCanvasView({
    super.key,
    required this.post,
    this.onDayTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isVerticalStory = post.ratio == YearRatio.vertical9x16;
    final isSquare = post.ratio == YearRatio.square1x1;

    // Reference canvas sizes for proportional scaling
    const double refWidth = 380.0;
    final double refHeight = isVerticalStory
        ? (380.0 * 16 / 9) // 675.5
        : (isSquare ? 380.0 : (380.0 * 5 / 4)); // 475.0 for 4:5

    if (post.ratio == YearRatio.cardOnly) {
      return Container(
        decoration: BoxDecoration(
          color: post.transparentBg ? Colors.transparent : post.theme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: post.transparentBg ? null : Border.all(color: post.theme.cardBorder, width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: SizedBox(
            width: refWidth,
            child: _buildContent(context, isVerticalStory: false),
          ),
        ),
      );
    }

    final backdrop = YearBackdropPreset.presets[post.backdropIndex % YearBackdropPreset.presets.length];

    final BoxDecoration canvasDecoration = BoxDecoration(
      color: post.transparentBg ? Colors.transparent : post.theme.cardBg,
      borderRadius: BorderRadius.circular(16),
      gradient: !post.transparentBg && post.customWallpaperPath == null && post.backdropIndex > 0
          ? LinearGradient(
              colors: backdrop.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      image: !post.transparentBg && post.customWallpaperPath != null
          ? DecorationImage(
              image: FileImage(File(post.customWallpaperPath!)),
              fit: BoxFit.cover,
            )
          : null,
      border: post.transparentBg ? null : Border.all(color: post.theme.cardBorder, width: 1.2),
      boxShadow: post.transparentBg
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
    );

    return AspectRatio(
      aspectRatio: post.ratio.aspectRatio,
      child: Container(
        decoration: canvasDecoration,
        padding: EdgeInsets.symmetric(
          horizontal: isVerticalStory ? 20 : (isSquare ? 14 : 16),
          vertical: isVerticalStory ? 24 : (isSquare ? 12 : 16),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: refWidth,
            height: refHeight,
            child: _buildContent(context, isVerticalStory: isVerticalStory),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isVerticalStory}) {
    return Column(
      mainAxisAlignment: isVerticalStory ? MainAxisAlignment.spaceBetween : MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header: Year Badge, Current Date & Author ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: post.theme.todayColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: post.theme.todayColor.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    '${post.year}',
                    style: TextStyle(
                      color: post.theme.todayColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  post.formattedCurrentDate.toUpperCase(),
                  style: TextStyle(
                    color: post.theme.secondaryText,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            if (post.showAuthorBadge)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (post.authorAvatarPath != null) ...[
                    CircleAvatar(
                      radius: 10,
                      backgroundImage: FileImage(File(post.authorAvatarPath!)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    post.authorHandle,
                    style: TextStyle(
                      color: post.theme.secondaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
          ],
        ),

        // ─── Title & Subtitle / Reflection ───
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: post.theme.primaryText,
                fontSize: isVerticalStory ? 20 : 17,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                height: 1.2,
              ),
            ),
            if (post.subtitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                post.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: post.theme.secondaryText,
                  fontSize: isVerticalStory ? 12 : 11,
                  fontFamily: 'Poppins',
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),

        // ─── Hero Progress Bar & Percentage ───
        if (post.showProgressBar)
          _buildHeroProgressBar(context, isVerticalStory: isVerticalStory),

        // ─── Main Visualization (Matrix, Month Blocks, or Stream) ───
        _buildMainVisualization(context, isVerticalStory: isVerticalStory),

        // ─── Bottom Stats Badges Row ───
        if (post.showStatsBadges)
          _buildStatsRow(context),

        // ─── Bottom Legend ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${post.daysRemaining} days remaining in ${post.year}',
              style: TextStyle(
                color: post.theme.secondaryText,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLegendItem(post.theme.passedColor, 'Passed'),
                const SizedBox(width: 6),
                _buildLegendItem(post.theme.todayColor, 'Today'),
                const SizedBox(width: 6),
                _buildLegendItem(post.theme.remainingColor, 'Remaining'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.5,
          height: 7.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(post.dotShape == YearDotShape.circle ? 4 : 1.5),
          ),
        ),
        const SizedBox(width: 3.5),
        Text(
          label,
          style: TextStyle(color: post.theme.secondaryText, fontSize: 8.5, fontFamily: 'Poppins'),
        ),
      ],
    );
  }

  Widget _buildHeroProgressBar(BuildContext context, {required bool isVerticalStory}) {
    final percent = post.percentageCompleted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: post.theme.remainingColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: post.theme.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.hourglass_bottom_rounded, size: 14, color: post.theme.todayColor),
                  const SizedBox(width: 5),
                  Text(
                    '${post.year} COMPLETION',
                    style: TextStyle(
                      color: post.theme.secondaryText,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: post.theme.primaryText,
                  fontSize: isVerticalStory ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: post.theme.remainingColor),
                  FractionallySizedBox(
                    widthFactor: (percent / 100.0).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: post.theme.progressBarGradient,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        _buildStatItem('Day of Year', '${post.currentDayOfYear}/${post.totalDaysInYear}', Icons.calendar_today_rounded, post.theme.passedColor),
        const SizedBox(width: 5),
        _buildStatItem('Days Left', '${post.daysRemaining} Left', Icons.timer_outlined, const Color(0xFFF97316)),
        const SizedBox(width: 5),
        _buildStatItem('Weeks Left', '${post.weeksRemaining} Wks', Icons.date_range_rounded, post.theme.todayColor),
        const SizedBox(width: 5),
        _buildStatItem('Quarter', 'Q${((post.currentMonth - 1) ~/ 3) + 1}', Icons.pie_chart_rounded, const Color(0xFF38BDF8)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: post.theme.remainingColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: post.theme.cardBorder, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 9, color: color),
                const SizedBox(width: 2.5),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: post.theme.secondaryText,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: post.theme.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainVisualization(BuildContext context, {required bool isVerticalStory}) {
    switch (post.layout) {
      case YearGridLayout.matrix:
        return _buildMatrixGrid(context, isVerticalStory: isVerticalStory);
      case YearGridLayout.monthBlocks:
        return _buildMonthBlocksGrid(context, isVerticalStory: isVerticalStory);
      case YearGridLayout.stream:
        return _buildStreamView(context, isVerticalStory: isVerticalStory);
    }
  }

  // ─── Layout 1: 365 Dot Matrix ───
  Widget _buildMatrixGrid(BuildContext context, {required bool isVerticalStory}) {
    final totalDays = post.totalDaysInYear;
    const columns = 26;
    final rows = (totalDays / columns).ceil();

    final double dotSize = isVerticalStory ? 10.0 : 8.5;
    final double spacing = post.dotSpacing;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows, (r) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(columns, (c) {
                final dayNumber = (r * columns) + c + 1;
                if (dayNumber > totalDays) {
                  return SizedBox(width: dotSize + spacing, height: dotSize + spacing);
                }

                final isPassed = dayNumber < post.currentDayOfYear;
                final isToday = dayNumber == post.currentDayOfYear;

                Color color;
                if (isToday) {
                  color = post.theme.todayColor;
                } else if (isPassed) {
                  color = post.theme.passedColor;
                } else {
                  color = post.theme.remainingColor;
                }

                return GestureDetector(
                  onTap: () => onDayTapped?.call(dayNumber),
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    margin: EdgeInsets.all(spacing / 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(
                        post.dotShape == YearDotShape.circle
                            ? dotSize / 2
                            : (post.dotShape == YearDotShape.pixelSharp
                                ? 0.0
                                : (post.dotShape == YearDotShape.squircle ? dotSize * 0.45 : post.dotShape.radius)),
                      ),
                      border: isToday && post.highlightToday
                          ? Border.all(color: Colors.white, width: 1.5)
                          : Border.all(color: Colors.transparent),
                      boxShadow: isToday && post.highlightToday
                          ? [
                              BoxShadow(
                                color: post.theme.todayColor.withValues(alpha: 0.7),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }

  // ─── Layout 2: 12 Month Blocks (4 columns x 3 rows) ───
  Widget _buildMonthBlocksGrid(BuildContext context, {required bool isVerticalStory}) {
    const monthNames = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    const daysInMonths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    final isLeap = post.totalDaysInYear == 366;
    final adjustedDays = List<int>.from(daysInMonths);
    if (isLeap) adjustedDays[1] = 29;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(12, (mIdx) {
            final monthName = monthNames[mIdx];
            final numDays = adjustedDays[mIdx];

            int startDayOfYear = 1;
            for (int i = 0; i < mIdx; i++) {
              startDayOfYear += adjustedDays[i];
            }

            return Container(
              width: 82,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                color: post.theme.remainingColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: post.theme.cardBorder, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monthName,
                    style: TextStyle(
                      color: post.theme.secondaryText,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 2.0,
                    runSpacing: 2.0,
                    children: List.generate(numDays, (d) {
                      final dayNum = startDayOfYear + d;
                      final isPassed = dayNum < post.currentDayOfYear;
                      final isToday = dayNum == post.currentDayOfYear;

                      Color color;
                      if (isToday) {
                        color = post.theme.todayColor;
                      } else if (isPassed) {
                        color = post.theme.passedColor;
                      } else {
                        color = post.theme.remainingColor;
                      }

                      return GestureDetector(
                        onTap: () => onDayTapped?.call(dayNum),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(
                              post.dotShape == YearDotShape.circle ? 3.0 : (post.dotShape == YearDotShape.pixelSharp ? 0 : 1.5),
                            ),
                            border: isToday && post.highlightToday
                                ? Border.all(color: Colors.white, width: 1)
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── Layout 3: Hero Progress Stream ───
  Widget _buildStreamView(BuildContext context, {required bool isVerticalStory}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: post.theme.remainingColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: post.theme.cardBorder, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBigStat('DAYS PASSED', '${post.currentDayOfYear}', post.theme.passedColor),
              Container(width: 1, height: 32, color: post.theme.cardBorder),
              _buildBigStat('DAYS LEFT', '${post.daysRemaining}', const Color(0xFFF97316)),
              Container(width: 1, height: 32, color: post.theme.cardBorder),
              _buildBigStat('WEEKS LEFT', '${post.weeksRemaining}', post.theme.todayColor),
            ],
          ),
          const SizedBox(height: 12),
          // 52-week Mini Indicator Stream
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: List.generate(52, (wIdx) {
                final passedWeeks = (post.currentDayOfYear / 7).floor();
                final isPassed = wIdx < passedWeeks;
                final isCurrent = wIdx == passedWeeks;

                return Container(
                  width: 5.5,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 1.0),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? post.theme.todayColor
                        : (isPassed ? post.theme.passedColor : post.theme.remainingColor),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigStat(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: post.theme.secondaryText,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}
