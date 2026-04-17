import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/license_backend_service.dart';
import '../utils/page_routes.dart';
import 'claim_gift_screen.dart';
import 'gift_license_wizard.dart';
import 'license_verification_screen.dart';

/// The full-featured License Account management screen.
///
/// Lets users view their licenses, initiate/cancel license transfers (gifts),
/// claim incoming gifts, verify their email, and change their password.
class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger an account sync when the screen opens if we have credentials.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = context.read<LicenseBackendService>();
      if (svc.canManageAccount) {
        svc.syncAccount();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<LicenseBackendService>();

    // If the user is not signed in at all, ask them to verify their license
    // first (which also caches the password).
    if (!svc.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('License Account')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.manage_accounts_outlined, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Sign in to manage your Vetviona license account.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Verify License'),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    fadeRoute(
                      builder: (_) => const LicenseVerificationScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If signed in but password not in memory (app was restarted), show a
    // compact re-auth form rather than the full page.
    if (!svc.canManageAccount) {
      return Scaffold(
        appBar: AppBar(title: const Text('License Account')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _ReAuthCard(accountEmail: svc.accountEmail!),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('License Account'),
        actions: [
          if (svc.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Refresh',
              onPressed: () => svc.syncAccount(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: svc.syncAccount,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (svc.errorMessage != null) ...[
              _ErrorBanner(message: svc.errorMessage!),
              const SizedBox(height: 8),
            ],

            // ── Account header ─────────────────────────────────────────
            _AccountSection(svc: svc),
            const SizedBox(height: 12),

            // ── Email verification ─────────────────────────────────────
            if (!svc.emailVerified) ...[
              _EmailVerificationSection(svc: svc),
              const SizedBox(height: 12),
            ],

            // ── My Licenses ────────────────────────────────────────────
            _LicensesSection(svc: svc),
            const SizedBox(height: 12),

            // ── Outgoing gifts ─────────────────────────────────────────
            if (svc.outgoingGifts.isNotEmpty) ...[
              _OutgoingGiftsSection(svc: svc),
              const SizedBox(height: 12),
            ],

            // ── Incoming gifts ─────────────────────────────────────────
            if (svc.incomingGifts.isNotEmpty) ...[
              _IncomingGiftsSection(svc: svc),
              const SizedBox(height: 12),
            ],

            // ── Claim by token ─────────────────────────────────────────
            _ClaimSection(svc: svc),
            const SizedBox(height: 12),

            // ── Change password ────────────────────────────────────────
            _ChangePasswordSection(svc: svc),
            const SizedBox(height: 12),

            // ── Sign out ───────────────────────────────────────────────
            _SignOutSection(svc: svc),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Re-auth card ──────────────────────────────────────────────────────────────

class _ReAuthCard extends StatefulWidget {
  final String accountEmail;
  const _ReAuthCard({required this.accountEmail});

  @override
  State<_ReAuthCard> createState() => _ReAuthCardState();
}

class _ReAuthCardState extends State<_ReAuthCard> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<LicenseBackendService>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 12),
              Text(
                'Re-enter your password',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.accountEmail,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Password is required.' : null,
              ),
              if (svc.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  svc.errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: svc.isLoading ? null : _submit,
                child: svc.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<LicenseBackendService>().verifyLicense(
      email: context.read<LicenseBackendService>().accountEmail!,
      password: _passwordCtrl.text,
    );
  }
}

// ── Section widgets ───────────────────────────────────────────────────────────

class _AccountSection extends StatelessWidget {
  final LicenseBackendService svc;
  const _AccountSection({required this.svc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SectionCard(
      icon: Icons.manage_accounts_outlined,
      title: 'Account',
      children: [
        Row(
          children: [
            Icon(Icons.alternate_email, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                svc.accountEmail ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            svc.emailVerified
                ? _StatusChip(
                    label: 'Email verified',
                    color: Colors.green,
                    icon: Icons.verified_outlined,
                  )
                : _StatusChip(
                    label: 'Unverified',
                    color: cs.error,
                    icon: Icons.warning_amber_outlined,
                  ),
          ],
        ),
      ],
    );
  }
}

class _EmailVerificationSection extends StatefulWidget {
  final LicenseBackendService svc;
  const _EmailVerificationSection({required this.svc});

  @override
  State<_EmailVerificationSection> createState() =>
      _EmailVerificationSectionState();
}

class _EmailVerificationSectionState extends State<_EmailVerificationSection> {
  final _tokenCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 18,
                  color: cs.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Verify your email',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Email verification is required to transfer or gift licenses. '
              'Check your inbox for a verification code.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tokenCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                      isDense: true,
                    ),
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: widget.svc.isLoading
                      ? null
                      : () async {
                          if (_tokenCtrl.text.trim().isEmpty) return;
                          final ok = await widget.svc.verifyEmail(
                            token: _tokenCtrl.text.trim(),
                          );
                          if (ok && mounted) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Email verified!')),
                            );
                          }
                        },
                  child: const Text('Verify'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.send_outlined, size: 16),
              label: Text(_sent ? 'Code sent!' : 'Resend verification email'),
              onPressed: widget.svc.isLoading
                  ? null
                  : () async {
                      final ok = await widget.svc.resendVerification();
                      if (ok && mounted) {
                        setState(() => _sent = true);
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Verification email sent.'),
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _LicensesSection extends StatelessWidget {
  final LicenseBackendService svc;
  const _LicensesSection({required this.svc});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.verified_user_outlined,
      title: 'My Licenses',
      children: [
        _LicenseTile(
          svc: svc,
          licenseType: 'apple',
          label: 'Apple (iOS)',
          icon: Icons.phone_iphone_outlined,
          status: svc.appleLicenseStatus,
        ),
        const Divider(height: 20),
        _LicenseTile(
          svc: svc,
          licenseType: 'android',
          label: 'Android',
          icon: Icons.android_outlined,
          status: svc.androidLicenseStatus,
        ),
        const Divider(height: 20),
        _LicenseTile(
          svc: svc,
          licenseType: 'desktop',
          label: 'Desktop',
          icon: Icons.desktop_windows_outlined,
          status: svc.desktopLicenseStatus,
        ),
      ],
    );
  }
}

class _LicenseTile extends StatelessWidget {
  final LicenseBackendService svc;
  final String licenseType;
  final String label;
  final IconData icon;
  final String status; // 'active' | 'gifted_out' | 'none'

  const _LicenseTile({
    required this.svc,
    required this.licenseType,
    required this.label,
    required this.icon,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusLabel = 'Active';
      case 'gifted_out':
        statusColor = cs.tertiary;
        statusLabel = 'Transfer pending';
      default:
        statusColor = cs.onSurfaceVariant;
        statusLabel = 'Not owned';
    }

    return Row(
      children: [
        Icon(icon, size: 22, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              _StatusChip(
                label: statusLabel,
                color: statusColor,
                icon: status == 'active'
                    ? Icons.check_circle_outline
                    : status == 'gifted_out'
                    ? Icons.swap_horiz_outlined
                    : Icons.cancel_outlined,
              ),
            ],
          ),
        ),
        if (status == 'active')
          TextButton.icon(
            icon: const Icon(Icons.card_giftcard_outlined, size: 16),
            label: const Text('Gift'),
            onPressed: svc.emailVerified
                ? () => Navigator.push(
                    context,
                    fadeSlideRoute(
                      builder: (_) =>
                          GiftLicenseWizard(preselectedType: licenseType),
                    ),
                  )
                : () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Verify your email first to transfer licenses.',
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}

class _OutgoingGiftsSection extends StatelessWidget {
  final LicenseBackendService svc;
  const _OutgoingGiftsSection({required this.svc});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.outbox_outlined,
      title: 'Outgoing Transfers',
      children: [
        for (final gift in svc.outgoingGifts) ...[
          _OutgoingGiftTile(svc: svc, gift: gift),
          if (gift != svc.outgoingGifts.last) const Divider(height: 20),
        ],
      ],
    );
  }
}

class _OutgoingGiftTile extends StatelessWidget {
  final LicenseBackendService svc;
  final LicensePendingGift gift;
  const _OutgoingGiftTile({required this.svc, required this.gift});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expires = _formatExpiry(gift.expiresAt);
    return Row(
      children: [
        Icon(Icons.swap_horiz_outlined, color: cs.tertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _licenseLabel(gift.licenseType),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '→ ${gift.toEmail ?? ''}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              Text(
                'Expires $expires',
                style: TextStyle(fontSize: 11, color: cs.outlineVariant),
              ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: cs.error),
          onPressed: svc.isLoading
              ? null
              : () async {
                  final ok = await svc.cancelGift(giftId: gift.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Transfer cancelled — license returned to your account.'
                              : svc.errorMessage ?? 'Cancel failed.',
                        ),
                      ),
                    );
                  }
                },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _IncomingGiftsSection extends StatelessWidget {
  final LicenseBackendService svc;
  const _IncomingGiftsSection({required this.svc});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.move_to_inbox_outlined,
      title: 'Incoming Gifts',
      children: [
        for (final gift in svc.incomingGifts) ...[
          _IncomingGiftTile(svc: svc, gift: gift),
          if (gift != svc.incomingGifts.last) const Divider(height: 20),
        ],
      ],
    );
  }
}

class _IncomingGiftTile extends StatelessWidget {
  final LicenseBackendService svc;
  final LicensePendingGift gift;
  const _IncomingGiftTile({required this.svc, required this.gift});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expires = _formatExpiry(gift.expiresAt);
    return Row(
      children: [
        Icon(Icons.card_giftcard_outlined, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _licenseLabel(gift.licenseType),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'From ${gift.fromEmail ?? ''}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              Text(
                'Expires $expires',
                style: TextStyle(fontSize: 11, color: cs.outlineVariant),
              ),
            ],
          ),
        ),
        FilledButton(
          onPressed: svc.isLoading
              ? null
              : () async {
                  final ok = await svc.claimGift(giftId: gift.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? '${_licenseLabel(gift.licenseType)} license claimed!'
                              : svc.errorMessage ?? 'Claim failed.',
                        ),
                      ),
                    );
                  }
                },
          child: const Text('Claim'),
        ),
      ],
    );
  }
}

