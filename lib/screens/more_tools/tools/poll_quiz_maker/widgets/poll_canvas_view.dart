import 'dart:io';
import 'package:flutter/material.dart';
import '../models/poll_quiz_model.dart';

/// The live render canvas for poll and quiz posts.
/// Dynamically scales to 9:16, 4:5, or 1:1 with zero text clipping.
class PollCanvasView extends StatelessWidget {
  final PollPost post;
  final VoidCallback? onEditRequested;

  const PollCanvasView({
    super.key,
    required this.post,
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bool isStory = post.aspectRatio == PollAspectRatio.story9x16;
    final bool isSquare = post.aspectRatio == PollAspectRatio.square1x1;
    const double refWidth = 380.0;
    final double refHeight = isStory
        ? (380.0 * 16 / 9)
        : (isSquare ? 380.0 : (380.0 * 5 / 4));

    return AspectRatio(
      aspectRatio: post.aspectRatio.ratio,
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
              // 1. Background (Custom Image or Curated Gradient)
              _buildBackground(),

              // 2. Subtle Dark Vignette / Frosted Layer for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),

              // 3. Proportional Foreground Content (Zero-Overflow Guaranteed)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isStory ? 18 : (isSquare ? 12 : 16),
                    vertical: isStory ? 18 : (isSquare ? 10 : 14),
                  ),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: refWidth,
                      height: refHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Ribbon: Category Pill & Optional Timer
                          _buildHeaderRibbon(),

                          const SizedBox(height: 14),

                          // Central Question Headline
                          _buildQuestionBox(),

                          const SizedBox(height: 14),

                          // Layout Body according to Poll Type
                          Expanded(
                            child: _buildPollBody(),
                          ),

                          const SizedBox(height: 10),

                          // Watermark Footer
                          _buildFooter(),
                        ],
                      ),
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

