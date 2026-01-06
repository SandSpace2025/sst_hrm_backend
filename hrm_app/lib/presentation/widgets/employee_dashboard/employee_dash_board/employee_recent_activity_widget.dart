import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_loading_state.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_error_state.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_empty_state.dart';

class EmployeeRecentActivityWidget extends StatefulWidget {
  const EmployeeRecentActivityWidget({super.key});

  @override
  State<EmployeeRecentActivityWidget> createState() =>
      _EmployeeRecentActivityWidgetState();
}

class _EmployeeRecentActivityWidgetState
    extends State<EmployeeRecentActivityWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      try {
        final connectivity = await Connectivity().checkConnectivity();
        final isOnline =
            connectivity.isNotEmpty &&
            connectivity.any((result) => result != ConnectivityResult.none);

        final employeeProvider = Provider.of<EmployeeProvider>(
          context,
          listen: false,
        );

        if (isOnline || employeeProvider.messages.isEmpty) {
          employeeProvider.loadMessages(
            authProvider.token!,
            forceRefresh: false,
          );
        } else {}
      } catch (e) {
        final employeeProvider = Provider.of<EmployeeProvider>(
          context,
          listen: false,
        );
        employeeProvider.loadMessages(authProvider.token!, forceRefresh: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
        child: _buildRecentActivitySection(isSmallDevice),
      ),
    );
  }

  Widget _buildRecentActivitySection(bool isSmallDevice) {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        if (employeeProvider.isLoading) {
          return CustomLoadingState(
            message: 'Loading recent activity...',
            isSmallDevice: isSmallDevice,
          );
        }

        if (employeeProvider.error != null) {
          return CustomErrorState(
            message: 'Failed to load recent activity',
            isSmallDevice: isSmallDevice,
          );
        }

        final recentMessages = employeeProvider.messages.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppColors.edgePrimary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: isSmallDevice ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                if (recentMessages.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.edgePrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.edgePrimary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${recentMessages.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgePrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (recentMessages.isEmpty)
              CustomEmptyState(
                title: 'No recent activity',
                subtitle: 'Your recent activities will appear here',
                icon: Icons.history,
                isSmallDevice: isSmallDevice,
              )
            else
              ...recentMessages.map(
                (message) => _buildActivityItem(
                  _safeCastMessage(message),
                  isSmallDevice,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, bool isSmallDevice) {
    final type = activity['type'] ?? 'message';
    final title = activity['title'] ?? 'Activity';
    final description = activity['description'] ?? 'No description';
    final timestamp = activity['timestamp'] ?? '';
    final status = activity['status'] ?? 'completed';

    IconData icon;
    Color color;
    String statusText;

    switch (type) {
      case 'eod':
        icon = Icons.work_outline;
        color = AppColors.edgePrimary;
        statusText = 'EOD Update';
        break;
      case 'leave':
        icon = Icons.event_note_outlined;
        color = AppColors.edgeWarning;
        statusText = 'Leave Request';
        break;
      case 'message':
        icon = Icons.message_outlined;
        color = AppColors.edgeError;
        statusText = 'Message';
        break;
      default:
        icon = Icons.info_outline;
        color = AppColors.edgeTextSecondary;
        statusText = 'Activity';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.edgeBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallDevice ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _getStatusColor(status).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: isSmallDevice ? 11 : 12,
              color: AppColors.edgeTextSecondary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                timestamp,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.edgeTextSecondary.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.edgePrimary;
      case 'pending':
        return AppColors.edgeWarning;
      case 'rejected':
        return AppColors.edgeError;
      default:
        return AppColors.edgeTextSecondary;
    }
  }

  Map<String, dynamic> _safeCastMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      return message;
    } else if (message is Map) {
      return Map<String, dynamic>.from(message);
    } else {
      return {
        'type': 'message',
        'title': 'Activity',
        'description': 'Recent activity',
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'completed',
      };
    }
  }
}
