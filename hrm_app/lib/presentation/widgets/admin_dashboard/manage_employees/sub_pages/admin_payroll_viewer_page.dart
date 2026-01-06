import 'package:flutter/material.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/payroll_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class AdminPayrollViewerPage extends StatefulWidget {
  final Employee employee;

  const AdminPayrollViewerPage({super.key, required this.employee});

  @override
  State<AdminPayrollViewerPage> createState() => _AdminPayrollViewerPageState();
}

class _AdminPayrollViewerPageState extends State<AdminPayrollViewerPage>
    with SingleTickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeInOutCubic;

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
      _populateControllers();
    }
  }

  void _populateControllers() {
    final selected = _payrollProvider.selectedPayroll;

    if (selected != null) {
      final cf = selected.calculatedFields ?? {};
      final dd = selected.deductions ?? {};
      final pd = selected.payslipDetails ?? {};

      if (cf['basicPay'] != null) {
        _basicCtrl.text = (cf['basicPay'] is num)
            ? cf['basicPay'].toString()
            : cf['basicPay'].toString();
      }
      if (cf['hra'] != null) {
        _hraCtrl.text = (cf['hra'] is num)
            ? cf['hra'].toString()
            : cf['hra'].toString();
      }

      if (dd['pf'] != null) _pfCtrl.text = dd['pf'].toString();
      if (dd['esi'] != null) _esiCtrl.text = dd['esi'].toString();
      if (dd['pt'] != null) _ptCtrl.text = dd['pt'].toString();
      if (dd['lop'] != null) _lopCtrl.text = dd['lop'].toString();
      if (dd['penalty'] != null) _penaltyCtrl.text = dd['penalty'].toString();

      if (pd['pan'] != null) _panCtrl.text = pd['pan'];
      if (pd['bankName'] != null) _bankNameCtrl.text = pd['bankName'];
      if (pd['accountNumber'] != null) {
        _accountNumberCtrl.text = pd['accountNumber'];
      }
      if (pd['pfNumber'] != null) _pfNumberCtrl.text = pd['pfNumber'];
      if (pd['uan'] != null) _uanCtrl.text = pd['uan'];
      if (pd['paidDays'] != null) {
        _paidDaysCtrl.text = pd['paidDays'].toString();
      }
      if (pd['lopDays'] != null) _lopDaysCtrl.text = pd['lopDays'].toString();
    } else {
      _basicCtrl.text = '0';
      _hraCtrl.text = '0';
      _pfCtrl.text = '0';
      _esiCtrl.text = '0';
      _ptCtrl.text = '0';
      _lopCtrl.text = '0';
      _penaltyCtrl.text = '0';
      _panCtrl.clear();
      _bankNameCtrl.clear();
      _accountNumberCtrl.clear();
      _pfNumberCtrl.clear();
      _uanCtrl.clear();
      _paidDaysCtrl.clear();
      _lopDaysCtrl.clear();
    }

    _computeSandspaceTotals();
    if (mounted) setState(() {});
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
        backgroundColor: AppColors.edgeBackground,
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
          fontWeight: FontWeight.w600,
          fontSize: 18,
          letterSpacing: -0.5,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.edgeSurface),
        onPressed: () => Navigator.of(context).pop(),
      ),
      centerTitle: true,
      backgroundColor: AppColors.edgePrimary,
      elevation: 0,
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
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.edgeTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.employee.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildEmployeeDetailRow(
            icon: Icons.badge_outlined,
            text: widget.employee.employeeId,
          ),
          const SizedBox(height: 8),
          _buildEmployeeDetailRow(
            icon: Icons.email_outlined,
            text: widget.employee.email,
          ),
          const SizedBox(height: 8),
          _buildEmployeeDetailRow(
            icon: Icons.phone_outlined,
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
        Icon(icon, size: 16, color: AppColors.edgeTextSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: textColor ?? AppColors.edgeTextSecondary,
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
          borderRadius: BorderRadius.circular(6),
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
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.employee.subOrganisation.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.edgeText,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Payslip for the month of ${DateFormat('MMMM yyyy').format(provider.selectedPayPeriod)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.edgeTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          sectionHeader('Employee Pay Summary'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const double labelWidth = 130;

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
                              fontWeight: FontWeight.w700,
                              color: AppColors.edgeText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
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
                  const SizedBox(height: 12),
                  labeledInput('PAN', _panCtrl),
                  labeledInput('Bank Name', _bankNameCtrl),
                  labeledInput(
                    'Bank A/c No',
                    _accountNumberCtrl,
                    numeric: true,
                  ),
                  labeledInput('PF No', _pfNumberCtrl),
                  labeledInput('UAN', _uanCtrl),
                  labeledInput('Paid Days', _paidDaysCtrl, numeric: true),
                  labeledInput('LOP Days', _lopDaysCtrl, numeric: true),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          sectionHeader('Earnings'),
          const SizedBox(height: 12),
          moneyField('Total Pay (CTC)', provider.totalPayController),
          divider(),
          moneyField('Basic Pay', _basicCtrl),
          moneyField('HRA', _hraCtrl),
          moneyField('Bonus', provider.bonusController),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.edgeBackground,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gross Earnings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  fmt(
                    _sandGross +
                        double.parse(
                          provider.bonusController.text.replaceAll(',', '') ==
                                  ''
                              ? '0'
                              : provider.bonusController.text.replaceAll(
                                  ',',
                                  '',
                                ),
                        ),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.edgeAccent,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          sectionHeader('Deductions'),
          const SizedBox(height: 12),
          moneyField('PF', _pfCtrl),
          moneyField('ESI', _esiCtrl),
          moneyField('Professional Tax', _ptCtrl),
          moneyField('Loss of Pay', _lopCtrl),
          moneyField('Penalty', _penaltyCtrl),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.edgeBackground,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Deductions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  fmt(_sandDeductions),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.edgeError,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.edgePrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.edgePrimary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net Salary',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.edgePrimary,
                  ),
                ),
                Text(
                  fmt(
                    _sandNet +
                        double.parse(
                          provider.bonusController.text.replaceAll(',', '') ==
                                  ''
                              ? '0'
                              : provider.bonusController.text.replaceAll(
                                  ',',
                                  '',
                                ),
                        ),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.edgePrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, PayrollProvider provider) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _selectDate(context, provider),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Change Period'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.edgeText,
              side: const BorderSide(color: AppColors.edgeDivider),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.edgePrimary),
    );
  }

  Widget _buildErrorWidget(PayrollProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.edgeError),
          const SizedBox(height: 16),
          Text(
            provider.error ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.edgeTextSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _fetchData(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.edgePrimary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    PayrollProvider provider,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedPayPeriod,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.edgePrimary,
              onPrimary: AppColors.edgeSurface,
              onSurface: AppColors.edgeText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != provider.selectedPayPeriod) {
      provider.setPayPeriod(picked);
    }
  }

  Future<void> _handleSavePayroll(
    BuildContext context,
    PayrollProvider provider,
    String token,
  ) async {
    final success = await provider.savePayroll(
      widget.employee.id,
      token,
      calculatedFields: {
        'basicPay': double.tryParse(_basicCtrl.text.replaceAll(',', '')) ?? 0.0,
        'hra': double.tryParse(_hraCtrl.text.replaceAll(',', '')) ?? 0.0,
        'specialAllowance': 0.0,
      },
      deductions: {
        'pf': double.tryParse(_pfCtrl.text.replaceAll(',', '')) ?? 0.0,
        'esi': double.tryParse(_esiCtrl.text.replaceAll(',', '')) ?? 0.0,
        'pt': double.tryParse(_ptCtrl.text.replaceAll(',', '')) ?? 0.0,
        'lop': double.tryParse(_lopCtrl.text.replaceAll(',', '')) ?? 0.0,
        'penalty':
            double.tryParse(_penaltyCtrl.text.replaceAll(',', '')) ?? 0.0,
      },
      payslipDetails: {
        'pan': _panCtrl.text,
        'bankName': _bankNameCtrl.text,
        'accountNumber': _accountNumberCtrl.text,
        'pfNumber': _pfNumberCtrl.text,
        'uan': _uanCtrl.text,
        'paidDays': double.tryParse(_paidDaysCtrl.text) ?? 0,
        'lopDays': double.tryParse(_lopDaysCtrl.text) ?? 0,
      },
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payroll saved successfully'),
          backgroundColor: AppColors.edgeAccent,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save payroll'),
          backgroundColor: AppColors.edgeError,
        ),
      );
    }
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    PayrollProvider provider,
    String token,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payroll Record'),
        content: const Text(
          'Are you sure you want to delete this payroll record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.edgeError),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await provider.deletePayroll(widget.employee.id, token);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payroll record deleted'),
            backgroundColor: AppColors.edgeAccent,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to delete payroll'),
            backgroundColor: AppColors.edgeError,
          ),
        );
      }
    }
  }
}
