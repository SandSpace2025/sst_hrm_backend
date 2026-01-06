import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HREmployeeListCard extends StatefulWidget {
  final Map<String, dynamic> employee;
  final int index;
  final VoidCallback onViewProfile;
  final VoidCallback onViewEODs;
  final VoidCallback onViewPayroll;
  final VoidCallback onManageLeaves;

  const HREmployeeListCard({
    super.key,
    required this.employee,
    required this.index,
    required this.onViewProfile,
    required this.onViewEODs,
    required this.onViewPayroll,
    required this.onManageLeaves,
  });

  @override
  State<HREmployeeListCard> createState() => _HREmployeeListCardState();
}

class _HREmployeeListCardState extends State<HREmployeeListCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  static const Duration _animDuration = Duration(milliseconds: 400);
  static const Curve _animCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: _animCurve),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.8, curve: _animCurve),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: _animCurve),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: widget.index * 40), () {
        if (mounted) {
          _controller.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(scale: _scaleAnimation, child: _buildCard()),
      ),
    );
  }

  Widget _buildCard() {
    final name = widget.employee['name'] ?? 'Unknown';
    final profilePic = widget.employee['profilePic'] ?? '';
    final role =
        widget.employee['role']?.toString().toLowerCase() ?? 'employee';
    final bool isHr = role == 'hr';
    final Color roleColor = isHr ? AppColors.edgeAccent : AppColors.edgePrimary;

    return Hero(
      tag: 'hr_employee_${widget.employee['id'] ?? widget.index}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _triggerHaptic();
            widget.onViewProfile();
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: roleColor.withOpacity(0.1),
          highlightColor: roleColor.withOpacity(0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.edgeDivider, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.edgePrimary.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: AppColors.edgePrimary.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: roleColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                ),

                _buildAvatar(roleColor, name, profilePic),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoSection(name, isHr, roleColor),
                        const SizedBox(height: 8),
                        _buildActionsSection(isHr, roleColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Color roleColor, String name, String profilePic) {
    final hasProfilePic = profilePic.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.edgePrimary.withOpacity(0.1),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
      ),
      child: hasProfilePic
          ? Image.network(
              '${ApiConstants.baseUrl}$profilePic',
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.edgePrimary,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppColors.edgePrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                );
              },
            )
          : Container(
              color: AppColors.edgePrimary.withOpacity(0.1),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.edgePrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoSection(String name, bool isHr, Color roleColor) {
    return Text(
      name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.edgeText,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildActionsSection(bool isHr, Color roleColor) {
    final role =
        widget.employee['role']?.toString().toLowerCase() ?? 'employee';
    final bool isEmployee = role == 'employee';

    return Row(
      children: [
        if (isEmployee) ...[
          _buildActionButton(Icons.description_rounded, 'EODs', () {
            _triggerHaptic();
            widget.onViewEODs();
          }, AppColors.edgeWarning),
          const SizedBox(width: 8),
        ],
        _buildActionButton(Icons.account_balance_wallet_rounded, 'Payroll', () {
          _triggerHaptic();
          widget.onViewPayroll();
        }, AppColors.edgeAccent),
        const SizedBox(width: 8),
        _buildActionButton(Icons.event_available_rounded, 'Leaves', () {
          _triggerHaptic();
          widget.onManageLeaves();
        }, AppColors.edgeAccent),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
    Color color,
  ) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
