import 'dart:async';
import 'dart:io';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/widgets/common/common_blood_group_dropdown.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class CreateUserScreen extends StatefulWidget {
  final VoidCallback onUserCreated;
  const CreateUserScreen({super.key, required this.onUserCreated});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _bloodGroupController = TextEditingController();

  String? _selectedJobCategory;
  String? _selectedJobTitle;

  List<String> _availableCategories = [];
  List<String> _availableJobTitles = [];

  String _selectedRole = 'hr';
  String _selectedSubOrganisation = 'Academic Overseas';
  final List<String> _subOrganisations = [
    'Academic Overseas',
    'SandSpace Technologies Pvt Ltd.',
  ];
  bool _obscureText = true;
  late AnimationController _animationController;
  bool _isLoading = false;

  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeInOutCubic;

  final Map<String, Map<String, List<String>>> jobRoles = {
    'SandSpace Technologies Pvt Ltd.': {
      'Technical Roles': [
        'Intern',
        'Trainee',
        'Software Trainee',
        'Junior Software Developer',
        'Software Developer',
        'Software Engineer',
        'Data Scientist',
        'DevOps Engineer',
        'UI/UX Designer',
        'Frontend Developer',
        'Backend Developer',
        'Full Stack Developer',
        'Mobile App Developer',
        'AI/ML Engineer',
        'Data Engineer',
        'Cloud Engineer',
        'Technical Architect',
        'Solution Architect',
        'AI Architect',
        'QA Tester',
        'QA Engineer',
        'Senior QA Engineer',
        'Automation Test Engineer',
        'Senior Software Developer',
        'Senior Software Engineer',
        'Lead Software Engineer',
        'Principal Software Engineer',
      ],
      'NON IT': ['Research Analyst'],
      'Project & Management Roles': [
        'Team Lead',
        'Project Coordinator',
        'Project Manager',
        'Program Manager',
        'Product Manager',
        'Scrum Master',
        'Business Analyst',
        'Technical Manager',
        'Delivery Manager',
        'CTO (Chief Technology Officer)',
      ],
      'IT & Support Roles': [
        'IT Support Engineer',
        'System Administrator',
        'Network Engineer',
        'Security Analyst',
        'Database Administrator (DBA)',
        'Technical Support Engineer',
      ],
      'Business & Operations': [
        'Recruiter',
        'Talent Acquisition Specialist',
        'Finance Executive',
        'Finance Manager',
        'Sales Executive',
        'Business Development Manager',
        'Marketing Executive',
        'Digital Marketing Specialist',
        'Customer Success Manager',
        'Operations Manager',
      ],
    },
    'Academic Overseas': {
      'Counseling & Administration': [
        'Academic Counselor',
        'Student Counselor',
        'Senior Counselor',
        'Admissions Counselor',
        'Application Officer',
        'Documentation Officer',
        'Visa Counselor',
        'Visa Officer',
        'Compliance Officer',
        'University Relations Manager',
        'Overseas Education Consultant',
        'Country Manager',
        'Regional Manager',
        'Branch Manager',
        'Academic Advisor',
        'Career Guidance Specialist',
        'Training & Development Officer',
        'Enrollment Officer',
        'Partnership Manager (Universities & Colleges)',
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });

    _updateJobCategoryDropdown();
  }

  void _updateJobCategoryDropdown() {
    final categories = jobRoles[_selectedSubOrganisation]?.keys.toList() ?? [];
    setState(() {
      _availableCategories = categories;
      _selectedJobCategory = categories.isNotEmpty ? categories.first : null;
      _updateJobTitleDropdown();
    });
  }

  void _updateJobTitleDropdown() {
    final titles =
        jobRoles[_selectedSubOrganisation]?[_selectedJobCategory] ?? [];
    setState(() {
      _availableJobTitles = titles;
      _selectedJobTitle = titles.isNotEmpty ? titles.first : null;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _employeeIdController.dispose();
    _bloodGroupController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.edgeError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    String? employeeId;
    if (_selectedRole == 'employee' || _selectedRole == 'hr') {
      final number = _employeeIdController.text.padLeft(3, '0');
      String prefix;
      if (_selectedRole == 'hr') {
        prefix = 'SST';
      } else if (_selectedSubOrganisation ==
          'SandSpace Technologies Pvt Ltd.') {
        prefix = 'SST';
      } else if (_selectedSubOrganisation == 'Academic Overseas') {
        prefix = 'AOPL';
      } else {
        prefix = 'EMP';
      }
      employeeId = '$prefix$number';
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);

      await adminProvider.createUser(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _selectedRole,
        authProvider.token!,
        subOrganisation: _selectedRole == 'employee'
            ? _selectedSubOrganisation
            : _selectedRole == 'hr'
            ? 'SandSpace Technologies Pvt Ltd.'
            : null,
        employeeId: employeeId,
        jobTitle: _selectedRole == 'employee' ? _selectedJobTitle : null,
        bloodGroup: _bloodGroupController.text.trim().isNotEmpty
            ? _bloodGroupController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'User created successfully!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.edgeAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        widget.onUserCreated();
        Navigator.of(context).pop();
      }
    } on SocketException {
      _showErrorDialog('No internet connection. Please check your network.');
    } on TimeoutException {
      _showErrorDialog('The request timed out. Please try again.');
    } catch (error) {
      _showErrorDialog(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _animatedWidget({required Widget child, required double interval}) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(interval, 1.0, curve: Curves.easeOutCubic),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(interval, 1.0, curve: Curves.easeOutCubic),
              ),
            ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallDevice = size.width < 360;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.edgeBackground,
              AppColors.edgeBackground.withOpacity(0.95),
              AppColors.edgePrimary.withOpacity(0.02),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.edgePrimary.withOpacity(0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.edgePrimary.withOpacity(0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildEnhancedHeader(isSmallDevice),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallDevice ? 16 : 20,
                        vertical: isSmallDevice ? 16 : 20,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildAccountInfoCard(isSmallDevice),
                            SizedBox(height: isSmallDevice ? 16 : 20),
                            _buildRoleAssignmentCard(isSmallDevice),
                            SizedBox(height: isSmallDevice ? 24 : 32),
                            _buildSubmitButton(isSmallDevice),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleAssignmentCard(bool isSmallDevice) {
    return _animatedWidget(
      interval: 0.3,
      child: Container(
        padding: EdgeInsets.all(isSmallDevice ? 18 : 22),
        decoration: BoxDecoration(
          color: AppColors.edgeSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.edgeDivider.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.edgeText.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.edgeText.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEnhancedCardHeader(
              'Role & Assignment',
              Icons.badge_rounded,
              AppColors.edgePrimary,
              isSmallDevice,
            ),
            SizedBox(height: isSmallDevice ? 20 : 24),
            _buildEnhancedRoleDropdown(isSmallDevice),
            AnimatedSize(
              duration: _animDuration,
              curve: _animCurve,
              child: _selectedRole == 'employee' || _selectedRole == 'hr'
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedRole == 'employee') ...[
                          SizedBox(height: isSmallDevice ? 16 : 20),
                          _buildEnhancedSubOrganisationDropdown(isSmallDevice),
                          SizedBox(height: isSmallDevice ? 16 : 20),
                          _buildEnhancedJobCategoryDropdown(isSmallDevice),
                          SizedBox(height: isSmallDevice ? 16 : 20),
                          _buildEnhancedJobTitleDropdown(isSmallDevice),
                          SizedBox(height: isSmallDevice ? 16 : 20),
                          _buildEnhancedEmployeeIdField(isSmallDevice),
                          SizedBox(height: isSmallDevice ? 16 : 20),
                          _buildEnhancedBloodGroupField(isSmallDevice),
                        ] else if (_selectedRole == 'hr') ...[
                          SizedBox(height: isSmallDevice ? 16 : 20),
                          _buildEnhancedHROrganizationField(isSmallDevice),
                          SizedBox(height: isSmallDevice ? 16 : 20),
                          _buildEnhancedEmployeeIdField(isSmallDevice),
                          SizedBox(height: isSmallDevice ? 16 : 20),
                          _buildEnhancedBloodGroupField(isSmallDevice),
                        ],
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedJobCategoryDropdown(bool isSmallDevice) {
    return _buildEnhancedDropdown(
      value: _selectedJobCategory,
      items: _availableCategories,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedJobCategory = value;
            _updateJobTitleDropdown();
          });
        }
      },
      icon: Icons.category_rounded,
      iconColor: AppColors.edgePrimary,
      isSmallDevice: isSmallDevice,
      hintText: 'Select Job Category',
      labelText: 'Job Category',
      showPrefixIcon: false,
    );
  }

  Widget _buildEnhancedJobTitleDropdown(bool isSmallDevice) {
    return _buildEnhancedDropdown(
      value: _selectedJobTitle,
      items: _availableJobTitles,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedJobTitle = value;
          });
        }
      },
      icon: Icons.work_rounded,
      iconColor: AppColors.edgeAccent,
      isSmallDevice: isSmallDevice,
      hintText: 'Select Job Title',
      labelText: 'Job Title',
      showPrefixIcon: false,
    );
  }

  Widget _buildEnhancedSubOrganisationDropdown(bool isSmallDevice) {
    return _buildEnhancedDropdown(
      value: _selectedSubOrganisation,
      items: _subOrganisations,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedSubOrganisation = value;
            _updateJobCategoryDropdown();
          });
        }
      },
      icon: Icons.business_rounded,
      iconColor: AppColors.edgePrimary,
      isSmallDevice: isSmallDevice,
      hintText: 'Select Organisation',
      labelText: 'Organization',
      showPrefixIcon: false,
    );
  }

  Widget _buildEnhancedHROrganizationField(bool isSmallDevice) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: 'SandSpace Technologies Pvt Ltd.',
        readOnly: true,
        style: TextStyle(
          fontSize: isSmallDevice ? 14 : 15,
          fontWeight: FontWeight.w500,
          color: AppColors.edgeText,
        ),
        decoration: InputDecoration(
          labelText: 'Organization',
          labelStyle: TextStyle(
            color: AppColors.edgeTextSecondary,
            fontSize: isSmallDevice ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
          hintText: 'SandSpace Technologies Pvt Ltd.',
          hintStyle: TextStyle(
            color: AppColors.edgeTextSecondary.withOpacity(0.6),
            fontSize: isSmallDevice ? 12 : 13,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.edgePrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: AppColors.edgePrimary,
              size: 20,
            ),
          ),
          filled: true,
          fillColor: AppColors.edgeBackground,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 14 : 16,
            vertical: isSmallDevice ? 14 : 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.edgeDivider.withOpacity(0.5),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.edgePrimary,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    required Color iconColor,
    required bool isSmallDevice,
    required String hintText,
    required String labelText,
    Widget Function(String)? customItemBuilder,
    bool showPrefixIcon = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: customItemBuilder != null
                ? customItemBuilder(item)
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(icon, size: 16, color: iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.edgeText,
                            fontSize: isSmallDevice ? 13 : 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) =>
            value == null || value.isEmpty ? 'This field is required' : null,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: AppColors.edgeTextSecondary,
            fontSize: isSmallDevice ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.edgeTextSecondary.withOpacity(0.6),
            fontSize: isSmallDevice ? 12 : 13,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: showPrefixIcon
              ? Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: isSmallDevice ? 18 : 20,
                  ),
                )
              : null,
          filled: true,
          fillColor: AppColors.edgeBackground,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 14 : 16,
            vertical: isSmallDevice ? 14 : 16,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: iconColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.edgeDivider.withOpacity(0.5),
              width: 1,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.edgeError.withOpacity(0.7),
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.edgeError, width: 2),
          ),
          errorStyle: TextStyle(
            color: AppColors.edgeError,
            fontSize: isSmallDevice ? 11 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: TextStyle(
          color: AppColors.edgeText,
          fontWeight: FontWeight.w500,
          fontSize: isSmallDevice ? 14 : 15,
        ),
        dropdownColor: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        icon: Icon(
          Icons.arrow_drop_down_rounded,
          color: iconColor,
          size: isSmallDevice ? 24 : 28,
        ),
      ),
    );
  }

  Widget _buildEnhancedHeader(bool isSmallDevice) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.edgeDivider.withOpacity(0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallDevice ? 16 : 20,
          vertical: isSmallDevice ? 12 : 16,
        ),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.edgePrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.edgePrimary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.edgePrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create New User',
                    style: TextStyle(
                      color: AppColors.edgeText,
                      fontSize: isSmallDevice ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add team member to your organization',
                    style: TextStyle(
                      color: AppColors.edgeTextSecondary,
                      fontSize: isSmallDevice ? 12 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.edgeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_add_rounded,
                color: AppColors.edgeAccent,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard(bool isSmallDevice) {
    return _animatedWidget(
      interval: 0.2,
      child: Container(
        padding: EdgeInsets.all(isSmallDevice ? 18 : 22),
        decoration: BoxDecoration(
          color: AppColors.edgeSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.edgeDivider.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.edgeText.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.edgeText.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEnhancedCardHeader(
              'Account Information',
              Icons.account_circle_rounded,
              AppColors.edgeAccent,
              isSmallDevice,
            ),
            SizedBox(height: isSmallDevice ? 20 : 24),
            _buildEnhancedTextField(
              controller: _nameController,
              labelText: 'Full Name',
              hintText: 'Enter user\'s full name',
              icon: Icons.person_rounded,
              iconColor: AppColors.edgeAccent,
              isSmallDevice: isSmallDevice,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            SizedBox(height: isSmallDevice ? 16 : 20),
            _buildEnhancedTextField(
              controller: _emailController,
              labelText: 'Email Address',
              hintText: 'user@company.com',
              icon: Icons.email_rounded,
              iconColor: AppColors.edgePrimary,
              isSmallDevice: isSmallDevice,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an email';
                }
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Enter valid email';
                }
                return null;
              },
            ),
            SizedBox(height: isSmallDevice ? 16 : 20),
            _buildEnhancedTextField(
              controller: _passwordController,
              labelText: 'Password',
              hintText: 'Minimum 6 characters',
              icon: Icons.lock_rounded,
              iconColor: AppColors.edgePrimary,
              isSmallDevice: isSmallDevice,
              obscureText: _obscureText,
              suffixIcon: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.edgeTextSecondary,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Minimum 6 characters required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedRoleDropdown(bool isSmallDevice) {
    return _buildEnhancedDropdown(
      value: _selectedRole,
      items: ['hr', 'employee'],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedRole = value;
          });
        }
      },
      icon: Icons.badge_rounded,
      iconColor: AppColors.edgePrimary,
      isSmallDevice: isSmallDevice,
      hintText: 'Select Role',
      labelText: 'User Role',
      showPrefixIcon: false,
      customItemBuilder: (item) {
        final IconData icon = item == 'hr'
            ? Icons.admin_panel_settings_rounded
            : Icons.people_rounded;
        final Color itemColor = item == 'hr'
            ? AppColors.edgeAccent
            : AppColors.edgePrimary;
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: itemColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: itemColor),
            ),
            const SizedBox(width: 12),
            Text(
              item.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
                fontSize: isSmallDevice ? 13 : 14,
                letterSpacing: -0.3,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEnhancedEmployeeIdField(bool isSmallDevice) {
    String prefix;
    if (_selectedRole == 'hr') {
      prefix = 'SST';
    } else if (_selectedSubOrganisation == 'SandSpace Technologies Pvt Ltd.') {
      prefix = 'SST';
    } else if (_selectedSubOrganisation == 'Academic Overseas') {
      prefix = 'AOPL';
    } else {
      prefix = 'EMP';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Employee ID',
          style: TextStyle(
            color: AppColors.edgeTextSecondary,
            fontSize: isSmallDevice ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.edgePrimary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                border: Border.all(
                  color: AppColors.edgePrimary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                prefix,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.edgePrimary,
                  fontSize: isSmallDevice ? 14 : 15,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.edgeText.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _employeeIdController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallDevice ? 14 : 15,
                    letterSpacing: 2,
                    color: AppColors.edgeText,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _selectedRole == 'hr'
                          ? 'HR number required'
                          : 'Employee number required';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '000',
                    hintStyle: TextStyle(
                      color: AppColors.edgeTextSecondary.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                    filled: true,
                    fillColor: AppColors.edgeBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      borderSide: BorderSide(
                        color: AppColors.edgeDivider.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      borderSide: BorderSide(
                        color: AppColors.edgePrimary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      borderSide: BorderSide(
                        color: AppColors.edgeError.withOpacity(0.7),
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      borderSide: BorderSide(
                        color: AppColors.edgeError,
                        width: 2,
                      ),
                    ),
                    errorStyle: TextStyle(
                      color: AppColors.edgeError,
                      fontSize: isSmallDevice ? 11 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedBloodGroupField(bool isSmallDevice) {
    return _buildEnhancedDropdown(
      value: _bloodGroupController.text.isNotEmpty
          ? _bloodGroupController.text
          : null,
      items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _bloodGroupController.text = value;
          });
        }
      },
      icon: Icons.bloodtype_rounded,
      iconColor: AppColors.edgeError,
      isSmallDevice: isSmallDevice,
      hintText: 'Select Blood Group',
      labelText: 'Blood Group',
      showPrefixIcon: false,
    );
  }

  Widget _buildSubmitButton(bool isSmallDevice) {
    return _animatedWidget(
      interval: 0.4,
      child: Container(
        height: isSmallDevice ? 52 : 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.edgePrimary,
              AppColors.edgePrimary.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.edgePrimary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.edgePrimary.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _submit,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.05),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Create User',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallDevice ? 15 : 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedCardHeader(
    String title,
    IconData icon,
    Color iconColor,
    bool isSmallDevice,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallDevice ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.edgeText,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Configure user details and permissions',
                style: TextStyle(
                  fontSize: isSmallDevice ? 11 : 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.edgeTextSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required Color iconColor,
    required bool isSmallDevice,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        style: TextStyle(
          fontSize: isSmallDevice ? 14 : 15,
          fontWeight: FontWeight.w500,
          color: AppColors.edgeText,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: AppColors.edgeTextSecondary,
            fontSize: isSmallDevice ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.edgeTextSecondary.withOpacity(0.6),
            fontSize: isSmallDevice ? 12 : 13,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: isSmallDevice ? 18 : 20),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppColors.edgeBackground,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 14 : 16,
            vertical: isSmallDevice ? 14 : 16,
          ),
          isDense: false,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: iconColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.edgeDivider.withOpacity(0.5),
              width: 1,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.edgeError.withOpacity(0.7),
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.edgeError, width: 2),
          ),
          errorStyle: TextStyle(
            color: AppColors.edgeError,
            fontSize: isSmallDevice ? 11 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
