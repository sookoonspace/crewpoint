import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/form_card_shell.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/profile/application/current_user_doc_provider.dart';

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
  bool _showSuccess = false;

  static final _handlePattern = RegExp(r'^[A-Za-z0-9_-]{1,30}$');

  String? _validateHandle(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_handlePattern.hasMatch(value.trim())) {
      return 'Letters, numbers, _ or - only (≤30 chars)';
    }
    return null;
  }

  static const _paymentMethods = [
    ('venmo', 'Venmo', AppIcons.paymentVenmo),
    ('zelle', 'Zelle', AppIcons.paymentZelle),
    ('cashapp', 'Cash App', AppIcons.paymentCashApp),
    ('paypal', 'PayPal', AppIcons.paymentPayPal),
    ('cash', 'Cash', AppIcons.paymentCash),
    ('other', 'Other', AppIcons.actionMoreHoriz),
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

  void _showImagePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.photoLibrary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(fromCamera: false);
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.camera),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(fromCamera: true);
              },
            ),
          ],
        ),
      ),
    );
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

      if (mounted) {
        setState(() {
          _isSaving = false;
          _showSuccess = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e, st) {
      log('Profile save failed', error: e, stackTrace: st, name: 'profile');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('permission')
                  ? 'Permission denied. Please try again.'
                  : e.toString().contains('network')
                  ? 'Network error. Check your connection.'
                  : 'Failed to save profile. Please try again.',
            ),
            backgroundColor: AppColors.terracotta,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentPhotoUrl = authState is Authenticated
        ? authState.user.photoUrl
        : null;

    if (_showSuccess) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: Column(
            mainAxisSize: .min,
            spacing: AppSpacing.lg,
            children: [
              Lottie.asset(
                'assets/animations/success.json',
                width: 120,
                height: 120,
                errorBuilder: (_, _, _) => const Icon(
                  AppIcons.statusDone,
                  size: 80,
                  color: AppColors.sage,
                ),
              ),
              Text(
                'Profile updated!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.sage,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.actionClose),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.xl,
        ),
        child: ContentMaxWidth(
          key: const Key('editProfile.body.clamped'),
          maxWidth: 480,
          child: FormCardShell(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .start,
                spacing: AppSpacing.lg,
                children: [
                  // Avatar (tappable)
                  Center(
                    child: GestureDetector(
                      onTap: _isSaving ? null : _showImagePicker,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.sage.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: AppColors.charcoalDark,
                              backgroundImage: _picked != null
                                  ? MemoryImage(_picked!.bytes)
                                  : (currentPhotoUrl != null
                                            ? NetworkImage(currentPhotoUrl)
                                            : null)
                                        as ImageProvider?,
                              child:
                                  (_picked == null && currentPhotoUrl == null)
                                  ? Lottie.asset(
                                      'assets/animations/profile.json',
                                      width: 64,
                                      height: 64,
                                      errorBuilder: (_, _, _) => const Icon(
                                        AppIcons.navProfileFilled,
                                        size: 48,
                                        color: AppColors.sageLight,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: const BoxDecoration(
                                color: AppColors.sage,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                AppIcons.camera,
                                size: 18,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Center(
                    child: Text(
                      'Tap photo to change',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Display Name
                  Text(
                    'Display Name',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppColors.charcoal),
                  ),
                  CustomTextField(
                    hintText: 'How others see you',
                    controller: _nameController,
                    enabled: !_isSaving,
                    prefixIcon: const Icon(AppIcons.navProfile),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Payment section header
                  Text(
                    'Payment Info',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppColors.charcoal),
                  ),
                  Text(
                    'Optional — helps your crew settle up with you',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),

                  // Payment Method dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentMethod,
                    decoration: InputDecoration(
                      hintText: 'Select payment method',
                      prefixIcon: const Icon(AppIcons.paymentGeneric),
                      filled: true,
                      fillColor: AppColors.offWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.lightGrey,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.lightGrey,
                        ),
                      ),
                    ),
                    items: _paymentMethods
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.$1,
                            child: Row(
                              spacing: AppSpacing.sm,
                              children: [
                                Icon(m.$3, size: 20, color: AppColors.charcoal),
                                Text(m.$2),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) =>
                              setState(() => _selectedPaymentMethod = value),
                  ),

                  // Payment Handle
                  CustomTextField(
                    hintText: '@username, phone, or email',
                    controller: _paymentHandleController,
                    enabled: !_isSaving,
                    prefixIcon: const Icon(AppIcons.authEmail),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Deep-link handles for one-tap settle
                  Text(
                    'Settle handles',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppColors.charcoal),
                  ),
                  Text(
                    'Used by the Venmo / CashApp deep-link buttons in Budget',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  CustomTextField(
                    key: const Key('profile.edit.venmoHandle'),
                    hintText: 'Venmo handle (optional)',
                    controller: _venmoHandleController,
                    enabled: !_isSaving,
                    prefixIcon: const Icon(AppIcons.navBudget),
                    validator: _validateHandle,
                  ),
                  CustomTextField(
                    key: const Key('profile.edit.cashappHandle'),
                    hintText: 'Cash App \$cashtag (optional)',
                    controller: _cashappHandleController,
                    enabled: !_isSaving,
                    prefixIcon: const Icon(AppIcons.currency),
                    validator: _validateHandle,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Save button
                  PrimaryButton(
                    label: 'Save Changes',
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
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