class _ClaimSection extends StatelessWidget {
  final LicenseBackendService svc;
  const _ClaimSection({required this.svc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SectionCard(
      icon: Icons.redeem_outlined,
      title: 'Claim a License Gift',
      children: [
        Text(
          'Have a claim token from a gift email or a voucher code? '
          'Tap below for guided steps.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.redeem_outlined, size: 18),
          label: const Text('Claim a License Gift'),
          onPressed: () => Navigator.push(
            context,
            fadeSlideRoute(builder: (_) => const ClaimGiftScreen()),
          ),
        ),
      ],
    );
  }
}

class _ChangePasswordSection extends StatefulWidget {
  final LicenseBackendService svc;
  const _ChangePasswordSection({required this.svc});

  @override
  State<_ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<_ChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.lock_reset_outlined,
      title: 'Change Password',
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.expand_more,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Update password'),
            children: [
              const SizedBox(height: 8),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PasswordField(
                      controller: _currentCtrl,
                      label: 'Current password',
                      obscure: _obscureCurrent,
                      onToggle: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required.' : null,
                    ),
                    const SizedBox(height: 10),
                    _PasswordField(
                      controller: _newCtrl,
                      label: 'New password',
                      obscure: _obscureNew,
                      onToggle: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required.';
                        if (v.length < 8) return 'At least 8 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _PasswordField(
                      controller: _confirmCtrl,
                      label: 'Confirm new password',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (v) {
                        if (v != _newCtrl.text) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: widget.svc.isLoading ? null : _submit,
                      child: const Text('Change Password'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await widget.svc.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.svc.errorMessage ?? 'Password change failed.'),
        ),
      );
    }
  }
}

