import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hrm_app/data/models/attendance_model.dart';

class AttendanceDetailScreen extends StatelessWidget {
  final AttendanceRecord record;

  const AttendanceDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Attendance Details',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    DateFormat('d MMMM yyyy').format(record.date),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        record.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      record.status,
                      style: TextStyle(
                        color: _getStatusColor(record.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Work Hours',
                    _formatDuration(record.workingDuration),
                    Colors.blue,
                    Icons.access_time_filled_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Break Time',
                    _formatDuration(record.breakDuration),
                    Colors.orange,
                    Icons.coffee_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Text(
              'Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),

            // Timeline List
            if (record.sessions.isEmpty)
              _buildSimpleTimeline(record)
            else
              ...record.sessions
                  .map((session) => _buildSessionTimeline(session))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Fallback for old data or simple records
  Widget _buildSimpleTimeline(AttendanceRecord record) {
    if (record.clockInTime == null) {
      return const Center(child: Text('No punch data available'));
    }
    return Column(
      children: [
        _buildTimelineItem(
          time: DateFormat('hh:mm a').format(record.clockInTime!),
          title: 'Punch In',
          color: Colors.green,
          isFirst: true,
          isLast: record.clockOutTime == null,
        ),
        if (record.clockOutTime != null)
          _buildTimelineItem(
            time: DateFormat('hh:mm a').format(record.clockOutTime!),
            title: 'Punch Out',
            color: Colors.red,
            isFirst: false,
            isLast: true,
          ),
      ],
    );
  }

  Widget _buildSessionTimeline(dynamic session) {
    final checkIn = DateTime.parse(session['checkInTime']).toLocal();
    final checkOut = session['checkOutTime'] != null
        ? DateTime.parse(session['checkOutTime']).toLocal()
        : null;

    return Column(
      children: [
        _buildTimelineItem(
          time: DateFormat('hh:mm a').format(checkIn),
          title: 'Punch In',
          color: Colors.green,
          isFirst: false, // In a list of sessions, we can just show dots
          isLast: false,
        ),
        if (checkOut != null)
          _buildTimelineItem(
            time: DateFormat('hh:mm a').format(checkOut),
            title: 'Punch Out',
            color: Colors.red,
            isFirst: false,
            isLast: false,
          ),
        // Add a break visual if needed here
      ],
    );
  }

  Widget _buildTimelineItem({
    required String time,
    required String title,
    required Color color,
    required bool isFirst,
    required bool isLast,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (!isLast && !title.contains('Punch Out'))
                Container(width: 2, height: 40, color: Colors.grey[200]),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(
                bottom: 20,
              ), // Spacing between items
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[100]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return const Color(0xFF4CAF50);
      case 'Absent':
        return const Color(0xFFF44336);
      case 'Leave':
        return const Color(0xFF2196F3);
      case 'Weekend':
        return const Color(0xFF9E9E9E);
      case 'Holiday':
        return const Color(0xFFFFC107);
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    return "${twoDigits(duration.inHours)}h ${twoDigitMinutes}m";
  }
}
