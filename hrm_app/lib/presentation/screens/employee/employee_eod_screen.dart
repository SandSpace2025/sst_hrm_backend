import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/eod_provider.dart';
import 'package:intl/intl.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/presentation/widgets/common/three_dots_loading.dart';

class EmployeeEODScreen extends StatefulWidget {
  final Map<String, dynamic>? eodData;

  const EmployeeEODScreen({super.key, this.eodData});

  @override
  State<EmployeeEODScreen> createState() => _EmployeeEODScreenState();
}

class _EmployeeEODScreenState extends State<EmployeeEODScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _dateController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _taskDoneController = TextEditingController();
  final _challengesController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _whoWorkingController = TextEditingController();

  // Dropdown values
  String? _selectedTechnology;
  String? _selectedTaskType;
  String? _selectedProjectStatus;
  String? _selectedReportStatus;

  // Date and toggle
  DateTime? _selectedDeadline;
  bool _reportSent = false;

  // Dropdown options
  final List<String> _technologies = [
    'Flutter',
    'React Native',
    'Node.js',
    'Python',
    'Java',
    'C#',
    'PHP',
    'Angular',
    'Vue.js',
    'React',
    'ML',
    'DL',
    'NLP',
    'Data Analysis ',
    'Excel',
    'PowerBi',
    'Tableau',
    'R',
    'Figma',
    'PhP',
    'Laravel',
    'Mern',
    'SAP',
    'SAS',
  ];

  final List<String> _taskTypes = [
    'Assessment',
    'Dissertation',
    'Spare',
    'Real Time',
    'Local Project',
  ];

  final List<String> _projectStatuses = ['0%', '25%', '50%', '75%', '100%'];

  final List<String> _reportStatuses = [
    'Not Applicable',
    'Pending',
    'In Progress',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('EEEE, MMMM d, y').format(DateTime.now());

    // Pre-fill form if editing existing EOD
    if (widget.eodData != null) {
      _projectNameController.text = widget.eodData!['projectName'] ?? '';
      _taskDoneController.text = widget.eodData!['taskDoneToday'] ?? '';
      _challengesController.text = widget.eodData!['challengesFaced'] ?? '';
      _studentNameController.text = widget.eodData!['studentName'] ?? '';
      _whoWorkingController.text =
          widget.eodData!['personWorkingOnReport'] ?? '';

      _selectedTechnology = widget.eodData!['technology'];
      _selectedTaskType = widget.eodData!['taskType'];
      _selectedProjectStatus = widget.eodData!['projectStatus'] != null
          ? widget.eodData!['projectStatus'].toString() + '%'
          : null;
      _selectedReportStatus = widget.eodData!['reportStatus'];
      _reportSent = widget.eodData!['reportSent'] ?? false;

      if (widget.eodData!['deadline'] != null) {
        try {
          _selectedDeadline = DateTime.parse(widget.eodData!['deadline']);
        } catch (e) {
          // Handle parse error
        }
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _projectNameController.dispose();
    _taskDoneController.dispose();
    _challengesController.dispose();
    _studentNameController.dispose();
    _whoWorkingController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _submitEOD() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if current time is within allowed EOD submission window (6:30 PM - 7:30 PM IST)
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;

    // Convert to minutes for easier comparison
    final currentTimeInMinutes = currentHour * 60 + currentMinute;
    final startTime = 18 * 60 + 30; // 6:30 PM = 18:30 = 1110 minutes
    final endTime = 19 * 60 + 30; // 7:30 PM = 19:30 = 1170 minutes

    if (currentTimeInMinutes < startTime || currentTimeInMinutes > endTime) {
      if (mounted) {
        SnackBarUtils.showWarning(
          context,
          'EOD can only be submitted between 6:30 PM and 7:30 PM IST',
        );
      }
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final eodProvider = Provider.of<EODProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) return;

    final eodData = {
      'project': _projectNameController.text.trim(),
      'tasksCompleted': _taskDoneController.text.trim(),
      'challenges': _challengesController.text.trim().isEmpty
          ? 'No challenges'
          : _challengesController.text.trim(),
      'nextDayPlan': 'Continue work',
      'projectName': _projectNameController.text.trim(),
      'taskDoneToday': _taskDoneController.text.trim(),
      'challengesFaced': _challengesController.text.trim(),
      'studentName': _studentNameController.text.trim(),
      'technology': _selectedTechnology,
      'taskType': _selectedTaskType,
      'projectStatus': _selectedProjectStatus != null
          ? int.parse(_selectedProjectStatus!.replaceAll('%', ''))
          : 0,
      'deadline': _selectedDeadline?.toIso8601String(),
      'personWorkingOnReport': _whoWorkingController.text.trim(),
      'reportStatus': _selectedReportStatus,
      'reportSent': _reportSent,
    };

    bool success;
    if (widget.eodData != null) {
      // Update existing EOD
      success = await eodProvider.updateEOD(
        token,
        widget.eodData!['_id'],
        eodData,
        context: context,
      );
    } else {
      // Create new EOD
      success = await eodProvider.createEOD(token, eodData, context: context);
    }

    if (success && mounted) {
      SnackBarUtils.showSuccess(
        context,
        widget.eodData != null
            ? 'EOD updated successfully!'
            : 'EOD submitted successfully!',
      );
      Navigator.pop(context);
    } else if (mounted && eodProvider.error != null) {
      SnackBarUtils.showError(context, eodProvider.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.edgePrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        leadingWidth: 40,
        titleSpacing: 0,
        title: const Text(
          'Back',
          style: TextStyle(
            color: AppColors.edgePrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Consumer<EODProvider>(
        builder: (context, eodProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a EOD report',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildTextField(
                    label: 'Date',
                    controller: _dateController,
                    enabled: false,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    label: 'Project name',
                    controller: _projectNameController,
                    required: true,
                    hint: 'Enter here',
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    label: 'Task Done',
                    controller: _taskDoneController,
                    required: true,
                    hint: 'Enter here',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    label: 'Challenges faced (if any)',
                    controller: _challengesController,
                    hint: 'Enter here',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),

                  _buildDropdown(
                    label: 'Technology',
                    value: _selectedTechnology,
                    items: _technologies,
                    required: true,
                    onChanged: (value) =>
                        setState(() => _selectedTechnology = value),
                  ),
                  const SizedBox(height: 20),

                  _buildDropdown(
                    label: 'Task type',
                    value: _selectedTaskType,
                    items: _taskTypes,
                    required: true,
                    onChanged: (value) =>
                        setState(() => _selectedTaskType = value),
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    label: 'Student name',
                    controller: _studentNameController,
                    hint: 'Enter here',
                  ),
                  const SizedBox(height: 20),

                  _buildDropdown(
                    label: 'Project status',
                    value: _selectedProjectStatus,
                    items: _projectStatuses,
                    required: true,
                    onChanged: (value) =>
                        setState(() => _selectedProjectStatus = value),
                  ),
                  const SizedBox(height: 20),

                  _buildDatePicker(label: 'Deadline', required: true),
                  const SizedBox(height: 20),

                  _buildTextField(
                    label: "Who's working on report?",
                    controller: _whoWorkingController,
                    hint: 'Enter his/her name',
                  ),
                  const SizedBox(height: 20),

                  _buildDropdown(
                    label: 'Report status',
                    value: _selectedReportStatus,
                    items: _reportStatuses,
                    required: true,
                    onChanged: (value) =>
                        setState(() => _selectedReportStatus = value),
                  ),
                  const SizedBox(height: 20),

                  _buildToggle(
                    label: 'Report sent',
                    value: _reportSent,
                    onChanged: (value) => setState(() => _reportSent = value),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: eodProvider.isSubmitting ? null : _submitEOD,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.edgePrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: eodProvider.isSubmitting
                          ? const Center(
                              child: ThreePulsingDots(
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : Text(
                              widget.eodData != null ? 'Update EOD' : 'Submit',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    String? hint,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(fontSize: 14, color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.edgePrimary,
                width: 1.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(fontSize: 14, color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Select one',
            hintStyle: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.edgePrimary,
                width: 1.5,
              ),
            ),
          ),
          validator: required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an option';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker({required String label, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(fontSize: 14, color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDeadline,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDeadline != null
                        ? DateFormat('MMM d, y').format(_selectedDeadline!)
                        : 'Choose Date',
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedDeadline != null
                          ? Colors.black87
                          : Colors.grey[900],
                    ),
                  ),
                ),
                Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.edgeText,
            fontWeight: FontWeight.w900,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          trackOutlineColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.edgePrimary.withValues(alpha: 0.5);
            }
            return AppColors.edgePrimary;
          }),
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.grey;
          }),
        ),
      ],
    );
  }
}
