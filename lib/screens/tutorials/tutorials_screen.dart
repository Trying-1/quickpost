import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../home/home_shell_screen.dart';

class TutorialsScreen extends StatefulWidget {
  const TutorialsScreen({super.key});

  @override
  State<TutorialsScreen> createState() => _TutorialsScreenState();
}

class _TutorialsScreenState extends State<TutorialsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'QuickPost Academy 🎓',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Core Tools'),
            Tab(text: 'Pro Workflows'),
            Tab(text: 'FAQ & Tips'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoreToolsTab(primary),
          _buildProWorkflowsTab(primary),
          _buildFaqTab(primary),
        ],
      ),
    );
  }

  Widget _buildCoreToolsTab(Color primary) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _buildYouTubeHeader(),
        _buildGuideCard(
          title: '🎬 Master Video Cropping',
          description: 'Optimizing standard horizontal videos into high-retention 9:16 vertical clips.',
          steps: [
            'Tap the Video Cropper card on the Dashboard to select a video.',
            'Choose the target aspect ratio (9:16 for Reels/Shorts, 1:1 for posts).',
            'Drag and adjust the bounding crop box to frame active speakers.',
            'Hit Export to run lightning-fast hardware accelerated rendering.'
          ],
          ctaText: 'Try Cropper Now ⚡',
          tabIndex: 0,
          color: Colors.teal,
        ),
        const SizedBox(height: 20),
        _buildGuideCard(
          title: '🔒 Branding & Watermarks',
          description: 'How to overlay professional watermarks to protect your copyright.',
          steps: [
            'Open the Watermarker from the dashboard grid.',
            'Configure your brand text or upload a custom translucent PNG logo.',
            'Scale and drag the overlay to any corner (e.g. top-right).',
            'Set opacity to 0.2 to protect content without obstructing views.'
          ],
          ctaText: 'Open Watermarker 🎨',
          tabIndex: 1,
          color: Colors.blueAccent,
        ),
        const SizedBox(height: 20),
        _buildGuideCard(
          title: '🎨 Post Maker templates',
          description: 'Designing beautiful social media grid templates and layout collages.',
          steps: [
            'Launch the Post Maker Studio from the home dashboard.',
            'Browse our collection of curated grid and collage layouts.',
            'Import your photos and pinch to scale within template frames.',
            'Apply rounded corners, set margins, and save to gallery.'
          ],
          ctaText: 'Launch Post Maker 📸',
          tabIndex: 4,
          color: Colors.purpleAccent,
        ),
      ],
    );
  }

  Widget _buildProWorkflowsTab(Color primary) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _buildYouTubeHeader(),
        _buildGuideCard(
          title: '⚡ High-Speed Batch Automation',
          description: 'Process hundreds of social media posts concurrently on GPU.',
          steps: [
            'Open Batch Automation from the tools dashboard.',
            'Choose your target templates, watermark configs, or text designs.',
            'Queue multiple videos/images simultaneously from your folders.',
            'Tap Execute Pipeline to process all items concurrently.'
          ],
          ctaText: 'Start Automation ⚡',
          tabIndex: 10,
          color: primary,
        ),
        const SizedBox(height: 20),
        _buildGuideCard(
          title: '📝 Styled Text & Font Overlays',
          description: 'Injecting dynamic floating subtitle containers and caption assets.',
          steps: [
            'Launch the Video Text Overlay tool.',
            'Type custom hooks, pick visual text layout shapes.',
            'Select premium typography fonts (Outfit, Poppins, etc.)',
            'Define duration timing layers and trigger high-speed renders.'
          ],
          ctaText: 'Open Text Editor ✍️',
          tabIndex: 3,
          color: Colors.orangeAccent,
        ),
        const SizedBox(height: 20),
        _buildGuideCard(
          title: '🎵 Asset & SFX Library Management',
          description: 'Organizing background assets, sound effects, and audio directories.',
          steps: [
            'Access My Audios from the dashboard grid.',
            'Create organized audio directories (e.g., Hooks, Intro SFX).',
            'Upload custom audio files or download trending preset clips.',
            'Quick-link sound effects during your editing process.'
          ],
          ctaText: 'Open Audio Vault 🎵',
          tabIndex: 9,
          color: Colors.green.shade700,
        ),
      ],
    );
  }

  Widget _buildFaqTab(Color primary) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '💡 CREATIVE SECRETS',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        _buildFaqCard(
          q: 'How do I maximize my Reels reach?',
          a: 'Always use vertical 9:16 aspect ratios. The Instagram and TikTok algorithms heavily deprioritize horizontal views. Keep your hook text visible in the top third of the frame.',
        ),
        const SizedBox(height: 12),
        _buildFaqCard(
          q: 'Why should I use low watermark opacity?',
          a: 'A high opacity watermark makes clips feel like cheap stock assets. Drop opacity to 15-20% and use neutral white or light grey colors to stay professional while securing your IP.',
        ),
        const SizedBox(height: 12),
        _buildFaqCard(
          q: 'Where are my exported files saved?',
          a: 'All crops and designs are written directly to your device gallery under the "QuickPost" album for offline, high-fidelity security.',
        ),
        const SizedBox(height: 12),
        _buildFaqCard(
          q: 'Does batch processing degrade video quality?',
          a: 'No! QuickPost utilizes your device\'s native OpenGL / MediaCodec hardware rendering pipeline, preserving 100% of your source video\'s bitrate and color accuracy.',
        ),
      ],
    );
  }

  Widget _buildGuideCard({
    required String title,
    required String description,
    required List<String> steps,
    required String ctaText,
    required int tabIndex,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with visual indicator
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STEPS TO EXECUTE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...steps.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final text = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$idx',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                
                ElevatedButton(
                  onPressed: () {
                    // Navigate to appropriate tab inside HomeShellScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomeShellScreen(
                          initialIndex: tabIndex,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    ctaText,
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCard({required String q, required String a}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help_outline_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              a,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYouTubeHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchYouTube('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF1744),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Watch Masterclass Video 🎥',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFFB71C1C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Learn high-conversion editing strategies in our 5-minute video guide.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Color(0xFFD32F2F),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.open_in_new_rounded, color: Color(0xFFFF1744), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchYouTube(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}
