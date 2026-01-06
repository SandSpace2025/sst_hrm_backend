import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/presentation/providers/messaging_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:hrm_app/presentation/screens/messaging/conversation_screen.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:hrm_app/core/models/conversation.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeInOutCubic;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  int _selectedTab = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration);
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) return;

    if (forceRefresh) {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.any((result) => result != ConnectivityResult.none);

      if (!isOnline) {
        if (mounted) SnackBarUtils.showError(context, 'No internet connection');
        return;
      }

      if (mounted) SnackBarUtils.showInfo(context, 'Refreshing contacts...');
    }

    try {
      final userRole = authProvider.role?.toLowerCase();
      final List<Future> futures = [];

      if (userRole == 'employee') {
        final employeeProvider = Provider.of<EmployeeProvider>(
          context,
          listen: false,
        );

        futures.add(
          employeeProvider.loadHRContacts(
            authProvider.token!,
            forceRefresh: forceRefresh,
          ),
        );
        futures.add(
          employeeProvider.loadEmployeeContactsForMessaging(
            authProvider.token!,
            forceRefresh: forceRefresh,
          ),
        );
      } else if (userRole == 'hr') {
        final hrProvider = Provider.of<HRProvider>(context, listen: false);

        futures.add(
          hrProvider.loadAdminsForMessaging(
            authProvider.token!,
            forceRefresh: forceRefresh,
          ),
        );
        futures.add(
          hrProvider.loadEmployeesForMessaging(
            authProvider.token!,
            forceRefresh: forceRefresh,
          ),
        );
      } else if (userRole == 'admin') {
        final adminProvider = Provider.of<AdminProvider>(
          context,
          listen: false,
        );

        futures.add(
          adminProvider.loadHRUsers(
            authProvider.token!,
            forceRefresh: forceRefresh,
          ),
        );

        futures.add(
          adminProvider.loadEmployees(
            authProvider.token!,
            forceRefresh: forceRefresh,
          ),
        );
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

      if (forceRefresh && mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        String? error;
        bool hasData = false;

        if (userRole == 'employee') {
          final employeeProvider = Provider.of<EmployeeProvider>(
            context,
            listen: false,
          );
          error = employeeProvider.error;
          hasData =
              employeeProvider.hrContacts.isNotEmpty ||
              employeeProvider.employeeContacts.isNotEmpty;
        } else if (userRole == 'hr') {
          final hrProvider = Provider.of<HRProvider>(context, listen: false);
          error = hrProvider.error;
          hasData =
              hrProvider.adminsForMessaging.isNotEmpty ||
              hrProvider.employeesForMessaging.isNotEmpty;
        } else if (userRole == 'admin') {
          final adminProvider = Provider.of<AdminProvider>(
            context,
            listen: false,
          );
          error = adminProvider.error;
          hasData =
              adminProvider.hrUsers.isNotEmpty ||
              adminProvider.employees.isNotEmpty;
        }

        if (error != null) {
          final errorMsg = error.toLowerCase();
          if (errorMsg.contains('no internet') ||
              errorMsg.contains('socketexception') ||
              errorMsg.contains('connection')) {
            if (mounted) {
              SnackBarUtils.showError(context, 'No internet connection');
            }
          } else {
            if (mounted) {
              SnackBarUtils.showError(context, 'Failed to refresh: $error');
            }
          }
        } else if (hasData) {
          if (mounted) SnackBarUtils.showSuccess(context, 'Contacts refreshed');
        }
      }
    } catch (e) {
      if (forceRefresh && mounted) {
        SnackBarUtils.showError(context, 'Failed to refresh contacts');
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _selectTab(int tabIndex) {
    _triggerHaptic();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.role?.toLowerCase() == 'employee' && tabIndex == 2) {
      final employeeProvider = Provider.of<EmployeeProvider>(
        context,
        listen: false,
      );
      if (!employeeProvider.canMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.lock, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Admin access required to message administrators',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    setState(() {
      _selectedTab = tabIndex;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  String _getSearchHint() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.role?.toLowerCase();

    if (userRole == 'admin') {
      return _selectedTab == 0 ? 'Search HR...' : 'Search employees...';
    }

    if (userRole == 'employee') {
      switch (_selectedTab) {
        case 0:
          return 'Search HR contacts...';
        case 1:
          return 'Search employees...';
        case 2:
          return 'Search admin...';
        default:
          return 'Search...';
      }
    }

    switch (_selectedTab) {
      case 0:
        return 'Search Admin...';
      case 1:
        return 'Search employees...';
      default:
        return 'Search...';
    }
  }

  String _getEmptyStateTitle() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.role?.toLowerCase();

    if (userRole == 'admin') {
      return _selectedTab == 0 ? 'No HR contacts found' : 'No employees found';
    }

    if (userRole == 'employee') {
      switch (_selectedTab) {
        case 0:
          return 'No HR contacts found';
        case 1:
          return 'No employees found';
        case 2:
          return 'No admin found';
        default:
          return 'No items found';
      }
    }

    switch (_selectedTab) {
      case 0:
        return 'No admin found';
      case 1:
        return 'No employees found';
      default:
        return 'No items found';
    }
  }

  String _getEmptyStateMessage() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.role?.toLowerCase();

    if (userRole == 'admin') {
      return _selectedTab == 0
          ? 'HR contacts are always accessible for support'
          : 'Employee contacts are available for collaboration';
    }

    if (userRole == 'employee') {
      switch (_selectedTab) {
        case 0:
          return 'HR contacts are always accessible for support';
        case 1:
          return 'Employee contacts are available for collaboration';
        case 2:
          return 'Admin access requires permission';
        default:
          return 'No items available';
      }
    }

    switch (_selectedTab) {
      case 0:
        return 'Admins can assist with organizational matters';
      case 1:
        return 'Employee contacts are available for collaboration';
      default:
        return 'No items available';
    }
  }

  IconData _getEmptyStateIcon() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.role?.toLowerCase();

    if (userRole == 'admin') {
      return _selectedTab == 0
          ? Icons.support_agent_outlined
          : Icons.person_outline;
    }

    if (userRole == 'employee') {
      switch (_selectedTab) {
        case 0:
          return Icons.support_agent_outlined;
        case 1:
          return Icons.person_outline;
        case 2:
          return Icons.admin_panel_settings_outlined;
        default:
          return Icons.info_outline;
      }
    }

    switch (_selectedTab) {
      case 0:
        return Icons.admin_panel_settings_outlined;
      case 1:
        return Icons.person_outline;
      default:
        return Icons.info_outline;
    }
  }

  List<Map<String, dynamic>> _getContactsForTab() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.role?.toLowerCase();

    if (userRole == 'employee') {
      final employeeProvider = Provider.of<EmployeeProvider>(
        context,
        listen: false,
      );

      switch (_selectedTab) {
        case 0:
          return List<Map<String, dynamic>>.from(employeeProvider.hrContacts);
        case 1:
          return List<Map<String, dynamic>>.from(
            employeeProvider.employeeContacts,
          );
        case 2:
          return List<Map<String, dynamic>>.from(
            employeeProvider.adminContacts,
          );
        default:
          return [];
      }
    } else if (userRole == 'hr') {
      final hrProvider = Provider.of<HRProvider>(context, listen: false);

      switch (_selectedTab) {
        case 0:
          final adminContacts = List<Map<String, dynamic>>.from(
            hrProvider.adminsForMessaging,
          );
          return adminContacts;
        case 1:
          final employeeContacts = hrProvider.employeesForMessaging
              .map(
                (employee) => {
                  'id': employee.id,
                  'name': employee.name,
                  'email': employee.email,
                  'phone': employee.phone,
                  'profilePic': employee.profilePic,
                  'jobTitle': employee.jobTitle,
                  'subOrganisation': employee.subOrganisation,
                  'employeeId': employee.employeeId,
                  'userType': 'employee',
                },
              )
              .toList();
          return employeeContacts;
        default:
          return [];
      }
    } else if (userRole == 'admin') {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);

      switch (_selectedTab) {
        case 0:
          return adminProvider.hrUsers
              .map(
                (hr) => {
                  'id': hr.id,
                  'name': hr.name,
                  'email': hr.email,
                  'phone': hr.phone,
                  'profilePic': hr.profilePicture,
                  'userType': 'hr',
                },
              )
              .toList();
        case 1:
          return adminProvider.employees
              .map(
                (employee) => {
                  'id': employee.id,
                  'name': employee.name,
                  'email': employee.email,
                  'phone': employee.phone,
                  'profilePic': employee.profilePic,
                  'userType': 'employee',
                },
              )
              .toList();
        default:
          return [];
      }
    }

    return [];
  }

  void _openChat(Map<String, dynamic> contact) async {
    _triggerHaptic();

    _searchFocusNode.unfocus();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Universal routing logic using ConversationScreen
      final messagingProvider = Provider.of<MessagingProvider>(
        context,
        listen: false,
      );

      messagingProvider.initializeMessaging(authProvider.token!);

      await messagingProvider.loadConversations(forceRefresh: false);

      final userId = contact['_id'] ?? contact['id'] ?? '';
      final userType = _getUserTypeForTab();

      Conversation? targetConversation;
      for (final conversation in messagingProvider.conversations) {
        for (final participant in conversation.participants) {
          if (participant.userId == userId &&
              participant.userType.toLowerCase() == userType.toLowerCase()) {
            targetConversation = conversation;
            break;
          }
        }
        if (targetConversation != null) break;
      }

      if (targetConversation != null) {
        messagingProvider.setCurrentConversation(targetConversation);

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ConversationScreen(conversation: targetConversation!),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOutCubic;
                  final tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  final offsetAnimation = animation.drive(tween);
                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
            transitionDuration: _animDuration,
          ),
        ).then((_) {
          _searchFocusNode.unfocus();
        });
      } else {
        await _createNewConversation(contact, messagingProvider);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createNewConversation(
    Map<String, dynamic> contact,
    MessagingProvider messagingProvider,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Legacy routing removed
      final token = authProvider.token!;

      final payload = Jwt.parseJwt(token);
      final currentUserId = payload['userId'] ?? payload['id'];
      final currentUserRole = authProvider.role;
      final currentUserName = payload['name'] ?? payload['fullName'] ?? 'User';
      final currentUserEmail = payload['email'] ?? '';

      final participants = [
        {
          'userId': currentUserId.toString(),
          'userType': _capitalizeUserType(currentUserRole ?? ''),
          'name': currentUserName,
          'email': currentUserEmail,
        },

        {
          'userId': contact['_id'] ?? contact['id'],
          'userType': _capitalizeUserType(_getUserTypeForTab()),
          'name': contact['name'] ?? contact['fullName'] ?? contact['email'],
          'email': contact['email'],
        },
      ];

      final contactName =
          contact['name'] ?? contact['fullName'] ?? contact['email'];
      final conversationTitle = 'Chat with $contactName';

      final success = await messagingProvider.createConversation(
        participants: participants,
        title: conversationTitle,
        conversationType: 'direct',
      );

      if (success && messagingProvider.currentConversation != null) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ConversationScreen(
                  conversation: messagingProvider.currentConversation!,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOutCubic;
                  final tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  final offsetAnimation = animation.drive(tween);
                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
            transitionDuration: _animDuration,
          ),
        ).then((_) {
          _searchFocusNode.unfocus();
        });
      } else if (!success &&
          messagingProvider.error != null &&
          messagingProvider.error!.contains('already exists')) {
        await messagingProvider.loadConversations(refresh: true);

        final userId = contact['_id'] ?? contact['id'];
        final userType = _getUserTypeForTab();

        Conversation? existingConv;
        for (final conversation in messagingProvider.conversations) {
          for (final participant in conversation.participants) {
            if (participant.userId == userId &&
                participant.userType.toLowerCase() == userType.toLowerCase()) {
              existingConv = conversation;

              break;
            }
          }
          if (existingConv != null) break;
        }

        if (existingConv != null) {
          messagingProvider.setCurrentConversation(existingConv);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ConversationScreen(conversation: existingConv!),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeOutCubic;
                    final tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    final offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
              transitionDuration: _animDuration,
            ),
          ).then((_) {
            _searchFocusNode.unfocus();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation exists but could not be loaded'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to create conversation with ${contact['name'] ?? 'this contact'}. Error: ${messagingProvider.error ?? 'Unknown error'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating conversation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getUserTypeForTab() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.role?.toLowerCase();

    if (userRole == 'admin') {
      return _selectedTab == 0 ? 'hr' : 'employee';
    }

    if (userRole == 'employee') {
      switch (_selectedTab) {
        case 0:
          return 'hr';
        case 1:
          return 'employee';
        case 2:
          return 'admin';
        default:
          return '';
      }
    }

    return _selectedTab == 0 ? 'admin' : 'employee';
  }

  String _capitalizeUserType(String userType) {
    switch (userType.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'hr':
        return 'HR';
      case 'employee':
        return 'Employee';
      default:
        return userType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
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

            Column(
              children: [
                Container(
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    children: [
                      _buildEnhancedSearchBar(),
                      const SizedBox(height: 16),
                      _buildEnhancedToggleSwitch(),
                    ],
                  ),
                ),

                Expanded(child: _buildContactsList()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedSearchBar() {
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
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.edgeText,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: _getSearchHint(),
          hintStyle: TextStyle(
            color: AppColors.edgeTextSecondary.withOpacity(0.6),
            fontSize: 14,
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
              Icons.search_rounded,
              color: AppColors.edgePrimary,
              size: 20,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: AppColors.edgeTextSecondary,
                    size: 18,
                  ),
                  onPressed: () {
                    _triggerHaptic();
                    _searchController.clear();
                    _onSearchChanged('');
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.edgeBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.edgePrimary,
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.edgeDivider.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedToggleSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.edgeDivider.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildEnhancedToggleButton(
              label: 'HR',
              icon: Icons.support_agent_rounded,
              isSelected: _selectedTab == 0,
              onTap: () => _selectTab(0),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.edgeDivider.withOpacity(0.3),
          ),
          Expanded(
            child: _buildEnhancedToggleButton(
              label: 'Employees',
              icon: Icons.group_rounded,
              isSelected: _selectedTab == 1,
              onTap: () => _selectTab(1),
            ),
          ),
          // Admin tab removed for employees per requirement
        ],
      ),
    );
  }

  Widget _buildEnhancedToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: isLocked
            ? Colors.orange.withOpacity(0.1)
            : AppColors.edgePrimary.withOpacity(0.1),
        highlightColor: isLocked
            ? Colors.orange.withOpacity(0.05)
            : AppColors.edgePrimary.withOpacity(0.05),
        child: AnimatedContainer(
          duration: _animDuration,
          curve: _animCurve,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.edgePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.edgePrimary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLocked) ...[
                Icon(
                  Icons.lock,
                  color: isSelected ? Colors.white : Colors.orange,
                  size: 14,
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isLocked
                          ? Colors.orange.shade700
                          : AppColors.edgeTextSecondary),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isLocked
                            ? Colors.orange.shade700
                            : AppColors.edgeTextSecondary),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.role?.toLowerCase();

    if (userRole == 'employee') {
      return Consumer<EmployeeProvider>(
        builder: (context, employeeProvider, child) {
          if (employeeProvider.isLoading) {
            return _buildLoadingState();
          }

          if (employeeProvider.error != null) {
            return _buildErrorState(employeeProvider.error!);
          }

          final contacts = _getContactsForTab();

          if (contacts.isEmpty) {
            return _buildEmptyState();
          }

          final filteredContacts = contacts.where((contact) {
            if (_searchQuery.isEmpty) return true;

            final name = (contact['name'] ?? contact['fullName'] ?? '')
                .toLowerCase();
            final email = (contact['email'] ?? '').toLowerCase();

            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();

          if (filteredContacts.isEmpty) {
            return _buildNoResultsState();
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                return _buildContactItem(filteredContacts[index]);
              },
            ),
          );
        },
      );
    } else if (userRole == 'hr') {
      return Consumer<HRProvider>(
        builder: (context, hrProvider, child) {
          if (hrProvider.isLoading) {
            return _buildLoadingState();
          }

          if (hrProvider.error != null) {
            return _buildErrorState(hrProvider.error!);
          }

          final contacts = _getContactsForTab();

          if (contacts.isEmpty) {
            return _buildEmptyState();
          }

          final filteredContacts = contacts.where((contact) {
            if (_searchQuery.isEmpty) return true;

            final name = (contact['name'] ?? contact['fullName'] ?? '')
                .toLowerCase();
            final email = (contact['email'] ?? '').toLowerCase();

            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();

          if (filteredContacts.isEmpty) {
            return _buildNoResultsState();
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                return _buildContactItem(filteredContacts[index]);
              },
            ),
          );
        },
      );
    } else if (userRole == 'admin') {
      return Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          if (adminProvider.isLoading) {
            return _buildLoadingState();
          }

          if (adminProvider.error != null) {
            return _buildErrorState(adminProvider.error!);
          }

          final contacts = _getContactsForTab();

          if (contacts.isEmpty) {
            return _buildEmptyState();
          }

          final filteredContacts = contacts.where((contact) {
            if (_searchQuery.isEmpty) return true;

            final name = (contact['name'] ?? contact['fullName'] ?? '')
                .toLowerCase();
            final email = (contact['email'] ?? '').toLowerCase();

            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();

          if (filteredContacts.isEmpty) {
            return _buildNoResultsState();
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                return _buildContactItem(filteredContacts[index]);
              },
            ),
          );
        },
      );
    }

    return _buildEmptyState();
  }

  Widget _buildContactItem(Map<String, dynamic> contact) {
    final name =
        contact['fullName'] ?? contact['name'] ?? contact['email'] ?? 'Unknown';
    final email = contact['email'] ?? '';
    final profilePic = contact['profilePic'] ?? contact['profileImage'] ?? '';
    final userId = contact['_id'] ?? contact['id'] ?? '';

    // Check for unread messages
    bool isUnread = false;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.role?.toLowerCase() == 'employee') {
      final employeeProvider = Provider.of<EmployeeProvider>(
        context,
        listen: false,
      );
      if (userId.isNotEmpty) {
        isUnread = employeeProvider.hasUnreadMessages(userId);
      }
    } else if (authProvider.role?.toLowerCase() == 'admin') {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      if (userId.isNotEmpty) {
        isUnread = adminProvider.hasUnreadMessages(userId);
      }
    } else if (authProvider.role?.toLowerCase() == 'hr') {
      final hrProvider = Provider.of<HRProvider>(context, listen: false);
      if (userId.isNotEmpty) {
        isUnread = hrProvider.hasUnreadMessages(userId);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread
            ? AppColors.edgePrimary.withOpacity(0.05)
            : AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? AppColors.edgePrimary.withOpacity(0.5)
              : AppColors.edgeDivider.withOpacity(0.2),
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChat(contact),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.edgePrimary.withOpacity(0.1),
          highlightColor: AppColors.edgePrimary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.edgePrimary.withOpacity(0.1),
                    border: Border.all(
                      color: isUnread
                          ? AppColors.edgePrimary
                          : AppColors.edgeDivider.withOpacity(0.3),
                      width: isUnread ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.edgePrimary.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildProfileAvatar(name, profilePic),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: isUnread
                                    ? AppColors.edgePrimary
                                    : AppColors.edgeText,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.edgePrimary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'New',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // fixed
                      Text(
                        contact['jobTitle'] ?? contact['designation'] ?? email,
                        style: TextStyle(
                          fontSize: 13,
                          color: isUnread
                              ? AppColors.edgeText
                              : AppColors.edgeTextSecondary,
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isUnread
                        ? AppColors.edgePrimary
                        : AppColors.edgePrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: isUnread
                        ? Colors.white
                        : AppColors.edgeTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(String name, String profilePic) {
    if (profilePic.isNotEmpty) {
      String fullImageUrl = profilePic;
      if (profilePic.startsWith('/')) {
        final String baseUrl = AppConfig.websocketUrl;
        fullImageUrl = '$baseUrl$profilePic';
      }

      return ClipOval(
        child: Image.network(
          fullImageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(name);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.edgePrimary.withOpacity(0.1),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.edgePrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return _buildDefaultAvatar(name);
  }

  Widget _buildDefaultAvatar(String name) {
    final initials = name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.edgePrimary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(8, (index) => ShimmerLoading.listItem()),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.edgePrimary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.edgePrimary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.edgePrimary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unable to load contacts',
              style: TextStyle(
                color: AppColors.edgeText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.edgeTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.edgePrimary,
                    AppColors.edgePrimary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.edgePrimary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _loadData(forceRefresh: true),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Retry',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.edgePrimary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.edgePrimary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                _getEmptyStateIcon(),
                size: 40,
                color: AppColors.edgePrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _getEmptyStateTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.edgeText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getEmptyStateMessage(),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.edgeTextSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.edgeTextSecondary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.edgeTextSecondary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppColors.edgeTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.edgeText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Try searching with a different term',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.edgeTextSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
