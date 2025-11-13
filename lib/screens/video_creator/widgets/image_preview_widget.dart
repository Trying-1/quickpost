import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ImagePreviewWidget extends StatelessWidget {
  final File? selectedImage;
  final Function(File) onImageSelected;
  final bool isProcessing;
  
  const ImagePreviewWidget({
    Key? key,
    required this.selectedImage,
    required this.onImageSelected,
    required this.isProcessing,
  }) : super(key: key);
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      onImageSelected(File(pickedFile.path));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Image Preview
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: selectedImage == null ? Colors.grey[100] : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selectedImage == null ? Border.all(color: Colors.grey[300]!) : null,
          ),
          child: selectedImage == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No image selected',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      selectedImage!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        
        // Select Image Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isProcessing ? null : _pickImage,
            icon: const Icon(Icons.photo_library, size: 18),
            label: const Text('Select Image'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
