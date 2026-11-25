import 'carousel_slide.dart';
import 'carousel_template_theme.dart';

class CarouselProject {
  final String id;
  String title;
  CarouselTemplateTheme theme;
  List<CarouselSlide> slides;

  CarouselProject({
    required this.id,
    required this.title,
    required this.theme,
    required this.slides,
  });

  CarouselProject copyWith({
    String? id,
    String? title,
    CarouselTemplateTheme? theme,
    List<CarouselSlide>? slides,
  }) {
    return CarouselProject(
      id: id ?? this.id,
      title: title ?? this.title,
      theme: theme ?? this.theme,
      slides: slides ?? this.slides,
    );
  }

  static CarouselProject createDefault() {
    return CarouselProject(
      id: 'default_${DateTime.now().millisecondsSinceEpoch}',
      title: '5 Mindset Shifts for Success',
      theme: const CarouselTemplateTheme(),
      slides: [
        // 1. Cover Slide
        CarouselSlide(
          id: 'slide_cover',
          type: SlideType.cover,
          coverTitle: '5 MINDSET SHIFTS FOR INNER PEACE & SUCCESS',
          coverSubtitle: 'Timeless principles to master your focus, discipline, and emotional strength.',
        ),
        // 2. Content Slide #1
        CarouselSlide(
          id: 'slide_content_1',
          type: SlideType.content,
          slideNumber: 1,
          title: 'Focus on what you can control',
          bodyText: 'You have power over your mind - not outside events. Realize this, and you will find immense strength. Most suffering comes from trying to control outcomes beyond your direct reach.',
        ),
        // 3. Content Slide #2
        CarouselSlide(
          id: 'slide_content_2',
          type: SlideType.content,
          slideNumber: 2,
          title: 'The 1% compounding rule',
          bodyText: 'Small habits don\'t simply add up; they compound exponentially. Getting just 1% better each day yields a 37-fold improvement over the course of a single year.',
        ),
        // 4. Content Slide #3
        CarouselSlide(
          id: 'slide_content_3',
          type: SlideType.content,
          slideNumber: 3,
          title: 'Embrace voluntary discomfort',
          bodyText: 'Difficulties strengthen the mind, as labor does the body. If you never test your limits, you will never discover what you are truly capable of enduring.',
        ),
        // 5. Content Slide #4
        CarouselSlide(
          id: 'slide_content_4',
          type: SlideType.content,
          slideNumber: 4,
          title: 'Protect your deep focus',
          bodyText: 'The ability to perform deep work without interruption is becoming rare at the exact moment it is becoming most valuable in our economy.',
        ),
        // 6. Content Slide #5
        CarouselSlide(
          id: 'slide_content_5',
          type: SlideType.content,
          slideNumber: 5,
          title: 'Consistency beats intensity',
          bodyText: 'Anyone can stay motivated for an afternoon. True greatness comes from showing up on ordinary days when no one is watching and doing the work regardless.',
        ),
        // 7. CTA Slide
        CarouselSlide(
          id: 'slide_cta',
          type: SlideType.cta,
          ctaHeadline: 'Which mindset shift resonated most?',
          ctaSubheadline: 'Save this post for later & share your top takeaway in the comments below!',
          ctaTag: 'SAVE & SHARE',
        ),
      ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'theme': theme.toMap(),
      'slides': slides.map((s) => s.toMap()).toList(),
    };
  }

  factory CarouselProject.fromMap(Map<String, dynamic> map) {
    return CarouselProject(
      id: map['id'] as String? ?? 'proj_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? 'Carousel Post Project',
      theme: CarouselTemplateTheme.fromMap(Map<String, dynamic>.from(map['theme'] as Map? ?? {})),
      slides: (map['slides'] as List? ?? [])
          .map((item) => CarouselSlide.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}
