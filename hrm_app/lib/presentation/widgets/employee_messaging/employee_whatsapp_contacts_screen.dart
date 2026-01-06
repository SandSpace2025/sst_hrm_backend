import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/messaging_provider.dart';
import 'package:hrm_app/presentation/screens/messaging/conversation_screen.dart';
import 'package:hrm_app/core/models/conversation.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';

class EmployeeWhatsAppContactsScreen extends StatefulWidget {
  const EmployeeWhatsAppContactsScreen({super.key});

  @override
  State<EmployeeWhatsAppContactsScreen> createState() =>
      _EmployeeWhatsAppContactsScreenState();
}

class _EmployeeWhatsAppContactsScreenState
    extends State<EmployeeWhatsAppContactsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLoading = true;

  // 0: HR, 1: Employee, 2: Admin. Default to Employee (1) as in design it shows "Shehzaada"
  String _selectedCategory = 'Employees';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      setState(() => _isLoading = true);
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      setState(() => _isLoading = false);
      return;
    }

    final employeeProvider = Provider.of<EmployeeProvider>(
      context,
      listen: false,
    );

    try {
      if (forceRefresh) {
        if (mounted) SnackBarUtils.showInfo(context, 'Refreshing contacts...');
      }
      await Future.wait([
        employeeProvider.loadHRContacts(
          authProvider.token!,
          forceRefresh: forceRefresh,
        ),
        employeeProvider.loadAdminContacts(
          authProvider.token!,
          forceRefresh: forceRefresh,
        ),
        employeeProvider.loadEmployeeContactsForMessaging(
          authProvider.token!,
          forceRefresh: forceRefresh,
        ),
        employeeProvider.checkMessagingPermission(authProvider.token!),
      ]);
    } catch (e) {
      if (forceRefresh && mounted) {
        SnackBarUtils.showError(context, 'Failed to refresh contacts');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getProfileImageUrl(String profilePic) {
    if (profilePic.isEmpty) return '';
    if (profilePic.startsWith('http')) {
      return profilePic;
    }

    // Clean up base URL
    String baseUrl = ApiConstants.baseUrl;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    // If user provided a URL with /api suffix, strip it for static files
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    }

    // Normalize path: replace backslashes
    String path = profilePic.replaceAll(r'\', '/');

    // Check if path contains 'uploads/' and strip everything before it
    // This handles absolute system paths like D:/.../uploads/profiles/img.jpg
    if (path.contains('uploads/')) {
      final index = path.indexOf('uploads/');
      path = path.substring(index);
    }
    // If just filename (no slashes), assume uploads/profiles/
    else if (!path.contains('/')) {
      path = 'uploads/profiles/$path';
    }

    // Ensure leading slash is removed (to append to baseUrl/)
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    // Construct final URL
    final imageUrl = '$baseUrl/$path';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('EmployeeWhatsAppContactsScreen: Resolved Image URL: $imageUrl');
    return '$imageUrl?v=$timestamp';
  }

  void _openChat(String userId, String userName, String userType) async {
    HapticFeedback.lightImpact();
    try {
      final messagingProvider = Provider.of<MessagingProvider>(
        context,
        listen: false,
      );

      await messagingProvider.loadConversations();

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

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            height: MediaQuery.of(context).size.height - 70,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: ConversationScreen(conversation: targetConversation!),
            ),
          ),
        );
      } else {
        // Conversation not found, create new one
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUserId = authProvider.userId;
        final currentUserRole = authProvider.role ?? 'employee';

        if (currentUserId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: User identifier not found'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final success = await messagingProvider.createConversation(
          participants: [
            {
              'userId': currentUserId,
              'userType': currentUserRole.toLowerCase(),
              'name': 'Me',
            },
            {'userId': userId, 'userType': userType, 'name': userName},
          ],
          title: userName,
          conversationType: 'direct',
        );

        if (success && mounted) {
          final newConversation = messagingProvider.currentConversation;
          if (newConversation != null) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => Container(
                height: MediaQuery.of(context).size.height - 70,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: ConversationScreen(conversation: newConversation),
                ),
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to create conversation: ${messagingProvider.error ?? "Unknown error"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  List<dynamic> _getCurrentContacts(EmployeeProvider provider) {
    if (_selectedCategory == 'Employees') return provider.employeeContacts;
    if (_selectedCategory == 'HR') return provider.hrContacts;
    if (_selectedCategory == 'Admin') return provider.adminContacts;
    return [];
  }

  String _getUserTypeForCategory() {
    if (_selectedCategory == 'Employees') return 'employee';
    if (_selectedCategory == 'HR') return 'hr';
    if (_selectedCategory == 'Admin') return 'admin';
    return 'employee';
  }

  @override
  Widget build(BuildContext context) {
    // Return a Container/Column directly because the parent (EmployeeActivityScreen)
    // already provides Scaffold, AppBar (Header), and Tabs.
    // This screen is just the content of the "Messages" tab.

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            ShimmerLoading.card(
              height: 100,
              margin: const EdgeInsets.only(bottom: 16),
            ),
            ShimmerLoading.card(
              height: 80,
              margin: const EdgeInsets.only(bottom: 16),
            ),
            ShimmerLoading.card(
              height: 80,
              margin: const EdgeInsets.only(bottom: 16),
            ),
            ShimmerLoading.card(
              height: 80,
              margin: const EdgeInsets.only(bottom: 16),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildNewMessagesSection(),
            const SizedBox(height: 32),
            _buildChatResolveHeader(),
            const SizedBox(height: 32),
            _buildContactList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNewMessagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'New messages',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF555555),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: Consumer<EmployeeProvider>(
            builder: (context, provider, _) {
              final contacts = _getCurrentContacts(provider).take(5).toList();

              if (contacts.isEmpty) {
                return const Center(
                  child: Text(
                    "No new messages",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  final name =
                      contact['name'] ?? contact['fullName'] ?? 'Unknown';
                  final pic =
                      contact['profilePic'] ?? contact['profileImage'] ?? '';

                  return Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green[50],
                        ),
                        child: ClipOval(
                          child: pic.isNotEmpty
                              ? Image.network(
                                  _getProfileImageUrl(pic),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildPlaceholderAvatar(),
                                )
                              : _buildPlaceholderAvatar(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name.split(' ')[0],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        '(Employee)',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderAvatar() {
    return const Icon(Icons.person, color: AppColors.primary);
  }

  Widget _buildChatResolveHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Chat. Resolve.\nAnd manage.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
              height: 1.2,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  icon: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  isDense: true,
                  elevation: 2,
                  dropdownColor: const Color(0xFFE8F5E9),
                  focusColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  selectedItemBuilder: (BuildContext context) {
                    return ['Employees', 'HR'].map<Widget>((String item) {
                      return Center(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  items: ['Employees', 'HR'].map((e) {
                    final isSelected = _selectedCategory == e;
                    return DropdownMenuItem(
                      value: e,
                      child: SizedBox(
                        height: 30,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              e,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.check,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                        _controller.reset();
                        _controller.forward();
                      });
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactList() {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        final contacts = _getCurrentContacts(provider);

        if (contacts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("No contacts found found in this category."),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          itemCount: contacts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final contact = contacts[index];
            final name = contact['name'] ?? contact['fullName'] ?? 'Unknown';
            final pic = contact['profilePic'] ?? contact['profileImage'] ?? '';
            final id = contact['_id'] ?? contact['id'] ?? '';
            String designation =
                contact['jobTitle'] ??
                contact['designation'] ??
                contact['role'] ??
                '';

            if (designation.isEmpty || designation.toLowerCase() == 'member') {
              if (_selectedCategory == 'HR') {
                designation = 'HR';
              } else if (_selectedCategory == 'Admin') {
                designation = 'Admin';
              } else {
                designation = 'Member';
              }
            }

            // Debug logging
            if (_selectedCategory == 'Employees') {
              debugPrint('Employee Contact: $name');
              debugPrint('Raw Pic: "$pic"');
              debugPrint('Generated URL: "${_getProfileImageUrl(pic)}"');
            }

            return Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green[50],
                  ),
                  child: ClipOval(
                    child: pic.isNotEmpty
                        ? Image.network(
                            _getProfileImageUrl(pic),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildPlaceholderAvatar(),
                          )
                        : _buildPlaceholderAvatar(),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Text(
                        designation,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _openChat(id, name, _getUserTypeForCategory());
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.bubble_left,
                                size: 18,
                                color: Colors.white,
                              ),
                              Padding(
                                padding: EdgeInsets.only(bottom: 2),
                                child: Icon(
                                  Icons.more_horiz,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Message',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
