import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_form.dart';

/// What the registration form for a slug asks (#242), read once through
/// `getRegistrationForm`; Retry invalidates it.
final registrationFormProvider = FutureProvider.autoDispose
    .family<RegistrationFormSpec, ({String slug, String? complete})>(
      (ref, key) => ref
          .watch(memberCallsProvider)
          .getRegistrationForm(key.slug, complete: key.complete),
      retry: (_, _) => null,
    );
