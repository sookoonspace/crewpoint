import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/components/cp_logo.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';

/// The first-run pages: what CrewPoint does, then privacy, then Get
/// Started, which calls [onComplete].
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

  bool get _last => _currentPage == _pageCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    final motion = context.cp.motion;
    _pageController.animateToPage(
      page,
      duration: motion.slow,
      curve: motion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.onboarding;
    return Scaffold(
      backgroundColor: cp.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip keeps its height on the last page, so nothing jumps.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: cp.space.sm),
              child: SizedBox(
                height: cp.sizes.tapMin,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _last
                      ? null
                      : CpButton.text(
                          key: const Key('onboarding.skip'),
                          label: s.skip,
                          onPressed: () => _goToPage(_pageCount - 1),
                        ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                key: const Key('onboarding.pages'),
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _Page(
                    art: CpLogo(size: cp.sizes.iconHero + cp.space.xxl),
                    title: s.appName,
                    body: s.tagline,
                  ),
                  _Page(
                    art: const _PageIcon(CpIcons.calendar),
                    title: s.planTitle,
                    body: s.planBody,
                  ),
                  _Page(
                    art: const _PageIcon(CpIcons.chat),
                    title: s.syncTitle,
                    body: s.syncBody,
                  ),
                  _Page(
                    art: const _PageIcon(CpIcons.budget),
                    title: s.splitTitle,
                    body: s.splitBody,
                  ),
                  _Page(
                    art: const _PageIcon(CpIcons.shield),
                    title: s.privacyTitle,
                    body: s.privacyBody,
                  ),
                ],
              ),
            ),
            ContentMaxWidth(
              maxWidth: cp.sizes.phoneColumn,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  cp.space.xl,
                  cp.space.lg,
                  cp.space.xl,
                  cp.space.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: cp.space.lg,
                  children: [
                    if (_last)
                      CpCard(
                        padding: EdgeInsets.symmetric(
                          horizontal: cp.space.lg,
                          vertical: cp.space.sm,
                        ),
                        child: CpSwitchRow(
                          key: const Key('onboarding.dataOptIn'),
                          title: s.dataOptIn,
                          value: _dataOptIn,
                          onChanged: (value) =>
                              setState(() => _dataOptIn = value),
                        ),
                      ),
                    _PageDots(current: _currentPage, count: _pageCount),
                    if (_last)
                      CpButton(
                        key: const Key('onboarding.start'),
                        label: s.start,
                        expand: true,
                        onPressed: () => widget.onComplete?.call(),
                      )
                    else
                      CpButton(
                        key: const Key('onboarding.next'),
                        label: s.next,
                        expand: true,
                        onPressed: () => _goToPage(_currentPage + 1),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One page: its picture, a headline and a line under it, scrolling when
/// large text needs more room.
class _Page extends StatelessWidget {
  const _Page({required this.art, required this.title, required this.body});

  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: cp.space.xxl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ContentMaxWidth(
              maxWidth: cp.sizes.phoneColumn,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: cp.space.lg,
                children: [
                  art,
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: cp.type.headlineMedium.copyWith(
                        color: cp.colors.text,
                      ),
                    ),
                  ),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: cp.type.bodyLarge.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A feature's icon in a soft accent circle.
class _PageIcon extends StatelessWidget {
  const _PageIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final side = cp.sizes.iconHero + cp.space.xxl;
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: cp.colors.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: cp.sizes.iconHero, color: cp.colors.accent),
    );
  }
}

/// Which page is showing: the current dot is long and accent coloured.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final dot = cp.space.sm;
    return Semantics(
      label: context.strings.onboarding.page(current + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: cp.space.sm,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: cp.motion.fast,
              width: i == current ? dot * 3.5 : dot,
              height: dot,
              decoration: BoxDecoration(
                color: i == current ? cp.colors.accent : cp.colors.border,
                borderRadius: cp.radii.pill,
              ),
            ),
        ],
      ),
    );
  }
}
