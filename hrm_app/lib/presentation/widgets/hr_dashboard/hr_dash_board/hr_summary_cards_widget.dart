import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HRSummaryCardsWidget extends StatefulWidget {
  const HRSummaryCardsWidget({super.key});

  @override
  State<HRSummaryCardsWidget> createState() => _HRSummaryCardsWidgetState();
}

class _HRSummaryCardsWidgetState extends State<HRSummaryCardsWidget>
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

    _cardAnimations = List.generate(4, (index) {
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

    _cardsAnimationController.forward();
  }

  @override
  void dispose() {
    _cardsAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HRProvider>(
      builder: (context, hrProvider, child) {
        if (hrProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.edgePrimary),
            ),
          );
        }

        if (hrProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.edgeError),
                const SizedBox(height: 16),
                const Text(
                  'Error loading dashboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hrProvider.error!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.edgeTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    if (authProvider.token != null) {
                      final connectivity = await Connectivity()
                          .checkConnectivity();
                      final isOnline =
                          connectivity.isNotEmpty &&
                          connectivity.any(
                            (result) => result != ConnectivityResult.none,
                          );

                      if (!isOnline) {
                        if (context.mounted) {
                          SnackBarUtils.showError(
                            context,
                            'No internet connection',
                          );
                        }
                        return;
                      }

                      if (context.mounted) {
                        SnackBarUtils.showInfo(
                          context,
                          'Refreshing dashboard...',
                        );
                      }

                      await hrProvider.fetchHRDashboardSummary(
                        authProvider.token!,
                        forceRefresh: true,
                      );

                      await Future.delayed(const Duration(milliseconds: 300));

                      if (!context.mounted) return;

                      if (hrProvider.error != null) {
                        final errorMsg = hrProvider.error!.toLowerCase();
                        if (errorMsg.contains('no internet') ||
                            errorMsg.contains('socketexception') ||
                            errorMsg.contains('connection')) {
                          SnackBarUtils.showError(
                            context,
                            'No internet connection',
                          );
                        } else {
                          SnackBarUtils.showError(
                            context,
                            'Failed to refresh: ${hrProvider.error}',
                          );
                        }
                      } else {
                        SnackBarUtils.showSuccess(
                          context,
                          'Dashboard refreshed',
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.edgePrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final dashboardData = hrProvider.dashboardData;
        if (dashboardData == null) {
          return const Center(
            child: Text(
              'No dashboard data available',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.edgeTextSecondary,
              ),
            ),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildAnimatedSummaryCard(
                    index: 0,
                    count: '${dashboardData['employeesCount'] ?? 0}',
                    title: 'Total Employees',
                    subtitle: 'Active employees',
                    icon: Icons.people_rounded,
                    color: AppColors.edgePrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAnimatedSummaryCard(
                    index: 1,
                    count: '${dashboardData['recentAnnouncements'] ?? 0}',
                    title: 'Recent Announcements',
                    subtitle: 'Last 7 days',
                    icon: Icons.campaign_rounded,
                    color: AppColors.edgeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAnimatedSummaryCard(
                    index: 2,
                    count: '${dashboardData['pendingMessages'] ?? 0}',
                    title: 'Pending Messages',
                    subtitle: 'Unread messages',
                    icon: Icons.mail_rounded,
                    color: AppColors.edgeWarning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAnimatedSummaryCard(
                    index: 3,
                    count: 'Active',
                    title: 'HR Profile',
                    subtitle: 'Profile status',
                    icon: Icons.person_rounded,
                    color: AppColors.edgeAccent,
                  ),
                ),
              ],
            ),
          ],
        );
      },
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
  }) {
    return AnimatedBuilder(
      animation: _cardAnimations[index],
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _cardAnimations[index].value)),
          child: Opacity(
            opacity: _cardAnimations[index].value,
            child: Container(
              padding: const EdgeInsets.all(18),
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
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.edgeText,
                                height: 1,
                                letterSpacing: -1.5,
                                shadows: [
                                  Shadow(
                                    color: Color(0x20000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.edgeText,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),

                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.edgeTextSecondary,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        width: 52,
                        height: 52,
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
                        child: Icon(icon, color: color, size: 26),
                      ),
                    ],
                  ),
                  if (trend != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
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
                            size: 16,
                            color: trendUp
                                ? AppColors.edgeAccent
                                : AppColors.edgeWarning,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              trend,
                              style: TextStyle(
                                fontSize: 13,
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
