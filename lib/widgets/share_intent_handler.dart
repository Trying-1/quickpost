import 'package:flutter/material.dart';
import '../services/share_intent_service.dart';

/// Widget to handle shared images and show options to user
class ShareIntentHandler extends StatefulWidget {
  final Widget child;
  final Function(List<String> imagePaths, String purpose) onImagesSelected;

  const ShareIntentHandler({
    Key? key,
    required this.child,
    required this.onImagesSelected,
  }) : super(key: key);

  @override
  State<ShareIntentHandler> createState() => _ShareIntentHandlerState();
}

class _ShareIntentHandlerState extends State<ShareIntentHandler> {
  @override
  void initState() {
    super.initState();
    _initializeShareIntent();
  }

  Future<void> _initializeShareIntent() async {
    // 1) Check for any pending shared images on app startup (cold start)
    final (sharedImages, purpose) = await ShareIntentService.getSharedImages();
    if (mounted && sharedImages.isNotEmpty) {
      // Defer UI work until after first frame so context is fully ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (purpose != null && purpose.isNotEmpty) {
          // Direct purpose provided - skip dialog and go directly
          widget.onImagesSelected(sharedImages, purpose);
        } else {
          // Show options dialog once; native buffers are cleared after getSharedImages
          _showShareOptionsDialog(sharedImages);
        }
      });
    }

    // 2) Listen for future share intents while app is running
    ShareIntentService.init(
      onImagesShared: (imagePaths, purpose) {
        if (mounted) {
          if (purpose != null && purpose.isNotEmpty) {
            // Direct purpose provided - skip dialog and go directly
            widget.onImagesSelected(imagePaths, purpose);
          } else {
            // Show options dialog
            _showShareOptionsDialog(imagePaths);
          }
        }
      },
    );
  }

  void _showShareOptionsDialog(List<String> imagePaths) {
    // Show bottom sheet with options
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ShareOptionsSheet(
        imagePaths: imagePaths,
        onOptionSelected: (purpose) {
          Navigator.pop(context);
          widget.onImagesSelected(imagePaths, purpose);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Bottom sheet showing available options for shared images
class ShareOptionsSheet extends StatelessWidget {
  final List<String> imagePaths;
  final Function(String purpose) onOptionSelected;

  const ShareOptionsSheet({
    Key? key,
    required this.imagePaths,
    required this.onOptionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSingleImage = imagePaths.length == 1;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  'What would you like to do?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'You shared ${imagePaths.length} image${imagePaths.length > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // 1) Single image template (PostMakerScreen)
                if (isSingleImage)
                  _buildOption(
                    context,
                    icon: Icons.image,
                    title: 'Create Single Image Post',
                    subtitle: 'Use this image in the single image template',
                    purpose: 'single_image_post',
                  ),

                // 2) Fade-in video template (VideoCreatorScreen, fade_in)
                _buildOption(
                  context,
                  icon: Icons.movie,
                  title: 'Create Fade-In Video',
                  subtitle: 'Convert this image to a video with fade-in effect',
                  purpose: 'video_fade_in',
                ),

                // 3) Plain video template (mapped to existing zoom_in template)
                _buildOption(
                  context,
                  icon: Icons.play_circle_fill,
                  title: 'Create Plain Video',
                  subtitle: 'Simple video from this image',
                  purpose: 'video_zoom_in',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String purpose,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => onOptionSelected(purpose),
    );
  }
}
