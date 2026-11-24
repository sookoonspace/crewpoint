import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/web/ssr_handoff.dart';
import 'package:crewpoint_app/app/core/widgets/language_switch.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/registration/application/event_page_provider.dart';
import 'package:crewpoint_app/app/features/registration/domain/public_event.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';

/// The event's public link, as printed on flyers and in its QR code.
String eventPageLink(String slug) =>
    '${AppFlavor.current.legalBaseUrl}/e/$slug';

/// The public event page, `/e/:eventSlug` (Spec #233 Req 9-11, 13a, 14;
/// #240), outside the signed-in shell: anyone with the link, signed in or
/// not, sees the event's public fields, whether places remain, its QR code
/// and, while it is open to anyone with the link, Register. A draft says
/// only that it is not open yet.
class EventPageScreen extends ConsumerWidget {
  const EventPageScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.eventPage;
    final cp = context.cp;
    final key = slug.toLowerCase();
    final page = ref.watch(eventPageProvider(key));
    // Once the app shows the event, or why it cannot, the server-rendered
    // first page goes (Req 69).
    if (!page.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => removeServerRenderedPage(),
      );
    }

    Widget frame(List<Widget> children) => Scaffold(
      backgroundColor: cp.colors.background,
      body: SafeArea(
        child: ListView(
          key: const Key('events.page.body'),
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
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: LanguageSwitch(keyPrefix: 'events.page.language'),
                  ),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return page.when(
      loading: () => frame([
        CpLoadingState.rows(
          key: const Key('events.page.loading'),
          semanticLabel: strings.loading,
        ),
      ]),
      error: (error, _) {
        final code = error is FirebaseFunctionsException ? error.code : null;
        if (code == 'resource-exhausted') {
          return frame([
            CpEmptyState(
              key: const Key('events.page.rateLimited'),
              icon: CpIcons.statusDue,
              title: strings.rateLimited,
              actionLabel: strings.retry,
              actionKey: const Key('events.page.retry'),
              onAction: () => ref.invalidate(eventPageProvider(key)),
            ),
          ]);
        }
        if (code == 'not-found' || code == 'invalid-argument') {
          return frame([
            CpEmptyState(
              key: const Key('events.page.notFound'),
              icon: CpIcons.statusInfo,
              title: strings.notFound,
              message: strings.notFoundHelp,
            ),
          ]);
        }
        return frame([
          CpErrorState(
            key: const Key('events.page.error'),
            title: strings.failed,
            message: strings.failedHelp,
            retryLabel: strings.retry,
            retryKey: const Key('events.page.retry'),
            onRetry: () => ref.invalidate(eventPageProvider(key)),
          ),
        ]);
      },
      data: (event) {
        if (event.state == PublicEventState.notOpen) {
          return frame([
            CpEmptyState(
              key: const Key('events.page.notOpen'),
              icon: CpIcons.notOpenYet,
              title: strings.notOpen,
              message: strings.notOpenHelp,
            ),
          ]);
        }
        return frame([_EventDetails(event: event)]);
      },
    );
  }
}

class _EventDetails extends ConsumerWidget {
  const _EventDetails({required this.event});

  final PublicEvent event;

