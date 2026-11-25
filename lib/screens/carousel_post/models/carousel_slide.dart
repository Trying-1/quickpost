import 'dart:ui';
import 'carousel_template_theme.dart';

enum SlideType { cover, content, cta }

/// Standard component identifiers for dragging, positioning, font, and color styling.
class SlideComponentId {
  static const String allContent = 'allContent';
  static const String canvasBackground = 'canvasBackground';
  static const String numberBadge = 'numberBadge';
  static const String title = 'title';
  static const String bodyText = 'bodyText';
  static const String pageHandle = 'pageHandle';
  static const String slideCounter = 'slideCounter';
  static const String swipeIndicator = 'swipeIndicator';

  static const List<String> contentComponents = [
    allContent,
    title,
    bodyText,
    pageHandle,
    slideCounter,
  ];

  static const List<String> colorComponents = [
    canvasBackground,
    title,
    bodyText,
    pageHandle,
    slideCounter,
    swipeIndicator,
  ];

  static const List<String> coverComponents = [
    allContent,
    title,
    bodyText,
    swipeIndicator,
    pageHandle,
    slideCounter,
  ];

  static const List<String> ctaComponents = [
    allContent,
    title,
    bodyText,
    swipeIndicator,
    pageHandle,
    slideCounter,
  ];

  static String getLabel(String key) {
    switch (key) {
      case canvasBackground:
        return 'Slide Background';
      case allContent:
        return 'All Content (Group)';
      case title:
        return 'Headline / Quote';
      case bodyText:
        return 'Body Text / Quote';
      case pageHandle:
        return 'Watermark / Handle';
      case slideCounter:
        return 'Slide Counter';
      case swipeIndicator:
        return 'Swipe Cue';
      default:
        return key;
    }
  }
}

class CarouselSlide {
  final String id;
  SlideType type;

  // Background visual
  String? bgImagePath;
  double bgBrightness; // 0.0 to 1.5
  double bgBlur;       // 0.0 to 10.0

  // 1. Cover Slide Specifics
  String coverTag;         // e.g. "DAILY WISDOM" / "GUIDE"
  String coverTitle;       // e.g. "5 MINDSET SHIFTS FOR SUCCESS"
  String coverSubtitle;    // e.g. "Timeless lessons to master your focus & discipline."

  // 2. Content / Guide / Quote Slide Specifics
  int slideNumber;         // e.g. 1
  String title;            // e.g. "Focus on what you can control"
  String author;           // e.g. "— Marcus Aurelius" or "Rule #01"
  String bodyText;         // e.g. "You have power over your mind - not outside events."
  String takeaway;         // e.g. "Action: Identify 3 things today you cannot control and let them go."

  // 3. CTA Slide Specifics
  String ctaHeadline;      // e.g. "Which mindset shift resonated most?"
  String ctaSubheadline;   // e.g. "Save this post for later & share your top takeaway!"
  String ctaTag;           // e.g. "SAVE & SHARE"

  // Positioning & Component Offsets
  double contentOffsetX;
  double contentOffsetY;
  double headerOffsetY;

  final Map<String, Offset> componentOffsets;
  SlideLayout? customLayout;

  CarouselSlide({
    required this.id,
    required this.type,
    this.bgImagePath,
    this.bgBrightness = 0.55,
    this.bgBlur = 0.0,
    this.coverTag = '',
    this.coverTitle = '',
    this.coverSubtitle = 'Actionable steps and insights you can apply today.',
    this.slideNumber = 1,
    this.title = 'Headline or Core Principle',
    this.author = '',
    this.bodyText = 'Detailed explanation, actionable advice, or quote body goes here.',
    this.takeaway = '',
    this.ctaHeadline = 'Which insight resonated most?',
    this.ctaSubheadline = 'Save this post for later & share your thoughts in the comments!',
    this.ctaTag = 'SAVE & SHARE',
    this.contentOffsetX = 0.0,
    this.contentOffsetY = 0.0,
    this.headerOffsetY = 0.0,
    this.componentOffsets = const {},
    this.customLayout,
  });

  String? get imagePath => bgImagePath;

  Offset getComponentOffset(String componentKey) {
    if (componentKey == SlideComponentId.allContent) {
      return Offset(contentOffsetX, contentOffsetY);
    }
    if (componentKey == SlideComponentId.pageHandle) {
      return componentOffsets[componentKey] ?? Offset(0, headerOffsetY);
    }
    return componentOffsets[componentKey] ?? Offset.zero;
  }

