import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_loading_state.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_error_state.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_empty_state.dart';

class EmployeeSummaryCardsWidget extends StatefulWidget {
  final VoidCallback? onUnreadTap;
  const EmployeeSummaryCardsWidget({super.key, this.onUnreadTap});

  @override
  State<EmployeeSummaryCardsWidget> createState() =>
      _EmployeeSummaryCardsWidgetState();
}

class _EmployeeSummaryCardsWidgetState extends State<EmployeeSummaryCardsWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController1;
  late AnimationController _pulseController2;
  late AnimationController _pulseController3;
  late AnimationController _pulseController4;
  late Animation<double> _pulseAnimation1;
  late Animation<double> _pulseAnimation2;
  late Animation<double> _pulseAnimation3;
  late Animation<double> _pulseAnimation4;

  @override
  void initState() {
    super.initState();

    _pulseController1 = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController2 = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController3 = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController4 = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    Future.delayed(
      Duration.zero,
      () => _pulseController1.repeat(reverse: true),
    );
    Future.delayed(
      const Duration(milliseconds: 500),
      () => _pulseController2.repeat(reverse: true),
    );
    Future.delayed(
      const Duration(milliseconds: 1000),
      () => _pulseController3.repeat(reverse: true),
    );
    Future.delayed(
      const Duration(milliseconds: 1500),
      () => _pulseController4.repeat(reverse: true),
    );

    _pulseAnimation1 = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController1, curve: Curves.easeInOut),
    );

    _pulseAnimation2 = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController2, curve: Curves.easeInOut),
    );

    _pulseAnimation3 = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController3, curve: Curves.easeInOut),
    );

    _pulseAnimation4 = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController4, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController1.dispose();
    _pulseController2.dispose();
    _pulseController3.dispose();
    _pulseController4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        final dashboardData = employeeProvider.dashboardData;

        if (employeeProvider.isLoading) {
          return const CustomLoadingState(message: 'Loading summary...');
        }

        if (employeeProvider.error != null) {
          return CustomErrorState(message: employeeProvider.error!);
        }

        if (dashboardData == null) {
          return const CustomEmptyState(
            title: 'No data available',
            subtitle: 'Dashboard data invalid or empty',
            icon: Icons.dashboard_outlined,
          );
        }

        return _buildDashboard(
          dashboardData: dashboardData,
          employeeProvider: employeeProvider,
        );
      },
    );
  }

  String _getLeaveBalanceValue(EmployeeProvider employeeProvider) {
    final leaveBalance = employeeProvider.leaveBalance;
    final dashboardData = employeeProvider.dashboardData;

    String extractNumericValue(dynamic data) {
      if (data == null) return '0';
      if (data is num) return '${data.toInt()}';
      if (data is String) {
        final parsed = int.tryParse(data);
        if (parsed != null) return '$parsed';
      }
      if (data is Map) {
        final commonKeys = [
          'totalBalance',
          'availableBalance',
          'balance',
          'remaining',
          'total',
          'available',
          'days',
          'count',
          'value',
        ];
        for (String key in commonKeys) {
          if (data[key] is num) return '${data[key].toInt()}';
        }
        for (var value in data.values) {
          if (value is num) return '${value.toInt()}';
        }
      }
      return '0';
    }

    if (leaveBalance != null) {
      final result = extractNumericValue(leaveBalance);
      if (result != '0') return result;
    }

    if (dashboardData != null && dashboardData['leaveBalance'] != null) {
      final result = extractNumericValue(dashboardData['leaveBalance']);
      if (result != '0') return result;
    }

    return '0';
  }

  Widget _buildDashboard({
    required Map<String, dynamic> dashboardData,
    required EmployeeProvider employeeProvider,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 900;

        final containerHeight = isMobile ? 350.0 : (isTablet ? 380.0 : 420.0);
        final padding = isMobile ? 24.0 : (isTablet ? 50.0 : 24.0);
        final iconSize = isMobile ? 22.0 : 26.0;

        return Container(
          height: containerHeight,
          margin: EdgeInsets.symmetric(horizontal: padding / 2),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: isMobile ? 240 : (isTablet ? 260 : 280),
                  height: isMobile ? 240 : (isTablet ? 260 : 280),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.blueColor.withOpacity(0.05),
                    border: Border.all(
                      color: AppColors.blueColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
              ),

              Center(
                child: CustomPaint(
                  size: Size(
                    containerHeight - padding * 2,
                    containerHeight - padding * 2,
                  ),
                  painter: DashboardConnectionsPainter(
                    orangeColor: AppColors.orangeColor,
                    blueColor: AppColors.blueColor,
                    greenColor: AppColors.greenColor,
                    redColor: AppColors.redColor,
                    centerRadius: isMobile ? 60 : (isTablet ? 70 : 80),
                    padding: padding,
                    containerHeight: containerHeight,
                    iconSize: iconSize,
                  ),
                ),
              ),

              Center(
                child: Container(
                  width: isMobile ? 120 : (isTablet ? 140 : 160),
                  height: isMobile ? 120 : (isTablet ? 140 : 160),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 20 : 25),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              _buildMetricsOverlay(
                dashboardData: dashboardData,
                employeeProvider: employeeProvider,
                isMobile: isMobile,
                padding: padding,
                iconSize: iconSize,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsOverlay({
    required Map<String, dynamic> dashboardData,
    required EmployeeProvider employeeProvider,
    required bool isMobile,
    required double padding,
    required double iconSize,
  }) {
    return Stack(
      children: [
        Positioned(
          top: padding,
          left: padding,
          child: _buildMetricCard(
            label: 'PENDING EOD',
            value: '${dashboardData['pendingEOD'] ?? 0}',
            subtitle: 'Submit today\'s report',
            icon: Icons.work_outline_rounded,
            color: AppColors.orangeColor,
            isMobile: isMobile,
            alignment: Alignment.centerLeft,
            iconSize: iconSize,
            animation: _pulseAnimation1,
          ),
        ),

        Positioned(
          top: padding,
          right: padding,
          child: _buildMetricCard(
            label: 'LEAVE BALANCE',
            value: _getLeaveBalanceValue(employeeProvider),
            subtitle: 'Days remaining',
            icon: Icons.calendar_today_outlined,
            color: AppColors.greenColor,
            isMobile: isMobile,
            alignment: Alignment.centerRight,
            iconSize: iconSize,
            animation: _pulseAnimation2,
          ),
        ),

        Positioned(
          bottom: padding,
          left: padding,
          child: GestureDetector(
            onTap: widget.onUnreadTap,
            child: _buildMetricCard(
              label: 'UNREAD MESSAGES',
              value: '${employeeProvider.unreadMessagesCount}',
              subtitle: 'New notifications',
              icon: Icons.chat_bubble_outline_rounded,
              color: AppColors.blueColor,
              isMobile: isMobile,
              alignment: Alignment.centerLeft,
              iconSize: iconSize,
              animation: _pulseAnimation3,
            ),
          ),
        ),

        Positioned(
          bottom: padding,
          right: padding,
          child: _buildMetricCard(
            label: 'PENDING LEAVES',
            value: '${dashboardData['pendingLeaves'] ?? 0}',
            subtitle: 'Awaiting approval',
            icon: Icons.description_outlined,
            color: AppColors.redColor,
            isMobile: isMobile,
            alignment: Alignment.centerRight,
            iconSize: iconSize,
            animation: _pulseAnimation4,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isMobile,
    required Alignment alignment,
    required double iconSize,
    required Animation<double> animation,
  }) {
    final isRightAligned = alignment == Alignment.centerRight;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),

                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),

                BoxShadow(
                  color: color.withOpacity(0.05),
                  blurRadius: 70,
                  spreadRadius: 15,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: isRightAligned
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 9.5 : 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: isMobile ? 6 : 8),

          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: isRightAligned
                ? [
                    Icon(icon, color: color, size: iconSize),
                    const SizedBox(width: 8),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isMobile ? 36 : 42,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1.0,
                      ),
                    ),
                  ]
                : [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isMobile ? 36 : 42,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: color, size: iconSize),
                  ],
          ),
          const SizedBox(height: 4),

          SizedBox(
            width: isMobile ? 100 : 120,
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: isMobile ? 10.5 : 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
              textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardConnectionsPainter extends CustomPainter {
  final Color orangeColor;
  final Color blueColor;
  final Color greenColor;
  final Color redColor;
  final double centerRadius;
  final double padding;
  final double containerHeight;
  final double iconSize;

  DashboardConnectionsPainter({
    required this.orangeColor,
    required this.blueColor,
    required this.greenColor,
    required this.redColor,
    required this.centerRadius,
    required this.padding,
    required this.containerHeight,
    required this.iconSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final iconPositions = _calculateIconPositions(size);

    _drawDecorativeArcs(canvas, center, size);

    _drawConnectionLines(canvas, center, iconPositions);
  }

  Map<String, Offset> _calculateIconPositions(Size size) {
    final labelHeight = 11.0;
    final topOffset = 5.0;

    final topLeft = Offset(padding + 50.0, padding + topOffset);

    final topRight = Offset(size.width - padding - 50.0, padding + topOffset);

    final bottomLeft = Offset(
      padding + 50.0,
      size.height - padding - labelHeight * 4,
    );

    final bottomRight = Offset(
      size.width - padding - 50.0,
      size.height - padding - labelHeight * 4,
    );

    return {
      'topLeft': topLeft,
      'topRight': topRight,
      'bottomLeft': bottomLeft,
      'bottomRight': bottomRight,
    };
  }

  void _drawDecorativeArcs(Canvas canvas, Offset center, Size size) {
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final arcRadius1 = centerRadius + 15;
    final arcRadius2 = centerRadius + 25;
    final arcRadius3 = centerRadius + 35;

    arcPaint.color = orangeColor.withOpacity(0.3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcRadius1),
      pi * 1.2,
      pi * 0.3,
      false,
      arcPaint,
    );

    arcPaint.color = greenColor.withOpacity(0.3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcRadius2),
      -pi * 0.3,
      pi * 0.3,
      false,
      arcPaint,
    );

    arcPaint.color = blueColor.withOpacity(0.3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcRadius3),
      pi * 0.7,
      pi * 0.3,
      false,
      arcPaint,
    );

    arcPaint.color = redColor.withOpacity(0.3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcRadius1),
      pi * 0.2,
      pi * 0.3,
      false,
      arcPaint,
    );
  }

  void _drawConnectionLines(
    Canvas canvas,
    Offset center,
    Map<String, Offset> iconPositions,
  ) {
    _drawDottedLine(
      canvas,
      center,
      iconPositions['topLeft']!,
      orangeColor,
      centerRadius,
    );
    _drawDottedLine(
      canvas,
      center,
      iconPositions['topRight']!,
      greenColor,
      centerRadius,
    );
    _drawDottedLine(
      canvas,
      center,
      iconPositions['bottomLeft']!,
      blueColor,
      centerRadius,
    );
    _drawDottedLine(
      canvas,
      center,
      iconPositions['bottomRight']!,
      redColor,
      centerRadius,
    );
  }

  void _drawDottedLine(
    Canvas canvas,
    Offset center,
    Offset target,
    Color color,
    double startRadius,
  ) {
    final angle = atan2(target.dy - center.dy, target.dx - center.dx);

    final startPoint = Offset(
      center.dx + startRadius * cos(angle),
      center.dy + startRadius * sin(angle),
    );

    final lineDistance = sqrt(
      pow(target.dx - startPoint.dx, 2) + pow(target.dy - startPoint.dy, 2),
    );

    if (lineDistance < 20) return;

    final path = Path();
    path.moveTo(startPoint.dx, startPoint.dy);

    final midX = (startPoint.dx + target.dx) / 2;
    final midY = (startPoint.dy + target.dy) / 2;

    final curveOffset = lineDistance * 0.1;

    final controlPoint = Offset(
      midX + curveOffset * cos(angle + pi / 2),
      midY + curveOffset * sin(angle + pi / 2),
    );

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      target.dx,
      target.dy,
    );

    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;
    double distance = 0;
    const dashLength = 5.0;
    const gapLength = 5.0;

    while (distance < totalLength) {
      final start = metrics.getTangentForOffset(distance)?.position;
      final end = metrics
          .getTangentForOffset(min(distance + dashLength, totalLength))
          ?.position;

      if (start != null && end != null) {
        canvas.drawLine(start, end, paint);
      }

      distance += dashLength + gapLength;
    }

    distance = dashLength + gapLength;
    final dotPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    while (distance < totalLength) {
      final pos = metrics.getTangentForOffset(distance)?.position;
      if (pos != null && distance % (dashLength * 3) < dashLength) {
        canvas.drawCircle(pos, 3, dotPaint);
      }
      distance += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
