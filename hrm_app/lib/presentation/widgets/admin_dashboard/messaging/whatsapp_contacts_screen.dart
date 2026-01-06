import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/data/models/hr_model.dart';
import 'whatsapp_chat_screen.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class WhatsAppContactsScreen extends StatefulWidget {
  const WhatsAppContactsScreen({super.key});

  @override
  State<WhatsAppContactsScreen> createState() => _WhatsAppContactsScreenState();
}

class _WhatsAppContactsScreenState extends State<WhatsAppContactsScreen>
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
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  String _getProfileImageUrl(String profilePic) {
    if (profilePic.isEmpty) {
      return '';
    }

    String imageUrl;
    if (profilePic.startsWith('http')) {
      imageUrl = profilePic;
    } else {
      imageUrl = '${ApiConstants.baseUrl}$profilePic';
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cacheBustedUrl = '$imageUrl?v=$timestamp';
    return cacheBustedUrl;
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      adminProvider.loadEmployees(authProvider.token!);
      adminProvider.loadHRUsers(authProvider.token!);
      adminProvider.loadMessagingPermissionRequests(authProvider.token!);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _selectTab(int tabIndex) {
    _triggerHaptic();
    setState(() {
      _selectedTab = tabIndex;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  String _getSearchHint() {
    switch (_selectedTab) {
      case 0:
        return 'Search employees...';
      case 1:
        return 'Search HR staff...';
      case 2:
        return 'Search permission requests...';
      default:
        return 'Search...';
    }
  }

  String _getEmptyStateTitle() {
    switch (_selectedTab) {
      case 0:
        return 'No employees found';
      case 1:
        return 'No HR staff found';
      case 2:
        return 'No permission requests';
      default:
        return 'No items found';
    }
  }

  String _getEmptyStateMessage() {
    switch (_selectedTab) {
      case 0:
        return 'Start by adding employees to the system';
      case 1:
        return 'Start by adding HR members to the system';
      case 2:
        return 'No employees have requested messaging permissions yet';
      default:
        return 'No items available';
    }
  }

  IconData _getEmptyStateIcon() {
    switch (_selectedTab) {
      case 0:
        return Icons.people_outline;
      case 1:
        return Icons.admin_panel_settings_outlined;
      case 2:
        return Icons.pending_actions_outlined;
      default:
        return Icons.info_outline;
    }
  }

  List<dynamic> _getContactsForTab(AdminProvider adminProvider) {
    switch (_selectedTab) {
      case 0:
        return adminProvider.employees;
      case 1:
        return adminProvider.hrUsers;
      case 2:
        return adminProvider.messagingPermissionRequests;
      default:
        return [];
    }
  }

  void _handleContactTap(
    String userId,
    String userName,
    String userType,
    dynamic contact,
  ) {
    if (_selectedTab == 2) {
      _showPermissionRequestDialog(contact);
    } else {
      _openChat(userId, userName, userType);
    }
  }

  void _openChat(String userId, String userName, String userType) {
    _triggerHaptic();

    _searchFocusNode.unfocus();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WhatsAppChatScreen(
              userId: userId,
              userName: userName,
              userType: userType,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: _animDuration,
      ),
    ).then((_) {
      _searchFocusNode.unfocus();
    });
  }

  void _showPermissionRequestDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employee: ${request['name'] ?? 'Unknown'}'),
              const SizedBox(height: 8),
              Text('Email: ${request['email'] ?? ''}'),
              const SizedBox(height: 8),
              Text(
                'Requested: ${_formatDate(request['messagingPermissions']?['lastRequestedAt'])}',
              ),
              const SizedBox(height: 16),
              const Text(
                'This employee is requesting permission to send messages to admin. Grant access for 48 hours?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _grantPermission(request['_id']);
              },
              child: const Text('Grant Access'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _grantPermission(String employeeId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);

    adminProvider
        .grantMessagingPermission(
          authProvider.token!,
          employeeId,
          durationHours: 48,
        )
        .then((_) {
          adminProvider.loadMessagingPermissionRequests(authProvider.token!);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission granted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        })
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to grant permission: $error'),
              backgroundColor: Colors.red,
            ),
          );
        });
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
            borderSide: const BorderSide(color: AppColors.edgePrimary, width: 2),
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
              label: 'Employees',
              icon: Icons.people_rounded,
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
              label: 'HR Staff',
              icon: Icons.admin_panel_settings_rounded,
              isSelected: _selectedTab == 1,
              onTap: () => _selectTab(1),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.edgeDivider.withOpacity(0.3),
          ),
          Expanded(
            child: _buildEnhancedToggleButton(
              label: 'Requests',
              icon: Icons.pending_actions_rounded,
              isSelected: _selectedTab == 2,
              onTap: () => _selectTab(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.edgePrimary.withOpacity(0.1),
        highlightColor: AppColors.edgePrimary.withOpacity(0.05),
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
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.edgeTextSecondary,
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
                      : AppColors.edgeTextSecondary,
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
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoading) {
          return _buildLoadingState();
        }

        if (adminProvider.error != null) {
          return _buildErrorState(adminProvider.error!);
        }

        final contacts = _getContactsForTab(adminProvider);

        if (contacts.isEmpty) {
          return _buildEmptyState();
        }

        final filteredContacts = contacts.where((contact) {
          if (_searchQuery.isEmpty) return true;

          String name = '';
          String email = '';

          switch (_selectedTab) {
            case 0:
              name = contact.name.toLowerCase();
              email = contact.email.toLowerCase();
              break;
            case 1:
              name = contact.name.toLowerCase();
              email = contact.email.toLowerCase();
              break;
            case 2:
              name = (contact['name'] ?? '').toLowerCase();
              email = (contact['email'] ?? '').toLowerCase();
              break;
          }

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

  Widget _buildContactItem(dynamic contact) {
    final String name;
    final String email;
    final String userId;
    final String? avatarUrl;
    final String userType;

    switch (_selectedTab) {
      case 0:
        final employee = contact as Employee;
        name = employee.name;
        email = employee.email;
        userId = employee.id;
        avatarUrl = employee.profilePic;

        userType = 'Employee';
        break;
      case 1:
        final hr = contact as HR;
        name = hr.name;
        email = hr.email;
        userId = hr.id;
        avatarUrl = hr.profilePicture;
        userType = 'HR';
        break;
      case 2:
        name = contact['name'] ?? 'Unknown';
        email = contact['email'] ?? '';
        userId = contact['_id'] ?? contact['id'] ?? '';
        avatarUrl = null;
        userType = 'Permission Request';
        break;
      default:
        name = '';
        email = '';
        userId = '';
        avatarUrl = null;
        userType = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _selectedTab == 2
            ? AppColors.edgeAccent.withOpacity(0.05)
            : AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedTab == 2
              ? AppColors.edgeAccent.withOpacity(0.2)
              : AppColors.edgeDivider.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _selectedTab == 2
                ? AppColors.edgeAccent.withOpacity(0.08)
                : AppColors.edgeText.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _selectedTab == 2
                ? AppColors.edgeAccent.withOpacity(0.04)
                : AppColors.edgeText.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleContactTap(userId, name, userType, contact),
          borderRadius: BorderRadius.circular(16),
          splashColor: _selectedTab == 2
              ? AppColors.edgeAccent.withOpacity(0.1)
              : AppColors.edgePrimary.withOpacity(0.1),
          highlightColor: _selectedTab == 2
              ? AppColors.edgeAccent.withOpacity(0.05)
              : AppColors.edgePrimary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedTab == 2
                        ? AppColors.edgeAccent.withOpacity(0.1)
                        : AppColors.edgePrimary.withOpacity(0.1),
                    border: Border.all(
                      color: _selectedTab == 2
                          ? AppColors.edgeAccent.withOpacity(0.3)
                          : AppColors.edgeDivider.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedTab == 2
                            ? AppColors.edgeAccent.withOpacity(0.1)
                            : AppColors.edgePrimary.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _selectedTab == 2
                      ? const Icon(
                          Icons.pending_actions_rounded,
                          color: AppColors.edgeAccent,
                          size: 22,
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.edgePrimary.withOpacity(0.1),
                            border: Border.all(
                              color: AppColors.edgeDivider.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? Image.network(
                                    _getProfileImageUrl(avatarUrl),
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildDefaultAvatar(name);
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : _buildDefaultAvatar(name),
                          ),
                        ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.edgeText,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.edgeTextSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedTab == 2
                        ? AppColors.edgeAccent.withOpacity(0.1)
                        : AppColors.edgePrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _selectedTab == 2
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    size: 20,
                    color: _selectedTab == 2
                        ? AppColors.edgeAccent
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

  Widget _buildDefaultAvatar(String name) {
    final initials = name
        .split(' ')
        .map((e) => e[0])
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.edgePrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.edgePrimary,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading contacts...',
            style: TextStyle(
              color: AppColors.edgeText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
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
                color: AppColors.edgeError.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.edgeError.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.edgeError,
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
                  onTap: _loadData,
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
