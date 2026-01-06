import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/widgets/common/common_blood_group_dropdown.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HREmployeeManagementScreen extends StatefulWidget {
  final Employee employee;

  const HREmployeeManagementScreen({super.key, required this.employee});

  @override
  State<HREmployeeManagementScreen> createState() =>
      _HREmployeeManagementScreenState();
}

class _HREmployeeManagementScreenState extends State<HREmployeeManagementScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final TextEditingController _bloodGroupController = TextEditingController();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();

  String? _selectedJobCategory;
  String? _selectedJobTitle;
  List<String> _availableCategories = [];
  List<String> _availableJobTitles = [];

  static const Duration _animDuration = Duration(milliseconds: 400);
  static const Curve _animCurve = Curves.easeOutCubic;

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
    _nameController = TextEditingController(text: widget.employee.name);
    _phoneController = TextEditingController(text: widget.employee.phone);
    _bloodGroupController.text = widget.employee.bloodGroup ?? '';

    _controller = AnimationController(vsync: this, duration: _animDuration);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    if (widget.employee.user?.role == 'employee') {
      _initializeJobTitleDropdowns();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  void _initializeJobTitleDropdowns() {
    final subOrg = widget.employee.subOrganisation;
    final currentJobTitle = widget.employee.jobTitle;

    const String defaultOrgKey = 'SandSpace Technologies Pvt Ltd.';
    final orgData = jobRoles[subOrg] ?? jobRoles[defaultOrgKey];

    if (orgData == null) {
      _availableCategories = [];
      _selectedJobCategory = null;
      _availableJobTitles = [];
      _selectedJobTitle = null;
      return;
    }

    final categories = orgData.keys.toList();
    _availableCategories = categories;

    String? matchedCategory;
    for (var category in categories) {
      final titles = orgData[category] ?? [];
      if (titles.contains(currentJobTitle)) {
        matchedCategory = category;
        break;
      }
    }

    _selectedJobCategory =
        matchedCategory ?? (categories.isNotEmpty ? categories.first : null);

    _updateJobTitleDropdown();

    if (_availableJobTitles.contains(currentJobTitle)) {
      _selectedJobTitle = currentJobTitle;
    } else if (currentJobTitle.isNotEmpty) {
      _availableJobTitles.insert(0, currentJobTitle);
      _selectedJobTitle = currentJobTitle;
    } else {
      _selectedJobTitle = _availableJobTitles.isNotEmpty
          ? _availableJobTitles.first
          : null;
    }
  }

  void _updateJobTitleDropdown() {
    final titles =
        jobRoles[widget.employee.subOrganisation]?[_selectedJobCategory] ?? [];
    setState(() {
      _availableJobTitles = titles;

      if (!_availableJobTitles.contains(_selectedJobTitle)) {
        _selectedJobTitle = titles.isNotEmpty ? titles.first : null;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  Future<void> _handleSaveChanges() async {
    _triggerHaptic();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null || token.isEmpty) {
      _showSnackBar('Authentication error. Please log in again.');
      return;
    }

    final hrProvider = Provider.of<HRProvider>(context, listen: false);

    final Map<String, dynamic> updateData = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'bloodGroup': _bloodGroupController.text.trim(),
    };

    if (widget.employee.user?.role == 'employee' && _selectedJobTitle != null) {
      updateData['jobTitle'] = _selectedJobTitle;
    }

    try {
      await hrProvider.updateEmployee(
        employeeId: widget.employee.id,
        data: updateData,
        token: token,
      );

      if (mounted) {
        _showSnackBar('Profile updated successfully', isError: false);
        Future.delayed(
          const Duration(milliseconds: 800),
          () => Navigator.of(context).pop(true),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to update profile');
      }
    }
  }

  Future<void> _handleDeleteUser() async {
    _triggerHaptic();

    final confirmed = await _showConfirmationDialog(
      context,
      title: 'Delete Employee',
      content:
          'Are you sure you want to delete ${widget.employee.name}? This action cannot be undone.',
    );

    if (confirmed == true) {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        _showSnackBar('Authentication error. Please log in again.');
        return;
      }

      final hrProvider = Provider.of<HRProvider>(context, listen: false);

      try {
        await hrProvider.deleteEmployee(
          employeeId: widget.employee.id,
          token: token,
        );

        if (mounted) {
          _showSnackBar('Employee deleted successfully', isError: false);
          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.of(context).pop(true);
          });
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Failed to delete employee');
        }
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.edgeError : AppColors.edgeAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.edgeSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeText,
            letterSpacing: -0.5,
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.edgeTextSecondary,
            height: 1.4,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              _triggerHaptic();
              Navigator.of(context).pop(false);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.edgeTextSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _triggerHaptic();
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.edgeError),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _animatedWidget({required Widget child, required int delay}) {
    return TweenAnimationBuilder<double>(
      duration: _animDuration,
      curve: _animCurve,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hrProvider = context.watch<HRProvider>();
    final isLoading =
        hrProvider.isUpdatingEmployee || hrProvider.isDeletingEmployee;

    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Stack(
            children: [
              Form(
                key: _formKey,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _animatedWidget(delay: 0, child: _buildProfileCard()),
                    const SizedBox(height: 16),
                    if (widget.employee.subOrganisation.isNotEmpty)
                      _animatedWidget(
                        delay: 50,
                        child: _buildOrganizationCard(),
                      ),
                    if (widget.employee.subOrganisation.isNotEmpty)
                      const SizedBox(height: 16),
                    _animatedWidget(
                      delay: 100,
                      child: _buildFormSection(
                        title: 'Account Details',
                        icon: Icons.person_outline,
                        children: [
                          _buildNameField(),
                          if (widget.employee.user?.role == 'employee') ...[
                            _buildJobCategoryDropdown(),
                            const SizedBox(height: 16),
                            _buildJobTitleDropdown(),
                          ],
                          _buildRoleField(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _animatedWidget(
                      delay: 150,
                      child: _buildFormSection(
                        title: 'Contact Information',
                        icon: Icons.contact_mail_outlined,
                        children: [
                          _buildEmailField(),
                          const SizedBox(height: 16),
                          _buildPhoneField(),
                          const SizedBox(height: 16),
                          _buildBloodGroupField(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _animatedWidget(
                      delay: 200,
                      child: _buildSaveChangesButton(isLoading),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: AppColors.edgePrimary,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Manage Employee',
        style: TextStyle(
          color: AppColors.edgeSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: AppColors.edgePrimary,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.edgeSurface),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            _triggerHaptic();
            _handleDeleteUser();
          },
        ),
      ],
    );
  }

  Widget _buildSaveChangesButton(bool isLoading) {
    return ElevatedButton(
      onPressed: isLoading ? null : _handleSaveChanges,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.edgePrimary,
        foregroundColor: AppColors.edgeSurface,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        disabledBackgroundColor: AppColors.edgePrimary.withOpacity(0.5),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: AppColors.edgeSurface,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final hasProfilePic = widget.employee.profilePic.isNotEmpty;
    final initial = widget.employee.name.isNotEmpty
        ? widget.employee.name[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.edgeDivider, width: 2),
            ),
            child: ClipOval(
              child: hasProfilePic
                  ? Image.network(
                      '${ApiConstants.baseUrl}${widget.employee.profilePic}',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppColors.edgePrimary.withOpacity(0.1),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.edgePrimary,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.edgePrimary.withOpacity(0.1),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: AppColors.edgePrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: AppColors.edgePrimary.withOpacity(0.1),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: AppColors.edgePrimary,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.employee.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
              letterSpacing: -0.5,
            ),
          ),
          if (widget.employee.employeeId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.edgePrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ID: ${widget.employee.employeeId}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.edgePrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrganizationCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.edgePrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.business_outlined,
              color: AppColors.edgePrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Organization',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.edgeTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.employee.subOrganisation,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
              Icon(icon, color: AppColors.edgePrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.edgeText,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: _nameController,
        decoration: _inputDecoration(
          labelText: 'Full Name',
          icon: Icons.person_outline,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a name';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildBloodGroupField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: CommonBloodGroupDropdown(
        controller: _bloodGroupController,
        decoration: _inputDecoration(
          labelText: 'Blood Group',
          icon: Icons.bloodtype,
        ),
      ),
    );
  }

  Widget _buildJobCategoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedJobCategory,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Job Category',
          labelStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.edgeTextSecondary,
          ),
          prefixIcon: const Icon(
            Icons.category_outlined,
            color: AppColors.edgeTextSecondary,
            size: 18,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
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
        items: _availableCategories.map((category) {
          return DropdownMenuItem(
            value: category,
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedJobCategory = value;
              _updateJobTitleDropdown();
            });
          }
        },
        dropdownColor: AppColors.edgeSurface,
        icon: const Icon(
          Icons.arrow_drop_down,
          color: AppColors.edgeTextSecondary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildJobTitleDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedJobTitle,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Job Title',
          labelStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.edgeTextSecondary,
          ),
          prefixIcon: const Icon(
            Icons.work_outline,
            color: AppColors.edgeTextSecondary,
            size: 18,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.edgeError),
          ),
        ),
        items: _availableJobTitles.map((title) {
          return DropdownMenuItem(
            value: title,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedJobTitle = value;
            });
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a job title';
          }
          return null;
        },
        dropdownColor: AppColors.edgeSurface,
        icon: const Icon(
          Icons.arrow_drop_down,
          color: AppColors.edgeTextSecondary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      initialValue: widget.employee.email,
      readOnly: true,
      decoration: _inputDecoration(
        labelText: 'Email Address',
        icon: Icons.email_outlined,
      ).copyWith(filled: true, fillColor: AppColors.edgeBackground),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      decoration: _inputDecoration(
        labelText: 'Phone Number',
        icon: Icons.phone_outlined,
      ),
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildRoleField() {
    return TextFormField(
      initialValue: widget.employee.user?.role.toUpperCase() ?? 'N/A',
      readOnly: true,
      decoration: _inputDecoration(
        labelText: 'Role',
        icon: Icons.badge_outlined,
      ).copyWith(filled: true, fillColor: AppColors.edgeBackground),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        fontSize: 13,
        color: AppColors.edgeTextSecondary,
      ),
      prefixIcon: Icon(icon, color: AppColors.edgeTextSecondary, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
    );
  }
}
