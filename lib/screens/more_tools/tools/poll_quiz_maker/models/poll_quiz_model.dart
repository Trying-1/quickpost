import 'package:flutter/material.dart';

/// The format/layout archetype of the poll or quiz.
enum PollType {
  trivia4(
    id: 'trivia4',
    name: '4-Option Trivia',
    subtitle: 'Classic A/B/C/D multiple choice quiz with answer reveal',
    icon: Icons.quiz_rounded,
  ),
  thisOrThat(
    id: 'this_or_that',
    name: 'This or That (VS)',
    subtitle: 'Split-card matchup with central VS badge & image support',
    icon: Icons.compare_arrows_rounded,
  ),
  percentagePoll(
    id: 'percentage_poll',
    name: 'Percentage Poll',
    subtitle: 'Dynamic animated fill bars with voting percentage counters',
    icon: Icons.poll_rounded,
  ),
  trueOrFalse(
    id: 'true_false',
    name: 'True or False',
    subtitle: 'Fast 2-choice debate card with instant verdict styling',
    icon: Icons.thumbs_up_down_rounded,
  );

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;

  const PollType({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
  });
}

/// Canvas aspect ratio choices for feed vs stories/reels.
enum PollAspectRatio {
  portrait4x5(
    id: '4:5',
    label: '4:5 Feed Portrait',
    ratio: 4 / 5,
    icon: Icons.portrait_rounded,
  ),
  square1x1(
    id: '1:1',
    label: '1:1 Square Feed',
    ratio: 1.0,
    icon: Icons.crop_square_rounded,
  ),
  story9x16(
    id: '9:16',
    label: '9:16 Story / Reels',
    ratio: 9 / 16,
    icon: Icons.stay_current_portrait_rounded,
  );

  final String id;
  final String label;
  final double ratio;
  final IconData icon;

  const PollAspectRatio({
    required this.id,
    required this.label,
    required this.ratio,
    required this.icon,
  });
}

/// Single selectable answer or debate choice.
class PollOption {
  final String id;
  final String text;
  final int votesPercent; // 0 - 100
  final String? imagePath;
  final bool isCorrect;

  const PollOption({
    required this.id,
    required this.text,
    this.votesPercent = 25,
    this.imagePath,
    this.isCorrect = false,
  });

  PollOption copyWith({
    String? id,
    String? text,
    int? votesPercent,
    String? imagePath,
    bool? isCorrect,
    bool clearImage = false,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      votesPercent: votesPercent ?? this.votesPercent,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }
}

/// Curated background themes optimized for high viral contrast.
class PollThemePreset {
  final String name;
  final List<Color> gradientColors;
  final Color cardBg;
  final Color cardBorder;
  final Color accentColor;
  final Color textColor;

  const PollThemePreset({
    required this.name,
    required this.gradientColors,
    required this.cardBg,
    required this.cardBorder,
    required this.accentColor,
    this.textColor = Colors.white,
  });

  static const List<PollThemePreset> presets = [
    PollThemePreset(
      name: 'Cyber Midnight',
      gradientColors: [Color(0xFF090D16), Color(0xFF131C31)],
      cardBg: Color(0xFF1B243B),
      cardBorder: Color(0xFF2C395B),
      accentColor: Color(0xFF00E5FF),
    ),
    PollThemePreset(
      name: 'Neon Violet',
      gradientColors: [Color(0xFF180A2E), Color(0xFF2D1254)],
      cardBg: Color(0xFF381B66),
      cardBorder: Color(0xFF562C9B),
      accentColor: Color(0xFFC084FC),
    ),
    PollThemePreset(
      name: 'Sunset Ember',
      gradientColors: [Color(0xFF240E15), Color(0xFF421625)],
      cardBg: Color(0xFF4E1D2E),
      cardBorder: Color(0xFF7A2946),
      accentColor: Color(0xFFFF5252),
    ),
    PollThemePreset(
      name: 'Emerald Matrix',
      gradientColors: [Color(0xFF071C17), Color(0xFF0F362C)],
      cardBg: Color(0xFF16483C),
      cardBorder: Color(0xFF236E5C),
      accentColor: Color(0xFF10B981),
    ),
    PollThemePreset(
      name: 'Golden Royale',
      gradientColors: [Color(0xFF1C180A), Color(0xFF362E12)],
      cardBg: Color(0xFF423816),
      cardBorder: Color(0xFF6B5B24),
      accentColor: Color(0xFFFACC15),
    ),
    PollThemePreset(
      name: 'Clean Obsidian',
      gradientColors: [Color(0xFF111418), Color(0xFF1C2128)],
      cardBg: Color(0xFF252C36),
      cardBorder: Color(0xFF3B4452),
      accentColor: Color(0xFF38BDF8),
    ),
  ];
}

/// Domain configuration model representing the entire quiz/poll post.
class PollPost {
  final PollType type;
  final PollAspectRatio aspectRatio;
  final String category;
  final String question;
  final List<PollOption> options;
  final int themeIndex;
  final String? customBgImagePath;
  final bool showTimer;
  final int timerSeconds;
  final bool revealAnswer;
  final String creatorHandle;

