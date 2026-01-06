import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/employee_provider.dart';

class EmployeeNotificationScreen extends StatefulWidget {
  const EmployeeNotificationScreen({super.key});

  @override
  State<EmployeeNotificationScreen> createState() =>
      _EmployeeNotificationScreenState();
}

class _EmployeeNotificationScreenState
    extends State<EmployeeNotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Trigger a refresh of relevant data when screen opens
      // But verify if we should force refresh or just rely on cached data
      // For notifications, fresh data is usually better
      final provider = Provider.of<EmployeeProvider>(context, listen: false);
      provider.refreshAllData(
        provider.token ?? '',
        forceRefresh:
            false, // Don't force, let it use cache if available but fetch new in bg
      );
    });
  }

  Future<void> _handleRefresh() async {
    final provider = Provider.of<EmployeeProvider>(context, listen: false);
    await provider.refreshAllData(provider.token ?? '', forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Right Decorative Circle
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Icon(
                Icons.notifications,
                size: 100,
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title and Subtitle
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stay Active with daily updates!',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  Expanded(
                    child: Consumer<EmployeeProvider>(
                      builder: (context, provider, child) {
                        final notifications = provider.notifications;

                        if (provider.isLoading && notifications.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: _handleRefresh,
                          color: AppColors.primary,
                          child: notifications.isNotEmpty
                              ? ListView.separated(
                                  padding: const EdgeInsets.only(
                                    top: 20,
                                    bottom: 20,
                                  ),
                                  itemCount: notifications.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    return _NotificationCard(
                                      notification: notifications[index],
                                    );
                                  },
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight,
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Image.asset(
                                                'assets/images/no_noti.png',
                                                height: 250,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const Icon(
                                                        Icons
                                                            .notifications_off_outlined,
                                                        size: 100,
                                                        color: AppColors
                                                            .textSecondary,
                                                      );
                                                    },
                                              ),
                                              const SizedBox(height: 20),
                                              const Text(
                                                'No Updates at Present!',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF43C088),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              notification['title'] ?? 'Notification',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF43C088),
            ),
          ),
        ],
      ),
    );
  }
}
