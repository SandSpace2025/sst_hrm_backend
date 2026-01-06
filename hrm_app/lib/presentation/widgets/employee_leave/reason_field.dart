import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class ReasonField extends StatelessWidget {
  final TextEditingController controller;

  const ReasonField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reason for Leave',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeText,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Provide a reason for your leave...',
              hintStyle: TextStyle(
                color: AppColors.edgeTextSecondary.withOpacity(0.7),
                fontSize: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.edgePrimary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppColors.edgeBackground,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(fontSize: 13),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please provide a reason for your leave request';
              }
              if (value.trim().length < 10) {
                return 'Please provide a more detailed reason (minimum 10 characters)';
              }
              if (value.trim().length > 500) {
                return 'Reason cannot exceed 500 characters';
              }

              return null;
            },
          ),
        ),
      ],
    );
  }
}
