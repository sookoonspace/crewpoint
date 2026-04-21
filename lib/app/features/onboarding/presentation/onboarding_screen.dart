import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _dataOptIn = false;

  static const _pageCount = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Pages
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: const [
              _WelcomePage(),
              _FeaturePage(
                icon: Icons.calendar_month_rounded,
                title: 'Plan Events Together',
                description:
                    'Assign roles, set dates, and track progress\u2014all in one place.',
                backgroundColor: AppColors.offWhite,
                iconColor: AppColors.sage,
                textColor: AppColors.charcoal,
              ),
              _FeaturePage(
                icon: Icons.chat_rounded,
                title: 'Stay in Sync',
                description:
                    'Real-time messaging with critical alerts\nwhen it matters most.',
                backgroundColor: AppColors.charcoal,
                iconColor: AppColors.sageLight,
                textColor: AppColors.offWhite,
              ),
              _FeaturePage(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Split Costs Fairly',
                description:
                    'Track expenses, upload receipts,\nand see who owes what.',
                backgroundColor: AppColors.offWhite,
                iconColor: AppColors.terracotta,
                textColor: AppColors.charcoal,
              ),
              _PrivacyPage(),
            ],
          ),

          // Skip button (pages 0-3)
          if (_currentPage < _pageCount - 1)
            Positioned(
              top: MediaQuery.paddingOf(context).top + AppSpacing.md,
              right: AppSpacing.lg,
              child: TextButton(
                onPressed: () => _goToPage(_pageCount - 1),
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: _currentPage == 0 || _currentPage == 2
                        ? AppColors.mediumGrey
                        : AppColors.darkGrey,
                  ),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    // Data opt-in (last page only)
                    if (_currentPage == _pageCount - 1) ...[
                      _DataOptInToggle(
                        value: _dataOptIn,
                        onChanged: (value) =>
                            setState(() => _dataOptIn = value),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Page indicator
                    _PageIndicator(
                      currentPage: _currentPage,
                      pageCount: _pageCount,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Action button
                    PrimaryButton(
                      label: _currentPage == _pageCount - 1
                          ? 'Get Started'
                          : 'Continue',
                      onPressed: () {
                        if (_currentPage < _pageCount - 1) {
                          _goToPage(_currentPage + 1);
                        } else {
                          widget.onComplete?.call();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 1: Welcome with branding
class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.charcoal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          // App icon representation
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.sage,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.hub_rounded,
              size: 64,
              color: AppColors.offWhite,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'CrewPoint',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppColors.offWhite,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your crew, organized.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.sageLight,
              fontWeight: FontWeight.w400,
            ),
          ),
          // Extra space for bottom controls
          const SizedBox(height: 160),
        ],
      ),
    );
  }
}

/// Feature pages (2-4): Icon + headline + description
class _FeaturePage extends StatelessWidget {
  const _FeaturePage({
    required this.icon,
    required this.title,
    required this.description,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          // Icon with subtle background circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 72, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: textColor.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          // Extra space for bottom controls
          const SizedBox(height: 160),
        ],
      ),
    );
  }
}

/// Page 5: Privacy + data opt-in
class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.charcoal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 72,
              color: AppColors.sage,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Your Data, Your Rules',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.offWhite,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'We believe in transparency.\nYou decide what to share.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.offWhite.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          // Extra space for bottom controls + toggle
          const SizedBox(height: 200),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.currentPage, required this.pageCount});

  final int currentPage;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .center,
      spacing: AppSpacing.sm,
      children: List.generate(
        pageCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: index == currentPage ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == currentPage ? AppColors.sage : AppColors.darkGrey,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _DataOptInToggle extends StatelessWidget {
  const _DataOptInToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Allow anonymous usage data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.offWhite.withValues(alpha: 0.8),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.sage,
            activeTrackColor: AppColors.sageLight.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
