import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/light_sign_in_panel.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/phone.dart';
import 'package:crewpoint_app/app/features/registration/application/event_page_provider.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

/// Register and "my registration" (`/e/:eventSlug/register`,
/// `/e/:eventSlug/registration`; Spec #233 Req 9, 12; #241). An event
/// open to anyone with the link needs a light account, so someone signed
/// out signs in here, by email link, phone code, Google or Apple, and
/// carries on to [child] on the same page; onboarding waits until they
/// next open the app normally. An invited event needs no account: its
/// groups use their personal links.
class RegistrationSignInGate extends ConsumerWidget {
  const RegistrationSignInGate({
    super.key,
    required this.slug,
    required this.returnTo,
    required this.child,
  });

  final String slug;
  final String returnTo;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings.lightSignIn;
    final pageStrings = context.strings.eventPage;
    final cp = context.cp;
    final key = slug.toLowerCase();
    final page = ref.watch(eventPageProvider(key));
    final signedIn = ref.watch(authProvider) is Authenticated;

    Widget frame(List<Widget> children) => Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: page.value?.title ?? '',
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: () => context.go('/e/$slug'),
      ),
      body: ListView(
        key: const Key('registration.gate.body'),
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.md,
          cp.space.lg,
          cp.space.xxl,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: cp.sizes.phoneColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: children,
            ),
          ),
        ],
      ),
    );

    return page.when(
      loading: () => frame([
        CpLoadingState.rows(
          key: const Key('registration.gate.loading'),
          semanticLabel: pageStrings.loading,
        ),
      ]),
      error: (_, _) => frame([
        CpErrorState(
          key: const Key('registration.gate.error'),
          title: pageStrings.failed,
          message: pageStrings.failedHelp,
          retryLabel: pageStrings.retry,
          retryKey: const Key('registration.gate.retry'),
          onRetry: () => ref.invalidate(eventPageProvider(key)),
        ),
      ]),
      data: (event) {
        if (event.mode == RegistrationMode.invited) {
          return frame([
            CpEmptyState(
              key: const Key('registration.gate.invitedOnly'),
              icon: CpIcons.statusInfo,
              title: pageStrings.invitedOnly(
                event.words.one('group').toLowerCase(),
              ),
            ),
          ]);
        }
        if (signedIn) return child;
        return frame([
          Semantics(
            header: true,
            child: Text(
              s.title,
              key: const Key('registration.gate.signIn'),
              style: cp.type.titleLarge.copyWith(color: cp.colors.text),
            ),
          ),
          Text(
            s.help,
            style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
          ),
          LightSignInPanel(
            returnTo: returnTo,
            phoneCountry: countryForTimeZone(event.timeZone),
          ),
        ]);
      },
    );
  }
}