  const PollPost({
    this.type = PollType.trivia4,
    this.aspectRatio = PollAspectRatio.story9x16,
    this.category = 'DAILY TRIVIA',
    this.question = 'Which planet is known as the Red Planet in our solar system?',
    required this.options,
    this.themeIndex = 0,
    this.customBgImagePath,
    this.showTimer = true,
    this.timerSeconds = 10,
    this.revealAnswer = false,
    this.creatorHandle = '@app.quickpost',
  });

  PollThemePreset get theme => PollThemePreset.presets[themeIndex.clamp(0, PollThemePreset.presets.length - 1)];

  PollPost copyWith({
    PollType? type,
    PollAspectRatio? aspectRatio,
    String? category,
    String? question,
    List<PollOption>? options,
    int? themeIndex,
    String? customBgImagePath,
    bool? showTimer,
    int? timerSeconds,
    bool? revealAnswer,
    String? creatorHandle,
    bool clearBgImage = false,
  }) {
    return PollPost(
      type: type ?? this.type,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      category: category ?? this.category,
      question: question ?? this.question,
      options: options ?? List.from(this.options),
      themeIndex: themeIndex ?? this.themeIndex,
      customBgImagePath: clearBgImage ? null : (customBgImagePath ?? this.customBgImagePath),
      showTimer: showTimer ?? this.showTimer,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      revealAnswer: revealAnswer ?? this.revealAnswer,
      creatorHandle: creatorHandle ?? this.creatorHandle,
    );
  }

  /// Default starting quiz
  static PollPost get initialDefault => const PollPost(
        type: PollType.trivia4,
        aspectRatio: PollAspectRatio.portrait4x5,
        category: 'ASTRONOMY TRIVIA 🪐',
        question: 'Which planet is famously known as the Red Planet?',
        options: [
          PollOption(id: 'opt1', text: 'Venus', votesPercent: 12, isCorrect: false),
          PollOption(id: 'opt2', text: 'Mars', votesPercent: 68, isCorrect: true),
          PollOption(id: 'opt3', text: 'Jupiter', votesPercent: 15, isCorrect: false),
          PollOption(id: 'opt4', text: 'Mercury', votesPercent: 5, isCorrect: false),
        ],
        themeIndex: 0,
        showTimer: true,
        timerSeconds: 10,
        revealAnswer: false,
      );

  /// Viral pre-configured templates
  static List<PollPost> get viralTemplates => [
        // 1. Trivia 4-Option
        const PollPost(
          type: PollType.trivia4,
          aspectRatio: PollAspectRatio.story9x16,
          category: 'GEOGRAPHY QUIZ 🌍',
          question: 'What is the capital city of Australia?',
          options: [
            PollOption(id: 'g1', text: 'Sydney', votesPercent: 35, isCorrect: false),
            PollOption(id: 'g2', text: 'Melbourne', votesPercent: 20, isCorrect: false),
            PollOption(id: 'g3', text: 'Canberra', votesPercent: 40, isCorrect: true),
            PollOption(id: 'g4', text: 'Brisbane', votesPercent: 5, isCorrect: false),
          ],
          themeIndex: 1,
          showTimer: true,
          timerSeconds: 8,
          revealAnswer: false,
        ),

        // 2. This or That / Versus
        const PollPost(
          type: PollType.thisOrThat,
          aspectRatio: PollAspectRatio.story9x16,
          category: 'WOULD YOU RATHER? 🔥',
          question: 'Which superpower would you choose forever?',
          options: [
            PollOption(id: 'tot1', text: 'Fly Anywhere Anytime ✈️', votesPercent: 54),
            PollOption(id: 'tot2', text: 'Be Completely Invisible 👻', votesPercent: 46),
          ],
          themeIndex: 2,
          showTimer: false,
        ),

        // 3. Percentage Poll
        const PollPost(
          type: PollType.percentagePoll,
          aspectRatio: PollAspectRatio.story9x16,
          category: 'CREATOR COMMUNITY POLL 📊',
          question: 'What platform gives your content the best reach in 2026?',
          options: [
            PollOption(id: 'p1', text: 'Vertical Reels', votesPercent: 48),
            PollOption(id: 'p2', text: 'Short Videos', votesPercent: 34),
            PollOption(id: 'p3', text: 'Story Carousels', votesPercent: 18),
          ],
          themeIndex: 3,
          showTimer: false,
        ),

        // 4. True or False
        const PollPost(
          type: PollType.trueOrFalse,
          aspectRatio: PollAspectRatio.story9x16,
          category: 'FACT OR CAP? 🧠',
          question: 'Honey never spoils. Archeologists found 3,000-year-old edible honey in Egyptian tombs!',
          options: [
            PollOption(id: 'tf1', text: 'TRUE (100% Real Fact) ✅', votesPercent: 82, isCorrect: true),
            PollOption(id: 'tf2', text: 'FALSE (Total Myth) ❌', votesPercent: 18, isCorrect: false),
          ],
          themeIndex: 4,
          showTimer: true,
          timerSeconds: 5,
          revealAnswer: false,
        ),
      ];
}

