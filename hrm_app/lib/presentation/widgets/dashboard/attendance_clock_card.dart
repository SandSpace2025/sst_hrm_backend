import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class AttendanceClockCard extends StatefulWidget {
  final VoidCallback? onCheckIn;
  final VoidCallback? onCheckOut;
  final String? checkInTime;
  final String? checkOutTime;
  final String? totalHours;
  final bool isCheckedIn;

  const AttendanceClockCard({
    super.key,
    this.onCheckIn,
    this.onCheckOut,
    this.checkInTime,
    this.checkOutTime,
    this.totalHours,
    this.isCheckedIn = false,
  });

  @override
  State<AttendanceClockCard> createState() => _AttendanceClockCardState();
}

class _AttendanceClockCardState extends State<AttendanceClockCard> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Clock Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface,
                AppColors.primary.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            children: [
              Text(
                DateFormat('hh:mm a').format(_currentTime),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM dd, yyyy - EEEE').format(_currentTime),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionItem(
              icon: Icons.login_rounded,
              label: 'Check in',
              value: widget.checkInTime ?? '--:--',
              onTap: widget.onCheckIn,
              isActive: !widget.isCheckedIn,
            ),
            _buildActionItem(
              icon: Icons.logout_rounded,
              label: 'Check out',
              value: widget.checkOutTime ?? '--:--',
              onTap: widget.onCheckOut,
              isActive: widget.isCheckedIn,
            ),
            _buildActionItem(
              icon: Icons.schedule_rounded,
              label: 'Total hrs',
              value: widget.totalHours ?? '--:--',
              isInfo: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool isActive = false,
    bool isInfo = false,
  }) {
    final color = isInfo
        ? AppColors.textSecondary
        : (isActive ? AppColors.primary : AppColors.textDisabled);

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isInfo
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.border,
            ),
            child: Icon(
              icon,
              color: isActive || isInfo
                  ? AppColors.primary
                  : AppColors.textDisabled,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