  SlideLayout getEffectiveLayout(CarouselTemplateTheme theme) {
    return customLayout ?? theme.slideLayout;
  }

  CarouselSlide copyWithComponentOffset(String componentKey, Offset offset) {
    if (componentKey == SlideComponentId.allContent) {
      return copyWith(
        contentOffsetX: offset.dx,
        contentOffsetY: offset.dy,
      );
    }
    if (componentKey == SlideComponentId.pageHandle) {
      final updatedOffsets = Map<String, Offset>.from(componentOffsets);
      updatedOffsets[componentKey] = offset;
      return copyWith(
        headerOffsetY: offset.dy,
        componentOffsets: updatedOffsets,
      );
    }
    final updatedOffsets = Map<String, Offset>.from(componentOffsets);
    updatedOffsets[componentKey] = offset;
    return copyWith(componentOffsets: updatedOffsets);
  }

  CarouselSlide copyWithResetOffsets({String? specificKey}) {
    if (specificKey == null) {
      return copyWith(
        contentOffsetX: 0.0,
        contentOffsetY: 0.0,
        headerOffsetY: 0.0,
        componentOffsets: const {},
      );
    }

    if (specificKey == SlideComponentId.allContent) {
      return copyWith(contentOffsetX: 0.0, contentOffsetY: 0.0);
    }
    if (specificKey == SlideComponentId.pageHandle) {
      final updated = Map<String, Offset>.from(componentOffsets)..remove(specificKey);
      return copyWith(headerOffsetY: 0.0, componentOffsets: updated);
    }

    final updated = Map<String, Offset>.from(componentOffsets)..remove(specificKey);
    return copyWith(componentOffsets: updated);
  }

  CarouselSlide copyWith({
    String? id,
    SlideType? type,
    String? imagePath,
    bool clearImagePath = false,
    double? bgBrightness,
    double? bgBlur,
    String? coverTag,
    String? coverTitle,
    String? coverSubtitle,
    int? slideNumber,
    String? title,
    String? author,
    String? bodyText,
    String? takeaway,
    String? ctaHeadline,
    String? ctaSubheadline,
    String? ctaTag,
    double? contentOffsetX,
    double? contentOffsetY,
    double? headerOffsetY,
    Map<String, Offset>? componentOffsets,
    SlideLayout? customLayout,
  }) {
    return CarouselSlide(
      id: id ?? this.id,
      type: type ?? this.type,
      bgImagePath: clearImagePath ? null : (imagePath ?? this.bgImagePath),
      bgBrightness: bgBrightness ?? this.bgBrightness,
      bgBlur: bgBlur ?? this.bgBlur,
      coverTag: coverTag ?? this.coverTag,
      coverTitle: coverTitle ?? this.coverTitle,
      coverSubtitle: coverSubtitle ?? this.coverSubtitle,
      slideNumber: slideNumber ?? this.slideNumber,
      title: title ?? this.title,
      author: author ?? this.author,
      bodyText: bodyText ?? this.bodyText,
      takeaway: takeaway ?? this.takeaway,
      ctaHeadline: ctaHeadline ?? this.ctaHeadline,
      ctaSubheadline: ctaSubheadline ?? this.ctaSubheadline,
      ctaTag: ctaTag ?? this.ctaTag,
      contentOffsetX: contentOffsetX ?? this.contentOffsetX,
      contentOffsetY: contentOffsetY ?? this.contentOffsetY,
      headerOffsetY: headerOffsetY ?? this.headerOffsetY,
      componentOffsets: componentOffsets ?? this.componentOffsets,
      customLayout: customLayout ?? this.customLayout,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'bgImagePath': bgImagePath,
      'bgBrightness': bgBrightness,
      'bgBlur': bgBlur,
      'coverTag': coverTag,
      'coverTitle': coverTitle,
      'coverSubtitle': coverSubtitle,
      'slideNumber': slideNumber,
      'title': title,
      'author': author,
      'bodyText': bodyText,
      'takeaway': takeaway,
      'ctaHeadline': ctaHeadline,
      'ctaSubheadline': ctaSubheadline,
      'ctaTag': ctaTag,
      'contentOffsetX': contentOffsetX,
      'contentOffsetY': contentOffsetY,
      'headerOffsetY': headerOffsetY,
      'componentOffsets': componentOffsets.map(
        (key, offset) => MapEntry(key, {'dx': offset.dx, 'dy': offset.dy}),
      ),
      'customLayout': customLayout?.index,
    };
  }

