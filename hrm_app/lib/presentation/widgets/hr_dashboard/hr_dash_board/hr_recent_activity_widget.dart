import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/providers/announcement_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/message_provider.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HrRecentActivityWidget extends StatefulWidget {
  const HrRecentActivityWidget({super.key});

  @override
  State<HrRecentActivityWidget> createState() => _HrRecentActivityWidgetState();
}

class _HrRecentActivityWidgetState extends State<HrRecentActivityWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      Provider.of<AnnouncementProvider>(
        context,
        listen: false,
      ).loadAnnouncements(authProvider.token!);
      Provider.of<MessageProvider>(
        context,
        listen: false,
      ).loadMessageStats(authProvider.token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.edgeBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
            decoration: const BoxDecoration(
              color: AppColors.edgePrimary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Recent Notifications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadData,
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
            child: Column(
              children: [
                _buildAnnouncementsSection(isSmallDevice),
                const SizedBox(height: 20),
                _buildUnreadMessagesSection(isSmallDevice),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSection(bool isSmallDevice) {
    return Consumer<AnnouncementProvider>(
      builder: (context, announcementProvider, child) {
        if (announcementProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final recentAnnouncements = announcementProvider.announcements;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Announcements',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
              ),
            ),
            const SizedBox(height: 12),
            if (recentAnnouncements.isEmpty)
              const Text(
                'No recent announcements.',
                style: TextStyle(color: AppColors.edgeTextSecondary),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: recentAnnouncements
                        .map(
                          (announcement) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              announcement.title,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.edgeText,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUnreadMessagesSection(bool isSmallDevice) {
    return Consumer<MessageProvider>(
      builder: (context, messageProvider, child) {
        if (messageProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unread Messages',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${messageProvider.stats?['unread'] ?? 0} unread messages',
              style: const TextStyle(color: AppColors.edgeTextSecondary),
            ),
          ],
        );
      },
    );
  }
}
