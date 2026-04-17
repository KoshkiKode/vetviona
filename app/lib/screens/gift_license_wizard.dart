import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/license_backend_service.dart';

/// A full-screen, 4-step wizard for gifting or transferring a Vetviona
/// license to another person.
///
/// Steps:
///   1. Pick license type (skipped when [preselectedType] is provided)
///   2. Enter recipient email
///   3. Review & confirm (with warning)
///   4. Success — shows what the recipient must do
///
/// Usage:
/// ```dart
/// Navigator.push(context, fadeSlideRoute(builder: (_) =>
///   GiftLicenseWizard(preselectedType: 'desktop')));
/// ```
class GiftLicenseWizard extends StatefulWidget {
  /// When non-null the wizard starts at step 2 (skip the license picker).
  final String? preselectedType;

  const GiftLicenseWizard({super.key, this.preselectedType});

  @override
  State<GiftLicenseWizard> createState() => _GiftLicenseWizardState();
}

// ── Step indices ──────────────────────────────────────────────────────────────
const int _kPickLicense = 0;
const int _kEnterRecipient = 1;
const int _kReview = 2;
const int _kSuccess = 3;

class _GiftLicenseWizardState extends State<GiftLicenseWizard> {
  final PageController _pages = PageController();
  int _step = 0;

  String? _selectedType;
  final _emailCtrl = TextEditingController();
  final _emailKey = GlobalKey<FormState>();
  String? _claimToken; // returned by backend after successful initiate

