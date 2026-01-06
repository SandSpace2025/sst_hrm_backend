import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/screens/employee/employee_eod_screen.dart';
import 'package:hrm_app/presentation/screens/employee/employee_leave_screen.dart';
import 'package:hrm_app/presentation/screens/employee/employee_messaging_screen.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/eod_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:intl/intl.dart';

class EmployeeActivityScreen extends StatefulWidget {
  const EmployeeActivityScreen({super.key});

  @override
  State<EmployeeActivityScreen> createState() => _EmployeeActivityScreenState();
}

class _EmployeeActivityScreenState extends State<EmployeeActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      appBar: AppBar(
        backgroundColor: AppColors.edgeBackground,
        toolbarHeight: 90, // Increased height for more top gap
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0), // Added left margin
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.edgePrimary,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        leadingWidth: 40, // Adjusted width to account for padding
        titleSpacing: 0,
        title: const Text(
          'Back',
          style: TextStyle(
            color: AppColors.edgePrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900, // Bold text
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Employee Activity',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.edgeText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your workplace activities!',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.edgeTextSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    labelColor: const Color(0xFF00C853), // Green active text
                    unselectedLabelColor: AppColors.edgeTextSecondary,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(
                        width: 3.0,
                        color: Color(0xFF00C853), // Green active indicator
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(2),
                        topRight: Radius.circular(2),
                      ),
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: const [
                      Tab(text: 'End of the Day'),
                      Tab(text: 'Leaves'),
                      Tab(text: 'Messages'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics:
            const NeverScrollableScrollPhysics(), // Disable swipe to avoid conflict with inner tabs
        children: const [
          _EODTab(),
          EmployeeLeaveScreen(),
          EmployeeMessagingScreen(),
        ],
      ),
    );
  }
}

class _EODTab extends StatefulWidget {
  const _EODTab();

  @override
  State<_EODTab> createState() => _EODTabState();
}

class _EODTabState extends State<_EODTab> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    // No default date - show all EODs by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final eodProvider = Provider.of<EODProvider>(context, listen: false);
    final token = authProvider.token;

    if (token != null) {
      // Check today's EOD status first
      await eodProvider.loadTodayEOD(token);

      // If a date is selected, filter by that specific date
      String? startDate;
      String? endDate;

      if (_selectedDate != null) {
        // Set start and end to the same date for single day filter
        final dateOnly = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        );
        startDate = dateOnly.toIso8601String();
        endDate = dateOnly.add(const Duration(days: 1)).toIso8601String();
      }

      await eodProvider.loadMyEODs(
        token,
        startDate: startDate,
        endDate: endDate,
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00C853),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textTheme: Theme.of(context).textTheme.copyWith(
              headlineMedium: const TextStyle(fontWeight: FontWeight.bold),
              titleMedium: const TextStyle(fontWeight: FontWeight.bold),
              bodyLarge: const TextStyle(fontWeight: FontWeight.w600),
              labelLarge: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  void _clearFilter() {
    setState(() {
      _selectedDate = null;
    });
    _loadData();
  }

  String _getFilterText() {
    if (_selectedDate == null) {
      return 'All EODs';
    }

    final formatter = DateFormat('MMM d, y');
    return formatter.format(_selectedDate!);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EODProvider>(
      builder: (context, eodProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: eodProvider.todayEOD != null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EmployeeEODScreen(),
                            ),
                          ).then((_) {
                            // Reload data when returning from EOD screen
                            _loadData();
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: eodProvider.todayEOD != null
                        ? Colors.grey[400]
                        : const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey[400],
                    disabledForegroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        eodProvider.todayEOD != null
                            ? 'Already submitted for today'
                            : 'Create a new report',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (eodProvider.todayEOD == null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.add, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Header and Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total EOD's",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.edgeText,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getFilterText(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedDate != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _clearFilter,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (eodProvider.isLoading)
                Column(
                  children: List.generate(
                    3,
                    (index) => ShimmerLoading.card(
                      height: 140,
                      margin: const EdgeInsets.only(bottom: 16),
                    ),
                  ),
                )
              else if (eodProvider.myEODs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedDate != null
                              ? 'No EODs submitted on ${DateFormat('MMM d, y').format(_selectedDate!)}'
                              : 'No reports found.',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try selecting another date',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: eodProvider.myEODs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final eod = eodProvider.myEODs[index];
                    return _buildEODCard(eod);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEODCard(Map<String, dynamic> eod) {
    // Parsing date
    String dateStr = '';
    if (eod['date'] != null) {
      try {
        final date = DateTime.parse(eod['date'].toString());
        dateStr = DateFormat('dd-MM-yyyy').format(date);
      } catch (e) {
        dateStr = 'Unknown Date';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00C853),
          width: 1,
        ), // Green border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9), // Light green bg
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF00C853),
                  size: 24,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployeeEODScreen(eodData: eod),
                    ),
                  ).then((_) {
                    // Reload data when returning from edit screen
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    final eodProvider = Provider.of<EODProvider>(
                      context,
                      listen: false,
                    );
                    if (authProvider.token != null) {
                      eodProvider.loadTodayEOD(authProvider.token!);
                      eodProvider.loadMyEODs(authProvider.token!);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Open',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Your report is submitted',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.edgeText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Date created: ',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF00C853), // Green for date
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Submitted by You',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
