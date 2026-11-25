import 'package:flutter/material.dart';
import '../video_text_overlay/video_text_overlay_screen.dart';
import '../video_cropper/video_cropper_screen.dart';
import '../image_post/post_maker_screen.dart';
import '../image_post/post_maker_templates_screen.dart';
import '../image_post/image_post_maker_screen.dart';
import '../anime_post/anime_post_maker_screen.dart';
import '../carousel_post/carousel_post_maker_screen.dart';
import '../image_cropper/image_cropper_screen.dart';
import '../video_creator/video_creator_screen.dart';
import '../audio_library/audio_library_screen_with_folders.dart';
import '../text_box_overlay/text_box_overlay_screen.dart';
import '../profile/profile_screen.dart';
import '../mediapadding_automation/automation_screen.dart';
import '../caption_store/caption_store_screen.dart';
import '../quotes/my_quotes_screen.dart';
import '../video_watermark/video_watermark_screen.dart';
import '../cover_image/cover_image_screen.dart';
import '../font_library/font_library_screen.dart';
import '../../config/app_theme.dart';
import '../../services/analytics_service.dart';
import '../background_remover/background_remover_screen.dart';
import '../more_tools/more_tools_screen.dart';
import 'home_screen.dart';

/// Descriptor for tabs hosted inside [HomeShellScreen].
class HomeShellTab {
  final String id;
  final String label;
  final IconData icon;
  final List<String> supportedPurposes;
  final Widget Function(
    BuildContext context, {
    List<String>? paths,
    String? purpose,
    bool isActive,
  }) builder;

  const HomeShellTab({
    required this.id,
    required this.label,
    required this.icon,
    this.supportedPurposes = const [],
    required this.builder,
  });
}

class HomeShellScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final String? sharedPurpose;
  final int initialIndex;
  final String? initialTabId;

  static final GlobalKey<_HomeShellScreenState> shellKey = GlobalKey<_HomeShellScreenState>();

  /// All content creation & editing feature tabs.
  /// Any new feature added here will automatically appear before the trailing Profile tab.
  static final List<HomeShellTab> featureTabs = [
    HomeShellTab(
      id: 'dashboard',
      label: 'Dashboard',
      icon: Icons.dashboard,
      builder: (context, {paths, purpose, isActive = false}) => const HomeScreen(),
    ),
    HomeShellTab(
      id: 'video_cropper',
      label: 'Video Cropper',
      icon: Icons.video_library,
      supportedPurposes: ['video_cropper'],
      builder: (context, {paths, purpose, isActive = false}) =>
          VideoCropperScreen(sharedVideoPaths: paths, isActive: isActive),
    ),
    HomeShellTab(
      id: 'watermark',
      label: 'Watermark',
      icon: Icons.branding_watermark,
      supportedPurposes: ['watermark'],
      builder: (context, {paths, purpose, isActive = false}) =>
          VideoWatermarkScreen(sharedVideoPaths: paths, isActive: isActive),
    ),
    HomeShellTab(
      id: 'captions',
      label: 'Captions',
      icon: Icons.closed_caption,
      supportedPurposes: ['captions'],
      builder: (context, {paths, purpose, isActive = false}) => const CaptionStoreScreen(),
    ),
    HomeShellTab(
      id: 'anime_post_maker',
      label: 'Anime Post',
      icon: Icons.auto_awesome_motion,
      supportedPurposes: ['anime_post_maker'],
      builder: (context, {paths, purpose, isActive = false}) =>
          AnimePostMakerScreen(sharedImagePaths: paths),
    ),
    HomeShellTab(
      id: 'video_text',
      label: 'Video Text',
      icon: Icons.movie_filter,
      supportedPurposes: ['video_text'],
      builder: (context, {paths, purpose, isActive = false}) =>
          VideoTextOverlayScreen(sharedVideoPaths: paths, isActive: isActive),
    ),
    HomeShellTab(
      id: 'post_maker',
      label: 'Post Maker',
      icon: Icons.create,
      supportedPurposes: ['single_image_post', 'post_maker_templates'],
      builder: (context, {paths, purpose, isActive = false}) {
        if (purpose == 'post_maker_templates') {
          return PostMakerTemplatesScreen(sharedImagePaths: paths);
        }
        if (paths != null && paths.isNotEmpty) {
          return PostMakerScreen(
            sharedImagePaths: paths,
            sharedPurpose: purpose,
          );
        }
        return const PostMakerTemplatesScreen();
      },
    ),
    HomeShellTab(
      id: 'my_quotes',
      label: 'My Quotes',
      icon: Icons.format_quote,
      builder: (context, {paths, purpose, isActive = false}) => const MyQuotesScreen(),
    ),
    HomeShellTab(
      id: 'image_cropper',
      label: 'Image Cropper',
      icon: Icons.crop,
      supportedPurposes: ['cropper'],
      builder: (context, {paths, purpose, isActive = false}) =>
          ImageCropperScreen(sharedImagePaths: paths),
    ),
    HomeShellTab(
      id: 'video_creator',
      label: 'Image to Video',
      icon: Icons.video_call,
      supportedPurposes: ['video_fade_in', 'video_zoom_in'],
      builder: (context, {paths, purpose, isActive = false}) =>
          VideoCreatorScreen(sharedImagePaths: paths, sharedPurpose: purpose),
    ),
    HomeShellTab(
      id: 'text_box',
      label: 'Text Box',
      icon: Icons.text_fields,
      supportedPurposes: ['text_box'],
      builder: (context, {paths, purpose, isActive = false}) =>
          TextBoxOverlayScreen(sharedImagePaths: paths, isActive: isActive),
    ),
    HomeShellTab(
      id: 'audio_library',
      label: 'My Audios',
      icon: Icons.library_music,
      builder: (context, {paths, purpose, isActive = false}) =>
          AudioLibraryScreenWithFolders(isActive: isActive),
    ),
    HomeShellTab(
      id: 'media_padding',
      label: 'Media Padding',
      icon: Icons.auto_awesome,
      supportedPurposes: ['media_padding', 'automation'],
      builder: (context, {paths, purpose, isActive = false}) =>
          AriseAutomationScreen(sharedPaths: paths, sharedPurpose: purpose),
    ),
    HomeShellTab(
      id: 'cover_image',
      label: 'Cover Image',
      icon: Icons.image,
      builder: (context, {paths, purpose, isActive = false}) => const CoverImageScreen(),
    ),
    HomeShellTab(
      id: 'image_post_maker',
      label: 'Image Post',
      icon: Icons.add_photo_alternate,
      supportedPurposes: ['image_post_maker'],
      builder: (context, {paths, purpose, isActive = false}) =>
          ImagePostMakerScreen(sharedImagePaths: paths),
    ),
    HomeShellTab(
      id: 'carousel_post_maker',
      label: 'Carousel Post',
      icon: Icons.view_carousel_rounded,
      supportedPurposes: ['carousel_post_maker'],
      builder: (context, {paths, purpose, isActive = false}) =>
          CarouselPostMakerScreen(sharedImagePaths: paths, isActive: isActive),
    ),
    HomeShellTab(
      id: 'font_library',
      label: 'My Fonts',
      icon: Icons.font_download,
      builder: (context, {paths, purpose, isActive = false}) =>
          FontLibraryScreen(isActive: isActive),
    ),
    HomeShellTab(
      id: 'background_remover',
      label: 'BG Remover',
      icon: Icons.layers_clear,
      builder: (context, {paths, purpose, isActive = false}) =>
          BackgroundRemoverScreen(sharedImagePaths: paths),
    ),
  ];

  /// Dedicated More Tools tab for utilities, creative helpers, and misc micro-features.
  static final HomeShellTab moreToolsTab = HomeShellTab(
    id: 'more_tools',
    label: 'More Tools',
    icon: Icons.grid_view_rounded,
    supportedPurposes: ['more_tools'],
    builder: (context, {paths, purpose, isActive = false}) => const MoreToolsScreen(),
  );

  /// Dedicated Profile tab definition.
  static final HomeShellTab profileTab = HomeShellTab(
    id: 'profile',
    label: 'Profile',
    icon: Icons.person,
    builder: (context, {paths, purpose, isActive = false}) => const ProfileScreen(),
  );

  /// Dynamically assembled tabs.
  /// GUARANTEE: [moreToolsTab] is placed right before [profileTab], and [profileTab]
  /// is ALWAYS dynamically anchored as the very last tab.
  static List<HomeShellTab> get tabs => [
    ...featureTabs,
    moreToolsTab,
    profileTab,
  ];

  /// Dynamic index of the Profile tab (always guaranteed to be tabs.length - 1).
  static int get profileTabIndex => tabs.length - 1;

  /// Helper to lookup index by tab id (e.g. 'profile', 'text_box', 'watermark').
  static int indexOfTab(String id) => tabs.indexWhere((t) => t.id == id);

  static void navigateToTab(int index, {List<String>? paths, String? purpose}) {
    debugPrint('[HomeShellScreen] navigateToTab called: index=$index, paths=$paths, purpose=$purpose');
    final state = shellKey.currentState;
    if (state != null) {
      debugPrint('[HomeShellScreen] State found via GlobalKey, calling state.navigateToTab');
      state.navigateToTab(index, paths: paths, purpose: purpose);
    } else {
      debugPrint('[HomeShellScreen] ERROR: GlobalKey state is null. currentState is not available.');
    }
  }

  static void navigateToTabId(String id, {List<String>? paths, String? purpose}) {
    final idx = indexOfTab(id);
    if (idx != -1) {
      navigateToTab(idx, paths: paths, purpose: purpose);
    }
  }

  HomeShellScreen({
    Key? key,
    this.sharedImagePaths,
    this.sharedPurpose,
    this.initialIndex = 0,
    this.initialTabId,
  }) : super(key: key ?? shellKey);

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentBottomNavIndex = 0;
  DateTime? _lastBackPressTime;
  List<String>? _currentPaths;
  String? _currentPurpose;
  Key _stackKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialTabId != null) {
      final idx = HomeShellScreen.indexOfTab(widget.initialTabId!);
      _currentBottomNavIndex = idx != -1 ? idx : widget.initialIndex;
    } else {
      _currentBottomNavIndex = widget.initialIndex;
    }
    _currentPaths = widget.sharedImagePaths;
    _currentPurpose = widget.sharedPurpose;
    if (_currentPaths != null && _currentPaths!.isNotEmpty) {
      _handleSharedImages();
    }
  }

  @override
  void didUpdateWidget(covariant HomeShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPaths = oldWidget.sharedImagePaths;
    final newPaths = widget.sharedImagePaths;
    final oldPurpose = oldWidget.sharedPurpose;
    final newPurpose = widget.sharedPurpose;

    if (newPaths != null && newPaths.isNotEmpty) {
      final bool wasEmptyBefore = oldPaths == null || oldPaths.isEmpty;
      final bool lengthChanged = oldPaths == null || oldPaths.length != newPaths.length;
      final bool firstChanged = oldPaths == null || oldPaths.isEmpty || oldPaths.first != newPaths.first;
      final bool purposeChanged = oldPurpose != newPurpose;

      if (wasEmptyBefore || lengthChanged || firstChanged || purposeChanged) {
        setState(() {
          _currentPaths = newPaths;
          _currentPurpose = newPurpose;
          _stackKey = UniqueKey();
        });
        _handleSharedImages();
      }
    }
  }

  void navigateToTab(int index, {List<String>? paths, String? purpose}) {
    int targetIndex = index;
    if (purpose != null) {
      final matchedIndex = HomeShellScreen.tabs.indexWhere(
        (t) => t.supportedPurposes.contains(purpose) || t.id == purpose,
      );
      if (matchedIndex != -1) {
        targetIndex = matchedIndex;
      }
    }

    if (targetIndex < 0 || targetIndex >= HomeShellScreen.tabs.length) {
      targetIndex = 0;
    }

    debugPrint('[HomeShellScreen] state.navigateToTab resolved: index=$targetIndex, paths=$paths');
    setState(() {
      _currentBottomNavIndex = targetIndex;
      if (paths != null) {
        _currentPaths = List.from(paths);
      }
      if (purpose != null) {
        _currentPurpose = purpose;
      }
      _stackKey = UniqueKey();
      debugPrint('[HomeShellScreen] _stackKey refreshed to force child rebuild');
    });
  }

  void _handleSharedImages() {
    final purpose = _currentPurpose;
    final paths = _currentPaths;

    if (paths == null || paths.isEmpty) return;

    final matchedIndex = HomeShellScreen.tabs.indexWhere(
      (t) => t.supportedPurposes.contains(purpose) || t.id == purpose,
    );

    setState(() {
      _currentBottomNavIndex = matchedIndex != -1 ? matchedIndex : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[HomeShellScreen] build called with _currentBottomNavIndex=$_currentBottomNavIndex');
    return WillPopScope(
      onWillPop: () async {
        // If not on the first tab, go back to the main tab instead of exiting
        if (_currentBottomNavIndex != 0) {
          setState(() {
            _currentBottomNavIndex = 0;
          });
          return false;
        }

        // On first tab: require double-back within 2 seconds to exit
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
          return false;
        }

        return true; // allow app exit
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: IndexedStack(
          key: _stackKey,
          index: _currentBottomNavIndex,
          children: HomeShellScreen.tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            final isActive = _currentBottomNavIndex == index;
            return tab.builder(
              context,
              paths: isActive ? _currentPaths : null,
              purpose: isActive ? _currentPurpose : null,
              isActive: isActive,
            );
          }).toList(),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Navigation Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: HomeShellScreen.tabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tab = entry.value;
                    return _buildNavItem(index, tab.icon, tab.label);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentBottomNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentBottomNavIndex = index;
        });
        
        // Log screen view dynamically from label
        AnalyticsService().setCurrentScreen(screenName: label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.grey[600],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
