import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/data/models/eod_model.dart';
import 'package:hrm_app/core/services/optimized_api_service.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class EodViewerScreen extends StatefulWidget {
  final Employee employee;
  const EodViewerScreen({super.key, required this.employee});

  @override
  State<EodViewerScreen> createState() => _EodViewerScreenState();
}

class _EodViewerScreenState extends State<EodViewerScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 400);
  static const Curve _animCurve = Curves.easeOutCubic;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<EodModel> _allEodReports = [];
  List<EodModel> _filteredEodReports = [];
  DateTime? _selectedDateFilter;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _animDuration);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEodData();
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  Future<void> _fetchEodData({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 1;
        _hasMoreData = true;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await OptimizedApiService.getEmployeeEODs(
        authProvider.token!,
        widget.employee.id,
        page: _currentPage,
        limit: 20,
      );

      final List<dynamic> eodData = response['eods'] ?? [];
      final List<EodModel> newEods = eodData
          .map((eod) => EodModel.fromJson(eod as Map<String, dynamic>))
          .toList();

      setState(() {
        if (loadMore) {
          _allEodReports.addAll(newEods);
        } else {
          _allEodReports.clear();
          _allEodReports.addAll(newEods);
        }

        _filteredEodReports = _allEodReports;
        _totalPages = response['totalPages'] ?? 1;
        _hasMoreData = _currentPage < _totalPages;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (!_hasMoreData || _isLoading) return;

    setState(() {
      _currentPage++;
    });

    await _fetchEodData(loadMore: true);
  }

  Future<void> _selectDateFilter(BuildContext context) async {
    _triggerHaptic();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.edgePrimary,
              onPrimary: AppColors.edgeSurface,
              surface: AppColors.edgeSurface,
              onSurface: AppColors.edgeText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateFilter = picked;
        _filteredEodReports = _allEodReports.where((report) {
          return report.date.year == picked.year &&
              report.date.month == picked.month &&
              report.date.day == picked.day;
        }).toList();
      });
    }
  }

  void _clearFilter() {
    _triggerHaptic();
    setState(() {
      _selectedDateFilter = null;
      _filteredEodReports = _allEodReports;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              if (_selectedDateFilter != null) _buildFilterChip(),
              Expanded(
                child: _isLoading && _allEodReports.isEmpty
                    ? _buildLoadingState()
                    : _error != null
                    ? _buildErrorState()
                    : _allEodReports.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'No EOD Reports Found',
                        message:
                            '${widget.employee.name} has not submitted any EODs yet.',
                      )
                    : _filteredEodReports.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.search_off,
                        title: 'No Report Found',
                        message:
                            'There is no EOD report for the selected date.',
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            _filteredEodReports.length + (_hasMoreData ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _filteredEodReports.length) {
                            return _buildLoadMoreButton();
                          }
                          return _buildAnimatedCard(
                            child: _buildEodCard(_filteredEodReports[index]),
                            delay: index * 50,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({required Widget child, required int delay}) {
    return TweenAnimationBuilder<double>(
      duration: _animDuration,
      curve: _animCurve,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'EODs for ${widget.employee.name}',
        style: const TextStyle(
          color: AppColors.edgeSurface,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          letterSpacing: -0.5,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.edgeSurface),
        onPressed: () {
          _triggerHaptic();
          Navigator.of(context).pop();
        },
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.calendar_today_outlined,
            color: AppColors.edgeSurface,
            size: 20,
          ),
          onPressed: () => _selectDateFilter(context),
          tooltip: 'Filter by Date',
        ),
      ],
      backgroundColor: AppColors.edgePrimary,
      elevation: 0,
    );
  }

  Widget _buildFilterChip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Chip(
          label: Text(
            'Date: ${DateFormat('MMM dd, yyyy').format(_selectedDateFilter!)}',
            style: const TextStyle(
              color: AppColors.edgePrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          onDeleted: _clearFilter,
          backgroundColor: AppColors.edgePrimary.withOpacity(0.1),
          deleteIconColor: AppColors.edgePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: AppColors.edgePrimary.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.edgeTextSecondary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.edgeTextSecondary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.edgeTextSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEodCard(EodModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.edgePrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM dd, yyyy').format(report.date),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    ...[
                      const SizedBox(height: 2),
                      Text(
                        'Submitted: ${report.formattedSubmittedAt}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.edgeTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.edgeDivider),
          const SizedBox(height: 16),

          if (report.projectName != null && report.projectName!.isNotEmpty)
            _buildDetailSection(
              icon: Icons.folder_outlined,
              iconColor: AppColors.edgePrimary,
              title: 'Project Name',
              content: report.projectName!,
            ),
          if (report.projectName != null && report.projectName!.isNotEmpty)
            const SizedBox(height: 16),

          if (report.taskDoneToday != null && report.taskDoneToday!.isNotEmpty)
            _buildDetailSection(
              icon: Icons.description_outlined,
              iconColor: AppColors.edgeAccent,
              title: 'Task Done Today',
              content: report.taskDoneToday!,
            ),
          if (report.taskDoneToday != null && report.taskDoneToday!.isNotEmpty)
            const SizedBox(height: 16),

          if (report.studentName != null && report.studentName!.isNotEmpty)
            _buildDetailSection(
              icon: Icons.person_outline_rounded,
              iconColor: AppColors.edgePrimary,
              title: 'Student Name',
              content: report.studentName!,
            ),
          if (report.studentName != null && report.studentName!.isNotEmpty)
            const SizedBox(height: 16),

          if (report.technology != null && report.technology!.isNotEmpty)
            _buildDetailSection(
              icon: Icons.code_outlined,
              iconColor: AppColors.edgeAccent,
              title: 'Technology',
              content: report.technology!,
            ),
          if (report.technology != null && report.technology!.isNotEmpty)
            const SizedBox(height: 16),

          if (report.taskType != null && report.taskType!.isNotEmpty)
            _buildDetailSection(
              icon: Icons.category_outlined,
              iconColor: AppColors.edgePrimary,
              title: 'Task Type',
              content: report.taskType!,
            ),
          if (report.taskType != null && report.taskType!.isNotEmpty)
            const SizedBox(height: 16),

          if (report.projectStatus != null)
            _buildDetailSection(
              icon: Icons.trending_up_outlined,
              iconColor: AppColors.edgeAccent,
              title: 'Project Status',
              content: '${report.projectStatus!.toInt()}%',
            ),
          if (report.projectStatus != null) const SizedBox(height: 16),

          if (report.deadline != null)
            _buildDetailSection(
              icon: Icons.event_outlined,
              iconColor: AppColors.edgeWarning,
              title: 'Deadline',
              content: DateFormat('MMM dd, yyyy').format(report.deadline!),
            ),
          if (report.deadline != null) const SizedBox(height: 16),

          if (report.daysTaken != null && report.daysTaken! > 0)
            _buildDetailSection(
              icon: Icons.schedule_outlined,
              iconColor: AppColors.edgePrimary,
              title: 'Days Taken',
              content: '${report.daysTaken} days',
            ),
          if (report.daysTaken != null && report.daysTaken! > 0)
            const SizedBox(height: 16),

          if (report.reportSent != null)
            _buildDetailSection(
              icon: Icons.send_outlined,
              iconColor: AppColors.edgeAccent,
              title: 'Report Sent',
              content: report.reportSent! ? 'Yes' : 'No',
            ),
          if (report.reportSent != null) const SizedBox(height: 16),

          if (report.personWorkingOnReport != null &&
              report.personWorkingOnReport!.isNotEmpty)
            _buildDetailSection(
              icon: Icons.assignment_outlined,
              iconColor: AppColors.edgePrimary,
              title: 'Person Working on Report',
              content: report.personWorkingOnReport!,
            ),
          if (report.personWorkingOnReport != null &&
              report.personWorkingOnReport!.isNotEmpty)
            const SizedBox(height: 16),

          if (report.reportStatus != null && report.reportStatus!.isNotEmpty)
            _buildDetailSection(
              icon: Icons.assessment_outlined,
              iconColor: AppColors.edgeAccent,
              title: 'Report Status',
              content: report.reportStatus!,
            ),
          if (report.reportStatus != null && report.reportStatus!.isNotEmpty)
            const SizedBox(height: 16),

          if (report.challengesFaced != null &&
              report.challengesFaced!.isNotEmpty)
            _buildDetailSection(
              icon: Icons.warning_amber_outlined,
              iconColor: AppColors.edgeWarning,
              title: 'Challenges Faced',
              content: report.challengesFaced!,
            ),
          if (report.challengesFaced != null &&
              report.challengesFaced!.isNotEmpty)
            const SizedBox(height: 16),

          if ((report.projectName == null || report.projectName!.isEmpty) &&
              report.project.isNotEmpty)
            _buildDetailSection(
              icon: Icons.work_outline,
              iconColor: AppColors.edgePrimary,
              title: 'Project (Legacy)',
              content: report.project,
            ),
          if ((report.projectName == null || report.projectName!.isEmpty) &&
              report.project.isNotEmpty)
            const SizedBox(height: 16),

          if ((report.taskDoneToday == null || report.taskDoneToday!.isEmpty) &&
              report.tasksCompleted.isNotEmpty)
            _buildDetailSection(
              icon: Icons.check_circle_outline,
              iconColor: AppColors.edgeAccent,
              title: 'Tasks Completed (Legacy)',
              content: report.tasksCompleted,
            ),
          if ((report.taskDoneToday == null || report.taskDoneToday!.isEmpty) &&
              report.tasksCompleted.isNotEmpty)
            const SizedBox(height: 16),

          if ((report.challengesFaced == null ||
                  report.challengesFaced!.isEmpty) &&
              report.challenges.isNotEmpty)
            _buildDetailSection(
              icon: Icons.warning_amber_outlined,
              iconColor: AppColors.edgeWarning,
              title: 'Challenges (Legacy)',
              content: report.challenges,
            ),
          if ((report.challengesFaced == null ||
                  report.challengesFaced!.isEmpty) &&
              report.challenges.isNotEmpty)
            const SizedBox(height: 16),

          if (report.nextDayPlan.isNotEmpty)
            _buildDetailSection(
              icon: Icons.arrow_forward_outlined,
              iconColor: AppColors.edgeSecondary,
              title: 'Plan for Next Day',
              content: report.nextDayPlan,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 24.0),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.edgeTextSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.edgePrimary,
            strokeWidth: 2.5,
          ),
          SizedBox(height: 16),
          Text(
            'Loading EOD reports...',
            style: TextStyle(fontSize: 14, color: AppColors.edgeTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.edgeError.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.edgeError,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to Load EOD Reports',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.edgeTextSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _fetchEodData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.edgePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator(
                color: AppColors.edgePrimary,
                strokeWidth: 2.5,
              )
            : ElevatedButton(
                onPressed: _loadMoreData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.edgePrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Load More'),
              ),
      ),
    );
  }
}
