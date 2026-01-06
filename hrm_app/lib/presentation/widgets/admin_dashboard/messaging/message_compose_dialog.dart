import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/message_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class MessageComposeDialog extends StatefulWidget {
  const MessageComposeDialog({super.key});

  @override
  State<MessageComposeDialog> createState() => _MessageComposeDialogState();
}

class _MessageComposeDialogState extends State<MessageComposeDialog>
    with TickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 400);
  static const Curve _animCurve = Curves.easeOutCubic;

  late TabController _tabController;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();

  String _selectedRecipientType = 'employee';
  String? _selectedRecipientId;
  String? _selectedRecipientName;
  String _priority = 'normal';
  DateTime? _scheduledFor;
  bool _isScheduled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller = AnimationController(vsync: this, duration: _animDuration);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipients();
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  void _loadRecipients() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      final messageProvider = Provider.of<MessageProvider>(
        context,
        listen: false,
      );
      messageProvider.loadEmployees(authProvider.token!);
      messageProvider.loadHRUsers(authProvider.token!);
    }
  }

  void _onSearchChanged(String query) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      final messageProvider = Provider.of<MessageProvider>(
        context,
        listen: false,
      );
      if (_selectedRecipientType == 'employee') {
        messageProvider.loadEmployees(authProvider.token!, search: query);
      } else {
        messageProvider.loadHRUsers(authProvider.token!, search: query);
      }
    }
  }

  void _selectRecipient(Map<String, dynamic> recipient) {
    _triggerHaptic();
    setState(() {
      _selectedRecipientId = recipient['_id'];
      _selectedRecipientName = recipient['name'] ?? recipient['fullName'];
    });
  }

  Future<void> _sendMessage() async {
    _triggerHaptic();

    if (!_formKey.currentState!.validate()) return;
    if (_selectedRecipientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a recipient'),
          backgroundColor: AppColors.edgeError,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;

    final messageProvider = Provider.of<MessageProvider>(
      context,
      listen: false,
    );
    bool success = false;

    if (_selectedRecipientType == 'employee') {
      success = await messageProvider.sendMessageToEmployee(
        _selectedRecipientId!,
        _subjectController.text,
        _contentController.text,
        authProvider.token!,
        priority: _priority,
        scheduledFor: _isScheduled ? _scheduledFor : null,
      );
    } else {
      success = await messageProvider.sendMessageToHR(
        _selectedRecipientId!,
        _subjectController.text,
        _contentController.text,
        authProvider.token!,
        priority: _priority,
        scheduledFor: _isScheduled ? _scheduledFor : null,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Message sent successfully'
                : messageProvider.error ?? 'Failed to send message',
          ),
          backgroundColor: success ? AppColors.edgeAccent : AppColors.edgeError,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      if (success) _clearForm();
    }
  }

  void _clearForm() {
    _triggerHaptic();
    _subjectController.clear();
    _contentController.clear();
    _selectedRecipientId = null;
    _selectedRecipientName = null;
    _priority = 'normal';
    _scheduledFor = null;
    _isScheduled = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildRecipientTypeTabs(),
              const SizedBox(height: 16),
              Expanded(child: _buildForm()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.edit_outlined, color: AppColors.edgePrimary, size: 20),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Compose Message',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
              letterSpacing: -0.5,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _clearForm,
          icon: const Icon(
            Icons.clear,
            color: AppColors.edgeTextSecondary,
            size: 16,
          ),
          label: const Text(
            'Clear',
            style: TextStyle(color: AppColors.edgeTextSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientTypeTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.edgeBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.edgeDivider),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          _triggerHaptic();
          setState(() {
            _selectedRecipientType = index == 0 ? 'employee' : 'hr';
            _selectedRecipientId = null;
            _selectedRecipientName = null;
          });
          _loadRecipients();
        },
        labelColor: AppColors.edgePrimary,
        unselectedLabelColor: AppColors.edgeTextSecondary,
        indicator: BoxDecoration(
          color: AppColors.edgePrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Send to Employee'),
          Tab(text: 'Send to HR'),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildRecipientSelection(),
            const SizedBox(height: 12),
            _buildSubjectField(),
            const SizedBox(height: 12),
            _buildContentField(),
            const SizedBox(height: 12),
            _buildOptionsRow(),
            if (_isScheduled) ...[
              const SizedBox(height: 12),
              _buildScheduleField(),
            ],
            const SizedBox(height: 16),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectField() {
    return TextFormField(
      controller: _subjectController,
      style: const TextStyle(fontSize: 13, color: AppColors.edgeText),
      decoration: InputDecoration(
        labelText: 'Subject',
        labelStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.edgeTextSecondary,
        ),
        hintText: 'Enter message subject',
        hintStyle: TextStyle(
          fontSize: 13,
          color: AppColors.edgeTextSecondary.withOpacity(0.6),
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
        prefixIcon: const Icon(
          Icons.subject,
          color: AppColors.edgeTextSecondary,
          size: 18,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        isDense: true,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Subject is required';
        }
        return null;
      },
    );
  }

  Widget _buildContentField() {
    return SizedBox(
      height: 180,
      child: TextFormField(
        controller: _contentController,
        style: const TextStyle(fontSize: 13, color: AppColors.edgeText),
        decoration: InputDecoration(
          labelText: 'Message Content',
          labelStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.edgeTextSecondary,
          ),
          hintText: 'Type your message here...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: AppColors.edgeTextSecondary.withOpacity(0.6),
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
          contentPadding: const EdgeInsets.all(12),
          alignLabelWithHint: true,
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Message content is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildOptionsRow() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: InputDecoration(
              labelText: 'Priority',
              labelStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.edgeTextSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.edgeDivider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.edgeDivider),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.edgeText),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Low')),
              DropdownMenuItem(value: 'normal', child: Text('Normal')),
              DropdownMenuItem(value: 'high', child: Text('High')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
            ],
            onChanged: (value) {
              _triggerHaptic();
              setState(() => _priority = value!);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Checkbox(
                value: _isScheduled,
                onChanged: (value) {
                  _triggerHaptic();
                  setState(() {
                    _isScheduled = value!;
                    if (!_isScheduled) _scheduledFor = null;
                  });
                },
                activeColor: AppColors.edgePrimary,
              ),
              const Expanded(
                child: Text(
                  'Schedule',
                  style: TextStyle(
                    color: AppColors.edgeTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleField() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Schedule Date & Time',
        labelStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.edgeTextSecondary,
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
        prefixIcon: const Icon(
          Icons.schedule,
          color: AppColors.edgeTextSecondary,
          size: 18,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, color: AppColors.edgeText),
      readOnly: true,
      controller: TextEditingController(
        text: _scheduledFor != null
            ? '${_scheduledFor!.day}/${_scheduledFor!.month}/${_scheduledFor!.year} ${_scheduledFor!.hour}:${_scheduledFor!.minute.toString().padLeft(2, '0')}'
            : 'Select date and time',
      ),
      onTap: () async {
        _triggerHaptic();
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null && mounted) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (time != null) {
            setState(() {
              _scheduledFor = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            });
          }
        }
      },
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _sendMessage,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.edgePrimary,
          foregroundColor: AppColors.edgeSurface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send, size: 16),
            const SizedBox(width: 8),
            Text(
              _isScheduled ? 'Schedule Message' : 'Send Message',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientSelection() {
    return Consumer<MessageProvider>(
      builder: (context, messageProvider, child) {
        final recipients = _selectedRecipientType == 'employee'
            ? messageProvider.employees
            : messageProvider.hrUsers;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Recipient',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 13, color: AppColors.edgeText),
              decoration: InputDecoration(
                hintText: 'Search ${_selectedRecipientType}s...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.edgeTextSecondary.withOpacity(0.6),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.edgeTextSecondary,
                  size: 18,
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedRecipientName != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.edgePrimary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person,
                      color: AppColors.edgePrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedRecipientName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgePrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _triggerHaptic();
                        setState(() {
                          _selectedRecipientId = null;
                          _selectedRecipientName = null;
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.edgeError,
                        size: 16,
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.edgeDivider),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: recipients.isEmpty
                    ? Center(
                        child: Text(
                          'No ${_selectedRecipientType}s found',
                          style: const TextStyle(
                            color: AppColors.edgeTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: recipients.length,
                        itemBuilder: (context, index) {
                          final recipient = recipients[index];
                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.edgePrimary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  (recipient['name'] ??
                                          recipient['fullName'] ??
                                          'U')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.edgePrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              recipient['name'] ??
                                  recipient['fullName'] ??
                                  'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              recipient['email'] ?? '',
                              style: const TextStyle(
                                color: AppColors.edgeTextSecondary,
                                fontSize: 11,
                              ),
                            ),
                            onTap: () => _selectRecipient(recipient),
                          );
                        },
                      ),
              ),
          ],
        );
      },
    );
  }
}
