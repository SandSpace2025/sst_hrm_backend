import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/providers/attendance_provider.dart';
import 'package:hrm_app/presentation/widgets/attendance/history_calendar.dart';
import 'package:hrm_app/presentation/widgets/attendance/live_attendance_card.dart';
import 'package:provider/provider.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Attendance'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          Consumer<AttendanceProvider>(
            builder: (context, provider, _) {
              if (provider.isDevMode) {
                return IconButton(
                  icon: const Icon(Icons.developer_mode),
                  onPressed: provider.toggleDevMode,
                  tooltip: 'Toggle Dev Mode',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: const SafeArea(
        child: Column(
          children: [
            LiveAttendanceCard(),

            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 20.0),
                  child: Column(
                    children: [HistoryCalendar(), SizedBox(height: 20)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
