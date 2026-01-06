part of 'employee_provider.dart';

extension EmployeeProviderNotifications on EmployeeProvider {
  List<Map<String, dynamic>> get notifications {
    List<Map<String, dynamic>> allNotifications = [];

    // 1. Add Announcements
    for (var announcement in _announcements) {
      if (announcement is Map<String, dynamic>) {
        allNotifications.add({
          'type': 'announcement',
          'title': announcement['title'] ?? 'New Announcement',
          'subtitle': announcement['message'] ?? announcement['content'] ?? '',
          'timestamp': DateTime.parse(
            announcement['createdAt'] ??
                announcement['timestamp'] ??
                DateTime.now().toIso8601String(),
          ),
          'data': announcement,
          'isRead': false, // Announcements don't strictly have read state yet
        });
      }
    }

    // 2. Add Unread/Recent Messages
    for (var conversation in _messages) {
      if (conversation is Map<String, dynamic>) {
        final lastMessage = conversation['lastMessage'];
        // Use 'partner' or similar based on how getConversations returns data
        // Checking structure based on previous knowledge or assumption
        // Actually messaging_repository returns conversations with 'partner' usually
        final partner = conversation['partner'];
        final senderName =
            partner?['name'] ?? partner?['fullName'] ?? 'Unknown';

        // Check if there are unread messages
        final unreadCount = conversation['unreadCount'] ?? 0;
        final isUnread = unreadCount > 0;

        if (lastMessage != null) {
          allNotifications.add({
            'type': 'message',
            'title': 'Message from $senderName',
            'subtitle': lastMessage['content'] ?? 'Sent an attachment',
            'timestamp': DateTime.parse(
              lastMessage['createdAt'] ?? DateTime.now().toIso8601String(),
            ),
            'data': conversation,
            'isRead': !isUnread,
          });
        }
      }
    }

    // 3. Add Leave Requests (Updates)
    for (var request in _leaveRequests) {
      if (request is Map<String, dynamic>) {
        final status = request['status'] ?? 'Pending';
        // Only show interesting updates, maybe? Or all?
        // Let's show all for now as a log

        String title = 'Leave Request Update';
        if (status == 'Approved') {
          title = 'Leave Request Approved';
        } else if (status == 'Rejected') {
          title = 'Leave Request Rejected';
        } else {
          title = 'Leave Request Sent';
        }

        allNotifications.add({
          'type': 'leave',
          'title': title,
          'subtitle':
              '${request['leaveType']} - ${request['status']}', // e.g. "Sick Leave - Pending"
          'timestamp': DateTime.parse(
            request['createdAt'] ?? DateTime.now().toIso8601String(),
          ),
          'data': request,
          'isRead': true, // Assume read for now as they are just status logs
        });
      }
    }

    // 4. Sort by timestamp descending (newest first)
    allNotifications.sort((a, b) {
      DateTime timeA = a['timestamp'];
      DateTime timeB = b['timestamp'];
      return timeB.compareTo(timeA);
    });

    return allNotifications;
  }
}
