import 'dart:developer';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _paymentHandleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _pickedImage;
  String? _selectedPaymentMethod;
  bool _isSaving = false;
  bool _showSuccess = false;

  static const _paymentMethods = [
    ('venmo', 'Venmo', Icons.payment),
    ('zelle', 'Zelle', Icons.account_balance),
    ('cashapp', 'Cash App', Icons.attach_money),
    ('paypal', 'PayPal', Icons.paypal_outlined),
    ('cash', 'Cash', Icons.money),
    ('other', 'Other', Icons.more_horiz),
  ];

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    if (authState is Authenticated) {
      _nameController.text = authState.user.displayName ?? '';
      _selectedPaymentMethod = authState.user.paymentMethod;
      _paymentHandleController.text = authState.user.paymentHandle ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paymentHandleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
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

      // Upload photo if changed
      if (_pickedImage != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
          'users/${user.uid}/profile.jpg',
        );
        await storageRef.putFile(_pickedImage!);
        photoUrl = await storageRef.getDownloadURL();
      }

      // Update Firebase Auth profile
      await user.updateDisplayName(newName);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Update Firestore user doc
      final updateData = <String, dynamic>{
        'displayName': newName,
        'updatedAt': FieldValue.serverTimestamp(),
        'paymentMethod': _selectedPaymentMethod,
        'paymentHandle': _paymentHandleController.text.trim().isEmpty
            ? null
            : _paymentHandleController.text.trim(),
      };
      if (photoUrl != null) {
        updateData['photoUrl'] = photoUrl;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      // Show success animation briefly
      if (mounted) {
        setState(() {
          _isSaving = false;
          _showSuccess = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).pop();
        }
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
                  Icons.check_circle,
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
          icon: const Icon(Icons.close),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            spacing: AppSpacing.xl,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Avatar (tappable)
              GestureDetector(
                onTap: _isSaving ? null : _pickImage,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sage,
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: AppColors.charcoalDark,
                        backgroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!)
                            : (currentPhotoUrl != null
                                      ? NetworkImage(currentPhotoUrl)
                                      : null)
                                  as ImageProvider?,
                        child: (_pickedImage == null && currentPhotoUrl == null)
                            ? Lottie.asset(
                                'assets/animations/profile.json',
                                width: 64,
                                height: 64,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person,
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
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                'Tap photo to change',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGrey),
              ),

              // Name field
              Card(
                elevation: 1,
                color: AppColors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.borderLg,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: CustomTextField(
                    hintText: 'Display Name',
                    controller: _nameController,
                    enabled: !_isSaving,
                    prefixIcon: const Icon(Icons.person_outline),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                ),
              ),

              // Payment method section
              Card(
                elevation: 1,
                color: AppColors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.borderLg,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: AppSpacing.md,
                    children: [
                      Text(
                        'Payment Method (optional)',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.darkGrey),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPaymentMethod,
                        decoration: const InputDecoration(
                          hintText: 'Select payment method',
                          prefixIcon: Icon(Icons.payment_outlined),
                        ),
                        items: _paymentMethods
                            .map(
                              (m) => DropdownMenuItem(
                                value: m.$1,
                                child: Row(
                                  spacing: AppSpacing.sm,
                                  children: [
                                    Icon(
                                      m.$3,
                                      size: 20,
                                      color: AppColors.charcoal,
                                    ),
                                    Text(m.$2),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(
                                () => _selectedPaymentMethod = value,
                              ),
                      ),
                      CustomTextField(
                        hintText: '@username, phone, or email',
                        controller: _paymentHandleController,
                        enabled: !_isSaving,
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

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
    );
  }
}