  @override
  void initState() {
    super.initState();
    if (widget.preselectedType != null) {
      _selectedType = widget.preselectedType;
      _step = _kEnterRecipient;
      // Jump page immediately (no animation on first frame).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pages.jumpToPage(_kEnterRecipient);
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _back() {
    if (_step == _kEnterRecipient && widget.preselectedType != null) {
      Navigator.pop(context);
    } else if (_step > _kPickLicense) {
      _goTo(_step - 1);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: _step == _kSuccess
            ? const SizedBox.shrink()
            : BackButton(onPressed: _back),
        title: Text(_title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _WizardProgressBar(
            current: _step,
            total: 4,
            color: cs.primary,
          ),
        ),
      ),
      body: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _PickLicensePage(
            onSelect: (type) {
              setState(() => _selectedType = type);
              _goTo(_kEnterRecipient);
            },
          ),
          _EnterRecipientPage(
            emailCtrl: _emailCtrl,
            formKey: _emailKey,
            selectedType: _selectedType,
            onNext: () => _goTo(_kReview),
          ),
          _ReviewPage(
            selectedType: _selectedType,
            recipientEmail: _emailCtrl.text.trim(),
            onConfirm: _submit,
          ),
          _SuccessPage(
            recipientEmail: _emailCtrl.text.trim(),
            licenseType: _selectedType,
            claimToken: _claimToken,
            onDone: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String get _title => switch (_step) {
    _kPickLicense => 'Gift a License',
    _kEnterRecipient => 'Recipient',
    _kReview => 'Confirm Transfer',
    _ => 'Transfer Initiated',
  };

  Future<void> _submit() async {
    if (_selectedType == null) return;
    final email = _emailCtrl.text.trim();
    final svc = context.read<LicenseBackendService>();
    final ok = await svc.initiateGift(
      licenseType: _selectedType!,
      toEmail: email,
    );
    if (!mounted) return;
    if (ok) {
      // The backend returns the gift info inside the updated account sync,
      // but the devToken is only in EMAIL_DEV_MODE.  Check the outgoing gifts
      // list for the token that matches what we just created.
      _claimToken = svc.outgoingGifts
          .where((g) => g.toEmail == email && g.licenseType == _selectedType)
          .map(
            (g) => g.id,
          ) // show gift ID as a reference since token isn't surfaced
          .firstOrNull;
      _goTo(_kSuccess);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            svc.errorMessage ?? 'Transfer failed. Please try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

// ── Step 1: Pick license ──────────────────────────────────────────────────────

class _PickLicensePage extends StatelessWidget {
  final void Function(String) onSelect;
  const _PickLicensePage({required this.onSelect});

  static const _items = [
    (
      type: 'apple',
      label: 'Apple (iOS)',
      icon: Icons.phone_iphone_outlined,
      description: 'For iPhones and iPads running the Vetviona iOS app.',
    ),
    (
      type: 'android',
      label: 'Android',
      icon: Icons.android_outlined,
      description: 'For Android phones and tablets.',
    ),
    (
      type: 'desktop',
      label: 'Desktop',
      icon: Icons.desktop_windows_outlined,
      description: 'For Windows, macOS and Linux computers.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final svc = context.watch<LicenseBackendService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Which license do you want to gift?',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Only licenses you own and that are not already in a pending transfer can be gifted.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            for (final item in _items) ...[
              _LicenseOptionCard(
                item: item,
                status: _licenseStatus(svc, item.type),
                onTap: _licenseStatus(svc, item.type) == 'active'
                    ? () => onSelect(item.type)
                    : null,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  String _licenseStatus(LicenseBackendService svc, String type) {
    return switch (type) {
      'apple' => svc.appleLicenseStatus,
      'android' => svc.androidLicenseStatus,
      _ => svc.desktopLicenseStatus,
    };
  }
}

class _LicenseOptionCard extends StatelessWidget {
  final ({String type, String label, IconData icon, String description}) item;
  final String status;
  final VoidCallback? onTap;

  const _LicenseOptionCard({
    required this.item,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final available = status == 'active';
    final color = available ? cs.primary : cs.onSurfaceVariant;

    return Material(
      color: available
          ? cs.primaryContainer.withValues(alpha: 0.28)
          : cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: available ? null : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (available)
                Icon(Icons.chevron_right_outlined, color: cs.primary)
              else
                _StatusPill(status: status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      'gifted_out' => ('Pending', cs.tertiary),
      'none' => ('Not owned', cs.onSurfaceVariant),
      _ => (status, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Step 2: Enter recipient ───────────────────────────────────────────────────

class _EnterRecipientPage extends StatelessWidget {
  final TextEditingController emailCtrl;
  final GlobalKey<FormState> formKey;
  final String? selectedType;
  final VoidCallback onNext;

  const _EnterRecipientPage({
    required this.emailCtrl,
    required this.formKey,
    required this.selectedType,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedType != null) ...[
              _LicenseHeaderChip(licenseType: selectedType!),
              const SizedBox(height: 20),
            ],
            Text(
              "Who will receive this license?",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the email address of the person you want to gift this license to. '
              "If they don't have a Vetviona account yet, they'll be guided to create one and claim the license.",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Form(
              key: formKey,
              child: TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: "Recipient's email",
                  prefixIcon: Icon(Icons.alternate_email),
                  hintText: 'friend@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _next(context),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Email is required.';
                  if (!s.contains('@')) return 'Enter a valid email address.';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            // What happens info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'What happens next',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final (n, text) in [
                    (
                      1,
                      'The license is placed in escrow — you temporarily lose access.',
                    ),
                    (2, 'The recipient gets an email with a claim code.'),
                    (
                      3,
                      "If they're new to Vetviona, they create a free account first.",
                    ),
                    (4, 'They enter the code in Settings → License Account.'),
                    (
                      5,
                      "If they don't claim within 72 hours, the license returns to you.",
                    ),
                  ]) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$n',
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              text,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _next(context),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _next(BuildContext context) {
    if (formKey.currentState!.validate()) onNext();
  }
}

// ── Step 3: Review ────────────────────────────────────────────────────────────

class _ReviewPage extends StatelessWidget {
  final String? selectedType;
  final String recipientEmail;
  final Future<void> Function() onConfirm;

  const _ReviewPage({
    required this.selectedType,
    required this.recipientEmail,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final svc = context.watch<LicenseBackendService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review your transfer',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ReviewRow(
                      icon: Icons.verified_user_outlined,
                      label: 'License',
                      value: _licenseLabel(selectedType ?? ''),
                    ),
                    const Divider(height: 20),
                    _ReviewRow(
                      icon: Icons.alternate_email,
                      label: 'Recipient',
                      value: recipientEmail,
                    ),
                    const Divider(height: 20),
                    _ReviewRow(
                      icon: Icons.access_time_outlined,
                      label: 'Offer expires',
                      value: 'After 72 hours',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Warning
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_outlined, size: 18, color: cs.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your ${_licenseLabel(selectedType ?? '')} license will be suspended '
                      "while this transfer is pending. You'll regain access if the recipient "
                      "doesn't claim it within 72 hours, or if you cancel the transfer.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: svc.isLoading ? null : onConfirm,
                icon: svc.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Send Transfer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── Step 4: Success ───────────────────────────────────────────────────────────

class _SuccessPage extends StatelessWidget {
  final String recipientEmail;
  final String? licenseType;
  final String? claimToken;
  final VoidCallback onDone;

  const _SuccessPage({
    required this.recipientEmail,
    required this.licenseType,
    required this.claimToken,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 52,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Transfer initiated!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A claim email has been sent to $recipientEmail.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            // Recipient instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.forward_to_inbox_outlined,
                          size: 16,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tell $recipientEmail to:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final (n, text) in [
                      (1, 'Check their inbox for an email from Vetviona.'),
                      (2, 'Download the Vetviona app.'),
                      (3, 'Open Settings → License Account.'),
                      (
                        4,
                        'Tap "Claim a License Gift" and enter the code from the email.',
                      ),
                    ]) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CircleNumber(n: n),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                text,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Info about auto-return
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.undo_outlined,
                    size: 15,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The license will automatically return to your account in 72 hours if not claimed. '
                      'You can also cancel the transfer at any time from Settings → License Account.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _LicenseHeaderChip extends StatelessWidget {
  final String licenseType;
  const _LicenseHeaderChip({required this.licenseType});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = switch (licenseType) {
      'apple' => Icons.phone_iphone_outlined,
      'android' => Icons.android_outlined,
      _ => Icons.desktop_windows_outlined,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          _licenseLabel(licenseType),
          style: TextStyle(
            fontSize: 13,
            color: cs.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CircleNumber extends StatelessWidget {
  final int n;
  const _CircleNumber({required this.n});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$n',
        style: TextStyle(
          fontSize: 11,
          color: cs.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _WizardProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final Color color;
  const _WizardProgressBar({
    required this.current,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: (current + 1) / total,
      backgroundColor: color.withValues(alpha: 0.15),
      color: color,
      minHeight: 3,
    );
  }
}

String _licenseLabel(String type) => switch (type) {
  'apple' => 'Apple (iOS)',
  'android' => 'Android',
  'desktop' => 'Desktop',
  _ => type,
};