  String _dates(PublicEvent e, String locale) {
    final start = e.startDate;
    if (start == null) return '';
    final zone = e.dateOnly ? 'UTC' : e.timeZone;
    final format = e.dateOnly
        ? DateFormat.yMMMEd(locale)
        : DateFormat.yMMMEd(locale).add_jm();
    String day(DateTime d) => format.format(inEventZone(d, zone));
    final end = e.endDate;
    return end == null || end == start
        ? day(start)
        : '${day(start)} – ${day(end)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.eventPage;
    final cp = context.cp;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final language = Localizations.localeOf(context).languageCode;
    final link = eventPageLink(event.slug);
    final dates = _dates(event, locale);
    final deadline = event.deadline == null
        ? null
        : DateFormat.yMMMEd(
            locale,
          ).add_jm().format(inEventZone(event.deadline!, event.timeZone));
    final included = event.included == null
        ? null
        : (language == 'gu' ? event.included!.gu : null) ?? event.included!.en;
    final closed = event.state == PublicEventState.closed;
    final words = event.words;

    final (status, statusIcon, statusTone) = closed
        ? (strings.closed, CpIcons.registrationClosed, CpTagTone.quiet)
        : event.placesRemain
        ? (strings.placesRemain, CpIcons.placesRemain, CpTagTone.accent)
        : (strings.full, CpIcons.placesFull, CpTagTone.quiet);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.lg,
      children: [
        if (event.hasCover)
          ClipRRect(
            borderRadius: cp.radii.lg,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                '$link/cover.jpg',
                fit: BoxFit.cover,
                semanticLabel: strings.coverLabel(event.title),
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: cp.colors.accentSoft),
              ),
            ),
          ),
        Semantics(
          header: true,
          child: Text(
            event.title,
            key: const Key('events.page.title'),
            style: cp.type.headlineSmall.copyWith(color: cp.colors.text),
          ),
        ),
        if (dates.isNotEmpty)
          Text(
            dates,
            key: const Key('events.page.dates'),
            style: cp.type.titleMedium.copyWith(color: cp.colors.text),
          ),
        if (!event.dateOnly)
          Text(
            strings.timeZone(event.timeZone),
            style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
          ),
        Wrap(
          children: [
            CpTag(
              key: const Key('events.page.status'),
              label: status,
              icon: statusIcon,
              tone: statusTone,
            ),
          ],
        ),
        if (event.canRegister)
          CpButton(
            key: const Key('events.page.register'),
            label: strings.register(words.one('registration')),
            expand: true,
            onPressed: () => context.push('/e/${event.slug}/register'),
          )
        else if (!closed)
          Text(
            strings.invitedOnly(words.one('group').toLowerCase()),
            key: const Key('events.page.invitedOnly'),
            style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
          ),
        if (deadline != null)
          Text(
            closed && event.deadline!.isBefore(DateTime.now())
                ? strings.closedOn(deadline)
                : strings.closesOn(deadline),
            key: const Key('events.page.deadline'),
            style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
          ),
        if (event.venues.isNotEmpty) ...[
          CpSectionHeader(title: strings.whereHeading),
          CpCard(
            child: CpRowGroup(
              children: [
                for (final (i, v) in event.venues.indexed)
                  _VenueRow(key: Key('events.page.venue.$i'), venue: v),
              ],
            ),
          ),
        ],
        if (event.description.isNotEmpty) ...[
          CpSectionHeader(title: strings.aboutHeading),
          CpCard(
            padding: EdgeInsets.all(cp.space.lg),
            child: Text(
              event.description,
              style: cp.type.bodyLarge.copyWith(color: cp.colors.text),
            ),
          ),
        ],
        if (included != null) ...[
          CpSectionHeader(title: strings.includedHeading),
          CpCard(
            padding: EdgeInsets.all(cp.space.lg),
            child: Text(
              included,
              key: const Key('events.page.included'),
              style: cp.type.bodyLarge.copyWith(color: cp.colors.text),
            ),
          ),
        ],
        CpSectionHeader(title: strings.shareHeading),
        CpCard(
          padding: EdgeInsets.all(cp.space.lg),
          child: Column(
            spacing: cp.space.md,
            children: [
              Container(
                padding: EdgeInsets.all(cp.space.md),
                decoration: BoxDecoration(
                  color: CpFixedColors.qrPaper,
                  borderRadius: cp.radii.lg,
                  border: Border.all(
                    color: cp.colors.border,
                    width: cp.sizes.hairline,
                  ),
                ),
                child: KeyedSubtree(
                  key: const Key('events.page.qr'),
                  child: ref
                      .watch(qrRendererProvider)
                      .render(
                        link,
                        size: cp.sizes.qrCode,
                        foreground: CpFixedColors.qrInk,
                        background: CpFixedColors.qrPaper,
                        semanticLabel: strings.qrLabel(link),
                      ),
                ),
              ),
              SelectableText(
                link,
                key: const Key('events.page.link'),
                textAlign: TextAlign.center,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: cp.space.sm,
                runSpacing: cp.space.sm,
                children: [
                  CpButton.secondary(
                    key: const Key('events.page.copy'),
                    label: strings.copyLink,
                    icon: CpIcons.actionCopy,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(strings.copied)));
                    },
                  ),
                  CpButton.secondary(
                    key: const Key('events.page.share'),
                    label: strings.share,
                    icon: CpIcons.actionShare,
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: '${event.title}\n$link'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VenueRow extends ConsumerWidget {
  const _VenueRow({super.key, required this.venue});

  final PublicVenue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.eventPage;
    final cp = context.cp;
    final link = mapLinkFor(
      EventVenue(
        id: '',
        name: venue.name,
        address: venue.address,
        mapUrl: venue.mapUrl,
        directions: venue.directions,
      ),
    );
    final details = [
      venue.address.isEmpty ? strings.addressTba : venue.address,
      if (venue.directions.isNotEmpty) venue.directions,
    ].join('\n');
    return CpListRow(
      leading: Icon(
        CpIcons.place,
        size: cp.sizes.iconMd,
        color: cp.colors.accent,
      ),
      title: venue.name,
      subtitle: details,
      trailing: link == null
          ? null
          : Icon(
              CpIcons.actionOpenInNew,
              size: cp.sizes.iconMd,
              color: cp.colors.textMuted,
              semanticLabel: strings.openMap,
            ),
      onTap: link == null
          ? null
          : () => ref.read(urlLauncherProvider).launch(link),
    );
  }
}

/// `/e/:eventSlug/register` until the registration form lands (#241,
/// #242): says the form is on its way and leads back to the event page.
class RegisterComingScreen extends StatelessWidget {
  const RegisterComingScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.eventPage;
    final cp = context.cp;
    return Scaffold(
      backgroundColor: cp.colors.background,
      body: SafeArea(
        child: CpEmptyState(
          key: const Key('events.page.registerSoon'),
          icon: CpIcons.notOpenYet,
          title: strings.registerSoon,
          message: strings.registerSoonHelp,
          actionLabel: strings.backToEvent,
          actionKey: const Key('events.page.back'),
          onAction: () => context.go('/e/$slug'),
        ),
      ),
    );
  }
}
