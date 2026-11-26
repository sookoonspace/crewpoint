import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/registration/domain/my_registration.dart';

const _k = 'registration.mine';

/// "My registration" for a slug (#242), read through `getMyRegistration`;
/// Retry invalidates it.
final myRegistrationProvider = FutureProvider.autoDispose
    .family<MyRegistrationView, String>(
      (ref, slug) => ref.watch(memberCallsProvider).getMyRegistration(slug),
      retry: (_, _) => null,
    );

/// `/e/:eventSlug/registration` (Spec #233 Req 9, 19, 35; #242), behind
/// the sign-in gate: the registration's status with an icon and colour,
/// when it was sent, the waitlist number, who is in it, and the
/// after-registration note for submitted groups. Without a registration it
/// offers Register. No fee is shown (Req 7).
class MyRegistrationScreen extends ConsumerWidget {
  const MyRegistrationScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings.myRegistration;
    final form = context.strings.registerForm;
    final cp = context.cp;
    final key = slug.toLowerCase();
    final view = ref.watch(myRegistrationProvider(key));
    Widget frame(String title, List<Widget> children) => Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: () => context.go('/e/$slug'),
      ),
      body: ListView(
        key: const Key('$_k.body'),
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
    return view.when(
      loading: () => frame(s.title, [
        CpLoadingState.rows(
          key: const Key('$_k.loading'),
          semanticLabel: form.loading,
        ),
      ]),
      error: (_, _) => frame(s.title, [
        CpErrorState(
          key: const Key('$_k.error'),
          title: form.failed,
          message: form.failedHelp,
          retryLabel: form.retry,
          retryKey: const Key('$_k.retry'),
          onRetry: () => ref.invalidate(myRegistrationProvider(key)),
        ),
      ]),
      data: (v) {
        final r = v.registration;
        if (r == null) {
          return frame(v.title, [
            CpEmptyState(
              key: const Key('$_k.none'),
              icon: CpIcons.registration,
              title: s.none,
              message: s.noneHelp,
              actionLabel: s.register,
              actionKey: const Key('$_k.register'),
              onAction: () => context.go('/e/$slug/register'),
            ),
          ]);
        }
        final language = Localizations.localeOf(context).languageCode;
        final locale = Localizations.localeOf(context).toLanguageTag();
        final note = v.note;
        return frame(v.title, [
          _StatusCard(registration: r, view: v, locale: locale),
          CpSectionHeader(title: s.people),
          CpCard(
            key: const Key('$_k.people'),
            child: CpRowGroup(
              children: [
                for (final p in r.people)
                  CpListRow(
                    leading: CpAvatar(name: p.name),
                    title: p.name,
                  ),
              ],
            ),
          ),
          if (note != null) ...[
            CpSectionHeader(title: s.note),
            CpCard(
              key: const Key('$_k.note'),
              padding: EdgeInsets.all(cp.space.lg),
              child: SelectableText(
                language == 'gu' && note.gu != null ? note.gu! : note.en,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
              ),
            ),
          ],
          // Before the deadline everything can change; after it, the
          // contact details only (#244, Req 35, 36).
          if (r.status != 'cancelled')
            CpButton(
              key: const Key('$_k.change'),
              label: v.deadline != null && DateTime.now().isAfter(v.deadline!)
                  ? s.changeContact
                  : s.change,
              icon: CpIcons.actionEdit,
              expand: true,
              onPressed: () => context.go('/e/$slug/register'),
            ),
          CpButton.secondary(
            key: const Key('$_k.back'),
            label: s.backToEvent,
            onPressed: () => context.go('/e/$slug'),
          ),
        ]);
      },
    );
  }
}

/// The status with an icon and colour together (Req 71), when it was
/// sent, and what happens next for pending and waitlisted groups.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.registration,
    required this.view,
    required this.locale,
  });

  final MyRegistration registration;
  final MyRegistrationView view;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.myRegistration;
    final cp = context.cp;
    final r = registration;
    final (label, icon, tone, help) = switch (r.status) {
      'submitted' => (s.submitted, CpIcons.statusDone, CpTagTone.accent, null),
      'pending' => (
        s.pending,
        CpIcons.statusDoing,
        CpTagTone.quiet,
        s.pendingHelp,
      ),
      'waitlisted' => (
        s.waitlisted(r.waitlistPosition ?? 0),
        CpIcons.placesFull,
        CpTagTone.quiet,
        s.waitlistHelp,
      ),
      'cancelled' => (s.cancelled, CpIcons.inviteOff, CpTagTone.quiet, null),
      _ => (s.draft, CpIcons.statusTodo, CpTagTone.quiet, null),
    };
    final sent = r.submittedAt == null
        ? null
        : DateFormat.yMMMEd(
            locale,
          ).format(inEventZone(r.submittedAt!, view.timeZone));
    return CpCard(
      key: Key('$_k.status.${r.status}'),
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: cp.space.sm,
        children: [
          if (r.groupName.isNotEmpty && r.people.length > 1)
            Text(
              r.groupName,
              style: cp.type.titleMedium.copyWith(color: cp.colors.text),
            ),
          CpTag(label: label, icon: icon, tone: tone),
          if (sent != null)
            Text(
              s.sentOn(sent),
              style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
            ),
          if (help != null)
            Text(
              help,
              style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
            ),
        ],
      ),
    );
  }
}
