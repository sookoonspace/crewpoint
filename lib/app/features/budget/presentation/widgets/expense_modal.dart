import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_list_detail.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/large_event.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/member_picker_sheet.dart';

/// Submit signature: receives the expense model AND the picked receipt
/// (if any). The parent uploads the bytes out-of-band so the modal stays
/// free of Firebase / Storage coupling. Web-safe — no `dart:io File`.
///
/// The form stays open until this reports [ExpenseSaveResult.saved], so what
/// was entered survives a failure.
typedef ExpenseSubmit =
    Future<ExpenseSaveResult> Function(
      ExpenseModel expense,
      PickedImage? receipt,
    );

/// Async receipt picker callback — returns null if the user cancels.
typedef ReceiptPicker = Future<PickedImage?> Function();

/// The expense form (Spec #186), in the Person form's pattern: a top bar
/// with close, cards of fields, and save in a bar at the bottom. It opens
/// as its own page ([show]), or in place beside the Budget list with
/// [onCancel], where choosing another expense with unsaved edits asks
/// first (Req 23).
class ExpenseModal extends StatefulWidget {
  const ExpenseModal({
    super.key,
    required this.eventId,
    required this.payerId,
    required this.memberIds,
    this.words = const LabelResolver({}),
    this.currencySymbol = '\$',
    this.minAmount = 0.01,
    this.maxAmount = 10000000,
    this.initial,
    this.onPickReceipt,
    this.onSubmit,
    this.onCancel,
  });

  final String eventId;
  final String payerId;
  final List<String> memberIds;

  /// The event's words, for the member picker.
  final LabelResolver words;
  final String currencySymbol;
  final double minAmount;
  final double maxAmount;

  /// When non-null, the modal opens in edit mode: pre-fills from this
  /// model, locks `payerId` (display-only), preserves the id on submit,
  /// and renders `Save changes` instead of `Add Expense`.
  final ExpenseModel? initial;
  final ReceiptPicker? onPickReceipt;
  final ExpenseSubmit? onSubmit;

  /// Closes a form shown in place rather than as its own page; also
  /// called once it saves.
  final VoidCallback? onCancel;

  /// Validates amount-string then bounds. Returns null if valid; else error msg.
  static String? validateAmountInput(
    String? raw, {
    double minAmount = 0.01,
    double maxAmount = 10000000,
  }) {
    if (raw == null || raw.trim().isEmpty) return 'Enter an amount';
    final value = double.tryParse(raw.trim());
    if (value == null) return 'Invalid amount';
    if (value < minAmount) return 'Amount must be at least $minAmount';
    if (value > maxAmount) return 'Amount must be at most $maxAmount';
    return null;
  }

  /// Returns null if splits sum is within `tolerance` of `total`; else error.
  static String? validateSplitSum(
    Iterable<ExpenseSplit> splits,
    double total, {
    double tolerance = 0.01,
  }) {
    final sum = splits.fold<double>(0, (acc, s) => acc + s.amount);
    if ((sum - total).abs() > tolerance) {
      return 'Split sum (${sum.toStringAsFixed(2)}) must equal total '
          '(${total.toStringAsFixed(2)})';
    }
    return null;
  }

  static Future<void> show({
    required BuildContext context,
    required String eventId,
    required String payerId,
    required List<String> memberIds,
    LabelResolver words = const LabelResolver({}),
    String currencySymbol = '\$',
    ExpenseModel? initial,
    ReceiptPicker? onPickReceipt,
    ExpenseSubmit? onSubmit,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExpenseModal(
          eventId: eventId,
          payerId: payerId,
          memberIds: memberIds,
          words: words,
          currencySymbol: currencySymbol,
          initial: initial,
          onPickReceipt: onPickReceipt,
          onSubmit: onSubmit,
        ),
      ),
    );
  }

  @override
  State<ExpenseModal> createState() => _ExpenseModalState();
}

