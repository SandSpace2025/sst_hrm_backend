import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class CommonBloodGroupDropdown extends StatefulWidget {
  final TextEditingController controller;
  final bool isReadOnly;
  final bool isSmallDevice;
  final Function(String)? onChanged;
  final InputDecoration? decoration;

  const CommonBloodGroupDropdown({
    super.key,
    required this.controller,
    this.isReadOnly = false,
    this.isSmallDevice = false,
    this.onChanged,
    this.decoration,
  });

  @override
  State<CommonBloodGroupDropdown> createState() =>
      _CommonBloodGroupDropdownState();
}

class _CommonBloodGroupDropdownState extends State<CommonBloodGroupDropdown> {
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  @override
  Widget build(BuildContext context) {
    // Ensure the current value is valid or null
    String? currentValue = widget.controller.text.trim();
    if (currentValue.isEmpty || !_bloodGroups.contains(currentValue)) {
      currentValue = null;
    }

    return DropdownButtonFormField<String>(
      value: currentValue,
      items: _bloodGroups.map((bg) {
        return DropdownMenuItem(
          value: bg,
          child: Text(
            bg,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.edgeText,
            ),
          ),
        );
      }).toList(),
      onChanged: widget.isReadOnly
          ? null
          : (value) {
              if (value != null) {
                widget.controller.text = value;
                if (widget.onChanged != null) {
                  widget.onChanged!(value);
                }
                setState(() {}); // Rebuild to show selected value
              }
            },
      decoration:
          widget.decoration ??
          InputDecoration(
            labelText: 'Blood Group',
            prefixIcon: const Icon(
              Icons.bloodtype,
              color: AppColors.edgeTextSecondary,
              size: 20,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: widget.isSmallDevice ? 10 : 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.edgeDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.edgeDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: AppColors.edgePrimary,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: widget.isReadOnly
                ? AppColors.edgeBackground
                : AppColors.edgeSurface,
          ),
      dropdownColor: AppColors.edgeSurface,
      icon: const Icon(
        Icons.arrow_drop_down,
        color: AppColors.edgeTextSecondary,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a blood group';
        }
        return null;
      },
    );
  }
}
