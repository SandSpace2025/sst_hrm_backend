import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HRLeaveManagementPage extends StatefulWidget {
  final Map<String, dynamic> employee;

  const HRLeaveManagementPage({super.key, required this.employee});

  @override
  State<HRLeaveManagementPage> createState() => _HRLeaveManagementPageState();
}

class _HRLeaveManagementPageState extends State<HRLeaveManagementPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pageAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _casualLeaveController = TextEditingController();
  final _wfhLeaveController = TextEditingController();
  final _permissionHoursController = TextEditingController();
  final _carryOverCasualController = TextEditingController();
  final _carryOverWfhController = TextEditingController();
  final _carryOverPermissionController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;

  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    _pageAnimationController = AnimationController(
      vsync: this,
      duration: _animDuration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pageAnimationController, curve: _animCurve),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(parent: _pageAnimationController, curve: _animCurve),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmployeeLeaveData(forceRefresh: true);
      _pageAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _pageAnimationController.dispose();
    _casualLeaveController.dispose();
    _wfhLeaveController.dispose();
    _permissionHoursController.dispose();
    _carryOverCasualController.dispose();
    _carryOverWfhController.dispose();
    _carryOverPermissionController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployeeLeaveData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final hrProvider = Provider.of<HRProvider>(context, listen: false);

      if (authProvider.token != null) {
        await hrProvider.getEmployeeLeaveData(
          authProvider.token!,
          widget.employee['_id'],
          forceRefresh: forceRefresh,
        );

        final leaveData = hrProvider.employeeLeaveData;

        if (leaveData != null) {
          final casualLeave = (leaveData['leaveBalance']?['casualLeave'] ?? 1)
              .toString();
          final wfhLeave = (leaveData['leaveBalance']?['workFromHome'] ?? 1)
              .toString();
          final permissionHours =
              (leaveData['leaveBalance']?['permissionHours'] ?? 3).toString();

          _casualLeaveController.text = casualLeave;
          _wfhLeaveController.text = wfhLeave;
          _permissionHoursController.text = permissionHours;

          _carryOverCasualController.text = '0';
          _carryOverWfhController.text = '0';
          _carryOverPermissionController.text = '0';
        } else {}
      } else {}
    } catch (e) {
      _showErrorSnackbar('Failed to load leave data: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLeaveData() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final hrProvider = Provider.of<HRProvider>(context, listen: false);

      if (authProvider.token != null) {
        final leaveData = {
          'casualLeave': int.tryParse(_casualLeaveController.text) ?? 1,
          'workFromHome': int.tryParse(_wfhLeaveController.text) ?? 1,
          'permissionHours': int.tryParse(_permissionHoursController.text) ?? 3,
          'carryOverCasual': int.tryParse(_carryOverCasualController.text) ?? 0,
          'carryOverWfh': int.tryParse(_carryOverWfhController.text) ?? 0,
          'carryOverPermission':
              int.tryParse(_carryOverPermissionController.text) ?? 0,
        };

        await hrProvider.updateEmployeeLeaveData(
          authProvider.token!,
          widget.employee['_id'],
          leaveData,
        );

        _showSuccessSnackbar('Leave data updated successfully');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to update leave data: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.edgeAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.edgeError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: _animDuration,
                    switchInCurve: _animCurve,
                    switchOutCurve: _animCurve,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.03),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _buildAnimatedBody(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    return _buildBody();
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      key: const ValueKey('content'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAnimatedCard(child: _buildCurrentBalanceSection(), delay: 0),
          const SizedBox(height: 16),
          _buildAnimatedCard(child: _buildCarryOverSection(), delay: 50),
          const SizedBox(height: 20),
          _buildAnimatedCard(child: _buildSaveButton(), delay: 100),
        ],
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.edgeSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.edgeDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back, color: AppColors.edgeText),
            iconSize: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Leaves',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.employee['name'] ?? 'Employee',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.edgeTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await _loadEmployeeLeaveData(forceRefresh: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Leave data refreshed successfully'),
                    backgroundColor: AppColors.edgeAccent,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.refresh, color: AppColors.edgeText),
            tooltip: 'Refresh leave data',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      key: ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: AppColors.edgePrimary,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading leave data...',
            style: TextStyle(
              color: AppColors.edgeTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBalanceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.edgeDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.edgePrimary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.edgePrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Leave Balance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Monthly allocated leave days and hours',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.edgeTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLeaveInputGrid([
            _buildLeaveInputField(
              'Casual Leave',
              'days per month',
              _casualLeaveController,
              Icons.event_outlined,
              AppColors.edgeAccent,
            ),
            _buildLeaveInputField(
              'Work from Home',
              'days per month',
              _wfhLeaveController,
              Icons.home_outlined,
              AppColors.edgePrimary,
            ),
            _buildLeaveInputField(
              'Permission Hours',
              'hours per month',
              _permissionHoursController,
              Icons.access_time_outlined,
              AppColors.edgeWarning,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildCarryOverSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.edgeDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.edgeWarning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.edgeWarning.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.history_outlined,
                  color: AppColors.edgeWarning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carry-Over Leaves',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Additional leaves from previous months',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.edgeTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLeaveInputGrid([
            _buildLeaveInputField(
              'Carry-Over Casual',
              'additional days',
              _carryOverCasualController,
              Icons.event_available_outlined,
              AppColors.edgeAccent,
            ),
            _buildLeaveInputField(
              'Carry-Over WFH',
              'additional days',
              _carryOverWfhController,
              Icons.home_work_outlined,
              AppColors.edgePrimary,
            ),
            _buildLeaveInputField(
              'Carry-Over Permission',
              'additional hours',
              _carryOverPermissionController,
              Icons.schedule_outlined,
              AppColors.edgeWarning,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildLeaveInputGrid(List<Widget> inputFields) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: inputFields[0]),
            const SizedBox(width: 12),
            Expanded(child: inputFields[1]),
          ],
        ),
        const SizedBox(height: 16),

        if (inputFields.length > 2) inputFields[2],
      ],
    );
  }

  Widget _buildLeaveInputField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.edgeText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.edgeTextSecondary,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.edgeBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.edgeDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.edgeDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.edgeText,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveLeaveData,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.edgePrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
