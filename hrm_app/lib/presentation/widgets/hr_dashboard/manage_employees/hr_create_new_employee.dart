import 'dart:async';
import 'dart:io';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/widgets/common/common_blood_group_dropdown.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class HRCreateNewEmployee extends StatefulWidget {
  final VoidCallback? onEmployeeCreated;
  const HRCreateNewEmployee({super.key, this.onEmployeeCreated});

  @override
  State<HRCreateNewEmployee> createState() => _HRCreateNewEmployeeState();
}

class _HRCreateNewEmployeeState extends State<HRCreateNewEmployee>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _employeeIdController = TextEditingController();

  String? _selectedJobCategory;
  String? _selectedJobTitle;
  String? _selectedBloodGroup;
  List<String> _availableCategories = [];
  List<String> _availableJobTitles = [];

  String _selectedSubOrganisation = 'SandSpace Technologies Pvt Ltd.';
  final List<String> _subOrganisations = [
    'Academic Overseas',
    'SandSpace Technologies Pvt Ltd.',
  ];
  bool _obscureText = true;
  late AnimationController _animationController;
  bool _isLoading = false;

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
      duration: const Duration(milliseconds: 1200),
    );
    _animationController.forward();

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

    final number = _employeeIdController.text.padLeft(3, '0');
    String prefix;
    if (_selectedSubOrganisation == 'SandSpace Technologies Pvt Ltd.') {
      prefix = 'SST';
    } else if (_selectedSubOrganisation == 'Academic Overseas') {
      prefix = 'AOPL';
    } else {
      prefix = 'EMP';
    }
    final employeeId = '$prefix$number';

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final hrProvider = Provider.of<HRProvider>(context, listen: false);

      await hrProvider.createEmployee(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _selectedSubOrganisation,
        employeeId,
        authProvider.token!,
        jobTitle: _selectedJobTitle,
        bloodGroup: _selectedBloodGroup,
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
                    'Employee created successfully!',
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
        widget.onEmployeeCreated?.call();
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
      backgroundColor: AppColors.edgeBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isSmallDevice),
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
    );
  }

  Widget _buildHeader(bool isSmallDevice) {
    return Container(
      color: AppColors.edgePrimary,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallDevice ? 16 : 20,
          vertical: isSmallDevice ? 12 : 16,
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
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
                    'Create New Employee',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallDevice ? 18 : 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add team member',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isSmallDevice ? 12 : 13,
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

  Widget _buildAccountInfoCard(bool isSmallDevice) {
    return _animatedWidget(
      interval: 0.3,
      child: Container(
        padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
        decoration: BoxDecoration(
          color: AppColors.edgeSurface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.edgeDivider, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCardHeader(
              'Account Info',
              Icons.account_circle,
              isSmallDevice,
            ),
            SizedBox(height: isSmallDevice ? 16 : 20),
            TextFormField(
              controller: _nameController,
              decoration: _responsiveInputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter employee\'s full name',
                icon: Icons.person,
                iconColor: AppColors.edgeAccent,
                isSmallDevice: isSmallDevice,
              ),
              style: TextStyle(
                fontSize: isSmallDevice ? 14 : 15,
                fontWeight: FontWeight.w500,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            SizedBox(height: isSmallDevice ? 14 : 16),
            TextFormField(
              controller: _emailController,
              decoration: _responsiveInputDecoration(
                labelText: 'Email',
                hintText: 'employee@company.com',
                icon: Icons.email,
                iconColor: AppColors.edgePrimary,
                isSmallDevice: isSmallDevice,
              ),
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(
                fontSize: isSmallDevice ? 14 : 15,
                fontWeight: FontWeight.w500,
              ),
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
            SizedBox(height: isSmallDevice ? 14 : 16),
            TextFormField(
              controller: _passwordController,
              decoration:
                  _responsiveInputDecoration(
                    labelText: 'Password',
                    hintText: 'Min 6 characters',
                    icon: Icons.lock,
                    iconColor: AppColors.edgePrimary,
                    isSmallDevice: isSmallDevice,
                  ).copyWith(
                    suffixIcon: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.edgeTextSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
              obscureText: _obscureText,
              style: TextStyle(
                fontSize: isSmallDevice ? 14 : 15,
                fontWeight: FontWeight.w500,
              ),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Min 6 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleAssignmentCard(bool isSmallDevice) {
    return _animatedWidget(
      interval: 0.4,
      child: Container(
        padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
        decoration: BoxDecoration(
          color: AppColors.edgeSurface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.edgeDivider, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCardHeader('Employee Assignment', Icons.badge, isSmallDevice),
            SizedBox(height: isSmallDevice ? 16 : 20),
            _buildSubOrganisationDropdown(isSmallDevice),
            SizedBox(height: isSmallDevice ? 14 : 16),
            _buildJobCategoryDropdown(isSmallDevice),
            SizedBox(height: isSmallDevice ? 14 : 16),
            _buildJobTitleDropdown(isSmallDevice),
            SizedBox(height: isSmallDevice ? 14 : 16),
            SizedBox(height: isSmallDevice ? 14 : 16),
            _buildEmployeeIdField(isSmallDevice),
            SizedBox(height: isSmallDevice ? 14 : 16),
            _buildBloodGroupDropdown(isSmallDevice),
          ],
        ),
      ),
    );
  }

  Widget _buildSubOrganisationDropdown(bool isSmallDevice) {
    return _customDropdown(
      value: _selectedSubOrganisation,
      items: _subOrganisations,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedSubOrganisation = value;
            _updateJobCategoryDropdown();

            _employeeIdController.clear();
          });
        }
      },
      icon: Icons.business,
      iconColor: AppColors.edgePrimary,
      isSmallDevice: isSmallDevice,
      hintText: 'Select Organisation',
    );
  }

  Widget _buildJobCategoryDropdown(bool isSmallDevice) {
    return _customDropdown(
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
      icon: Icons.category,
      iconColor: AppColors.edgePrimary,
      isSmallDevice: isSmallDevice,
      hintText: 'Select Job Category',
    );
  }

  Widget _buildJobTitleDropdown(bool isSmallDevice) {
    return _customDropdown(
      value: _selectedJobTitle,
      items: _availableJobTitles,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedJobTitle = value;
          });
        }
      },
      icon: Icons.work,
      iconColor: AppColors.edgeAccent,
      isSmallDevice: isSmallDevice,
      hintText: 'Select Job Title',
    );
  }

  Widget _buildBloodGroupDropdown(bool isSmallDevice) {
    return CommonBloodGroupDropdown(
      controller: TextEditingController(text: _selectedBloodGroup),
      isSmallDevice: isSmallDevice,
      onChanged: (value) {
        setState(() {
          _selectedBloodGroup = value;
        });
      },
      decoration: _responsiveInputDecoration(
        labelText: 'Blood Group',
        hintText: 'Select Blood Group',
        icon: Icons.bloodtype,
        iconColor: AppColors.edgeError,
        isSmallDevice: isSmallDevice,
      ),
    );
  }

  Widget _buildEmployeeIdField(bool isSmallDevice) {
    String prefix;
    if (_selectedSubOrganisation == 'SandSpace Technologies Pvt Ltd.') {
      prefix = 'SST';
    } else if (_selectedSubOrganisation == 'Academic Overseas') {
      prefix = 'AOPL';
    } else {
      prefix = 'EMP';
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.edgePrimary.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: AppColors.edgePrimary.withOpacity(0.3)),
          ),
          child: Text(
            prefix,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.edgePrimary,
              fontSize: isSmallDevice ? 13 : 14,
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: _employeeIdController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isSmallDevice ? 14 : 15,
              letterSpacing: 2,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Employee number required';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: '000',
              hintStyle: TextStyle(
                color: AppColors.edgeTextSecondary.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
              filled: true,
              fillColor: AppColors.edgeBackground,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                borderSide: BorderSide(color: AppColors.edgeDivider),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                borderSide: BorderSide(
                  color: AppColors.edgePrimary,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                borderSide: BorderSide(
                  color: AppColors.edgeError.withOpacity(0.7),
                  width: 1,
                ),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                borderSide: BorderSide(color: AppColors.edgeError, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isSmallDevice) {
    return _animatedWidget(
      interval: 0.5,
      child: Container(
        height: isSmallDevice ? 48 : 52,
        decoration: BoxDecoration(
          color: AppColors.edgePrimary,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _submit,
            borderRadius: BorderRadius.circular(4),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_add,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Create Employee',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallDevice ? 14 : 15,
                            fontWeight: FontWeight.w600,
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

  Widget _buildCardHeader(String title, IconData icon, bool isSmallDevice) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.edgePrimary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: isSmallDevice ? 15 : 16,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _customDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    required Color iconColor,
    required bool isSmallDevice,
    required String hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
        color: AppColors.edgeBackground,
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
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
          hintText: hintText,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 12 : 14,
            vertical: isSmallDevice ? 10 : 12,
          ),
          border: InputBorder.none,
          errorStyle: const TextStyle(height: 0.01, color: Colors.transparent),
        ),
        style: TextStyle(
          color: AppColors.edgeText,
          fontWeight: FontWeight.w500,
          fontSize: isSmallDevice ? 14 : 15,
        ),
        dropdownColor: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(4),
        icon: Icon(
          Icons.arrow_drop_down_rounded,
          color: iconColor,
          size: isSmallDevice ? 24 : 28,
        ),
      ),
    );
  }

  InputDecoration _responsiveInputDecoration({
    required String labelText,
    required String hintText,
    required IconData icon,
    required Color iconColor,
    required bool isSmallDevice,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: AppColors.edgeTextSecondary,
        fontSize: isSmallDevice ? 13 : 14,
        fontWeight: FontWeight.w500,
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        color: AppColors.edgeTextSecondary.withOpacity(0.7),
        fontSize: isSmallDevice ? 12 : 13,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: iconColor, size: isSmallDevice ? 18 : 20),
      ),
      filled: true,
      fillColor: AppColors.edgeBackground,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallDevice ? 12 : 14,
        vertical: isSmallDevice ? 12 : 14,
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
        borderSide: const BorderSide(color: AppColors.edgePrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.edgeError, width: 1.5),
      ),
    );
  }
}
