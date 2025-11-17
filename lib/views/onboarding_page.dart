import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';
import 'package:webcamo/utils/strings.dart';
import 'package:webcamo/views/home_page.dart';

class OnboardingData {
  final String image;
  final String title;

  const OnboardingData({required this.image, required this.title});
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  int _currentPage = 0;

  final List<OnboardingData> _pages = const [
    OnboardingData(
      image: AppStrings.illustration01,
      title: 'Welcome! Discover amazing features.',
    ),
    OnboardingData(
      image: AppStrings.illustration01,
      title: 'Personalize your experience with ease.',
    ),
    OnboardingData(
      image: AppStrings.illustration01,
      title: 'Let\'s get started on your journey!',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToHome() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    // Apply custom page transitions globally for this screen
    return Theme(
      data: Theme.of(context).copyWith(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      child: Scaffold(
        backgroundColor: MyColors.lightColorScheme.primary,
        body: SafeArea(
          child: Column(
            children: [
              // ---- Header (page counter) ----
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.p24,
                    vertical: AppSizes.p16,
                  ),
                  child: Text(
                    '${_currentPage + 1}/${_pages.length}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: MyColors.white,
                    ),
                  ),
                ),
              ),

              // ---- Page Content (70%) ----
              Expanded(
                flex: 7,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (p) => setState(() => _currentPage = p),
                  itemCount: _pages.length,
                  itemBuilder: (_, index) {
                    return OnboardingPage(
                      data: _pages[index],
                      // Pass animation progress for shared dot animation
                      progress: _currentPage == index
                          ? 1.0
                          : (index > _currentPage ? 0.0 : 1.0),
                    );
                  },
                ),
              ),

              // ---- Dots + Buttons (30%) ----
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.p24),
                  child: Column(
                    children: [
                      // Dots
                      AnimatedDotsIndicator(
                        currentPage: _currentPage,
                        itemCount: _pages.length,
                      ),
                      const Spacer(),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _goToHome,
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: MyColors.white,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MyColors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 32.w,
                                vertical: 14.h,
                              ),
                            ),
                            onPressed: () {
                              if (_currentPage == _pages.length - 1) {
                                _goToHome();
                              } else {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            child: Text(
                              _currentPage == _pages.length - 1
                                  ? 'Get Started'
                                  : 'Next',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSizes.p16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Individual Onboarding Page (with scale + fade)
// ---------------------------------------------------------------
class OnboardingPage extends StatefulWidget {
  final OnboardingData data;
  final double progress; // 0.0 → 1.0 (used only for entry animation)

  const OnboardingPage({super.key, required this.data, required this.progress});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Trigger when page becomes active
    if (widget.progress == 1.0) _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant OnboardingPage old) {
    super.didUpdateWidget(old);
    if (widget.progress == 1.0 && old.progress != 1.0) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Padding(
              padding: EdgeInsets.all(AppSizes.p32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    widget.data.image,
                    height: AppSizes.image_md,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 48.sp),
                  Text(
                    widget.data.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: MyColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// Animated Dots Indicator
// ---------------------------------------------------------------
class AnimatedDotsIndicator extends StatelessWidget {
  final int currentPage;
  final int itemCount;
  final double dotSize = 8.0;
  final double spacing = 10.0;
  final Color activeColor = MyColors.green;
  final Color inactiveColor = MyColors.white.withOpacity(0.4);

  AnimatedDotsIndicator({
    super.key,
    required this.currentPage,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        final bool isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isActive ? dotSize * 2.5 : dotSize,
          height: dotSize,
          margin: EdgeInsets.symmetric(horizontal: spacing / 2),
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(dotSize),
          ),
        );
      }),
    );
  }
}
