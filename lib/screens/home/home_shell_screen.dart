import 'package:flutter/material.dart';
import '../image_post/post_maker_screen.dart';
import '../image_cropper/image_cropper_screen.dart';
import '../video_creator/video_creator_screen.dart';
import '../audio_extraction/audio_extraction_screen.dart';
import '../audio_library/audio_library_screen_with_folders.dart';
import '../text_box_overlay/text_box_overlay_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/ad_banner_widget.dart';

class HomeShellScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final String? sharedPurpose;

  const HomeShellScreen({
    super.key,
    this.sharedImagePaths,
    this.sharedPurpose,
  });

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentBottomNavIndex = 0;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    // Handle shared images if provided at startup
    if (widget.sharedImagePaths != null && widget.sharedImagePaths!.isNotEmpty) {
      _handleSharedImages();
    }
  }

  @override
  void didUpdateWidget(covariant HomeShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPaths = oldWidget.sharedImagePaths;
    final newPaths = widget.sharedImagePaths;

    // When new shared images arrive from ShareIntentHandler, route to the correct tab
    if (newPaths != null && newPaths.isNotEmpty) {
      final bool wasEmptyBefore = oldPaths == null || oldPaths.isEmpty;
      final bool lengthChanged = oldPaths == null || oldPaths.length != newPaths.length;
      final bool firstChanged = oldPaths == null || oldPaths.isEmpty || oldPaths.first != newPaths.first;

      if (wasEmptyBefore || lengthChanged || firstChanged) {
        _handleSharedImages();
      }
    }
  }

  void _handleSharedImages() {
    final purpose = widget.sharedPurpose;
    final paths = widget.sharedImagePaths;

    if (paths == null || paths.isEmpty) return;

    // Route to appropriate screen based on purpose
    setState(() {
      switch (purpose) {
        case 'single_image_post':
          _currentBottomNavIndex = 0; // Post Maker
          break;
        case 'video_fade_in':
          _currentBottomNavIndex = 2; // Video Creator (fade-in template)
          break;
        case 'video_zoom_in':
          _currentBottomNavIndex = 2; // Video Creator (plain/zoom template)
          break;
        default:
          _currentBottomNavIndex = 0;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          index: _currentBottomNavIndex,
          children: [
            PostMakerScreen(sharedImagePaths: widget.sharedImagePaths, sharedPurpose: widget.sharedPurpose),
            ImageCropperScreen(sharedImagePaths: widget.sharedImagePaths),
            VideoCreatorScreen(sharedImagePaths: widget.sharedImagePaths, sharedPurpose: widget.sharedPurpose),
            const TextBoxOverlayScreen(),
            const AudioLibraryScreenWithFolders(),
            const ProfileScreen(),
          ],
        ),
        floatingActionButton: _currentBottomNavIndex == 4
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AudioExtractionScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Extract New'),
                backgroundColor: Colors.purple,
              )
            : null,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner Ad
            const AdBannerWidget(screenName: 'post_maker'),
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
                    _buildNavItem(0, Icons.create, 'Post Maker'),
                    _buildNavItem(1, Icons.crop, 'Image Cropper'),
                    _buildNavItem(2, Icons.video_call, 'Image to Video'),
                    _buildNavItem(3, Icons.text_fields, 'Text Box'),
                    _buildNavItem(4, Icons.library_music, 'My Audios'),
                    _buildNavItem(5, Icons.person, 'Profile'),
                  ],
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
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.purple : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.purple : Colors.grey[600],
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
