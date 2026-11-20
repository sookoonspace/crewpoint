import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/profile/application/current_user_doc_provider.dart';
import 'package:crewpoint_app/app/features/profile/presentation/widgets/profile_photo.dart';

/// Editing your name, photo and how people pay you, in the Person form's
/// pattern (Spec #186): cards of fields with Save at the bottom.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _paymentHandleController = TextEditingController();
  final _venmoHandleController = TextEditingController();
  final _cashappHandleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  PickedImage? _picked;
  String? _selectedPaymentMethod;
  bool _isSaving = false;

  static final _handlePattern = RegExp(r'^[A-Za-z0-9_-]{1,30}$');

  String? _validateHandle(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_handlePattern.hasMatch(value.trim())) {
      return context.strings.profile.handleInvalid;
    }
    return null;
  }

  static List<(String id, String label, IconData icon)> _paymentMethods(
    ProfileStrings s,
  ) => [
    ('venmo', s.paymentMethodVenmo, CpIcons.paymentVenmo),
    ('zelle', s.paymentMethodZelle, CpIcons.paymentZelle),
    ('cashapp', s.paymentMethodCashApp, CpIcons.paymentCashApp),
    ('paypal', s.paymentMethodPayPal, CpIcons.paymentPayPal),
    ('cash', s.paymentMethodCash, CpIcons.paymentCash),
    ('other', s.paymentMethodOther, CpIcons.actionMoreHoriz),
  ];

  @override
  void initState() {
    super.initState();
    // Prefer the Firestore-backed user (carries derived displayName +
    // payment fields written via saveProfile). Fall back to the
    // auth-only AppUser before the first snapshot lands.
    final fsUser = ref.read(currentUserDocProvider).value;
    final authState = ref.read(authProvider);
    final user = fsUser ?? (authState is Authenticated ? authState.user : null);
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _selectedPaymentMethod = user.paymentMethod;
      _paymentHandleController.text = user.paymentHandle ?? '';
      _venmoHandleController.text = user.venmoHandle ?? '';
      _cashappHandleController.text = user.cashappHandle ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paymentHandleController.dispose();
    _venmoHandleController.dispose();
    _cashappHandleController.dispose();
    super.dispose();
  }

  Future<void> _showImagePicker() async {
    final s = context.strings.profile;
    final fromCamera = await showCpSheet<bool>(
      context: context,
      title: s.changePhoto,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            CpListRow(
              key: const Key('profile.edit.photo.gallery'),
              leading: const _FieldIcon(CpIcons.photoLibrary),
              title: s.photoGallery,
              onTap: () => Navigator.of(sheet).pop(false),
            ),
            CpListRow(
              key: const Key('profile.edit.photo.camera'),
              leading: const _FieldIcon(CpIcons.camera),
              title: s.photoCamera,
              onTap: () => Navigator.of(sheet).pop(true),
            ),
          ],
        ),
      ),
    );
    if (fromCamera != null) await _pickImage(fromCamera: fromCamera);
  }

  Future<void> _pickMethod() async {
    final cp = context.cp;
    final s = context.strings.profile;
    final picked = await showCpSheet<String>(
      context: context,
      title: s.paymentMethodLabel,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final (id, label, icon) in _paymentMethods(s))
              CpListRow(
                key: Key('profile.edit.method.$id'),
                leading: _FieldIcon(icon),
                title: label,
                selected: id == _selectedPaymentMethod,
                trailing: id == _selectedPaymentMethod
                    ? Icon(
                        CpIcons.statusDone,
                        size: cp.sizes.iconMd,
                        color: cp.colors.accent,
                      )
                    : const SizedBox.shrink(),
                onTap: () => Navigator.of(sheet).pop(id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedPaymentMethod = picked);
    }
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    final imageService = ref.read(imageServiceProvider);
    final picked = fromCamera
        ? await imageService.takePhoto()
        : await imageService.pickFromGallery();
    if (picked != null) {
      setState(() => _picked = picked);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final s = context.strings.profile;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final newName = _nameController.text.trim();
      String? photoUrl;

      // Upload photo if changed — via image service
      final picked = _picked;
      if (picked != null) {
        final imageService = ref.read(imageServiceProvider);
        photoUrl = await imageService.uploadToStorage(
          bytes: picked.bytes,
          storagePath: 'users/${user.uid}/profile.jpg',
          contentType: picked.contentType,
        );
      }

      // Update Firebase Auth profile
      await user.updateDisplayName(newName);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Save via repository (handles Firestore merge + doc creation)
      final repo = ref.read(userRepositoryProvider);
      await repo.saveProfile(
        uid: user.uid,
        displayName: newName,
        photoUrl: photoUrl,
        paymentMethod: _selectedPaymentMethod,
        paymentHandle: _paymentHandleController.text.trim().isEmpty
            ? null
            : _paymentHandleController.text.trim(),
        venmoHandle: _venmoHandleController.text.trim().isEmpty
            ? null
            : _venmoHandleController.text.trim(),
        cashappHandle: _cashappHandleController.text.trim().isEmpty
            ? null
            : _cashappHandleController.text.trim(),
      );

      // No manual refresh needed — `currentUserDocProvider` streams the
      // updated public doc via Firestore snapshot.

      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(s.saved)));
      navigator.pop();
    } catch (e, st) {
      log('Profile save failed', error: e, stackTrace: st, name: 'profile');
      if (!mounted) return;
      setState(() => _isSaving = false);
      final text = e.toString();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            text.contains('permission')
                ? s.saveDenied
                : text.contains('network')
                ? s.saveOffline
                : s.saveFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.profile;
    final authState = ref.watch(authProvider);
    final currentPhotoUrl = authState is Authenticated
        ? authState.user.photoUrl
        : null;
    final method = [
      for (final m in _paymentMethods(s))
        if (m.$1 == _selectedPaymentMethod) m,
    ].firstOrNull;
    final editable = !_isSaving;

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: s.editTitle,
        leadingIcon: CpIcons.actionClose,
        leadingTooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        leadingKey: const Key('profile.edit.close'),
        onLeading: _isSaving ? null : () => Navigator.of(context).pop(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        child: ContentMaxWidth(
          key: const Key('editProfile.body.clamped'),
          maxWidth: cp.sizes.phoneColumn,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: [
                CpCard(
                  padding: EdgeInsets.all(cp.space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: cp.space.lg,
                    children: [
                      Row(
                        spacing: cp.space.lg,
                        children: [
                          ListenableBuilder(
                            listenable: _nameController,
                            builder: (_, _) => ProfilePhoto(
                              url: currentPhotoUrl,
                              name: _nameController.text,
                              bytes: _picked?.bytes,
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: CpButton.secondary(
                                key: const Key('profile.edit.photo'),
                                label: s.changePhoto,
                                icon: CpIcons.camera,
                                onPressed: editable ? _showImagePicker : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      CpTextField(
                        fieldKey: const Key('profile.edit.name'),
                        label: s.nameLabel,
                        hint: s.nameHint,
                        required: true,
                        controller: _nameController,
                        enabled: editable,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return s.nameRequired;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                CpSectionHeader(title: s.paymentHeading),
                CpCard(
                  padding: EdgeInsets.all(cp.space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: cp.space.lg,
                    children: [
                      Text(
                        s.paymentHelp,
                        style: cp.type.bodyMedium.copyWith(
                          color: cp.colors.textMuted,
                        ),
                      ),
                      CpSelectField(
                        fieldKey: const Key('profile.edit.method'),
                        label: s.paymentMethodLabel,
                        placeholder: s.paymentMethodPlaceholder,
                        value: method?.$2,
                        leadingIcon: method?.$3 ?? CpIcons.paymentGeneric,
                        onTap: editable ? _pickMethod : null,
                      ),
                      CpTextField(
                        fieldKey: const Key('profile.edit.paymentHandle'),
                        label: s.paymentHandleLabel,
                        hint: s.paymentHandleHint,
                        controller: _paymentHandleController,
                        enabled: editable,
                      ),
                    ],
                  ),
                ),
                CpSectionHeader(title: s.settleHeading),
                CpCard(
                  padding: EdgeInsets.all(cp.space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: cp.space.lg,
                    children: [
                      Text(
                        s.settleHelp,
                        style: cp.type.bodyMedium.copyWith(
                          color: cp.colors.textMuted,
                        ),
                      ),
                      CpTextField(
                        fieldKey: const Key('profile.edit.venmoHandle'),
                        label: s.venmoHandleLabel,
                        controller: _venmoHandleController,
                        enabled: editable,
                        validator: _validateHandle,
                      ),
                      CpTextField(
                        fieldKey: const Key('profile.edit.cashappHandle'),
                        label: s.cashappHandleLabel,
                        controller: _cashappHandleController,
                        enabled: editable,
                        validator: _validateHandle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CpSaveBar(
        child: CpButton(
          key: const Key('profile.edit.save'),
          label: s.save,
          busy: _isSaving,
          onPressed: _save,
        ),
      ),
    );
  }
}

/// A row's icon in this screen's sheets.
class _FieldIcon extends StatelessWidget {
  const _FieldIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Icon(icon, size: cp.sizes.iconMd, color: cp.colors.textMuted);
  }
}
