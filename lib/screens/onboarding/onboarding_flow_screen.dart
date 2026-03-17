import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/onboarding_service.dart';
import 'onboarding_page_library.dart';
import 'onboarding_page_posts.dart';
import 'onboarding_page_video_text.dart';
import 'onboarding_page_welcome.dart';

class OnboardingFlowScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const OnboardingFlowScreen({
    super.key,
    this.onFinished,
  });

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  final List<Widget> _pages = const [
    OnboardingPageWelcome(),
    OnboardingPagePosts(),
    OnboardingPageVideoText(),
    OnboardingPageLibrary(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    await OnboardingService.setCompleted(true);
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    const bg = Color(0xFFF4F5F7);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _index = i),
              children: _pages,
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.95),
                          blurRadius: 18,
                          offset: const Offset(-10, -10),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 18,
                          offset: const Offset(12, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () async {
                            await _finish();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black87,
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(
                            _pages.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: i == _index ? 22 : 8,
                              decoration: BoxDecoration(
                                color: i == _index ? color : Colors.black.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () async {
                            if (_isLast) {
                              await _finish();
                              return;
                            }
                            await _pageController.nextPage(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: bg,
                            foregroundColor: color,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text(
                            _isLast ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bg,
      ),
    );
  }
}
