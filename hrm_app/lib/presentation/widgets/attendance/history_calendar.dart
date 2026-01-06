import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/providers/attendance_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/data/models/attendance_model.dart';
import 'package:hrm_app/presentation/screens/employee/attendance_detail_screen.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HistoryCalendar extends StatefulWidget {
  final VoidCallback? onBack;
  const HistoryCalendar({super.key, this.onBack});

  @override
  State<HistoryCalendar> createState() => _HistoryCalendarState();
}

class _HistoryCalendarState extends State<HistoryCalendar> {
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(
        context,
        listen: false,
      ).getAttendanceForMonth(_focusedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Back Button
            GestureDetector(
              onTap: widget.onBack,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "Back",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Header
            const Text(
              "Attendance",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Quick Attendance Records for Everyone",
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            // Calendar Label
            Row(
              children: [
                const Text(
                  "Calendar",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Month Selector
            _buildMonthSelector(),
            const SizedBox(height: 24),

            // Calendar Grid
            _buildCalendarGrid(),

            const SizedBox(height: 16),
            // Legend
            _buildLegendCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
            });
            Provider.of<AttendanceProvider>(
              context,
              listen: false,
            ).getAttendanceForMonth(_focusedDay);
          },
          child: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 16),
        Text(
          DateFormat('MMMM yyyy').format(_focusedDay),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () {
            setState(() {
              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
            });
            Provider.of<AttendanceProvider>(
              context,
              listen: false,
            ).getAttendanceForMonth(_focusedDay);
          },
          child: const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final provider = Provider.of<AttendanceProvider>(context);

    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedDay.year,
      _focusedDay.month,
    );
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final int firstWeekday = firstDayOfMonth.weekday % 7; // 0 is Sunday

    // Total cells to display
    final totalCells = firstWeekday + daysInMonth;

    return Column(
      children: [
        // Days Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
            mainAxisSpacing: 16, // Space between rows
            crossAxisSpacing: 8,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < firstWeekday) {
              return const SizedBox.shrink();
            }

            final day = index - firstWeekday + 1;
            final date = DateTime(_focusedDay.year, _focusedDay.month, day);

            return _buildDateCell(date, provider);
          },
        ),
      ],
    );
  }

  Widget _buildDateCell(DateTime date, AttendanceProvider provider) {
    // Get status color from provider, but map it to our design colors
    // We assume provider gives generic colors, we might need to override.
    // Ideally we check specific status strings if possible, but color check is a proxy.

    // Logic:
    // Present -> Green
    // Absent -> Red
    // Holiday -> Blue
    // Leave -> Grey/LightGrey (Image shows Grey for 'On Leave')

    final statusColor = provider.getStatusColor(date);
    final isFuture = date.isAfter(DateTime.now());

    // Verify colors against design palette if needed, currently using what provider gives
    // but enforcing shape.

    // Force circular shape
    bool hasStatus = statusColor != Colors.transparent && !isFuture;

    // For weekends that are not marked, keep them plain
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    return InkWell(
      onTap: isFuture
          ? null
          : () {
              final record = provider.attendanceHistory.firstWhere(
                (r) => DateUtils.isSameDay(r.date, date),
                orElse: () =>
                    AttendanceRecord(date: date, status: 'Not Marked'),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceDetailScreen(record: record),
                ),
              );
            },
      customBorder: const CircleBorder(),
      child: Container(
        decoration: BoxDecoration(
          color: hasStatus ? statusColor : Colors.transparent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: hasStatus
                ? Colors.white
                : (isWeekend
                      ? AppColors.textSecondary.withOpacity(0.5)
                      : AppColors.textPrimary),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: "Note: ",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text:
                      "Track your attendance based on the colour shown below.",
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceAround,
            children: [
              _legendItem(const Color(0xFF00B359), 'Present'), // Green
              _legendItem(const Color(0xFFFF5252), 'Absent'), // Red
              _legendItem(const Color(0xFF2196F3), 'Holiday'), // Blue
              _legendItem(
                Colors.grey[300]!,
                'On Leave',
                textColor: AppColors.textSecondary,
              ), // Grey
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, {Color? textColor}) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 60, // Tall capsule
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
