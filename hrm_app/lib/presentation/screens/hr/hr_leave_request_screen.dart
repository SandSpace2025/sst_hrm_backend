import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/leave_request_provider.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/data/models/leave_request_model.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/leave_management/leave_request_list_item.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/leave_management/leave_request_stats.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HRLeaveRequestScreen extends StatefulWidget {
  final int initialTabIndex;
  const HRLeaveRequestScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HRLeaveRequestScreen> createState() => _HRLeaveRequestScreenState();
}

class _HRLeaveRequestScreenState extends State<HRLeaveRequestScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final leaveRequestProvider = Provider.of<LeaveRequestProvider>(
      context,
      listen: false,
    );

    if (authProvider.token != null) {
      leaveRequestProvider.loadLeaveRequests(authProvider.token!);
      leaveRequestProvider.loadLeaveRequestStats(authProvider.token!);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<LeaveRequestModel> _getFilteredRequests(
    List<LeaveRequestModel> requests,
  ) {
    if (_searchQuery.isEmpty) return requests;

    return requests.where((request) {
      return request.employeeName.toLowerCase().contains(_searchQuery) ||
          request.employeeIdNumber.toLowerCase().contains(_searchQuery) ||
          request.leaveType.toLowerCase().contains(_searchQuery) ||
          request.reason.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.edgeText.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by employee name, ID, or reason...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.edgeTextSecondary.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.edgePrimary,
                      ),
                    ),
                    filled: true,
                    fillColor: AppColors.edgeBackground,
                  ),
                ),
                const SizedBox(height: 16),

                LeaveRequestStatsWidget(isSmallDevice: isSmallDevice),
              ],
            ),
          ),

          Container(
            color: AppColors.edgeSurface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.edgePrimary,
              unselectedLabelColor: AppColors.edgeTextSecondary,
              indicatorColor: AppColors.edgePrimary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Pending'),
                Tab(text: 'Approved'),
                Tab(text: 'Rejected'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLeaveRequestList(null),
                _buildLeaveRequestList('pending'),
                _buildLeaveRequestList('approved'),
                _buildLeaveRequestList('rejected'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestList(String? status) {
    return Consumer<LeaveRequestProvider>(
      builder: (context, leaveRequestProvider, child) {
        if (leaveRequestProvider.isLoading &&
            leaveRequestProvider.leaveRequests.isEmpty) {
          return Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: List.generate(5, (index) => ShimmerLoading.listItem()),
            ),
          );
        }

        if (leaveRequestProvider.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.edgeError,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading leave requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.edgeText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    leaveRequestProvider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.edgeTextSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.edgePrimary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        List<LeaveRequestModel> requests = leaveRequestProvider.leaveRequests;

        if (status != null) {
          requests = requests
              .where((request) => request.status == status)
              .toList();
        }

        requests = _getFilteredRequests(requests);

        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: AppColors.edgeTextSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    status == null
                        ? 'No leave requests found'
                        : 'No $status leave requests',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.edgeText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Leave requests will appear here when employees submit them',
                    style: TextStyle(color: AppColors.edgeTextSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            if (authProvider.token != null) {
              await leaveRequestProvider.refreshLeaveRequests(
                authProvider.token!,
              );
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount:
                requests.length + (leaveRequestProvider.hasMoreData ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < requests.length) {
                return LeaveRequestListItem(
                  leaveRequest: requests[index],
                  onStatusUpdate: (newStatus, comments) async {
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    if (authProvider.token != null) {
                      final success = await leaveRequestProvider
                          .updateLeaveRequestStatus(
                            requests[index].id,
                            newStatus,
                            authProvider.token!,
                            adminComments: comments,
                          );

                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Leave request $newStatus successfully',
                            ),
                            backgroundColor: newStatus == 'approved'
                                ? AppColors.edgeAccent
                                : newStatus == 'rejected'
                                ? AppColors.edgeError
                                : AppColors.edgeWarning,
                          ),
                        );
                      }
                    }
                  },
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: leaveRequestProvider.isLoading
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: List.generate(
                              3,
                              (index) => ShimmerLoading.listItem(),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              if (authProvider.token != null) {
                                leaveRequestProvider.loadMoreLeaveRequests(
                                  authProvider.token!,
                                );
                              }
                            },
                            child: const Text('Load More'),
                          ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}
