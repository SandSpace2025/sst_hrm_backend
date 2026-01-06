import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:hrm_app/core/theme/app_colors.dart';

class MedicalCertificateField extends StatelessWidget {
  final File? selectedFile;
  final Function(File?) onFileSelected;

  const MedicalCertificateField({
    super.key,
    required this.selectedFile,
    required this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Medical Certificate',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.edgeSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.edgeDivider),
          ),
          child: InkWell(
            onTap: () => _showImagePicker(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    selectedFile != null
                        ? Icons.attach_file
                        : Icons.add_photo_alternate_outlined,
                    color: selectedFile != null
                        ? AppColors.edgePrimary
                        : AppColors.edgeTextSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedFile != null
                              ? 'Medical certificate uploaded'
                              : 'Upload medical certificate',
                          style: TextStyle(
                            fontSize: 13,
                            color: selectedFile != null
                                ? AppColors.edgePrimary
                                : AppColors.edgeText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (selectedFile != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            selectedFile!.path.split('/').last,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.edgeTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selectedFile != null) ...[
                    IconButton(
                      onPressed: () => onFileSelected(null),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.edgeError,
                        size: 18,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ] else ...[
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.edgeTextSecondary,
                      size: 14,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please upload a valid medical certificate (PDF, JPG, PNG)',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.edgeTextSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Medical Certificate',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPickerOption(
                    context,
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () => _pickImage(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPickerOption(
                    context,
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => _pickImage(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.edgeSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.edgeDivider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.edgePrimary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.edgeText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        onFileSelected(File(image.path));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: AppColors.edgeError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
