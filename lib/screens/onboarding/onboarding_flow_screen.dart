import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../services/onboarding_service.dart';
import '../../services/analytics_service.dart';
import '../../config/app_theme.dart';
import '../subscription/subscription_screen.dart';

class OnboardingFlowScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const OnboardingFlowScreen({
    super.key,
    this.onFinished,
  });

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _index = 0;

  // Questionnaire Selections
  String? _selectedGoal;
  String? _selectedPlatform;
  String? _selectedExperience;
  String? _selectedStyle;

  // Personalization Loading State
  double _loadProgress = 0.0;
  String _loadStatusText = 'Analyzing choices...';
  Timer? _loadTimer;

  // Pulse controller for background aesthetics
  late AnimationController _pulseController;

  final List<Map<String, String>> _goals = [
    {'icon': '🚀', 'title': 'Grow my personal brand', 'desc': 'Create high-impact content to stand out.'},
    {'icon': '📈', 'title': 'Scale client social channels', 'desc': 'Batch process posts for professional clients.'},
    {'icon': '🎨', 'title': 'Design stunning visual assets', 'desc': 'Focus on layout aesthetics and typography.'},
    {'icon': '⚡', 'title': 'Save time with fast editing', 'desc': 'Automate cropping, overlaying and watermark rendering.'},
  ];

  final List<Map<String, String>> _platforms = [
    {'icon': '📱', 'title': 'Short-Form Vertical Feeds', 'desc': 'Optimized for high-energy 9:16 vertical feeds.'},
    {'icon': '📸', 'title': 'Social Reels & Grid', 'desc': 'Focus on beautiful layouts, feeds and stories.'},
    {'icon': '💼', 'title': 'Business & Editorial Posts', 'desc': 'Minimalist, clear educational text and posts.'},
    {'icon': '🌐', 'title': 'Multi-channel syndication', 'desc': 'Adaptive sizes for all social networks.'},
  ];

  final List<Map<String, String>> _experienceLevels = [
    {'title': '🐣 Beginner', 'desc': 'Just starting out, looking for easy template workflows.'},
    {'title': '🚀 Intermediate', 'desc': 'Comfortable with video timelines and cropping structures.'},
    {'title': '👑 Professional', 'desc': 'Require high-performance batch automated processing.'},
  ];

  final List<Map<String, String>> _creativeStyles = [
    {'icon': '💥', 'title': 'High-Energy & Fast Cuts'},
    {'icon': '🎨', 'title': 'Aesthetic, Clean & Minimal'},
    {'icon': '💡', 'title': 'Educational & Subtitled'},
    {'icon': '📊', 'title': 'Corporate & Professional'},
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService().logOnboardingStarted();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _loadTimer?.cancel();
    super.dispose();
  }

  bool get _isLast => _index == 7; // 0: Welcome, 1: Goal, 2: Platform, 3: Exp, 4: Style, 5: Personalizing, 6: Paywall, 7: Final Ready

  Future<void> _finish() async {
    await OnboardingService.setCompleted(true);
    await AnalyticsService().logOnboardingCompleted();
    widget.onFinished?.call();
  }

  void _nextPage() {
    if (_index < 7) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  void _prevPage() {
    if (_index > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  void _selectGoal(String goal) {
    setState(() => _selectedGoal = goal);
    OnboardingService.setGoal(goal);
    Timer(const Duration(milliseconds: 350), _nextPage);
  }

  void _selectPlatform(String platform) {
    setState(() => _selectedPlatform = platform);
    OnboardingService.setPlatform(platform);
    Timer(const Duration(milliseconds: 350), _nextPage);
  }

  void _selectExperience(String exp) {
    setState(() => _selectedExperience = exp);
    OnboardingService.setExperience(exp);
    Timer(const Duration(milliseconds: 350), _nextPage);
  }

  void _selectStyle(String style) {
    setState(() => _selectedStyle = style);
    OnboardingService.setStyle(style);
    Timer(const Duration(milliseconds: 350), () {
      _nextPage();
      _startPersonalizationLoading();
    });
  }

  void _startPersonalizationLoading() {
    _loadTimer?.cancel();
    setState(() {
      _loadProgress = 0.0;
      _loadStatusText = 'Analyzing preferences...';
    });

    final statuses = [
      'Tailoring workspace widgets...',
      'Optimizing hardware render channels...',
      'Setting up automated watermark configs...',
      'Finalizing tailored templates...',
      'Workspace fully personalized! 🎉'
    ];

    int statusIndex = 0;

    _loadTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _loadProgress += 0.025;
        if (_loadProgress >= 1.0) {
          _loadProgress = 1.0;
          _loadStatusText = statuses.last;
          timer.cancel();
          Timer(const Duration(milliseconds: 600), () {
            if (mounted) {
              _nextPage();
            }
          });
        } else {
          int newIndex = ((_loadProgress * statuses.length)).floor().clamp(0, statuses.length - 1);
          if (newIndex != statusIndex) {
            statusIndex = newIndex;
            _loadStatusText = statuses[statusIndex];
          }
        }
      });
    });
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
            // Glowing background aesthetics
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = _pulseController.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -120 + (pulse * 20),
                      right: -120 + (pulse * 20),
                      child: Container(
                        width: 320 + (pulse * 30),
                        height: 320 + (pulse * 30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withOpacity(0.04 + (pulse * 0.03)),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 120 - (pulse * 20),
                      left: -80 - (pulse * 20),
                      child: Container(
                        width: 280 + (pulse * 40),
                        height: 280 + (pulse * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE65100).withOpacity(0.02 + (pulse * 0.02)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Page Contents
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Force user to answer questionnaire or use bottom nav
              onPageChanged: (i) {
                setState(() => _index = i);
                if (i == 5 && (_loadTimer == null || !_loadTimer!.isActive)) {
                  _startPersonalizationLoading();
                }
              },
              children: [
                _buildWelcomeSlide(primary),
                _buildGoalQuestionSlide(primary),
                _buildPlatformQuestionSlide(primary),
                _buildExperienceQuestionSlide(primary),
                _buildStyleQuestionSlide(primary),
                _buildPersonalizationLoadingSlide(primary),
                SubscriptionScreen(
                  skippable: true,
                  onClose: _nextPage,
                ),
                _buildFinalDashboardSlide(primary),
              ],
            ),
            
            // Bottom Glassmorphic Navigation Panel
            if (_index != 5 && _index != 6) // Hide during personalization loading & paywall slides
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: cardBg.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: glassBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          if (_index > 0 && _index != 6) ...[
                            IconButton(
                              onPressed: _prevPage,
                              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
                              tooltip: 'Back',
                            ),
                            const SizedBox(width: 8),
                          ],
                          TextButton(
                            onPressed: () async => await _finish(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text(
                              _index == 6 ? 'Close' : 'Skip',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          
                          // Question steps dots
                          Row(
                            children: List.generate(
                              6,
                              (i) {
                                // Maps questionnaire steps
                                final stepIdx = i >= 5 ? 6 : i;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  height: 6,
                                  width: _index == stepIdx ? 16 : 6,
                                  decoration: BoxDecoration(
                                    color: _index == stepIdx ? primary : AppColors.divider,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              },
                            ),
                          ),
                          const Spacer(),

                          // Primary glowing action
                          GestureDetector(
                            onTap: () async {
                              if (_isLast) {
                                  await _finish();
                                  return;
                              }
                              // Auto progress check for questionnaire pages
                              if (_index == 0) {
                                _nextPage();
                              } else if (_index == 1 && _selectedGoal != null) {
                                _nextPage();
                              } else if (_index == 2 && _selectedPlatform != null) {
                                _nextPage();
                              } else if (_index == 3 && _selectedExperience != null) {
                                _nextPage();
                              } else if (_index == 4 && _selectedStyle != null) {
                                _nextPage();
                                _startPersonalizationLoading();
                              } else if (_index != 5) {
                                // Fallback
                                _nextPage();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primary, primary.withRed(15)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isLast ? 'Get Started' : 'Next',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
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

  // ──────────────────────────────────────────────────────────
  // PAGE 0: Welcome Slide
  // ──────────────────────────────────────────────────────────
  Widget _buildWelcomeSlide(Color primary) {
    return _buildSlideLayout(
      title: 'QuickPost v2.0',
      subtitle: 'Build stunning video templates, customize captions, and automate layouts with raw speed.',
      content: Column(
        children: [
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 120 + (_pulseController.value * 25),
                      height: 120 + (_pulseController.value * 25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primary.withOpacity(0.12), width: 1.5),
                      ),
                    );
                  },
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primary, primary.withRed(15)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, size: 30, color: Colors.white),
                ),
                Positioned(
                  top: 24,
                  left: 28,
                  child: _buildBadgeCard('⚡ Parity Engine', Colors.teal.shade700, Colors.teal.shade50),
                ),
                Positioned(
                  bottom: 24,
                  right: 28,
                  child: _buildBadgeCard('🔒 Privacy First', Colors.indigo.shade700, Colors.indigo.shade50),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const OnboardingBullet(
            icon: Icons.offline_bolt_rounded,
            title: 'No Cloud, Zero Tracking',
            description: 'All processing, databases, and metadata reside locally on your hardware.',
          ),
          const OnboardingBullet(
            icon: Icons.dashboard_customize_rounded,
            title: 'Workspace Tailoring',
            description: 'Help us configure the layout to fit your custom creative requirements.',
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // PAGE 1: Question 1 — Goal Selection
  // ──────────────────────────────────────────────────────────
  Widget _buildGoalQuestionSlide(Color primary) {
    return _buildSlideLayout(
      title: 'What is your primary goal?',
      subtitle: 'This optimizes editor widgets, templates, and timeline presets on your dashboard.',
      content: Column(
        children: _goals.map((g) {
          final active = _selectedGoal == g['title'];
          return _buildQuestionCard(
            active: active,
            icon: Text(g['icon']!, style: const TextStyle(fontSize: 20)),
            title: g['title']!,
            desc: g['desc']!,
            onTap: () => _selectGoal(g['title']!),
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // PAGE 2: Question 2 — Platform Selection
  // ──────────────────────────────────────────────────────────
  Widget _buildPlatformQuestionSlide(Color primary) {
    return _buildSlideLayout(
      title: 'Where do you publish most?',
      subtitle: 'We will preset layout ratios, export resolutions, and tagging catalogs.',
      content: Column(
        children: _platforms.map((p) {
          final active = _selectedPlatform == p['title'];
          return _buildQuestionCard(
            active: active,
            icon: Text(p['icon']!, style: const TextStyle(fontSize: 20)),
            title: p['title']!,
            desc: p['desc']!,
            onTap: () => _selectPlatform(p['title']!),
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // PAGE 3: Question 3 — Experience Level
  // ──────────────────────────────────────────────────────────
  Widget _buildExperienceQuestionSlide(Color primary) {
    return _buildSlideLayout(
      title: 'Your editing experience?',
      subtitle: 'Choose your workflow speed. You can easily adjust this inside your profile settings.',
      content: Column(
        children: _experienceLevels.map((e) {
          final active = _selectedExperience == e['title'];
          return _buildQuestionCard(
            active: active,
            icon: Icon(
              Icons.trending_up_rounded, 
              color: active ? Colors.white : primary,
              size: 20,
            ),
            title: e['title']!,
            desc: e['desc']!,
            onTap: () => _selectExperience(e['title']!),
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // PAGE 4: Question 4 — Preferred Design Style
  // ──────────────────────────────────────────────────────────
  Widget _buildStyleQuestionSlide(Color primary) {
    return _buildSlideLayout(
      title: 'Select your creative style',
      subtitle: 'This will auto-select high-performing caption fonts, neon settings, and shadows.',
      content: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
        ),
        itemCount: _creativeStyles.length,
        itemBuilder: (context, idx) {
          final s = _creativeStyles[idx];
          final active = _selectedStyle == s['title'];
          return GestureDetector(
            onTap: () => _selectStyle(s['title']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: active ? primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? primary.withRed(20) : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: active ? primary.withOpacity(0.15) : Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s['icon']!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 8),
                  Text(
                    s['title']!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      color: active ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // PAGE 5: Personalization Loading Engine
  // ──────────────────────────────────────────────────────────
  Widget _buildPersonalizationLoadingSlide(Color primary) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinning Glowing Ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: _loadProgress,
                      strokeWidth: 5,
                      color: primary,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  Icon(Icons.brush_rounded, color: primary, size: 36),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                'Personalizing Workspace',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _loadStatusText,
                  key: ValueKey(_loadStatusText),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // PAGE 6: Final Ready Slide (Summary)
  // ──────────────────────────────────────────────────────────
  Widget _buildFinalDashboardSlide(Color primary) {
    return _buildSlideLayout(
      title: 'Workspace Personalized!',
      subtitle: 'Your editing pipeline, caption assets, and automation setups are ready for use.',
      content: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Tailored Configuration Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSummaryLine('Goal Style', _selectedGoal ?? 'Visual Asset Designs'),
                _buildSummaryLine('Primary Platform', _selectedPlatform ?? 'Social Reels & Grid'),
                _buildSummaryLine('Workflow speed', _selectedExperience ?? 'Intermediate Workflows'),
                _buildSummaryLine('Selected theme preset', _selectedStyle ?? 'Aesthetic & Minimal'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const OnboardingBullet(
            icon: Icons.speed_rounded,
            title: 'GPU Accelerated Processing',
            description: 'Your native Android hardware renderers are fully configured.',
          ),
          const OnboardingBullet(
            icon: Icons.workspace_premium_rounded,
            title: 'Features 100% Unlocked',
            description: 'All watermark presets, subtitle tools, and libraries are ready to roll.',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String title, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // UNIVERSAL SLIDE LAYOUT WRAPPER
  // ──────────────────────────────────────────────────────────
  Widget _buildSlideLayout({
    required String title,
    required String subtitle,
    required Widget content,
  }) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard({
    required bool active,
    required Widget icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
    required Color primary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active ? primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? primary.withRed(20) : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: active ? primary.withOpacity(0.12) : Colors.black.withOpacity(0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: active ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: active ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 9,
          fontFamily: 'Poppins',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class OnboardingBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const OnboardingBullet({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
