import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class CreateLeaveRequestScreen extends StatefulWidget {
  const CreateLeaveRequestScreen({super.key});

  @override
  State<CreateLeaveRequestScreen> createState() =>
      _CreateLeaveRequestScreenState();
}

class _CreateLeaveRequestScreenState extends State<CreateLeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedLeaveType;
  String? _selectedDuration;
  DateTime? _fromDate;
  DateTime? _toDate;
  final _reasonController = TextEditingController();
  final _hoursController = TextEditingController();
  String? _selectedHalfDayPeriod;
  TimeOfDay? _startTime;

  final List<String> _leaveTypes = [
    'Casual Leave',
    'Sick Leave',
    'Work From Home',
    'Permission',
  ]; // Backend values might differ, mapping needed
  final List<String> _durations = [
    'Full Day',
    'Half Day',
    'Hours',
  ]; // Backend values: full_day, half_day, hours

  // Mapping for API
  String _getApiLeaveType(String displayType) {
    switch (displayType) {
      case 'Casual Leave':
        return 'casual';
      case 'Sick Leave':
        return 'sick';
      case 'Work From Home':
        return 'work_from_home';
      case 'Permission':
        return 'permission';
      default:
        return 'casual';
    }
  }

  String _getApiDuration(String displayDuration) {
    switch (displayDuration) {
      case 'Full Day':
        return 'full_day';
      case 'Half Day':
        return 'half_day';
      case 'Hours':
        return 'hours';
      default:
        return 'full_day';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 100,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Row(
            children: [
              const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 4),
              const Text(
                'Back',
                style: TextStyle(color: AppColors.primary, fontSize: 16),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Create a leave request',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      label: 'Leave Type',
                      value: _selectedLeaveType,
                      items: _leaveTypes,
                      hint: 'Select one',
                      onChanged: (val) => setState(() {
                        _selectedLeaveType = val;
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(
                      label: 'Duration',
                      value: _selectedDuration,
                      items: _durations,
                      hint: 'Select one',
                      onChanged: (val) =>
                          setState(() => _selectedDuration = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Conditional Fields based on Duration
              if (_selectedDuration == 'Half Day') ...[
                _buildDropdownField(
                  label: 'Session',
                  value: _selectedHalfDayPeriod,
                  items: ['First Half', 'Second Half'],
                  hint: 'Select session',
                  onChanged: (val) =>
                      setState(() => _selectedHalfDayPeriod = val),
                ),
                const SizedBox(height: 24),
              ],

              if (_selectedDuration == 'Hours') ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Hours',
                        controller: _hoursController,
                        keyboardType: TextInputType.number,
                        hint: 'e.g. 2',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeField(
                        label: 'Start Time',
                        time: _startTime,
                        onTap: () => _selectTime(true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'From',
                      date: _fromDate,
                      onTap: () => _selectDate(true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_selectedDuration !=
                      'Hours') // Hours usually implies single day
                    Expanded(
                      child: _buildDateField(
                        label: 'To',
                        date: _toDate,
                        onTap: () => _selectDate(false),
                      ),
                    ),
                  if (_selectedDuration == 'Hours')
                    Expanded(child: Container()), // Spacer
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Reason for the Leave',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextFormField(
                  controller: _reasonController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Enter your message here.',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter a reason'
                      : null,
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: Consumer<EmployeeProvider>(
                    builder: (context, provider, _) {
                      return provider.isApplyingLeave
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Submit request',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required String hint,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF4B5563),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                hint,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.primary,
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF4B5563),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null
                      ? DateFormat('dd, MMMM yyyy').format(date)
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: date != null
                        ? Colors.black87
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(picked)) {
            _toDate = null;
          }
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF4B5563),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.only(
                bottom: 8,
              ), // align text center
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF4B5563),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time != null ? time.format(context) : 'Select time',
                  style: TextStyle(
                    fontSize: 14,
                    color: time != null
                        ? Colors.black87
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                const Icon(
                  Icons.access_time,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLeaveType == null || _selectedDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select leave type and duration')),
      );
      return;
    }
    if (_fromDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select from date')));
      return;
    }
    // Logic for single date vs range based on duration could be added here
    final endDate = _toDate ?? _fromDate!; // Default to single day if not range

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeProvider = Provider.of<EmployeeProvider>(
        context,
        listen: false,
      );

      if (authProvider.token == null) return;

      String? halfDayPeriod;
      int? permissionHours;
      String? permissionStartTimeStr;
      String? permissionEndTimeStr;

      if (_selectedDuration == 'Half Day') {
        // Map display to API: 'First Half' -> 'first_half'
        halfDayPeriod = _selectedHalfDayPeriod == 'First Half'
            ? 'first_half'
            : 'second_half';
      } else if (_selectedDuration == 'Hours') {
        if (_hoursController.text.isNotEmpty)
          permissionHours = int.tryParse(_hoursController.text);
        if (_startTime != null) {
          permissionStartTimeStr =
              '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
          // Calculate end time simply for now or let backend handle
          // If strictly needed:
          final end = TimeOfDay(
            hour: (_startTime!.hour + (permissionHours ?? 1)) % 24,
            minute: _startTime!.minute,
          );
          permissionEndTimeStr =
              '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
        }
      }

      await employeeProvider.applyForLeave(
        authProvider.token!,
        _getApiLeaveType(_selectedLeaveType!),
        _getApiDuration(_selectedDuration!),
        _fromDate!,
        endDate,
        _reasonController.text,
        halfDayPeriod: halfDayPeriod,
        permissionHours: permissionHours,
        permissionStartTime: permissionStartTimeStr,
        permissionEndTime: permissionEndTimeStr,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave applied successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
