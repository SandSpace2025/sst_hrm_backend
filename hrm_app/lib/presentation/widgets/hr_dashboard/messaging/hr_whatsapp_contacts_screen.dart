import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'hr_whatsapp_chat_screen.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HRWhatsAppContactsScreen extends StatefulWidget {
  const HRWhatsAppContactsScreen({super.key});

  @override
  State<HRWhatsAppContactsScreen> createState() =>
      _HRWhatsAppContactsScreenState();
}

class _HRWhatsAppContactsScreenState extends State<HRWhatsAppContactsScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeInOutCubic;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _showEmployees = true;
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

    final hrProvider = Provider.of<HRProvider>(context, listen: false);

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
      await Future.wait([
        hrProvider.loadEmployeesForMessaging(
          authProvider.token!,
          forceRefresh: forceRefresh,
        ),
        hrProvider.loadAdminsForMessaging(
          authProvider.token!,
          forceRefresh: forceRefresh,
        ),
      ]);

      if (forceRefresh) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        if (hrProvider.error != null) {
          final errorMsg = hrProvider.error!.toLowerCase();
          if (errorMsg.contains('no internet') ||
              errorMsg.contains('socketexception') ||
              errorMsg.contains('connection')) {
            if (mounted) {
              SnackBarUtils.showError(context, 'No internet connection');
            }
          } else {
            if (mounted) {
              SnackBarUtils.showError(
                context,
                'Failed to refresh: ${hrProvider.error}',
              );
            }
          }
        } else if (hrProvider.employeesForMessaging.isNotEmpty ||
            hrProvider.adminsForMessaging.isNotEmpty) {
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

  void _toggleUserType() {
    _triggerHaptic();
    setState(() {
      _showEmployees = !_showEmployees;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _openChat(String userId, String userName, String userType) {
    _triggerHaptic();

    _searchFocusNode.unfocus();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HRWhatsAppChatScreen(
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

  List<dynamic> _getFilteredContacts() {
    final hrProvider = Provider.of<HRProvider>(context, listen: false);

    List<dynamic> contacts = [];
    if (_showEmployees) {
      contacts = hrProvider.employeesForMessaging;
    } else {
      contacts = hrProvider.adminsForMessaging;
    }

    if (_searchQuery.isEmpty) {
      return contacts;
    }

    return contacts.where((contact) {
      final name =
          (contact is Employee
                  ? contact.name
                  : contact['fullName'] ?? contact['name'] ?? '')
              .toLowerCase();
      final email =
          (contact is Employee ? contact.email : contact['email'] ?? '')
              .toLowerCase();
      final employeeId =
          (contact is Employee
                  ? contact.employeeId
                  : contact['employeeId'] ?? '')
              .toLowerCase();

      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          employeeId.contains(_searchQuery);
    }).toList();
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
          hintText: 'Search ${_showEmployees ? 'employees' : 'admins'}...',
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
              label: 'Employees',
              icon: Icons.people_rounded,
              isSelected: _showEmployees,
              onTap: () {
                if (!_showEmployees) _toggleUserType();
              },
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.edgeDivider.withOpacity(0.3),
          ),
          Expanded(
            child: _buildEnhancedToggleButton(
              label: 'Admins',
              icon: Icons.admin_panel_settings_rounded,
              isSelected: !_showEmployees,
              onTap: () {
                if (_showEmployees) _toggleUserType();
              },
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
    return Consumer<HRProvider>(
      builder: (context, hrProvider, child) {
        if (hrProvider.isLoading) {
          return _buildLoadingState();
        }

        if (hrProvider.error != null) {
          return _buildErrorState(hrProvider.error!);
        }

        final contacts = _getFilteredContacts();

        if (contacts.isEmpty) {
          return _buildEmptyState();
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              return _buildContactItem(contacts[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildContactItem(dynamic contact) {
    final isEmployee = contact is Employee;

    final name = isEmployee
        ? contact.name
        : contact['fullName'] ?? contact['name'] ?? 'Unknown';
    final email = isEmployee ? contact.email : contact['email'] ?? '';
    final profilePic = isEmployee
        ? contact.profilePic
        : contact['profileImage'] ?? '';
    final userId = isEmployee ? contact.id : contact['_id'] ?? contact['id'];
    final userType = isEmployee ? 'employee' : 'admin';

    final hrProvider = Provider.of<HRProvider>(context, listen: false);
    final hasUnread = hrProvider.hasUnreadMessages(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: hasUnread
            ? AppColors.edgePrimary.withOpacity(0.05)
            : AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasUnread
              ? AppColors.edgePrimary.withOpacity(0.3)
              : AppColors.edgeDivider.withOpacity(0.2),
          width: hasUnread ? 1.5 : 1,
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
          onTap: () => _openChat(userId, name, userType),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.edgePrimary.withOpacity(0.1),
          highlightColor: AppColors.edgePrimary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatar(name, profilePic),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: AppColors.edgeText,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.edgePrimary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'New',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: hasUnread
                              ? AppColors.edgeText
                              : AppColors.edgeTextSecondary,
                          fontWeight: hasUnread
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
                if (hasUnread)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.edgePrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.edgePrimary.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.edgePrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.edgeTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String profilePic) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.edgePrimary.withOpacity(0.1),
        border: Border.all(
          color: AppColors.edgeDivider.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgePrimary.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: (profilePic.isNotEmpty)
            ? Image.network(
                _getProfileImageUrl(profilePic),
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
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              )
            : _buildDefaultAvatar(name),
      ),
    );
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
                _showEmployees
                    ? Icons.people_outline_rounded
                    : Icons.admin_panel_settings_outlined,
                size: 40,
                color: AppColors.edgePrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No ${_showEmployees ? 'employees' : 'admins'} found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.edgeText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? 'No ${_showEmployees ? 'employees' : 'admins'} available'
                  : 'Try searching with a different term',
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
}