class _ExpenseModalState extends State<ExpenseModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late bool _isDonation;
  PickedImage? _pickedReceipt;
  bool _saving = false;
  ExpenseSaveResult? _failure;

  /// Who shares the cost, or null for everyone (Req 43a).
  Set<String>? _chosen;
  bool _splitError = false;
  bool _changed = false;

  /// Kept across retries, so a save that reached the server is not duplicated.
  final String _newExpenseId = const Uuid().v4();

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _amountController = TextEditingController(
      text: initial != null ? initial.amount.toString() : '',
    );
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _isDonation = initial?.isDonation ?? false;
    _chosen = _initialChoice();
  }

  /// Editing starts from who shared the expense, or everyone when it has no
  /// splits saved. A new one is split with
  /// everyone, except past 50 members, where people must be chosen.
  Set<String>? _initialChoice() {
    final initial = widget.initial;
    if (initial == null) {
      return splitNeedsChoosing(widget.memberIds.length) ? <String>{} : null;
    }
    // An expense saved without its splits was shared with everyone.
    if (initial.splits.isEmpty) return null;
    final shared = {
      for (final s in initial.splits) s.userId,
      if (initial.isDonation) initial.payerId,
    };
    final everyone = widget.memberIds.toSet();
    return shared.length == everyone.length && shared.containsAll(everyone)
        ? null
        : shared;
  }

  /// Who the amount is divided between, in member order where possible.
  List<String> get _splitters {
    final chosen = _chosen;
    final pool = chosen == null
        ? widget.memberIds
        : [
            for (final id in widget.memberIds)
              if (chosen.contains(id)) id,
            for (final id in chosen)
              if (!widget.memberIds.contains(id)) id,
          ];
    return _isDonation
        ? pool.where((id) => id != widget.payerId).toList()
        : pool;
  }

  Future<void> _choosePeople() async {
    final picked = await MemberPickerSheet.pickMany(
      context,
      eventId: widget.eventId,
      words: widget.words,
      initial: _chosen ?? widget.memberIds.toSet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _chosen = picked;
      _changed = true;
      _splitError = false;
    });
  }

  /// Leaves, asking first when something changed.
  Future<void> _leave() async {
    final navigator = Navigator.of(context);
    if (_changed && !_saving) {
      final roles = context.strings.roles;
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialog) => CpDialog(
          title: roles.discardTitle,
          message: roles.discardBody,
          actions: [
            CpButton.text(
              key: const Key('budget.expense.discard.keep'),
              label: roles.keepEditing,
              onPressed: () => Navigator.of(dialog).pop(false),
            ),
            CpButton.destructive(
              key: const Key('budget.expense.discard.confirm'),
              label: roles.discard,
              onPressed: () => Navigator.of(dialog).pop(true),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    _close(navigator);
  }

  void _close(NavigatorState navigator) {
    final cancel = widget.onCancel;
    if (cancel != null) {
      cancel();
    } else {
      navigator.pop();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final picker = widget.onPickReceipt;
    if (picker == null) return;
    final picked = await picker();
    if (!mounted || picked == null) return;
    setState(() => _pickedReceipt = picked);
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    final splitOk = _splitters.isNotEmpty;
    setState(() => _splitError = !splitOk);
    if (_saving || !formOk || !splitOk) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final splits = ExpenseModel.calculateSplits(
      amount: amount,
      payerId: widget.payerId,
      memberIds: _splitters,
      isDonation: false,
    );

    final initial = widget.initial;
    final expense = ExpenseModel(
      id: initial?.id ?? _newExpenseId,
      eventId: widget.eventId,
      payerId: widget.payerId,
      amount: amount,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isDonation: _isDonation,
      isPayment: initial?.isPayment ?? false,
      splits: splits,
      receiptPath: initial?.receiptPath,
      createdAt: initial?.createdAt,
    );

    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      _close(Navigator.of(context));
      return;
    }

    setState(() {
      _saving = true;
      _failure = null;
    });
    ExpenseSaveResult result;
    try {
      result = await onSubmit(expense, _pickedReceipt);
    } catch (e, st) {
      log('Expense submit failed', error: e, stackTrace: st, name: 'budget');
      result = ExpenseSaveResult.rejected;
    }
    if (!mounted) return;
    if (result == ExpenseSaveResult.saved) {
      _changed = false;
      _close(Navigator.of(context));
      return;
    }
    setState(() {
      _saving = false;
      _failure = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final splitCount = _splitters.length;
    final pickerStrings = context.strings.memberPicker;
    final chosen = _chosen;
    final splitAmount = splitCount > 0 ? amount / splitCount : 0.0;
    final canPickReceipt = widget.onPickReceipt != null;
    final strings = context.strings.budget;
    final symbol = widget.currencySymbol;

    Widget card(List<Widget> children) => CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: children,
      ),
    );

    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          card([
            CpTextField(
              key: const Key('budget.expense.amount'),
              label: '${strings.amountLabel} ($symbol)',
              controller: _amountController,
              required: true,
              requiredLabel: context.strings.groupEntry.required,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefixIcon: CpIcons.currency,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _changed = true),
              validator: (value) => ExpenseModal.validateAmountInput(
                value,
                minAmount: widget.minAmount,
                maxAmount: widget.maxAmount,
              ),
            ),
            CpTextField(
              key: const Key('budget.expense.description'),
              label: strings.descriptionLabel,
              hint: strings.descriptionHint,
              controller: _descriptionController,
              enabled: !_saving,
              onChanged: (_) => setState(() => _changed = true),
            ),
            CpSwitchRow(
              key: const Key('budget.expense.donate'),
              title: strings.donateLabel,
              help: strings.donateHelp,
              value: _isDonation,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _isDonation = value;
                      _changed = true;
                    }),
            ),
          ]),
          CpSectionHeader(title: pickerStrings.splitHeading),
          card([
            _SplitSection(
              summary: chosen == null
                  ? pickerStrings.splitEveryone(widget.memberIds.length)
                  : pickerStrings.splitChosen(chosen.length),
              mustChoose:
                  chosen != null &&
                      chosen.isEmpty &&
                      splitNeedsChoosing(widget.memberIds.length)
                  ? pickerStrings.splitMustChoose(largeEventMembers)
                  : null,
              error: _splitError ? pickerStrings.splitNoneChosen : null,
              chooseLabel: pickerStrings.choosePeople,
              everyoneLabel: chosen == null
                  ? null
                  : pickerStrings.splitUseEveryone,
              onChoose: _saving ? null : _choosePeople,
              onEveryone: () => setState(() {
                _chosen = null;
                _changed = true;
                _splitError = false;
              }),
            ),
            if (amount > 0)
              Text(
                strings.perPerson(
                  '$symbol${splitAmount.toStringAsFixed(2)}',
                  splitCount,
                ),
                key: const Key('budget.expense.split.perPerson'),
                style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
              ),
          ]),
          if (canPickReceipt)
            card([
              _ReceiptRow(
                receipt: _pickedReceipt,
                onPick: _pickReceipt,
                onClear: () => setState(() => _pickedReceipt = null),
              ),
            ]),
          if (_failure != null)
            Container(
              padding: EdgeInsets.all(cp.space.md),
              decoration: BoxDecoration(
                color: cp.colors.overdueSoft,
                borderRadius: cp.radii.md,
              ),
              child: CpFieldError(
                _failure == ExpenseSaveResult.needsConnection
                    ? strings.expenseNeedsConnection
                    : strings.expenseSaveRejected,
                key: const Key('budget.expense.error'),
              ),
            ),
        ],
      ),
    );

    final saveBar = Material(
      color: cp.colors.surface,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cp.colors.border)),
          ),
          child: Padding(
            padding: EdgeInsets.all(cp.space.md),
            // heightFactor 1: the bar is only as tall as its button.
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              heightFactor: 1,
              child: CpButton(
                key: const Key('budget.expense.save'),
                label: _failure == ExpenseSaveResult.needsConnection
                    ? strings.expenseRetry
                    : (_isEdit
                          ? strings.saveChangesCta
                          : strings.addExpenseCta),
                busy: _saving,
                onPressed: _submit,
              ),
            ),
          ),
        ),
      ),
    );

    return PopScope(
      // A form in place never pops its page; one of its own asks first.
      canPop: widget.onCancel == null && (!_changed || _saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: CpUnsavedChanges(
        dirty: _changed && !_saving,
        child: Scaffold(
          backgroundColor: cp.colors.background,
          appBar: CpTopBar(
            title: _isEdit ? strings.editExpenseTitle : strings.addExpenseTitle,
            leadingIcon: CpIcons.actionClose,
            leadingKey: const Key('budget.expense.close'),
            leadingTooltip: MaterialLocalizations.of(
              context,
            ).closeButtonTooltip,
            onLeading: _leave,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              cp.space.lg,
              cp.space.sm,
              cp.space.lg,
              cp.space.xxl,
            ),
            child: ContentMaxWidth(maxWidth: cp.sizes.phoneColumn, child: body),
          ),
          bottomNavigationBar: saveBar,
        ),
      ),
    );
  }
}

