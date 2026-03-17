import 'package:flutter/material.dart';

import 'single_image_post_screen.dart';
import 'grid_post_screen.dart';

class PostMakerScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final String? sharedPurpose;

  const PostMakerScreen({
    super.key,
    this.sharedImagePaths,
    this.sharedPurpose,
  });

  @override
  State<PostMakerScreen> createState() => _PostMakerScreenState();
}

class _PostMakerScreenState extends State<PostMakerScreen> {
  String _selectedTemplate = 'single_image_post';

  @override
  void initState() {
    super.initState();
    _updateTemplateFromShare(widget.sharedImagePaths, widget.sharedPurpose);
  }

  @override
  void didUpdateWidget(covariant PostMakerScreen oldWidget) {
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
        _updateTemplateFromShare(newPaths, newPurpose);
      }
    }
  }

  void _updateTemplateFromShare(List<String>? paths, String? purpose) {
    // Decide which template to route to based on intent and number of images
    if (purpose == 'grid_post') {
      _selectedTemplate = 'grid_post';
      setState(() {});
      return;
    }

    if (purpose == 'single_image_post') {
      _selectedTemplate = 'single_image_post';
      setState(() {});
      return;
    }

    // Fallback: infer from image count if provided
    if (paths != null && paths.isNotEmpty) {
      _selectedTemplate = paths.length > 1 ? 'grid_post' : 'single_image_post';
      setState(() {});
      return;
    }

    // Default when nothing is shared
    _selectedTemplate = 'single_image_post';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedTemplate == 'grid_post') {
      return GridPostScreen(
        sharedImagePaths: widget.sharedImagePaths,
        sharedPurpose: widget.sharedPurpose,
      );
    }

    // Default and single image case
    return SingleImagePostScreen(
      sharedImagePaths: widget.sharedImagePaths,
      sharedPurpose: widget.sharedPurpose,
    );
  }
}

