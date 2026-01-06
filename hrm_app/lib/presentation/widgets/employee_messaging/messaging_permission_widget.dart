import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class MessagingPermissionWidget extends StatefulWidget {
  final VoidCallback? onPermissionGranted;

  const MessagingPermissionWidget({super.key, this.onPermissionGranted});

  @override
  State<MessagingPermissionWidget> createState() =>
      _MessagingPermissionWidgetState();
}

class _MessagingPermissionWidgetState extends State<MessagingPermissionWidget> {
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    return Selector<EmployeeProvider, Map<String, dynamic>>(
      selector: (context, provider) => {
        'canMessage': provider.canMessage,
        'expiresAt': provider.permissionExpiresAt,
      },
      builder: (context, data, child) {
        final canMessage = data['canMessage'] as bool;
        final expiresAt = data['expiresAt'] as DateTime?;

        if (canMessage && expiresAt != null) {
          return _buildPermissionStatusCard(expiresAt);
        } else {
          return _buildRequestPermissionCard(
            Provider.of<EmployeeProvider>(context, listen: false),
          );
        }
      },
    );
  }

  Widget _buildPermissionStatusCard(DateTime expiresAt) {
    final now = DateTime.now();
    final timeLeft = expiresAt.difference(now);
    final hoursLeft = timeLeft.inHours;
    final minutesLeft = timeLeft.inMinutes % 60;

    String timeLeftText;
    Color statusColor;
    IconData statusIcon;

    if (hoursLeft > 1) {
      timeLeftText = '$hoursLeft hours left';
      statusColor = AppColors.edgeAccent;
      statusIcon = Icons.check_circle_outline;
    } else if (hoursLeft == 1) {
      timeLeftText = '1 hour left';
      statusColor = AppColors.edgeWarning;
      statusIcon = Icons.warning_outlined;
    } else if (minutesLeft > 0) {
      timeLeftText = '$minutesLeft minutes left';
      statusColor = AppColors.edgeError;
      statusIcon = Icons.error_outline;
    } else {
      timeLeftText = 'Expired';
      statusColor = AppColors.edgeError;
      statusIcon = Icons.cancel_outlined;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Messaging Access Active',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLeftText,
                      style: TextStyle(
                        fontSize: 14,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.edgeBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.edgeDivider),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.edgeTextSecondary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can send messages to HR and Admin until ${_formatDateTime(expiresAt)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.edgeTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPermissionCard(EmployeeProvider employeeProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.edgeWarning.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.edgeWarning, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messaging Access Required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Admin approval needed to send messages',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.edgeTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.edgeWarning.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.edgeWarning.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.edgeWarning,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You need admin approval to send messages. Access expires after 48 hours.',
                    style: TextStyle(fontSize: 13, color: AppColors.edgeText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRequesting
                  ? null
                  : () => _requestPermission(employeeProvider),
              icon: _isRequesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(_isRequesting ? 'Requesting...' : 'Request Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.edgePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermission(EmployeeProvider employeeProvider) async {
    setState(() {
      _isRequesting = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        await employeeProvider.requestMessagingPermission(authProvider.token!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Messaging access requested successfully'),
              backgroundColor: AppColors.edgeAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );

          widget.onPermissionGranted?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request access: ${e.toString()}'),
            backgroundColor: AppColors.edgeError,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
