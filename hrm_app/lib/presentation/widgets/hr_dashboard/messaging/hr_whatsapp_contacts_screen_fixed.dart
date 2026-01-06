import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:provider/provider.dart';
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
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      final hrProvider = Provider.of<HRProvider>(context, listen: false);
      hrProvider.loadEmployeesForMessaging(authProvider.token!);
      hrProvider.loadAdminsForMessaging(authProvider.token!);
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
          const curve = Curves.easeInOutCubic;

          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: _animDuration,
      ),
    );
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

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.edgeDivider),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search ${_showEmployees ? 'employees' : 'admins'}...',
          hintStyle: const TextStyle(
            color: AppColors.edgeTextSecondary,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.edgeTextSecondary,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
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
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        style: const TextStyle(fontSize: 14, color: AppColors.edgeText),
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.edgeBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.edgeDivider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: 'Employees',
              icon: Icons.people_outline,
              isSelected: _showEmployees,
              onTap: () {
                if (!_showEmployees) _toggleUserType();
              },
            ),
          ),
          Container(width: 1, height: 32, color: AppColors.edgeDivider),
          Expanded(
            child: _buildToggleButton(
              label: 'Admins',
              icon: Icons.admin_panel_settings_outlined,
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

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _animDuration,
          curve: _animCurve,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.edgePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
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
                  color: isSelected
                      ? Colors.white
                      : AppColors.edgeTextSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
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
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.edgePrimary),
            ),
          );
        }

        if (hrProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.edgeTextSecondary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Error loading contacts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hrProvider.error!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.edgeTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.edgePrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final contacts = _getFilteredContacts();
        if (contacts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showEmployees
                      ? Icons.people_outline
                      : Icons.admin_panel_settings_outlined,
                  size: 64,
                  color: AppColors.edgeTextSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${_showEmployees ? 'employees' : 'admins'} found',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isEmpty
                      ? 'No ${_showEmployees ? 'employees' : 'admins'} available'
                      : 'No ${_showEmployees ? 'employees' : 'admins'} match your search',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.edgeTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return _buildContactCard(contact, index);
          },
        );
      },
    );
  }

  String _getProfileImageUrl(String profilePic) {
    if (profilePic.isEmpty) {
      return '';
    }

    // Handle different URL formats
    String imageUrl;
    if (profilePic.startsWith('http')) {
      // Full URL already provided
      imageUrl = profilePic;
    } else {
      // Relative path, prepend base URL
      imageUrl = '${ApiConstants.baseUrl}$profilePic';
    }

    // Add cache-busting parameter to force image reload
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

  Widget _buildContactCard(dynamic contact, int index) {
    final hrProvider = Provider.of<HRProvider>(context, listen: false);
    final isEmployee = contact is Employee;
    final name = isEmployee
        ? contact.name
        : contact['fullName'] ?? contact['name'] ?? 'Unknown';
    final email = isEmployee ? contact.email : contact['email'] ?? '';
    final employeeId = isEmployee
        ? contact.employeeId
        : contact['employeeId'] ?? '';
    final profilePic = isEmployee
        ? contact.profilePic
        : contact['profilePic'] ?? '';
    final hasUnread = hrProvider.hasUnreadMessages(employeeId);
    final userType = isEmployee ? 'employee' : 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: hasUnread
            ? AppColors.edgePrimary.withOpacity(0.05)
            : AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasUnread
              ? AppColors.edgePrimary.withOpacity(0.4)
              : AppColors.edgeDivider.withOpacity(0.2),
          width: hasUnread ? 2 : 1,
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
          onTap: () => _openChat(employeeId, name, userType),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.edgePrimary.withOpacity(0.1),
          highlightColor: AppColors.edgePrimary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Enhanced Avatar
                _buildAvatar(name, profilePic),
                const SizedBox(width: 16),
                // Enhanced Info
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
                // Unread indicator badge
                if (hasUnread)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.edgePrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.edgePrimary.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                // Enhanced Arrow Icon
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

  @override
  Widget build(BuildContext context) {
    return Consumer<HRProvider>(
      builder: (context, hrProvider, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: () {
              _searchFocusNode.unfocus();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: AppColors.edgeBackground,
              child: Column(
                children: [
                  Container(
                    color: AppColors.edgeSurface,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 12),
                        _buildToggleSwitch(),
                      ],
                    ),
                  ),

                  Container(height: 1, color: AppColors.edgeDivider),

                  Expanded(child: _buildContactsList()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
