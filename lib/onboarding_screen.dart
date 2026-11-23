import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';

import 'role_selection_screen.dart';
import 'ui/design_tokens.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: '3D volumetric geofencing',
      description: 'Sign-ins are locked to the physical classroom volume. The altitude gatekeeper and GPS boundaries prevent spoofing from other floors or nearby locations.',
      lottieAsset: 'assets/lottie/Tech.json',
      accentColor: AppColors.indigo,
    ),
    OnboardingPageData(
      title: 'Biometric device binding',
      description: 'Your identity is bound to a single physical device. Biometric checks are completed inside the native hardware Secure Enclave, eliminating buddy check-ins entirely.',
      lottieAsset: 'assets/lottie/register.json',
      accentColor: AppColors.amber,
    ),
    OnboardingPageData(
      title: 'Automated sync & analytics',
      description: 'Check-in records sync automatically to Supabase Cloud and your instructor\'s connected Google Sheet in real-time, working seamlessly even while offline.',
      lottieAsset: 'assets/lottie/Educatin.json',
      accentColor: AppColors.success,
    ),
  ];

  Future<void> _completeOnboarding() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/.onboarding_completed');
      await file.writeAsString('done');
    } catch (_) {
      // Fallback
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.slate900, AppColors.indigoDeep]
                : [AppColors.slate50, const Color(0xFFEEF2F6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip Button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Skip',
                      style: AppType.body(
                        context,
                        color: AppColors.textSecondary(isDark),
                        weight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Lottie Animation Container
                          Container(
                            height: 280,
                            width: 280,
                            decoration: BoxDecoration(
                              color: page.accentColor.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: page.accentColor.withValues(alpha: 0.15),
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Lottie.asset(
                              page.lottieAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.animation_rounded,
                                    size: 80,
                                    color: page.accentColor,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Title
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: AppType.display(
                              context,
                              fontSize: 24,
                              weight: FontWeight.w700,
                              color: AppColors.textPrimary(isDark),
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          // Description
                          Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: AppType.body(
                              context,
                              fontSize: 14,
                              color: AppColors.textSecondary(isDark),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Indicators & Navigation Row
              Padding(
                padding: const EdgeInsets.fromLTRB(32.0, 16.0, 32.0, 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dot Indicators
                    Row(
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6.0),
                          height: 8.0,
                          width: _currentPage == index ? 24.0 : 8.0,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? _pages[_currentPage].accentColor
                                : (isDark ? AppColors.slate700 : AppColors.slate300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    // Next/Get Started Button
                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage].accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.xlR,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? 'Get started'
                                : 'Next',
                            style: AppType.body(context, weight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == _pages.length - 1
                                ? Icons.check_circle_outline_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                        ],
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

class OnboardingPageData {
  final String title;
  final String description;
  final String lottieAsset;
  final Color accentColor;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.lottieAsset,
    required this.accentColor,
  });
}
