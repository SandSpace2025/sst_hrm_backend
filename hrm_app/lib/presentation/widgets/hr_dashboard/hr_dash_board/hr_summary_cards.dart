import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HrSummaryCards extends StatefulWidget {
  final bool isSmallDevice;
  final Function({required Widget child, required double interval})
  animatedWidget;

  const HrSummaryCards({
    super.key,
    required this.isSmallDevice,
    required this.animatedWidget,
  });

  @override
  State<HrSummaryCards> createState() => _HrSummaryCardsState();
}

class _HrSummaryCardsState extends State<HrSummaryCards>
    with TickerProviderStateMixin {
  late AnimationController _cardsAnimationController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _cardsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardAnimations = List.generate(3, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _cardsAnimationController,
          curve: Interval(
            index * 0.2,
            0.6 + (index * 0.2),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    _cardsAnimationController.forward();
  }

  @override
  void dispose() {
    _cardsAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hrProvider = Provider.of<HRProvider>(context);
    final dashboardData = hrProvider.dashboardData;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAnimatedSummaryCard(
                index: 0,
                count: dashboardData?['totalEmployees']?.toString() ?? '0',
                title: 'Employees',
                subtitle: 'Total Count',
                icon: Icons.people_rounded,
                color: AppColors.edgePrimary,
              ),
            ),
            SizedBox(width: widget.isSmallDevice ? 12 : 16),
            Expanded(
              child: _buildAnimatedSummaryCard(
                index: 1,
                count:
                    dashboardData?['pendingLeaveApprovals']?.toString() ?? '0',
                title: 'Pending Leaves',
                subtitle: 'Requests',
                icon: Icons.event_note_rounded,
                color: AppColors.edgeWarning,
              ),
            ),
          ],
        ),
        SizedBox(height: widget.isSmallDevice ? 12 : 16),
        _buildAnimatedSummaryCard(
          index: 2,
          count: dashboardData?['unreadMessages']?.toString() ?? '0',
          title: 'Unread Messages',
          subtitle: 'Inbox',
          icon: Icons.mail_rounded,
          color: AppColors.edgeAccent,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildAnimatedSummaryCard({
    required int index,
    required String count,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? trend,
    bool trendUp = true,
    bool isFullWidth = false,
  }) {
    return AnimatedBuilder(
      animation: _cardAnimations[index],
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _cardAnimations[index].value)),
          child: Opacity(
            opacity: _cardAnimations[index].value,
            child: Container(
              padding: EdgeInsets.all(widget.isSmallDevice ? 16 : 18),
              decoration: BoxDecoration(
                color: AppColors.edgeSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.edgeDivider.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.edgeText.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.edgeText.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              count,
                              style: TextStyle(
                                fontSize: widget.isSmallDevice ? 28 : 32,
                                fontWeight: FontWeight.w800,
                                color: color,
                                height: 1,
                                letterSpacing: -1.5,
                                shadows: [
                                  Shadow(
                                    color: color.withOpacity(0.2),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              title,
                              style: TextStyle(
                                fontSize: widget.isSmallDevice ? 14 : 15,
                                color: AppColors.edgeText,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),

                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: widget.isSmallDevice ? 12 : 13,
                                color: AppColors.edgeTextSecondary,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        width: widget.isSmallDevice ? 48 : 52,
                        height: widget.isSmallDevice ? 48 : 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withOpacity(0.15),
                              color.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: color.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: widget.isSmallDevice ? 24 : 26,
                        ),
                      ),
                    ],
                  ),
                  if (trend != null) ...[
                    SizedBox(height: widget.isSmallDevice ? 12 : 16),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.isSmallDevice ? 10 : 12,
                        vertical: widget.isSmallDevice ? 5 : 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            (trendUp
                                    ? AppColors.edgeAccent
                                    : AppColors.edgeWarning)
                                .withOpacity(0.1),
                            (trendUp
                                    ? AppColors.edgeAccent
                                    : AppColors.edgeWarning)
                                .withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              (trendUp
                                      ? AppColors.edgeAccent
                                      : AppColors.edgeWarning)
                                  .withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            trendUp
                                ? Icons.trending_up_rounded
                                : Icons.info_outline_rounded,
                            size: widget.isSmallDevice ? 14 : 16,
                            color: trendUp
                                ? AppColors.edgeAccent
                                : AppColors.edgeWarning,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              trend,
                              style: TextStyle(
                                fontSize: widget.isSmallDevice ? 12 : 13,
                                color: trendUp
                                    ? AppColors.edgeAccent
                                    : AppColors.edgeWarning,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
