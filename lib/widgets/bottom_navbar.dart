import 'package:flutter/material.dart';
import 'dart:ui';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isEnabled;
  final bool noInternet; // <-- NEW: pass whether internet is down

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.isEnabled = true,
    this.noInternet = false, // default
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (noInternet) // <-- Show warning if no internet
          Container(
            width: double.infinity,
            color: Colors.red.shade700,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Center(
              child: Text(
                'No Internet Connection',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? screenWidth * 0.2 : 12.0,
              vertical: 8,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: AbsorbPointer(
                       absorbing: !isEnabled || noInternet,
                      child: Opacity(
                        opacity: (!isEnabled || noInternet) ? 0.4 : 1.0,
                        child: BottomNavigationBar(
                          backgroundColor: Colors.transparent,
                          selectedItemColor: Colors.amber,
                          unselectedItemColor: Colors.grey[400],
                          currentIndex: currentIndex,
                          onTap: onTap,
                          type: BottomNavigationBarType.fixed,
                          elevation: 0,
                          selectedLabelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 15 : 12,
                          ),
                          unselectedLabelStyle: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: isTablet ? 14 : 11,
                          ),
                          items: [
                            BottomNavigationBarItem(
                              icon: _buildIcon(Icons.home_outlined, currentIndex == 0, isTablet),
                              label: 'Home',
                            ),
                            BottomNavigationBarItem(
                              icon: _buildIcon(Icons.list_alt_outlined, currentIndex == 1, isTablet),
                              label: 'Orders',
                            ),
                            BottomNavigationBarItem(
                              icon: _buildIcon(Icons.person_outline, currentIndex == 2, isTablet),
                              label: 'Profile',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(IconData icon, bool isSelected, bool isTablet) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? Colors.amber.withOpacity(0.15) : Colors.transparent,
      ),
      child: Icon(
        icon,
        size: isSelected ? (isTablet ? 30 : 26) : (isTablet ? 26 : 22),
        color: isSelected ? Colors.amber : Colors.grey[400],
      ),
    );
  }
}
