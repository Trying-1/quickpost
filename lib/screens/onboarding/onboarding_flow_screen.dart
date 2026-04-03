import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/onboarding_service.dart';
import 'onboarding_page_welcome.dart';
import 'onboarding_page_posts.dart';
import 'onboarding_page_video_text.dart';
import 'onboarding_page_library.dart';
import 'onboarding_page_automation.dart';
import 'onboarding_page_final.dart';
import '../../config/app_theme.dart';

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

  final List<Widget> _pages = [
    OnboardingPageWelcome(),
    OnboardingPagePosts(),
    OnboardingPageVideoText(),
    OnboardingPageLibrary(),
    OnboardingPageAutomation(),
    OnboardingPageFinal(),
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
    final primary = AppColors.primary;
    final bg = AppColors.background;
    final cardBg = Colors.white;
    final glassBorder = AppColors.divider;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            // Background subtle glows
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00897B).withValues(alpha: 0.05),
                ),
              ),
            ),

            PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _index = i),
              children: _pages,
            ),
            
            // Modern Tactical Navigation Bar
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cardBg.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async => await _finish(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Progress Dots
                        Row(
                          children: List.generate(
                            _pages.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 6,
                              width: i == _index ? 24 : 6,
                              decoration: BoxDecoration(
                                color: i == _index ? primary : AppColors.divider,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Action Button
                        GestureDetector(
                          onTap: () async {
                            if (_isLast) {
                                await _finish();
                                return;
                            }
                            await _pageController.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.fastOutSlowIn,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00796B), Color(0xFF004D40)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isLast ? 'Enter' : 'Next',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ],
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
      ),
    );
  }
}
