import 'package:flutter/material.dart';
import '../video_text_overlay/video_text_overlay_screen.dart';
import '../video_cropper/video_cropper_screen.dart';
import '../image_post/post_maker_screen.dart';
import '../image_post/post_maker_templates_screen.dart';
import '../image_cropper/image_cropper_screen.dart';
import '../video_creator/video_creator_screen.dart';
import '../audio_library/audio_library_screen_with_folders.dart';
import '../text_box_overlay/text_box_overlay_screen.dart';
import '../profile/profile_screen.dart';
import '../arise_automation/arise_automation_screen.dart';
import '../caption_store/caption_store_screen.dart';
import '../quotes/my_quotes_screen.dart';
import '../video_watermark/video_watermark_screen.dart';
import '../../config/app_theme.dart';
import '../../services/analytics_service.dart';
import '../opengl_watermark/opengl_watermark_screen.dart';
class HomeShellScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final String? sharedPurpose;

  static final GlobalKey<_HomeShellScreenState> shellKey = GlobalKey<_HomeShellScreenState>();

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

  HomeShellScreen({
    Key? key,
    this.sharedImagePaths,
    this.sharedPurpose,
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
    debugPrint('[HomeShellScreen] state.navigateToTab called: index=$index, paths=$paths');
    setState(() {
      _currentBottomNavIndex = index;
      if (paths != null) {
        _currentPaths = List.from(paths);
        debugPrint('[HomeShellScreen] _currentPaths updated to: $_currentPaths');
      }
      if (purpose != null) {
        _currentPurpose = purpose;
        debugPrint('[HomeShellScreen] _currentPurpose updated to: $_currentPurpose');
      }
      _stackKey = UniqueKey();
      debugPrint('[HomeShellScreen] _stackKey refreshed to force child rebuild');
    });
  }

  void _handleSharedImages() {
    final purpose = _currentPurpose;
    final paths = _currentPaths;

    if (paths == null || paths.isEmpty) return;

    setState(() {
      switch (purpose) {
        case 'video_cropper':
          _currentBottomNavIndex = 0;
          break;
        case 'watermark':
          _currentBottomNavIndex = 1;
          break;
        case 'captions':
          _currentBottomNavIndex = 2;
          break;
        case 'video_text':
          _currentBottomNavIndex = 3;
          break;
        case 'single_image_post':
          _currentBottomNavIndex = 4;
          break;
        case 'cropper':
          _currentBottomNavIndex = 6; 
          break;
        case 'video_fade_in':
        case 'video_zoom_in':
          _currentBottomNavIndex = 7;
          break;
        case 'text_box':
          _currentBottomNavIndex = 8;
          break;
        case 'automation':
          _currentBottomNavIndex = 10;
          break;
        default:
          _currentBottomNavIndex = 0;
          break;
      }
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
          children: [
            VideoCropperScreen(sharedVideoPaths: _currentBottomNavIndex == 0 ? _currentPaths : null, isActive: _currentBottomNavIndex == 0),
            VideoWatermarkScreen(sharedVideoPaths: _currentBottomNavIndex == 1 ? _currentPaths : null, isActive: _currentBottomNavIndex == 1),
            const CaptionStoreScreen(),
            VideoTextOverlayScreen(sharedVideoPaths: _currentBottomNavIndex == 3 ? _currentPaths : null, isActive: _currentBottomNavIndex == 3),
            _buildPostMakerTab(),
            const MyQuotesScreen(),
            ImageCropperScreen(sharedImagePaths: _currentBottomNavIndex == 6 ? _currentPaths : null),
            VideoCreatorScreen(sharedImagePaths: _currentBottomNavIndex == 7 ? _currentPaths : null, sharedPurpose: _currentPurpose),
            TextBoxOverlayScreen(sharedImagePaths: _currentBottomNavIndex == 8 ? _currentPaths : null, isActive: _currentBottomNavIndex == 8),
            AudioLibraryScreenWithFolders(isActive: _currentBottomNavIndex == 9),
            AriseAutomationScreen(sharedPaths: _currentBottomNavIndex == 10 ? _currentPaths : null, sharedPurpose: _currentPurpose),
            const ProfileScreen(),
            OpenglWatermarkScreen(sharedVideoPaths: _currentBottomNavIndex == 12 ? _currentPaths : null, isActive: _currentBottomNavIndex == 12),
          ],
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
                  children: [
            _buildNavItem(0, Icons.video_library, 'Video Cropper'),
            _buildNavItem(1, Icons.branding_watermark, 'Watermark'),
            _buildNavItem(2, Icons.closed_caption, 'Captions'),
            _buildNavItem(3, Icons.movie_filter, 'Video Text'),
            _buildNavItem(4, Icons.create, 'Post Maker'),
            _buildNavItem(5, Icons.format_quote, 'My Quotes'),
            _buildNavItem(6, Icons.crop, 'Image Cropper'),
            _buildNavItem(7, Icons.video_call, 'Image to Video'),
            _buildNavItem(8, Icons.text_fields, 'Text Box'),
            _buildNavItem(9, Icons.library_music, 'My Audios'),
            _buildNavItem(10, Icons.auto_awesome, 'Automation'),
            _buildNavItem(11, Icons.person, 'Profile'),
            _buildNavItem(12, Icons.layers, 'GL Watermark'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostMakerTab() {
    final paths = _currentBottomNavIndex == 4 ? _currentPaths : null;
    final purpose = _currentBottomNavIndex == 4 ? _currentPurpose : null;

    // When the app is opened via share intent or deep link with images,
    // route into the appropriate post maker template via PostMakerScreen.
    if (purpose == 'post_maker_templates') {
      return PostMakerTemplatesScreen(sharedImagePaths: paths);
    }

    if (paths != null && paths.isNotEmpty) {
      return PostMakerScreen(
        sharedImagePaths: paths,
        sharedPurpose: purpose,
      );
    }

    // Normal in-app usage: show the template picker grid.
    return const PostMakerTemplatesScreen();
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentBottomNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentBottomNavIndex = index;
        });
        
        // Log screen view
        final screenNames = [
          'Video Cropper', 'Watermark', 'Captions', 'Video Text', 
          'Post Maker', 'My Quotes', 'Image Cropper', 'Image to Video', 
          'Text Box', 'My Audios', 'Automation', 'Profile', 'GL Watermark'
        ];
        if (index < screenNames.length) {
          AnalyticsService().setCurrentScreen(screenName: screenNames[index]);
        }
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