class _SignOutSection extends StatelessWidget {
  final LicenseBackendService svc;
  const _SignOutSection({required this.svc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SectionCard(
      icon: Icons.logout_outlined,
      title: 'Sign Out',
      iconColor: cs.error,
      titleColor: cs.error,
      children: [
        Text(
          'Remove your license credentials from this device. '
          'You will need to sign in again to use paid features.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: Icon(Icons.logout, color: cs.error),
          label: Text('Sign Out', style: TextStyle(color: cs.error)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: cs.error),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog.adaptive(
                title: const Text('Sign Out'),
                content: const Text(
                  'This will remove your license from this device. '
                  'Your license will still be active on the server — '
                  'sign in again to restore access.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: cs.error),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await svc.signOut();
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        isDense: true,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      validator: validator,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color? iconColor;
  final Color? titleColor;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? cs.primary;
    final effectiveTitleColor = titleColor ?? cs.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: effectiveIconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: effectiveTitleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Utility functions ─────────────────────────────────────────────────────────

String _licenseLabel(String type) {
  switch (type) {
    case 'apple':
      return 'Apple (iOS)';
    case 'android':
      return 'Android';
    case 'desktop':
      return 'Desktop';
    default:
      return type;
  }
}

String _formatExpiry(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inHours < 1) return 'soon';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return 'in ${diff.inDays}d';
  } catch (_) {
    return iso;
  }
}
