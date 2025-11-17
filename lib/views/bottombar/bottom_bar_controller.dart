// lib/views/bottombar/bottom_bar_controller.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';

class BottomBarController extends StatelessWidget {
  final int? currentIndex;
  final Function(int)? onTap;

  const BottomBarController({super.key, this.currentIndex, this.onTap});

  @override
  Widget build(BuildContext context) {
    // This is your main custom container that replaces BottomNavigationBar
    return Container(
      // Set a height for your bar
      height: 75.h,
      decoration: BoxDecoration(
        // Give it a color, or gradient, etc.
        color: MyColors.backgund,
        // Add a shadow to make it look like a bar
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      // SafeArea ensures your bar doesn't get hidden by phone UI
      child: SafeArea(
        top: false, // We only care about the bottom edge
        child: Row(
          // This row holds your three custom buttons
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Each button is a custom widget
            _buildNavItem(icon: Icons.wifi, label: 'Wi-Fi', index: 0),
            _buildNavItem(icon: Icons.usb, label: 'USB', index: 1),
            _buildNavItem(icon: Icons.settings, label: 'Settings', index: 2),
          ],
        ),
      ),
    );
  }

  // Helper method to build each custom navigation item
  // This is where you can customize each button
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    // Check if this item is the currently selected one
    final bool isActive = (currentIndex == index);

    // Define colors
    final Color activeColor = MyColors.green;
    final Color inactiveColor = Colors.grey.shade600;
    final Color iconActiveColor =
        Colors.white; // Icon color when inside the green box
    final Color iconInactiveColor = Colors.grey.shade600;

    // We use Expanded so each item takes up equal space in the Row
    return Expanded(
      child: InkWell(
        // This is the most important part:
        // When tapped, it calls the `onTap` function with its index
        onTap: () => onTap?.call(index),
        // Make the ripple effect clean
        borderRadius: BorderRadius.circular(12.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Keep column height compact
          children: [
            // This is your custom container from your original code
            Container(
              decoration: BoxDecoration(
                // ONLY show the green background if this item is active
                color: isActive ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  // Use more padding when active to create the "pill" effect
                  horizontal: isActive ? AppSizes.p16 : AppSizes.p8,
                  vertical: AppSizes.p4,
                ),
                // Use the correct icon color based on active state
                child: Icon(
                  icon,
                  color: isActive ? iconActiveColor : iconInactiveColor,
                ),
              ),
            ),
            SizedBox(height: 4.h), // Space between icon and label
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                // Use the active or inactive color for the text
                color:  inactiveColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
