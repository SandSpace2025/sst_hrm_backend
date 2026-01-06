import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class RoleToggleSwitch extends StatefulWidget {
  final bool isHrSelected;
  final ValueChanged<bool> onToggle;

  const RoleToggleSwitch({
    super.key,
    required this.isHrSelected,
    required this.onToggle,
  });

  @override
  State<RoleToggleSwitch> createState() => _RoleToggleSwitchState();
}

class _RoleToggleSwitchState extends State<RoleToggleSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: _animDuration, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));
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
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.edgeDivider, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.edgePrimary.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: AppColors.edgePrimary.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  alignment: widget.isHrSelected
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  duration: _animDuration,
                  curve: _animCurve,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.edgePrimary,
                            AppColors.edgePrimary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.edgePrimary.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _triggerHaptic();
                            _controller.forward().then((_) {
                              _controller.reverse();
                            });
                            widget.onToggle(true);
                          },
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(11),
                          ),
                          splashColor: AppColors.edgePrimary.withOpacity(0.1),
                          highlightColor: AppColors.edgePrimary.withOpacity(
                            0.05,
                          ),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_rounded,
                                  size: 18,
                                  color: widget.isHrSelected
                                      ? Colors.white
                                      : AppColors.edgeTextSecondary,
                                ),
                                const SizedBox(width: 8),
                                AnimatedDefaultTextStyle(
                                  duration: _animDuration,
                                  curve: _animCurve,
                                  style: TextStyle(
                                    color: widget.isHrSelected
                                        ? Colors.white
                                        : AppColors.edgeTextSecondary,
                                    fontWeight: widget.isHrSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                  child: const Text('HR'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _triggerHaptic();
                            _controller.forward().then((_) {
                              _controller.reverse();
                            });
                            widget.onToggle(false);
                          },
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(11),
                          ),
                          splashColor: AppColors.edgeAccent.withOpacity(0.1),
                          highlightColor: AppColors.edgeAccent.withOpacity(
                            0.05,
                          ),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_rounded,
                                  size: 18,
                                  color: !widget.isHrSelected
                                      ? Colors.white
                                      : AppColors.edgeTextSecondary,
                                ),
                                const SizedBox(width: 8),
                                AnimatedDefaultTextStyle(
                                  duration: _animDuration,
                                  curve: _animCurve,
                                  style: TextStyle(
                                    color: !widget.isHrSelected
                                        ? Colors.white
                                        : AppColors.edgeTextSecondary,
                                    fontWeight: !widget.isHrSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                  child: const Text('Employees'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
