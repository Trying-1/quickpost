import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../config/app_theme.dart';
import '../../services/onboarding_service.dart';
import '../../services/analytics_service.dart';
import '../../services/watermark_preset_service.dart';
import '../../services/caption_backup_service.dart';
import 'home_shell_screen.dart';
import '../tutorials/tutorials_screen.dart';
import '../subscription/subscription_screen.dart';
import '../../services/subscription_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _platform = MethodChannel('com.quickpost.app/processor');

  String? _goal;
  String? _targetPlatform;
  String? _experience;
  String? _style;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPersonalizationData();
    AnalyticsService().setCurrentScreen(screenName: 'Dashboard Home');
  }

  Future<void> _loadPersonalizationData() async {
    try {
      final goal = await OnboardingService.getGoal();
      final plat = await OnboardingService.getPlatform();
      final exp = await OnboardingService.getExperience();
      final style = await OnboardingService.getStyle();

      if (mounted) {
        setState(() {
          _goal = goal;
          _targetPlatform = plat;
          _experience = exp;
          _style = style;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading personalization data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    final primaryDark = AppColors.primaryDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header Section ───
                _buildHeader(primary),
                const SizedBox(height: 20),

                // ─── Personalization Config Badges ───
                if (!_isLoading) _buildPersonalizationBadges(primary),
                const SizedBox(height: 24),

                // ─── Academy / Learn to Create ───
                _buildAcademyBanner(context, primary),
                const SizedBox(height: 24),

                // ─── Creative Tips Carousel ───
                _buildTipsSection(primary),
                const SizedBox(height: 24),

                // ─── Quick Import Shortcuts ───
                _buildQuickImportButtons(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── UI Helper Widgets ───

  Widget _buildHeader(Color primary) {
    final now = DateTime.now();
    final dateString = '${_getMonthName(now.month)} ${now.day}, ${now.year}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateString.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Creative Dashboard',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                ).then((_) => setState(() {}));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: SubscriptionService.isProActive
                        ? [Colors.teal, Colors.tealAccent.shade400]
                        : [Colors.amber, Colors.orangeAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (SubscriptionService.isProActive ? Colors.teal : Colors.amber).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      SubscriptionService.isProActive ? Icons.workspace_premium_rounded : Icons.workspace_premium_rounded,
                      color: Colors.black,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      SubscriptionService.isProActive ? 'PRO ACTIVE 💎' : 'GO PRO 👑',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeShellScreen(
                      initialTabId: 'profile',
                    ),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonalizationBadges(Color primary) {
    final badges = <String>[];
    if (_targetPlatform != null) {
      badges.add('📱 ${_targetPlatform!.replaceAll('📱 ', '').replaceAll('📸 ', '').replaceAll('💼 ', '').replaceAll('🌐 ', '')}');
    }
    if (_style != null) {
      badges.add('🎨 ${_style!.replaceAll('💥 ', '').replaceAll('🎨 ', '').replaceAll('💡 ', '').replaceAll('📊 ', '')}');
    }
    if (_experience != null) {
      badges.add('👑 ${_experience!.replaceAll('🐣 ', '').replaceAll('🚀 ', '').replaceAll('👑 ', '')}');
    }

    if (badges.isEmpty) {
      badges.add('⚡ Tailored Workspace Active');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: badges.map((badge) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withOpacity(0.12), width: 1.2),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: primary,
                letterSpacing: 0.2,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTipsSection(Color primary) {
    final tips = [
      {
        'title': 'Viral Reach Strategy',
        'desc': '9:16 vertical templates significantly maximize user retention rates on TikTok and Reels algorithms.',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF00796B),
      },
      {
        'title': 'Branding Protection',
        'desc': 'Utilize the watermarker tool with subtle 0.2 opacity settings to safeguard assets without hiding core details.',
        'icon': Icons.verified_user_rounded,
        'color': const Color(0xFF0D47A1),
      },
      {
        'title': 'High Fidelity Audios',
        'desc': 'Bundle your trending sound effects in the special audio library for rapid timeline editing selection.',
        'icon': Icons.audiotrack_rounded,
        'color': const Color(0xFFE65100),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💡 CREATOR TIPS',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 115,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: tips.length,
            itemBuilder: (context, idx) {
              final tip = tips[idx];
              final tipColor = tip['color'] as Color;
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tipColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tip['icon'] as IconData, color: tipColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip['title'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              tip['desc'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }



  Widget _buildAcademyBanner(BuildContext context, Color primary) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TutorialsScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, primary.withRed(15).withBlue(10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              '🎓  CREATOR ACADEMY',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                fontFamily: 'Poppins',
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Unlock Pro Editing Skills 🚀',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Master video cropping, watermarking & GPU batch automation pipelines.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_rounded, color: primary, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Simple Quick Import Buttons ───

  Widget _buildQuickImportButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _quickImportCaptions,
            icon: const Icon(Icons.subtitles_rounded, size: 16),
            label: const Text('Import Captions', style: TextStyle(fontSize: 12, fontFamily: 'Poppins')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.divider),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _quickImportWatermarkPresets,
            icon: const Icon(Icons.branding_watermark_rounded, size: 16),
            label: const Text('Import Watermarks', style: TextStyle(fontSize: 12, fontFamily: 'Poppins')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.divider),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _quickImportCaptions() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || result.files.isEmpty || result.files.single.path == null) return;
      final res = await CaptionBackupService.importCaptionStoreFromFile(result.files.single.path!, replaceExisting: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported ${res.importedCount} captions!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _quickImportWatermarkPresets() async {
    try {
      final String? json = await _platform.invokeMethod('importPresets');
      if (json != null && json.isNotEmpty) {
        final int count = await WatermarkPresetService.importPresetsJson(json);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count watermark presets!')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }



  String _getMonthName(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }
}


