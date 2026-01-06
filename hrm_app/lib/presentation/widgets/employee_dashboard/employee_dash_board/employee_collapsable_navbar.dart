import 'package:flutter/material.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/presentation/widgets/common/nav/generic_collapsable_navbar.dart';

class EmployeeCollapsableNavbar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onLogout;
  final String userName;
  final String userRole;
  final Employee? employeeProfile;

  const EmployeeCollapsableNavbar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
    required this.userName,
    required this.userRole,
    this.employeeProfile,
  });

  @override
  Widget build(BuildContext context) {
    return GenericCollapsableNavbar(
      selectedIndex: selectedIndex,
      onItemSelected: onItemSelected, // Direct mapping
      onLogout: onLogout,
      userName: employeeProfile?.name ?? userName,
      userRole: employeeProfile?.jobTitle ?? userRole,
      profileImageUrl: employeeProfile?.profilePic,
      navItems: [
        const NavItem(icon: Icons.dashboard_rounded, title: 'Dashboard'),
        const NavItem(icon: Icons.access_time_rounded, title: 'Attendance'),
        if (employeeProfile?.subOrganisation != 'Academic Overseas')
          const NavItem(icon: Icons.work_rounded, title: 'EOD Update'),
        const NavItem(
          icon: Icons.event_note_rounded,
          title: 'Leave Application',
        ),
        const NavItem(icon: Icons.message_rounded, title: 'Message'),
        const NavItem(icon: Icons.payment_rounded, title: 'Payslip'),
        const NavItem(icon: Icons.account_circle_rounded, title: 'Profile'),
      ],
    );
  }
}
