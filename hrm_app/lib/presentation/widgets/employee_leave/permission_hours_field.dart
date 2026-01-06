import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class PermissionHoursField extends StatelessWidget {
  final int permissionHours;
  final ValueChanged<int> onChanged;

  const PermissionHoursField({
    super.key,
    required this.permissionHours,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permission Hours',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeText,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.edgeSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.edgeDivider),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: TextFormField(
                    initialValue: permissionHours.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _RangeTextInputFormatter(min: 1, max: 3),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      hintText: 'Hours',
                      hintStyle: TextStyle(fontSize: 13),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (value) {
                      onChanged(int.tryParse(value) ?? 1);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.edgePrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.edgePrimary.withOpacity(0.2),
                ),
              ),
              child: const Text(
                'Max: 3 hours',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.edgePrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RangeTextInputFormatter extends TextInputFormatter {
  final int min;
  final int max;

  _RangeTextInputFormatter({required this.min, required this.max});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(newValue.text);
    if (value == null) {
      return oldValue;
    }

    if (value < min || value > max) {
      return oldValue;
    }

    return newValue;
  }
}