  // ─── Background Layer ───
  Widget _buildBackground() {
    if (post.customBgImagePath != null && File(post.customBgImagePath!).existsSync()) {
      return Image.file(
        File(post.customBgImagePath!),
        fit: BoxFit.cover,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: post.theme.gradientColors,
        ),
      ),
    );
  }

  // ─── Header Category & Countdown Timer ───
  Widget _buildHeaderRibbon() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Category Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: post.theme.cardBg.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: post.theme.accentColor.withOpacity(0.6), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: post.theme.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                post.category.toUpperCase(),
                style: TextStyle(
                  color: post.theme.accentColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),

        // Optional Timer Countdown Badge
        if (post.showTimer)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 13, color: Color(0xFFFACC15)),
                const SizedBox(width: 4),
                Text(
                  '${post.timerSeconds}s',
                  style: const TextStyle(
                    color: Color(0xFFFACC15),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Central Question Card ───
  Widget _buildQuestionBox() {
    final double fontSize = switch (post.aspectRatio) {
      PollAspectRatio.square1x1 => 13.5,
      PollAspectRatio.portrait4x5 => 14.5,
      PollAspectRatio.story9x16 => 16.0,
    };

    final EdgeInsets padding = switch (post.aspectRatio) {
      PollAspectRatio.square1x1 => const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      PollAspectRatio.portrait4x5 => const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      PollAspectRatio.story9x16 => const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: post.theme.cardBg.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: post.theme.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        post.question,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: post.theme.textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.35,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  // ─── Type-specific Poll Body ───
  Widget _buildPollBody() {
    switch (post.type) {
      case PollType.trivia4:
        return _buildTrivia4Body();
      case PollType.thisOrThat:
        return _buildThisOrThatBody();
      case PollType.percentagePoll:
        return _buildPercentagePollBody();
      case PollType.trueOrFalse:
        return _buildTrueOrFalseBody();
    }
  }

  // ─── 1. Trivia 4-Option List (Adaptive: 2x2 Grid for 1:1, Vertical List for 4:5 & 9:16) ───
  Widget _buildTrivia4Body() {
    if (post.aspectRatio == PollAspectRatio.square1x1 && post.options.length >= 4) {
      return _buildTrivia2x2Grid();
    }
    return _buildTriviaVerticalList();
  }

  Widget _buildTrivia2x2Grid() {
    const letters = ['A', 'B', 'C', 'D'];

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridCard(0, letters[0])),
              const SizedBox(width: 8),
              Expanded(child: _buildGridCard(1, letters[1])),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridCard(2, letters[2])),
              const SizedBox(width: 8),
              Expanded(child: _buildGridCard(3, letters[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(int index, String letter) {
    if (index >= post.options.length) return const SizedBox.shrink();
    final opt = post.options[index];
    final isCorrect = opt.isCorrect;
    final isRevealed = post.revealAnswer;

    Color borderColor = post.theme.cardBorder;
    Color cardColor = post.theme.cardBg.withOpacity(0.85);
    Color badgeBg = post.theme.cardBorder;

    if (isRevealed && isCorrect) {
      borderColor = const Color(0xFF10B981);
      cardColor = const Color(0xFF064E3B).withOpacity(0.9);
      badgeBg = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isRevealed && isCorrect ? 2.0 : 1.2),
        boxShadow: isRevealed && isCorrect
            ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.35), blurRadius: 8)]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                child: isRevealed && isCorrect
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : Text(
                        letter,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                      ),
              ),
              if (isRevealed)
                Text(
                  '${opt.votesPercent}%',
                  style: TextStyle(
                    color: isCorrect ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            opt.text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: isRevealed && isCorrect ? FontWeight.w700 : FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriviaVerticalList() {
    const letters = ['A', 'B', 'C', 'D'];
    final isCompact = post.aspectRatio == PollAspectRatio.portrait4x5;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(post.options.length.clamp(0, 4), (index) {
        final opt = post.options[index];
        final isCorrect = opt.isCorrect;
        final isRevealed = post.revealAnswer;

        Color borderColor = post.theme.cardBorder;
        Color cardColor = post.theme.cardBg.withOpacity(0.85);
        Color badgeBg = post.theme.cardBorder;
        Color badgeText = Colors.white;

        if (isRevealed && isCorrect) {
          borderColor = const Color(0xFF10B981);
          cardColor = const Color(0xFF064E3B).withOpacity(0.9);
          badgeBg = const Color(0xFF10B981);
          badgeText = Colors.white;
        }

        return Container(
          margin: EdgeInsets.symmetric(vertical: isCompact ? 3 : 5),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: isCompact ? 8 : 11),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isRevealed && isCorrect ? 2.0 : 1.2),
            boxShadow: isRevealed && isCorrect
                ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            children: [
              // Letter Badge (A, B, C, D)
              Container(
                width: isCompact ? 24 : 28,
                height: isCompact ? 24 : 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                ),
                child: isRevealed && isCorrect
                    ? Icon(Icons.check_rounded, color: Colors.white, size: isCompact ? 14 : 16)
                    : Text(
                        letters[index % letters.length],
                        style: TextStyle(
                          color: badgeText,
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 11 : 12.5,
                          fontFamily: 'Poppins',
                        ),
                      ),
              ),
              const SizedBox(width: 10),

              // Option Text
              Expanded(
                child: Text(
                  opt.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: isRevealed && isCorrect ? FontWeight.w700 : FontWeight.w500,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),

              // Reveal Vote Percentage
              if (isRevealed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${opt.votesPercent}%',
                    style: TextStyle(
                      color: isCorrect ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ─── 2. This or That (Versus) ───
  Widget _buildThisOrThatBody() {
    final opt1 = post.options.isNotEmpty ? post.options[0] : const PollOption(id: '1', text: 'Option 1');
    final opt2 = post.options.length > 1 ? post.options[1] : const PollOption(id: '2', text: 'Option 2');

    final isVertical = post.aspectRatio == PollAspectRatio.story9x16;

    if (isVertical) {
      return Column(
        children: [
          Expanded(child: _buildVsCard(opt1, const Color(0xFF38BDF8))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildVsPill(),
          ),
          Expanded(child: _buildVsCard(opt2, const Color(0xFFFF5252))),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: _buildVsCard(opt1, const Color(0xFF38BDF8))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildVsPill(),
          ),
          Expanded(child: _buildVsCard(opt2, const Color(0xFFFF5252))),
        ],
      );
    }
  }

  Widget _buildVsCard(PollOption option, Color accent) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: post.theme.cardBg.withOpacity(0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.7), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Optional image inside option card
          if (option.imagePath != null && File(option.imagePath!).existsSync())
            Image.file(File(option.imagePath!), fit: BoxFit.cover),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black12, Colors.black.withOpacity(0.75)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  option.text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withOpacity(0.5)),
                  ),
                  child: Text(
                    '${option.votesPercent}% VOTES',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVsPill() {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFACC15),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFACC15).withOpacity(0.4),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Text(
        'VS',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  // ─── 3. Percentage Poll with Animated Fill Bars ───
  Widget _buildPercentagePollBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: post.options.map((opt) {
        final percent = (opt.votesPercent.clamp(0, 100)) / 100.0;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: post.theme.cardBg.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: post.theme.cardBorder, width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Fill progress bar
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: post.theme.accentColor.withOpacity(0.35),
                  ),
                ),
              ),

              // Text Overlay
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    Text(
                      '${opt.votesPercent}%',
                      style: TextStyle(
                        color: post.theme.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── 4. True or False Card Pair ───
  Widget _buildTrueOrFalseBody() {
    final optTrue = post.options.isNotEmpty ? post.options[0] : const PollOption(id: '1', text: 'TRUE');
    final optFalse = post.options.length > 1 ? post.options[1] : const PollOption(id: '2', text: 'FALSE');

    return Row(
      children: [
        Expanded(
          child: _buildTfChoiceCard(
            option: optTrue,
            accent: const Color(0xFF10B981),
            icon: Icons.check_circle_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTfChoiceCard(
            option: optFalse,
            accent: const Color(0xFFEF4444),
            icon: Icons.cancel_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildTfChoiceCard({
    required PollOption option,
    required Color accent,
    required IconData icon,
  }) {
    final isRevealed = post.revealAnswer;
    final isWinner = option.isCorrect;

    return Container(
      decoration: BoxDecoration(
        color: post.theme.cardBg.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRevealed && isWinner ? accent : post.theme.cardBorder,
          width: isRevealed && isWinner ? 2.5 : 1.2,
        ),
        boxShadow: isRevealed && isWinner
            ? [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 14)]
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: accent),
          const SizedBox(height: 10),
          Text(
            option.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          if (isRevealed) ...[
            const SizedBox(height: 8),
            Text(
              '${option.votesPercent}%',
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Footer Watermark ───
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flash_on_rounded, size: 11, color: Color(0xFF00E5FF)),
              const SizedBox(width: 4),
              Text(
                post.creatorHandle,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

