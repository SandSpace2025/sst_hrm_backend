import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class DashboardBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const DashboardBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeDarkGray.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.home_outlined, 0),
            activeIcon: _buildNavIcon(Icons.home_rounded, 0, isActive: true),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.groups_outlined, 1),
            activeIcon: _buildNavIcon(Icons.groups_rounded, 1, isActive: true),
            label: 'Employees',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.campaign_outlined, 2),
            activeIcon: _buildNavIcon(
              Icons.campaign_rounded,
              2,
              isActive: true,
            ),
            label: 'Announce',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIcon(Icons.event_note_outlined, 3),
            activeIcon: _buildNavIcon(
              Icons.event_note_rounded,
              3,
              isActive: true,
            ),
            label: 'Leaves',
          ),
          BottomNavigationBarItem(
            icon: _buildLogoutIcon(),
            activeIcon: _buildLogoutIcon(),
            label: 'Logout',
          ),
        ],
        currentIndex: selectedIndex,
        selectedItemColor: AppColors.edgeBlue,
        unselectedItemColor: AppColors.edgeMidGray,
        onTap: onItemTapped,
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
        selectedFontSize: 11,
        unselectedFontSize: 11,
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Container(
        padding: EdgeInsets.all(isActive ? 6 : 4),
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.edgeBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        child: Icon(icon, size: isActive ? 24 : 22),
      ),
    );
  }

  Widget _buildLogoutIcon() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.edgeRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.logout_rounded,
          size: 22,
          color: AppColors.edgeRed,
        ),
      ),
    );
  }
}
