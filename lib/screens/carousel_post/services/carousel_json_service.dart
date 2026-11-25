import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../../../services/carousel_post_preset_service.dart';
import '../models/carousel_project.dart';
import '../models/carousel_slide.dart';
import '../models/carousel_template_theme.dart';

/// Service for importing, exporting, and converting Carousel posts to/from JSON.
/// Designed for seamless integration with LLMs (Gemini, ChatGPT, Claude) to automate slide creation.
class CarouselJsonService {
  /// Robustly extracts and decodes a JSON Map or List from raw text.
  /// Handles LLM markdown blocks (```json ... ```), preamble text, and loose whitespace.
  static dynamic parseLlmJson(String rawText) {
    String cleaned = rawText.trim();

    // 1. Strip markdown fences if present
    if (cleaned.contains('```')) {
      final regExp = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false);
      final match = regExp.firstMatch(cleaned);
      if (match != null && match.group(1) != null) {
        cleaned = match.group(1)!.trim();
      }
    }

    // 2. If text still contains non-JSON prefix/suffix, locate first '{' or '[' and last '}' or ']'
    final firstObj = cleaned.indexOf('{');
    final firstArr = cleaned.indexOf('[');

    int startIdx = -1;
    int endIdx = -1;

    if (firstObj != -1 && (firstArr == -1 || firstObj < firstArr)) {
      startIdx = firstObj;
      endIdx = cleaned.lastIndexOf('}');
    } else if (firstArr != -1) {
      startIdx = firstArr;
      endIdx = cleaned.lastIndexOf(']');
    }

    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      cleaned = cleaned.substring(startIdx, endIdx + 1).trim();
    }

    return json.decode(cleaned);
  }

  /// Converts parsed JSON data (Map or List) into a fully populated [CarouselProject].
  /// Optionally preserves existing slide image paths matching the slide index.
  static CarouselProject createProjectFromJson({
    required dynamic jsonData,
    CarouselTemplateTheme? existingTheme,
    List<CarouselSlide>? existingSlides,
    bool preserveImages = true,
  }) {
    final Map<int, String> existingImagePaths = {};
    if (preserveImages && existingSlides != null) {
      for (int i = 0; i < existingSlides.length; i++) {
        final img = existingSlides[i].imagePath;
        if (img != null && img.isNotEmpty) {
          existingImagePaths[i] = img;
        }
      }
    }

    // Case 1: Direct CarouselProject.toMap() output (Full backup with serialized theme and slide types)
    final bool isProjectBackup = jsonData is Map &&
        jsonData.containsKey('theme') &&
        jsonData['theme'] is Map &&
        jsonData.containsKey('slides') &&
        jsonData['slides'] is List &&
        (jsonData['slides'] as List).isNotEmpty &&
        (jsonData['slides'] as List).first is Map &&
        ((jsonData['slides'] as List).first as Map).containsKey('type') &&
        !jsonData.containsKey('cover') &&
        !jsonData.containsKey('cta');

    if (isProjectBackup) {
      final project = CarouselProject.fromMap(Map<String, dynamic>.from(jsonData as Map));
      if (preserveImages && existingImagePaths.isNotEmpty) {
        final updated = List<CarouselSlide>.from(project.slides);
        for (int i = 0; i < updated.length; i++) {
          if (existingImagePaths.containsKey(i)) {
            updated[i] = updated[i].copyWith(imagePath: existingImagePaths[i]);
          }
        }
        return project.copyWith(slides: updated);
      }
      return project;
    }

    // Case 2: Structured Object { title, cover, slides: [...], cta } or any LLM-generated Map
    if (jsonData is Map) {
      final map = Map<String, dynamic>.from(jsonData);
      final projectTitle = map['title']?.toString() ??
          map['name']?.toString() ??
          map['topic']?.toString() ??
          'Carousel Post Guide';

      // 1. Cover Slide Info
      final coverData = map['cover'] is Map ? Map<String, dynamic>.from(map['cover'] as Map) : null;
      final coverTitle = coverData?['title']?.toString() ??
          coverData?['headline']?.toString() ??
          map['coverTitle']?.toString() ??
          (map['cover'] is String ? map['cover'].toString() : projectTitle.toUpperCase());
      final coverSubtitle = coverData?['subtitle']?.toString() ??
          coverData?['subheadline']?.toString() ??
          coverData?['description']?.toString() ??
          map['coverSubtitle']?.toString() ??
          map['subtitle']?.toString() ??
          'Actionable steps and insights you can apply today.';

      // 2. Content Slides extraction across multiple LLM keys
      final rawSlides = map['slides'] ??
          map['items'] ??
          map['list'] ??
          map['quotes'] ??
          map['steps'] ??
          map['tips'] ??
          map['points'] ??
          map['content'];

      final List<CarouselSlide> contentSlides = [];
      CarouselSlide? customCoverSlide;
      CarouselSlide? customCtaSlide;

      if (rawSlides is List) {
        for (int i = 0; i < rawSlides.length; i++) {
          final item = rawSlides[i];
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);

            // Check if explicitly typed as cover
            final typeStr = m['type']?.toString().toLowerCase().trim();
            if (typeStr == 'cover' && customCoverSlide == null) {
              final cTitle = m['coverTitle']?.toString() ?? m['title']?.toString() ?? coverTitle;
              final cSub = m['coverSubtitle']?.toString() ?? m['subtitle']?.toString() ?? coverSubtitle;
              customCoverSlide = CarouselSlide(
                id: 'slide_cover_${DateTime.now().millisecondsSinceEpoch}',
                type: SlideType.cover,
                bgImagePath: existingImagePaths[0],
                coverTitle: cTitle,
                coverSubtitle: cSub,
                title: cTitle,
              );
              continue;
            }

            // Check if explicitly typed as CTA outro
            if ((typeStr == 'cta' || typeStr == 'outro') && customCtaSlide == null) {
              final ctaHead = m['ctaHeadline']?.toString() ?? m['headline']?.toString() ?? m['title']?.toString() ?? 'Which insight resonated most?';
              final ctaSub = m['ctaSubheadline']?.toString() ?? m['subheadline']?.toString() ?? m['subtitle']?.toString() ?? m['body']?.toString() ?? 'Save this post for later & share your top takeaway!';
              final ctaTag = m['ctaTag']?.toString() ?? m['tag']?.toString() ?? 'SAVE & SHARE';
              customCtaSlide = CarouselSlide(
                id: 'slide_cta_${DateTime.now().millisecondsSinceEpoch}',
                type: SlideType.cta,
                bgImagePath: existingImagePaths[rawSlides.length],
                ctaHeadline: ctaHead,
                ctaSubheadline: ctaSub,
                ctaTag: ctaTag,
              );
              continue;
            }

            final rawStep = m['step'] ?? m['number'] ?? m['rank'] ?? m['slide'] ?? m['slideNumber'] ?? (contentSlides.length + 1);
            final int stepNum = rawStep is num ? rawStep.toInt() : (int.tryParse(rawStep.toString()) ?? (contentSlides.length + 1));
            final itemTitle = m['title']?.toString() ??
                m['headline']?.toString() ??
                m['quote']?.toString() ??
                m['principle']?.toString() ??
                m['rule']?.toString() ??
                m['point']?.toString() ??
                'Step #${contentSlides.length + 1}';
            final body = m['body']?.toString() ??
                m['text']?.toString() ??
                m['description']?.toString() ??
                m['explanation']?.toString() ??
                m['content']?.toString() ??
                m['synopsis']?.toString() ??
                m['details']?.toString() ??
                '';

            contentSlides.add(
              CarouselSlide(
                id: 'slide_content_${DateTime.now().millisecondsSinceEpoch}_${contentSlides.length}',
                type: SlideType.content,
                bgImagePath: existingImagePaths[contentSlides.length + 1],
                slideNumber: stepNum,
                title: itemTitle,
                bodyText: body,
              ),
            );
          } else if (item is String && item.trim().isNotEmpty) {
            contentSlides.add(
              CarouselSlide(
                id: 'slide_content_${DateTime.now().millisecondsSinceEpoch}_${contentSlides.length}',
                type: SlideType.content,
                bgImagePath: existingImagePaths[contentSlides.length + 1],
                slideNumber: contentSlides.length + 1,
                title: 'Step #${contentSlides.length + 1}',
                bodyText: item.trim(),
              ),
            );
          }
        }
      }

      // Final Cover slide
      final coverSlide = customCoverSlide ?? CarouselSlide(
        id: 'slide_cover_${DateTime.now().millisecondsSinceEpoch}',
        type: SlideType.cover,
        bgImagePath: existingImagePaths[0],
        coverTitle: coverTitle,
        coverSubtitle: coverSubtitle,
        title: coverTitle,
      );

      // Final CTA slide
      final ctaData = map['cta'] is Map ? Map<String, dynamic>.from(map['cta'] as Map) : null;
      final ctaHeadline = ctaData?['headline']?.toString() ??
          ctaData?['title']?.toString() ??
          map['ctaHeadline']?.toString() ??
          'Which insight resonated most?';
      final ctaSub = ctaData?['subheadline']?.toString() ??
          ctaData?['subtitle']?.toString() ??
          ctaData?['body']?.toString() ??
          map['ctaSubheadline']?.toString() ??
          'Save this post for later & share your top takeaway in the comments below!';
      final ctaTag = ctaData?['tag']?.toString() ??
          ctaData?['action']?.toString() ??
          map['ctaTag']?.toString() ??
          'SAVE & SHARE';

      final ctaSlide = customCtaSlide ?? CarouselSlide(
        id: 'slide_cta_${DateTime.now().millisecondsSinceEpoch}',
        type: SlideType.cta,
        bgImagePath: existingImagePaths[contentSlides.length + 1],
        ctaHeadline: ctaHeadline,
        ctaSubheadline: ctaSub,
        ctaTag: ctaTag,
      );

      // Fallback if no content slides were detected
      if (contentSlides.isEmpty) {
        contentSlides.add(
          CarouselSlide(
            id: 'slide_content_${DateTime.now().millisecondsSinceEpoch}_0',
            type: SlideType.content,
            bgImagePath: existingImagePaths[1],
            slideNumber: 1,
            title: projectTitle,
            bodyText: 'Practical insights and lessons you can apply today.',
          ),
        );
      }

      final allSlides = <CarouselSlide>[coverSlide, ...contentSlides, ctaSlide];

      return CarouselProject(
        id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
        title: projectTitle,
        theme: existingTheme ?? const CarouselTemplateTheme(),
        slides: allSlides,
      );
    }

    // Case 3: List of raw items
    if (jsonData is List) {
      final List<CarouselSlide> contentSlides = [];
      String derivedTitle = 'KEY INSIGHTS & LESSONS';

      for (int i = 0; i < jsonData.length; i++) {
        final item = jsonData[i];
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final rawStep = m['step'] ?? m['number'] ?? m['rank'] ?? (i + 1);
          final int stepNum = rawStep is num ? rawStep.toInt() : (int.tryParse(rawStep.toString()) ?? (i + 1));
          final itemTitle = m['title']?.toString() ??
              m['headline']?.toString() ??
              m['quote']?.toString() ??
              'Insight #${i + 1}';
          final body = m['body']?.toString() ??
              m['text']?.toString() ??
              m['description']?.toString() ??
              m['explanation']?.toString() ??
              m['content']?.toString() ??
              '';
          if (i == 0 && itemTitle.isNotEmpty) {
            derivedTitle = itemTitle;
          }
          contentSlides.add(
            CarouselSlide(
              id: 'slide_content_${DateTime.now().millisecondsSinceEpoch}_$i',
              type: SlideType.content,
              bgImagePath: existingImagePaths[i + 1],
              slideNumber: stepNum,
              title: itemTitle,
              bodyText: body,
            ),
          );
        } else if (item is String && item.trim().isNotEmpty) {
          contentSlides.add(
            CarouselSlide(
              id: 'slide_content_${DateTime.now().millisecondsSinceEpoch}_$i',
              type: SlideType.content,
              bgImagePath: existingImagePaths[i + 1],
              slideNumber: i + 1,
              title: 'Insight #${i + 1}',
              bodyText: item.trim(),
            ),
          );
        }
      }

      final coverSlide = CarouselSlide(
        id: 'slide_cover_${DateTime.now().millisecondsSinceEpoch}',
        type: SlideType.cover,
        bgImagePath: existingImagePaths[0],
        coverTitle: derivedTitle.toUpperCase(),
        coverSubtitle: 'Practical wisdom and guidance for daily mastery.',
        title: derivedTitle.toUpperCase(),
      );

      final ctaSlide = CarouselSlide(
        id: 'slide_cta_${DateTime.now().millisecondsSinceEpoch}',
        type: SlideType.cta,
        bgImagePath: existingImagePaths[contentSlides.length + 1],
        ctaHeadline: 'Which takeaway was your favorite?',
        ctaSubheadline: 'Save this post for later & share your perspective below!',
        ctaTag: 'SAVE & SHARE',
      );

      return CarouselProject(
        id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
        title: derivedTitle,
        theme: existingTheme ?? const CarouselTemplateTheme(),
        slides: [coverSlide, ...contentSlides, ctaSlide],
      );
    }

    throw const FormatException('Unrecognized carousel JSON format.');
  }

  /// Generates a prompt for Gemini / ChatGPT / Claude to produce structured JSON
  /// for a carousel post on quotes, guides, or lessons.
  static String generateLlmPrompt({
    required String title,
    int count = 5,
    String topic = 'Personal Growth & Mindset',
  }) {
    return '''
Act as a world-class social media creator and carousel designer for Instagram/LinkedIn.
Generate an engaging, highly saveable $count-slide carousel post on:
Title: "$title"
Topic/Niche: $topic

Return ONLY valid JSON wrapped in a single ```json codeblock. No commentary outside the block.

Strict JSON Format:
{
  "title": "$title",
  "cover": {
    "title": "$title",
    "subtitle": "Clear, powerful subtitle that hooks the reader to swipe."
  },
  "slides": [
    {
      "title": "Core Principle or Headline",
      "body": "Punchy 2-3 sentence explanation or quote that explains the idea clearly."
    }
  ],
  "cta": {
    "headline": "Which insight resonated most?",
    "subheadline": "Save this post for later & share your top takeaway in the comments!",
    "tag": "SAVE & SHARE"
  }
}
Generate exactly $count high-impact slides following this format.
''';
  }

  /// Exports project to a JSON file in public Downloads.
  static Future<String?> exportProjectToJsonFile(CarouselProject project, {String? customFileName}) async {
    try {
      final jsonStr = json.encode(project.toMap());
      final backupDir = await CarouselPostPresetService.getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitized = project.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
      final fileName = customFileName ?? 'carousel_project_${sanitized}_$timestamp.json';
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(jsonStr);

      try {
        const MethodChannel('com.quickpost.app/processor').invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': 'application/json',
        });
      } catch (_) {}

      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Imports project from a JSON file.
  static Future<CarouselProject?> importProjectFromJsonFile({String? filePath}) async {
    try {
      String? path = filePath;
      if (path == null) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result == null || result.files.isEmpty || result.files.first.path == null) {
          return null;
        }
        path = result.files.first.path!;
      }

      final file = File(path);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final decoded = parseLlmJson(content);
      return createProjectFromJson(jsonData: decoded);
    } catch (_) {
      return null;
    }
  }
}