  factory CarouselSlide.fromMap(Map<String, dynamic> map) {
    Map<String, Offset> offsets = {};
    if (map['componentOffsets'] is Map) {
      (map['componentOffsets'] as Map).forEach((k, v) {
        if (k != null && v is Map) {
          final dx = (v['dx'] as num?)?.toDouble() ?? 0.0;
          final dy = (v['dy'] as num?)?.toDouble() ?? 0.0;
          offsets[k.toString()] = Offset(dx, dy);
        }
      });
    }

    // Intelligently deduce SlideType
    SlideType slideType = SlideType.content;
    if (map['type'] != null) {
      if (map['type'] is int) {
        final idx = map['type'] as int;
        if (idx >= 0 && idx < SlideType.values.length) {
          slideType = SlideType.values[idx];
        }
      } else if (map['type'] is String) {
        final tStr = (map['type'] as String).toLowerCase().trim();
        if (tStr == 'cover') {
          slideType = SlideType.cover;
        } else if (tStr == 'cta' || tStr == 'outro') {
          slideType = SlideType.cta;
        } else {
          slideType = SlideType.content;
        }
      }
    } else {
      if (map.containsKey('coverTitle') || map.containsKey('coverSubtitle')) {
        slideType = SlideType.cover;
      } else if (map.containsKey('ctaHeadline') || map.containsKey('ctaSubheadline') || map.containsKey('ctaTag')) {
        slideType = SlideType.cta;
      } else {
        slideType = SlideType.content;
      }
    }

    final rawTitle = map['title']?.toString() ??
        map['headline']?.toString() ??
        map['quote']?.toString() ??
        map['principle']?.toString() ??
        '';

    final coverTitle = map['coverTitle']?.toString() ??
        map['cover_title']?.toString() ??
        (slideType == SlideType.cover ? (rawTitle.isNotEmpty ? rawTitle : 'CAROUSEL TITLE') : '');

    final coverSubtitle = map['coverSubtitle']?.toString() ??
        map['cover_subtitle']?.toString() ??
        map['subtitle']?.toString() ??
        '';

    final bodyText = map['bodyText']?.toString() ??
        map['body']?.toString() ??
        map['text']?.toString() ??
        map['explanation']?.toString() ??
        map['description']?.toString() ??
        map['content']?.toString() ??
        map['synopsis']?.toString() ??
        '';

    final rawNum = map['slideNumber'] ??
        map['step'] ??
        map['number'] ??
        map['rank'] ??
        map['slide'] ??
        1;
    final int slideNumber = rawNum is num ? rawNum.toInt() : (int.tryParse(rawNum.toString()) ?? 1);

    final ctaHeadline = map['ctaHeadline']?.toString() ??
        map['cta_headline']?.toString() ??
        (slideType == SlideType.cta && rawTitle.isNotEmpty ? rawTitle : 'Which insight resonated most?');

    return CarouselSlide(
      id: map['id'] as String? ?? 'slide_${DateTime.now().millisecondsSinceEpoch}',
      type: slideType,
      bgImagePath: map['bgImagePath'] as String?,
      bgBrightness: (map['bgBrightness'] as num?)?.toDouble() ?? 0.55,
      bgBlur: (map['bgBlur'] as num?)?.toDouble() ?? 0.0,
      coverTag: map['coverTag'] as String? ?? '',
      coverTitle: coverTitle,
      coverSubtitle: coverSubtitle,
      slideNumber: slideNumber,
      title: rawTitle,
      author: map['author'] as String? ?? '',
      bodyText: bodyText,
      takeaway: map['takeaway'] as String? ?? '',
      ctaHeadline: ctaHeadline,
      ctaSubheadline: map['ctaSubheadline'] as String? ?? 'Save this post & share your thoughts in the comments!',
      ctaTag: map['ctaTag'] as String? ?? 'SAVE & SHARE',
      contentOffsetX: (map['contentOffsetX'] as num?)?.toDouble() ?? 0.0,
      contentOffsetY: (map['contentOffsetY'] as num?)?.toDouble() ?? 0.0,
      headerOffsetY: (map['headerOffsetY'] as num?)?.toDouble() ?? 0.0,
      componentOffsets: offsets,
      customLayout: map['customLayout'] != null && map['customLayout'] is int
          ? SlideLayout.values[(map['customLayout'] as int).clamp(0, SlideLayout.values.length - 1)]
          : null,
    );
  }
}
