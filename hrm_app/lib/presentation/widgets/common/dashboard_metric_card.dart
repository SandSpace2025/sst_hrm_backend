import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class DashboardMetricCard extends StatefulWidget {
  final String count;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool trendUp;
  final bool isSmallDevice;
  final Animation<double>? animation;

  const DashboardMetricCard({
    super.key,
    required this.count,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.trend,
    this.trendUp = true,
    this.isSmallDevice = false,
    this.animation,
  });

  @override
  State<DashboardMetricCard> createState() => _DashboardMetricCardState();
}

class _DashboardMetricCardState extends State<DashboardMetricCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.animation != null) {
      return AnimatedBuilder(
        animation: widget.animation!,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 30 * (1 - widget.animation!.value)),
            child: Opacity(
              opacity: widget.animation!.value,
              child: _buildCardContent(),
            ),
          );
        },
      );
    }
    return _buildCardContent();
  }

  Widget _buildCardContent() {
    return Container(
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
                      widget.count,
                      style: TextStyle(
                        fontSize: widget.isSmallDevice ? 28 : 32,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                        height: 1,
                        letterSpacing: -1.5,
                        shadows: [
                          Shadow(
                            color: widget.color.withOpacity(0.2),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: widget.isSmallDevice ? 14 : 15,
                        color: AppColors.edgeText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
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
                      widget.color.withOpacity(0.15),
                      widget.color.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.color.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: widget.isSmallDevice ? 24 : 26,
                ),
              ),
            ],
          ),
          if (widget.trend != null) ...[
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
                    (widget.trendUp
                            ? AppColors.edgeAccent
                            : AppColors.edgeWarning)
                        .withOpacity(0.1),
                    (widget.trendUp
                            ? AppColors.edgeAccent
                            : AppColors.edgeWarning)
                        .withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      (widget.trendUp
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
                    widget.trendUp
                        ? Icons.trending_up_rounded
                        : Icons.info_outline_rounded,
                    size: widget.isSmallDevice ? 14 : 16,
                    color: widget.trendUp
                        ? AppColors.edgeAccent
                        : AppColors.edgeWarning,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.trend!,
                      style: TextStyle(
                        fontSize: widget.isSmallDevice ? 12 : 13,
                        color: widget.trendUp
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
    );
  }
}
