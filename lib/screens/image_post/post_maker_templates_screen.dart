import 'package:flutter/material.dart';
import 'templates/post_template_card.dart';
import 'templates/post_template_catalog.dart';

/// Hub screen displaying the modular Post Maker template catalog.
class PostMakerTemplatesScreen extends StatelessWidget {
  final List<String>? sharedImagePaths;

  const PostMakerTemplatesScreen({
    super.key,
    this.sharedImagePaths,
  });

  @override
  Widget build(BuildContext context) {
    final templates = PostTemplateCatalog.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a template'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.65,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final item = templates[index];
            return PostTemplateCard(
              item: item,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => item.screenBuilder(sharedImagePaths),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
