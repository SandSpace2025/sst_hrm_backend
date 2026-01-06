import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class EmployeeSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;

  const EmployeeSearchField({
    super.key,
    required this.controller,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.edgeSurface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.edgeDivider),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 14, color: AppColors.edgeText),
            decoration: InputDecoration(
              hintText: 'Search by name...',
              hintStyle: const TextStyle(
                color: AppColors.edgeTextSecondary,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.edgeTextSecondary,
                size: 20,
              ),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: AppColors.edgeTextSecondary,
                        size: 18,
                      ),
                      onPressed: () {
                        controller.clear();
                        focusNode?.unfocus();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}
