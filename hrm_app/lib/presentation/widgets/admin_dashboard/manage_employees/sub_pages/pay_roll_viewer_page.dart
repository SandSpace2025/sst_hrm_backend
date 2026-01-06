import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/payroll_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class PayrollPage extends StatefulWidget {
  final Employee employee;

  const PayrollPage({super.key, required this.employee});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage>
    with SingleTickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeOutCubic;

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  late final PayrollProvider _payrollProvider;
  late final AnimationController _pageAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  final TextEditingController _basicCtrl = TextEditingController(text: '0');
  final TextEditingController _hraCtrl = TextEditingController(text: '0');
  final TextEditingController _pfCtrl = TextEditingController(text: '0');
  final TextEditingController _esiCtrl = TextEditingController(text: '0');
  final TextEditingController _ptCtrl = TextEditingController(text: '0');
  final TextEditingController _lopCtrl = TextEditingController(text: '0');
  final TextEditingController _penaltyCtrl = TextEditingController(text: '0');

  final TextEditingController _panCtrl = TextEditingController();
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _accountNumberCtrl = TextEditingController();
  final TextEditingController _pfNumberCtrl = TextEditingController();
  final TextEditingController _uanCtrl = TextEditingController();
  final TextEditingController _paidDaysCtrl = TextEditingController();
  final TextEditingController _lopDaysCtrl = TextEditingController();
  double _sandGross = 0;
  double _sandDeductions = 0;
  double _sandNet = 0;
  bool _sandspaceInitialized = false;
  bool _sandInitScheduled = false;

  @override
  void initState() {
    super.initState();
    _payrollProvider = PayrollProvider();

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
      _fetchData();
      _pageAnimationController.forward();
    });
  }

  bool get _isSandspaceOrg =>
      widget.employee.subOrganisation.toLowerCase().contains('sandspace');

  void _initSandspaceDefaultsFromProvider(PayrollProvider provider) {
    final total =
        double.tryParse(provider.totalPayController.text.replaceAll(',', '')) ??
        0.0;
    if (total > 0) {
      final basic = total * 0.65;
      final hra = total * 0.25;
      _basicCtrl.text = basic.toStringAsFixed(2);
      _hraCtrl.text = hra.toStringAsFixed(2);
    }
    _computeSandspaceTotals();

    for (final c in [
      _basicCtrl,
      _hraCtrl,
      _pfCtrl,
      _esiCtrl,
      _ptCtrl,
      _lopCtrl,
      _penaltyCtrl,
    ]) {
      c.addListener(() => _recalcSandspace(provider));
    }
  }

  void _recalcSandspace(PayrollProvider provider) {
    _computeSandspaceTotals();
    if (mounted) setState(() {});
  }

  void _computeSandspaceTotals() {
    double toD(String s) => double.tryParse(s.replaceAll(',', '')) ?? 0.0;
    final basic = toD(_basicCtrl.text);
    final hra = toD(_hraCtrl.text);
    final pf = toD(_pfCtrl.text);
    final esi = toD(_esiCtrl.text);
    final pt = toD(_ptCtrl.text);
    final lop = toD(_lopCtrl.text);
    final pen = toD(_penaltyCtrl.text);
    _sandGross = basic + hra;
    _sandDeductions = pf + esi + pt + lop + pen;
    _sandNet = (_sandGross - _sandDeductions).clamp(0, double.infinity);
  }

  Future<void> _fetchData() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      await _payrollProvider.fetchPayrollData(widget.employee.id, token);
    }
  }

  @override
  void dispose() {
    _pageAnimationController.dispose();
    _payrollProvider.dispose();
    _basicCtrl.dispose();
    _hraCtrl.dispose();
    _pfCtrl.dispose();
    _esiCtrl.dispose();
    _ptCtrl.dispose();
    _lopCtrl.dispose();
    _penaltyCtrl.dispose();
    _panCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _pfNumberCtrl.dispose();
    _uanCtrl.dispose();
    _paidDaysCtrl.dispose();
    _lopDaysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _payrollProvider,
      child: Scaffold(
        backgroundColor: AppColors.edgeSurface,
        appBar: _buildAppBar(),
        bottomNavigationBar: Consumer<PayrollProvider>(
          builder: (context, provider, _) {
            final token =
                Provider.of<AuthProvider>(context, listen: false).token ?? '';
            final bool recordExists = provider.selectedPayroll != null;
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.edgeSurface,
                border: Border(
                  top: BorderSide(color: AppColors.edgeDivider, width: 1),
                ),
              ),
              child: Row(
                children: [
                  if (recordExists)
                    IconButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => _showDeleteDialog(context, provider, token),
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.edgeError,
                      tooltip: 'Delete',
                    ),
                  if (recordExists) const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: provider.isSaving
                            ? null
                            : () =>
                                  _handleSavePayroll(context, provider, token),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.edgePrimary,
                          foregroundColor: AppColors.edgeSurface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: provider.isSaving
                              ? const SizedBox(
                                  key: ValueKey('saving'),
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  recordExists
                                      ? 'Update Payslip'
                                      : 'Create Payslip',
                                  key: const ValueKey('label'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Consumer<PayrollProvider>(
              builder: (context, payrollProvider, child) {
                return AnimatedSwitcher(
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
                  child: _buildAnimatedBody(context, payrollProvider),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBody(
    BuildContext context,
    PayrollProvider payrollProvider,
  ) {
    if (payrollProvider.isLoading) {
      return _buildLoadingState();
    }
    if (payrollProvider.error != null) {
      return _buildErrorWidget(payrollProvider);
    }
    return _buildBody(context, payrollProvider);
  }

  Widget _buildBody(BuildContext context, PayrollProvider payrollProvider) {
    return SingleChildScrollView(
      key: const ValueKey('content'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAnimatedCard(child: _buildEmployeeHeaderCard(), delay: 0),
          const SizedBox(height: 16),
          _buildAnimatedCard(
            child: _buildSummaryCards(payrollProvider),
            delay: 50,
          ),
          const SizedBox(height: 16),
          _buildAnimatedCard(
            child: _buildPayrollDetailsCard(payrollProvider),
            delay: 100,
          ),
          const SizedBox(height: 20),
          _buildAnimatedCard(
            child: _buildActionButtons(context, payrollProvider),
            delay: 150,
          ),
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

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Payroll Management',
        style: TextStyle(
          color: AppColors.edgeSurface,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.edgeSurface,
        ),
        onPressed: () {
          _triggerHaptic();
          Navigator.of(context).pop();
        },
      ),
      centerTitle: true,
      backgroundColor: AppColors.edgePrimary,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.edgePrimary,
              AppColors.edgePrimary.withOpacity(0.8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(PayrollProvider provider) {
    final selectedPeriod = provider.selectedPayPeriod;
    final payday = DateTime(selectedPeriod.year, selectedPeriod.month + 1, 10);

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: DateFormat('MMMM yyyy').format(selectedPeriod),
            value: provider.currencyFormat.format(
              double.tryParse(
                    provider.totalPayController.text.replaceAll(',', ''),
                  ) ??
                  0.0,
            ),
            icon: Icons.payments_outlined,
            color: AppColors.edgeAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Next Payday',
            value: DateFormat('MMM dd, yyyy').format(payday),
            icon: Icons.calendar_today_outlined,
            color: AppColors.edgePrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: _animDuration,
      curve: _animCurve,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.edgeTextSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeHeaderCard() {
    final bool isPhoneMissing = widget.employee.phone.isEmpty;

    return AnimatedContainer(
      duration: _animDuration,
      curve: _animCurve,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgePrimary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.edgePrimary.withOpacity(0.04),
            blurRadius: 4,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.edgePrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.employee.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.edgeText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Employee Details',
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
          const SizedBox(height: 20),
          _buildEmployeeDetailRow(
            icon: Icons.badge_rounded,
            text: widget.employee.employeeId,
          ),
          const SizedBox(height: 12),
          _buildEmployeeDetailRow(
            icon: Icons.email_rounded,
            text: widget.employee.email,
          ),
          const SizedBox(height: 12),
          _buildEmployeeDetailRow(
            icon: Icons.phone_rounded,
            text: isPhoneMissing
                ? 'To be updated by employee'
                : widget.employee.phone,
            textColor: isPhoneMissing
                ? AppColors.edgeError
                : AppColors.edgeTextSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDetailRow({
    required IconData icon,
    required String text,
    Color? textColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.edgePrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: AppColors.edgePrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: textColor ?? AppColors.edgeText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayrollDetailsCard(PayrollProvider provider) {
    if (!_sandspaceInitialized && !_sandInitScheduled) {
      _sandInitScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initSandspaceDefaultsFromProvider(provider);
        _sandspaceInitialized = true;
        _sandInitScheduled = false;
        setState(() {});
      });
    }
    return _buildSandspaceEditor(provider);
  }

  Widget _buildSandspaceEditor(PayrollProvider provider) {
    String fmt(double v) => provider.currencyFormat.format(v);

    Widget moneyField(String label, TextEditingController ctrl) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.edgeTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              height: 40,
              child: TextFormField(
                controller: ctrl,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixText: '₹',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.black87, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.black87, width: 1),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.black54, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.black, width: 1.5),
                  ),
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.edgeText,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget divider() => Container(height: 1, color: AppColors.edgeDivider);

    Widget sectionHeader(String title) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.edgeBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.edgeDivider, width: 1),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.edgeText,
            letterSpacing: -0.2,
          ),
        ),
      );
    }

    Widget headerRow(String left, String right) {
      return Row(
        children: [
          const Icon(
            Icons.list_alt_outlined,
            size: 14,
            color: AppColors.edgeTextSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              left,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.edgeTextSecondary,
              ),
            ),
          ),
          Text(
            right,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.edgeTextSecondary,
            ),
          ),
        ],
      );
    }

    Widget buildReadOnlyField(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '$label:',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.edgeTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.edgeBackground,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.edgeDivider, width: 1),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.edgeText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final payPeriod = DateFormat(
      'MMMM yyyy',
    ).format(provider.selectedPayPeriod);

    return AnimatedContainer(
      duration: _animDuration,
      curve: _animCurve,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeAccent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.edgeDivider, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.edgePrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.edgePrimary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    size: 80,
                    color: AppColors.edgePrimary,
                  ),
                ),
                const SizedBox(width: 20),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employee.subOrganisation.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.edgeText,
                          letterSpacing: 0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Payslip for the month of ${DateFormat('MMMM yyyy').format(provider.selectedPayPeriod)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.edgeTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          sectionHeader('Employee Pay Summary'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const double labelWidth = 130;

              Widget leftCard() => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.edgeSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.edgeDivider, width: 1),
                ),
                child: Column(
                  children: [
                    buildReadOnlyField('Employee Name', widget.employee.name),
                    buildReadOnlyField('Emp Code', widget.employee.employeeId),
                    buildReadOnlyField(
                      'Designation',
                      widget.employee.jobTitle.isEmpty
                          ? 'N/A'
                          : widget.employee.jobTitle,
                    ),
                    buildReadOnlyField('Joining Date', 'N/A'),
                    buildReadOnlyField('Pay Period', payPeriod),
                  ],
                ),
              );

              Widget labeledInput(
                String label,
                TextEditingController ctrl, {
                bool numeric = false,
              }) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Text(
                          '$label:',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.edgeTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextFormField(
                            controller: ctrl,
                            keyboardType: numeric
                                ? const TextInputType.numberWithOptions(
                                    decimal: false,
                                  )
                                : TextInputType.text,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Colors.black87,
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Colors.black87,
                                  width: 1,
                                ),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Colors.black54,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.edgeText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              Widget rightCard() => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.edgeSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.edgeDivider, width: 1),
                ),
                child: Column(
                  children: [
                    labeledInput('PAN', _panCtrl),
                    labeledInput('Bank Name', _bankNameCtrl),
                    labeledInput(
                      'Account Number',
                      _accountNumberCtrl,
                      numeric: true,
                    ),
                    labeledInput('PF Number', _pfNumberCtrl),
                    labeledInput('UAN No', _uanCtrl, numeric: true),
                    labeledInput('Paid Days', _paidDaysCtrl, numeric: true),
                    labeledInput('LOP Days', _lopDaysCtrl, numeric: true),
                  ],
                ),
              );

              final isWide = constraints.maxWidth >= 720;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftCard()),
                    const SizedBox(width: 16),
                    Expanded(child: rightCard()),
                  ],
                );
              }
              return Column(
                children: [leftCard(), const SizedBox(height: 12), rightCard()],
              );
            },
          ),

          const SizedBox(height: 16),
          divider(),
          const SizedBox(height: 16),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader('EARNINGS'),
              const SizedBox(height: 12),
              headerRow('Component', 'Amount'),
              const SizedBox(height: 6),
              moneyField('Basic Salary', _basicCtrl),
              moneyField('House Rent Allowance', _hraCtrl),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gross Earnings',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.edgeText,
                    ),
                  ),
                  Text(
                    fmt(_sandGross),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.edgeText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              divider(),
              const SizedBox(height: 16),

              sectionHeader('DEDUCTIONS'),
              const SizedBox(height: 12),
              headerRow('Component', 'Amount'),
              const SizedBox(height: 6),
              moneyField('PF', _pfCtrl),
              moneyField('ESI', _esiCtrl),
              moneyField('Professional Tax', _ptCtrl),
              moneyField('LOP', _lopCtrl),
              moneyField('Penalties', _penaltyCtrl),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Deductions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.edgeText,
                    ),
                  ),
                  Text(
                    fmt(_sandDeductions),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.edgeText,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          divider(),
          const SizedBox(height: 12),

          sectionHeader('NETPAY'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gross Earnings',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.edgeTextSecondary,
                ),
              ),
              Text(
                fmt(_sandGross),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.edgeText,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Deductions',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.edgeTextSecondary,
                ),
              ),
              Text(
                fmt(_sandDeductions),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.edgeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Net Payable',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.edgeText,
                ),
              ),
              Text(
                fmt(_sandNet),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.edgeAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    String? sublabel,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.edgeTextSecondary,
                  ),
                ),
                if (sublabel != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.edgeTextSecondary.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required String label,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.edgeText,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(
            width: 140,
            height: 38,
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                prefixText: '₹',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.edgeDivider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.edgeDivider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(
                    color: AppColors.edgePrimary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, PayrollProvider provider) {
    return const SizedBox.shrink();
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    PayrollProvider provider,
    String token,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.edgeSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.edgeDivider, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.edgeError.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.edgeError.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: AppColors.edgeError,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Payroll',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.edgeText,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This action cannot be undone',
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

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.edgeTextSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.edgeError,
                            AppColors.edgeError.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.edgeError.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(true),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && mounted) {
      final success = await provider.deletePayroll(widget.employee.id, token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Payroll deleted successfully'
                  : 'Failed to delete: ${provider.error}',
            ),
            backgroundColor: success
                ? AppColors.edgeAccent
                : AppColors.edgeError,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleSavePayroll(
    BuildContext context,
    PayrollProvider provider,
    String token,
  ) async {
    if (_isSandspaceOrg) {
      provider.totalPayController.text = _sandNet.toStringAsFixed(0);
      provider.bonusController.text = '0';
    }

    final Map<String, dynamic> calculatedFields = {
      'basicPay': double.tryParse(_basicCtrl.text.replaceAll(',', '')) ?? 0.0,
      'hra': double.tryParse(_hraCtrl.text.replaceAll(',', '')) ?? 0.0,
      'specialAllowance': 0.0,
      'netSalary': _sandNet,
      'bonus':
          double.tryParse(provider.bonusController.text.replaceAll(',', '')) ??
          0.0,
    };

    final Map<String, dynamic> deductions = {
      'pf': double.tryParse(_pfCtrl.text.replaceAll(',', '')) ?? 0.0,
      'esi': double.tryParse(_esiCtrl.text.replaceAll(',', '')) ?? 0.0,
      'pt': double.tryParse(_ptCtrl.text.replaceAll(',', '')) ?? 0.0,
      'lop': double.tryParse(_lopCtrl.text.replaceAll(',', '')) ?? 0.0,
      'penalty': double.tryParse(_penaltyCtrl.text.replaceAll(',', '')) ?? 0.0,
    };

    final Map<String, dynamic> payslipDetails = {
      'pan': _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
      'bankName': _bankNameCtrl.text.trim().isEmpty
          ? null
          : _bankNameCtrl.text.trim(),
      'accountNumber': _accountNumberCtrl.text.trim().isEmpty
          ? null
          : _accountNumberCtrl.text.trim(),
      'pfNumber': _pfNumberCtrl.text.trim().isEmpty
          ? null
          : _pfNumberCtrl.text.trim(),
      'uan': _uanCtrl.text.trim().isEmpty ? null : _uanCtrl.text.trim(),
      'paidDays': int.tryParse(_paidDaysCtrl.text),
      'lopDays': int.tryParse(_lopDaysCtrl.text) ?? 0,
    };

    final success = await provider.savePayroll(
      widget.employee.id,
      token,
      userRole: widget.employee.user?.role ?? 'employee',
      calculatedFields: calculatedFields,
      deductions: deductions,
      payslipDetails: payslipDetails,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Payroll saved successfully'
                : 'Failed to save: ${provider.error}',
          ),
          backgroundColor: success ? AppColors.edgeAccent : AppColors.edgeError,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildTotalRow({required String label, required String amount}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeText,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeAccent,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      key: ValueKey('loading'),
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: AppColors.edgePrimary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(PayrollProvider provider) {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.edgeError.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.edgeError,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load payroll data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'An unknown error occurred',
              style: const TextStyle(
                color: AppColors.edgeTextSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _fetchData,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.edgePrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: const BorderSide(
                    color: AppColors.edgePrimary,
                    width: 1,
                  ),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
