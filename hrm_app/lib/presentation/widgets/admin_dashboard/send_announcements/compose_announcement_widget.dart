import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class ComposeAnnouncementCard extends StatefulWidget {
  final Function(Map<String, dynamic>) onSend;

  const ComposeAnnouncementCard({super.key, required this.onSend});

  @override
  State<ComposeAnnouncementCard> createState() =>
      _ComposeAnnouncementCardState();
}

class _ComposeAnnouncementCardState extends State<ComposeAnnouncementCard>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedAudience = 'all';
  String _selectedPriority = 'normal';
  bool _isSending = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  static const Duration _animDuration = Duration(milliseconds: 400);
  static const Curve _animCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
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
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  Future<void> _sendAnnouncement() async {
    _triggerHaptic();

    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: AppColors.edgeError,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    await Future.delayed(const Duration(seconds: 2));

    widget.onSend({
      'title': _titleController.text,
      'message': _messageController.text,
      'audience': _selectedAudience,
      'priority': _selectedPriority,
    });

    setState(() {
      _titleController.clear();
      _messageController.clear();
      _selectedAudience = 'all';
      _selectedPriority = 'normal';
      _isSending = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement sent successfully'),
          backgroundColor: AppColors.edgeAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
          decoration: BoxDecoration(
            color: AppColors.edgeSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.edgeDivider, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.edit_rounded,
                    color: AppColors.edgePrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Compose Announcement',
                    style: TextStyle(
                      fontSize: isSmallDevice ? 16 : 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.edgeText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: isSmallDevice ? 14 : 15,
                  color: AppColors.edgeText,
                ),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(
                    fontSize: isSmallDevice ? 13 : 14,
                    color: AppColors.edgeTextSecondary,
                  ),
                  hintText: 'Enter announcement title',
                  hintStyle: TextStyle(
                    fontSize: isSmallDevice ? 14 : 15,
                    color: AppColors.edgeTextSecondary.withOpacity(0.6),
                  ),
                  prefixIcon: const Icon(
                    Icons.title_rounded,
                    color: AppColors.edgeTextSecondary,
                    size: 18,
                  ),
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
                    borderSide: const BorderSide(
                      color: AppColors.edgePrimary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 4,
                style: TextStyle(
                  fontSize: isSmallDevice ? 14 : 15,
                  color: AppColors.edgeText,
                ),
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: TextStyle(
                    fontSize: isSmallDevice ? 13 : 14,
                    color: AppColors.edgeTextSecondary,
                  ),
                  hintText: 'Type your announcement here...',
                  hintStyle: TextStyle(
                    fontSize: isSmallDevice ? 14 : 15,
                    color: AppColors.edgeTextSecondary.withOpacity(0.6),
                  ),
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 66),
                    child: Icon(
                      Icons.message_rounded,
                      color: AppColors.edgeTextSecondary,
                      size: 18,
                    ),
                  ),
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
                    borderSide: const BorderSide(
                      color: AppColors.edgePrimary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleDropdown(
                      'Audience',
                      _selectedAudience,
                      [
                        _buildDropdownItem(
                          'all',
                          'Everyone',
                          Icons.groups_rounded,
                        ),
                        _buildDropdownItem(
                          'hr',
                          'HR Only',
                          Icons.manage_accounts_rounded,
                        ),
                        _buildDropdownItem(
                          'employees',
                          'Employees',
                          Icons.person_rounded,
                        ),
                      ],
                      (value) {
                        _triggerHaptic();
                        setState(() => _selectedAudience = value!);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSimpleDropdown(
                      'Priority',
                      _selectedPriority,
                      [
                        _buildPriorityItem(
                          'normal',
                          'Normal',
                          AppColors.edgeAccent,
                        ),
                        _buildPriorityItem(
                          'high',
                          'High',
                          AppColors.edgeWarning,
                        ),
                        _buildPriorityItem(
                          'urgent',
                          'Urgent',
                          AppColors.edgeError,
                        ),
                      ],
                      (value) {
                        _triggerHaptic();
                        setState(() => _selectedPriority = value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendAnnouncement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.edgePrimary,
                    foregroundColor: AppColors.edgeSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: AppColors.edgePrimary.withOpacity(
                      0.5,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isSending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: AppColors.edgeSurface,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Send Announcement',
                                style: TextStyle(
                                  fontSize: isSmallDevice ? 13 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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

  Widget _buildSimpleDropdown(
    String label,
    String currentValue,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
  ) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallDevice ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeText,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.edgeDivider),
            color: AppColors.edgeSurface,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              icon: const Icon(
                Icons.arrow_drop_down,
                color: AppColors.edgeTextSecondary,
                size: 20,
              ),
              style: TextStyle(
                fontSize: isSmallDevice ? 12 : 13,
                color: AppColors.edgeText,
                fontWeight: FontWeight.w500,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(
    String value,
    String label,
    IconData icon,
  ) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.edgePrimary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _buildPriorityItem(
    String value,
    String label,
    Color color,
  ) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
