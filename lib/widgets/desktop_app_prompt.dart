import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/constants.dart';

/// A floating icon widget that appears at the bottom corner.
/// When clicked, shows a prompt asking if the user has downloaded the desktop app.
class DesktopAppPrompt extends StatefulWidget {
  const DesktopAppPrompt({super.key});

  @override
  State<DesktopAppPrompt> createState() => _DesktopAppPromptState();
}

class _DesktopAppPromptState extends State<DesktopAppPrompt>
    with TickerProviderStateMixin {
  static const String _hasDownloadedDesktopAppKey = 'hasDownloadedDesktopApp';
  static const String _downloadUrl = AppConstants.DOWNLOADS;

  bool _shouldShow = false;
  bool _isIconVisible = false;
  bool _isDialogOpen = false;

  late AnimationController _iconAnimationController;
  late AnimationController _dialogAnimationController;
  late AnimationController _pulseAnimationController;

  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconFadeAnimation;
  late Animation<double> _dialogScaleAnimation;
  late Animation<double> _dialogFadeAnimation;
  late Animation<Offset> _dialogSlideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkAndShowPrompt();
  }

  void _setupAnimations() {
    // Icon animations
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _iconFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Dialog animations
    _dialogAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dialogScaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _dialogAnimationController,
        curve: Curves.easeOutBack,
      ),
    );
    _dialogFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _dialogAnimationController,
        curve: Curves.easeOut,
      ),
    );
    _dialogSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _dialogAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Pulse animation for the icon
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _dialogAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final hasDownloaded = prefs.getBool(_hasDownloadedDesktopAppKey) ?? false;

    if (!hasDownloaded && mounted) {
      setState(() {
        _shouldShow = true;
      });
      // Show icon after 1 second delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _shouldShow) {
          setState(() {
            _isIconVisible = true;
          });
          _iconAnimationController.forward();
        }
      });
    }
  }

  Future<void> _handleYes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasDownloadedDesktopAppKey, true);
    _closeDialog();
    Future.delayed(const Duration(milliseconds: 250), () {
      _hideIcon();
    });
  }

  void _handleNo() {
    _closeDialog();
    Future.delayed(const Duration(milliseconds: 250), () {
      _hideIcon();
    });
  }

  void _openDialog() {
    setState(() {
      _isDialogOpen = true;
    });
    _dialogAnimationController.forward();
  }

  void _closeDialog() {
    _dialogAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isDialogOpen = false;
        });
      }
    });
  }

  void _hideIcon() {
    _iconAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isIconVisible = false;
          _shouldShow = false;
        });
      }
    });
  }

  void _copyLink() {
    Clipboard.setData(const ClipboardData(text: _downloadUrl));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20.sp),
            SizedBox(width: 10.w),
            Text(
              'Link copied to clipboard!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: MyColors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16.sp),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow || !_isIconVisible) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Semi-transparent overlay when dialog is open
        if (_isDialogOpen)
          Positioned.fill(
            child: FadeTransition(
              opacity: _dialogFadeAnimation,
              child: GestureDetector(
                onTap: _closeDialog,
                child: Container(color: Colors.black.withOpacity(0.7)),
              ),
            ),
          ),

        // Dialog popup - positioned just above the floating icon
        if (_isDialogOpen)
          Positioned(
            bottom: 95.h,
            right: 16.w,
            left: 16.w,
            child: SlideTransition(
              position: _dialogSlideAnimation,
              child: FadeTransition(
                opacity: _dialogFadeAnimation,
                child: ScaleTransition(
                  scale: _dialogScaleAnimation,
                  alignment: Alignment.bottomRight,
                  child: _buildDialogContent(),
                ),
              ),
            ),
          ),

        // Floating icon
        Positioned(
          bottom: 20.h,
          right: 20.w,
          child: ScaleTransition(
            scale: _iconScaleAnimation,
            child: FadeTransition(
              opacity: _iconFadeAnimation,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isDialogOpen ? 1.0 : _pulseAnimation.value,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: _isDialogOpen ? _closeDialog : _openDialog,
                  child: Container(
                    width: 58.sp,
                    height: 58.sp,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          MyColors.lightColorScheme.primary,
                          MyColors.lightColorScheme.primary.withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MyColors.lightColorScheme.primary.withOpacity(
                            0.4,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) {
                        return RotationTransition(
                          turns: _isDialogOpen
                              ? Tween(begin: 0.0, end: 0.25).animate(animation)
                              : Tween(begin: 0.0, end: 0.0).animate(animation),
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        _isDialogOpen
                            ? Icons.close_rounded
                            : Icons.desktop_windows_rounded,
                        key: ValueKey(_isDialogOpen),
                        color: Colors.white,
                        size: 26.sp,
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

  Widget _buildDialogContent() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: MyColors.green.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF2D2D2D), const Color(0xFF1F1F1F)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient accent
              Container(
                padding: EdgeInsets.all(20.sp),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      MyColors.green.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Logo container
                    Container(
                      padding: EdgeInsets.all(12.sp),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            MyColors.lightColorScheme.primary,
                            MyColors.lightColorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: MyColors.lightColorScheme.primary
                                .withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.asset(
                          'assets/logos/eazycam-without-bg.png',
                          width: 28.sp,
                          height: 28.sp,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Get Desktop App',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Have you downloaded it?',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 15.h),

              // URL Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.sp),
                child: Container(
                  padding: EdgeInsets.all(14.sp),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: MyColors.green.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.sp),
                        decoration: BoxDecoration(
                          color: MyColors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          color: MyColors.green,
                          size: 18.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Download Link',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: MyColors.green,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              _downloadUrl,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _copyLink,
                          borderRadius: BorderRadius.circular(10.r),
                          child: Container(
                            padding: EdgeInsets.all(10.sp),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  MyColors.green.withOpacity(0.25),
                                  MyColors.green.withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: MyColors.green.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 18.sp,
                              color: MyColors.green,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20.h),

              // Buttons
              Padding(
                padding: EdgeInsets.fromLTRB(20.sp, 0, 20.sp, 20.sp),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _handleNo,
                          borderRadius: BorderRadius.circular(14.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Not Yet',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _handleYes,
                          borderRadius: BorderRadius.circular(14.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  MyColors.green,
                                  MyColors.green.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(
                                  color: MyColors.green.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18.sp,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'Yes, I Have',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