/// Who shares the cost: everyone, or the people chosen in the picker.
class _SplitSection extends StatelessWidget {
  const _SplitSection({
    required this.summary,
    required this.chooseLabel,
    required this.onChoose,
    required this.onEveryone,
    this.everyoneLabel,
    this.mustChoose,
    this.error,
  });

  final String summary;
  final String chooseLabel;
  final String? everyoneLabel;
  final String? mustChoose;
  final String? error;
  final VoidCallback? onChoose;
  final VoidCallback onEveryone;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      key: const Key('budget.expense.split'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.sm,
      children: [
        Text(
          summary,
          key: const Key('budget.expense.split.summary'),
          style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
        ),
        if (mustChoose != null)
          Text(
            mustChoose!,
            key: const Key('budget.expense.split.mustChoose'),
            style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
          ),
        if (error != null)
          CpFieldError(error!, key: const Key('budget.expense.split.error')),
        Wrap(
          spacing: cp.space.sm,
          runSpacing: cp.space.sm,
          children: [
            CpButton.secondary(
              key: const Key('budget.expense.split.choose'),
              label: chooseLabel,
              icon: CpIcons.members,
              onPressed: onChoose,
            ),
            if (everyoneLabel != null)
              CpButton.text(
                key: const Key('budget.expense.split.everyone'),
                label: everyoneLabel!,
                onPressed: onEveryone,
              ),
          ],
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.receipt,
    required this.onPick,
    required this.onClear,
  });

  final PickedImage? receipt;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.budget;
    final r = receipt;
    if (r == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: CpButton.secondary(
          key: const Key('budget.expense.receipt.add'),
          label: s.addReceipt,
          icon: CpIcons.camera,
          onPressed: onPick,
        ),
      );
    }

    final side = cp.sizes.iconTile + cp.space.lg;
    return Row(
      key: const Key('budget.expense.receipt.preview'),
      spacing: cp.space.md,
      children: [
        ClipRRect(
          borderRadius: cp.radii.sm,
          child: Image.memory(
            r.bytes,
            width: side,
            height: side,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => SizedBox.square(
              dimension: side,
              child: ColoredBox(
                color: cp.colors.fill,
                child: Icon(CpIcons.imageBroken, color: cp.colors.textMuted),
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            s.receiptAttached,
            style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
          ),
        ),
        IconButton(
          key: const Key('budget.expense.receipt.clear'),
          tooltip: s.removeReceipt,
          onPressed: onClear,
          icon: Icon(
            CpIcons.actionClose,
            size: cp.sizes.iconMd,
            color: cp.colors.textMuted,
          ),
        ),
      ],
    );
  }
}
