import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class QuickActions extends StatefulWidget {
  final bool isSmallDevice;
  final Function({required Widget child, required double interval})
  animatedWidget;
  final String totalEmployees;
  final VoidCallback onViewAllEmployees;
  final VoidCallback onSendAnnouncement;

  const QuickActions({
    super.key,
    required this.isSmallDevice,
    required this.animatedWidget,
    required this.totalEmployees,
    required this.onViewAllEmployees,
    required this.onSendAnnouncement,
  });

  @override
  State<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<QuickActions>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _cardsAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _cardsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerAnimationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _cardAnimations = List.generate(3, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _cardsAnimationController,
          curve: Interval(
            index * 0.15,
            0.6 + (index * 0.15),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    _headerAnimationController.forward();
    _cardsAnimationController.forward();
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _cardsAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEnhancedHeader(),
        SizedBox(height: widget.isSmallDevice ? 20 : 24),
        _buildAnimatedActionCard(
          index: 0,
          label: 'Manage Employees',
          description: '${widget.totalEmployees} total',
          icon: Icons.people_rounded,
          color: AppColors.edgePrimary,
          onPressed: widget.onViewAllEmployees,
        ),
        SizedBox(height: widget.isSmallDevice ? 12 : 16),
        _buildAnimatedActionCard(
          index: 1,
          label: 'Send Announcement',
          description: 'Broadcast to team',
          icon: Icons.campaign_rounded,
          color: AppColors.edgeAccent,
          onPressed: widget.onSendAnnouncement,
        ),
        SizedBox(height: widget.isSmallDevice ? 12 : 16),
        _buildAnimatedActionCard(
          index: 2,
          label: 'Manage Payroll',
          description: 'Next in 5 days',
          icon: Icons.payments_rounded,
          color: AppColors.edgeSecondary,
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildEnhancedHeader() {
    return AnimatedBuilder(
      animation: _headerAnimationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _headerFadeAnimation,
          child: SlideTransition(
            position: _headerSlideAnimation,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: widget.isSmallDevice ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.edgeText,
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isSmallDevice ? 12 : 14,
                    vertical: widget.isSmallDevice ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.edgePrimary.withOpacity(0.1),
                        AppColors.edgePrimary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.edgePrimary.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.edgePrimary.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: widget.isSmallDevice ? 16 : 18,
                        color: AppColors.edgePrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Quick',
                        style: TextStyle(
                          fontSize: widget.isSmallDevice ? 12 : 13,
                          color: AppColors.edgePrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedActionCard({
    required int index,
    required String label,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return AnimatedBuilder(
      animation: _cardAnimations[index],
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _cardAnimations[index].value)),
          child: Opacity(
            opacity: _cardAnimations[index].value,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.edgeSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.edgeDivider.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.edgeText.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(16),
                  splashColor: color.withOpacity(0.1),
                  highlightColor: color.withOpacity(0.05),
                  child: Padding(
                    padding: EdgeInsets.all(widget.isSmallDevice ? 16 : 20),
                    child: Row(
                      children: [
                        Container(
                          width: widget.isSmallDevice ? 48 : 56,
                          height: widget.isSmallDevice ? 48 : 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                color.withOpacity(0.15),
                                color.withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withOpacity(0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            size: widget.isSmallDevice ? 24 : 28,
                          ),
                        ),
                        SizedBox(width: widget.isSmallDevice ? 16 : 20),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: widget.isSmallDevice ? 16 : 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.edgeText,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: widget.isSmallDevice ? 13 : 14,
                                  color: AppColors.edgeTextSecondary,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.edgeTextSecondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: widget.isSmallDevice ? 14 : 16,
                            color: AppColors.edgeTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
