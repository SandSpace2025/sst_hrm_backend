import 'package:flutter/material.dart';
import 'package:hrm_app/data/models/admin_profile.dart';
import 'package:hrm_app/presentation/widgets/common/nav/generic_collapsable_navbar.dart';

class CollapsibleSideNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final VoidCallback onLogout;
  final String userName;
  final String userRole;
  final AdminProfile? adminProfile;

  const CollapsibleSideNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.onLogout,
    required this.userName,
    required this.userRole,
    this.adminProfile,
  });

  @override
  Widget build(BuildContext context) {
    return GenericCollapsableNavbar(
      selectedIndex: selectedIndex,
      onItemSelected: onItemTapped,
      onLogout: onLogout,
      userName: adminProfile?.fullName ?? userName,
      userRole: adminProfile?.designation ?? userRole,
      profileImageUrl: adminProfile?.profileImage,
      navItems: const [
        NavItem(icon: Icons.dashboard_rounded, title: 'Dashboard'),
        NavItem(icon: Icons.campaign_rounded, title: 'Announcements'),
        NavItem(icon: Icons.event_note_rounded, title: 'Leave Requests'),
        NavItem(icon: Icons.people_rounded, title: 'Manage Team'),
        NavItem(icon: Icons.message_rounded, title: 'Message'),
        NavItem(icon: Icons.account_circle_rounded, title: 'Profile'),
      ],
    );
  }
}
