import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/employee_provider.dart';

class UserSelectionWidget extends StatefulWidget {
  final Function(Map<String, dynamic> user) onUserSelected;
  final List<Map<String, dynamic>> excludeUsers;

  const UserSelectionWidget({
    super.key,
    required this.onUserSelected,
    this.excludeUsers = const [],
  });

  @override
  State<UserSelectionWidget> createState() => _UserSelectionWidgetState();
}

class _UserSelectionWidgetState extends State<UserSelectionWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isExcluded(Map<String, dynamic> user) {
    final userId = user['userId'] ?? user['id'] ?? user['_id'];
    if (userId == null) return false;
    final excludedIds = widget.excludeUsers
        .map((u) => u['userId'] ?? u['id'] ?? u['_id'])
        .where((id) => id != null)
        .map((id) => id.toString())
        .toSet();

    return excludedIds.contains(userId.toString());
  }

  List<Map<String, dynamic>> _filterUsers(List<dynamic> users) {
    if (users.isEmpty) return [];

    return users
        .where((user) {
          if (user is! Map<String, dynamic>) return false;

          if (_isExcluded(user)) return false;

          if (_searchQuery.isNotEmpty) {
            final name = (user['name'] ?? user['fullName'] ?? '')
                .toString()
                .toLowerCase();
            final email = (user['email'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || email.contains(query);
          }

          return true;
        })
        .map((u) => u as Map<String, dynamic>)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search users...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        Expanded(
          child: Consumer<EmployeeProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(text: 'Employees'),
                        Tab(text: 'HR'),
                        Tab(text: 'Admin'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildUserList(
                            _filterUsers(provider.employeeContacts),
                          ),
                          _buildUserList(_filterUsers(provider.hrContacts)),
                          _buildUserList(_filterUsers(provider.adminContacts)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final name = user['name'] ?? user['fullName'] ?? 'Unknown';
        final email = user['email'] ?? '';
        final avatarUrl = user['avatar'] ?? user['profilePicture'];

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(name),
          subtitle: Text(email),
          onTap: () => widget.onUserSelected(user),
          trailing: const Icon(Icons.add_circle_outline, color: Colors.blue),
        );
      },
    );
  }
}
