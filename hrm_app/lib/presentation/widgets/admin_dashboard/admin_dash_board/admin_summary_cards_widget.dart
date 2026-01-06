import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/widgets/common/dashboard_metric_card.dart';

class SummaryCards extends StatefulWidget {
  final bool isSmallDevice;
  final Function({required Widget child, required double interval})
  animatedWidget;

  const SummaryCards({
    super.key,
    required this.isSmallDevice,
    required this.animatedWidget,
  });

  @override
  State<SummaryCards> createState() => _SummaryCardsState();
}

class _SummaryCardsState extends State<SummaryCards>
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
    final adminProvider = Provider.of<AdminProvider>(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardMetricCard(
                count:
                    adminProvider.dashboardData?['adminsOnline'].toString() ??
                    '0',
                title: 'Admins',
                subtitle: 'Total Count',
                icon: Icons.shield_rounded,
                color: AppColors.edgePrimary,
                isSmallDevice: widget.isSmallDevice,
                animation: _cardAnimations[0],
              ),
            ),
            SizedBox(width: widget.isSmallDevice ? 12 : 16),
            Expanded(
              child: DashboardMetricCard(
                count:
                    adminProvider.dashboardData?['hrsOnline'].toString() ?? '0',
                title: 'HR Team',
                subtitle: 'Total Count',
                icon: Icons.support_agent_rounded,
                color: AppColors.edgeWarning,
                isSmallDevice: widget.isSmallDevice,
                animation: _cardAnimations[1],
              ),
            ),
          ],
        ),
        SizedBox(height: widget.isSmallDevice ? 12 : 16),
        DashboardMetricCard(
          count:
              adminProvider.dashboardData?['employeesOnline'].toString() ?? '0',
          title: 'Employees',
          subtitle: 'Total Count',
          icon: Icons.people_rounded,
          color: AppColors.edgeAccent,
          isSmallDevice: widget.isSmallDevice,
          animation: _cardAnimations[2],
        ),
      ],
    );
  }
}
