import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/license_backend_service.dart';
import '../utils/page_routes.dart';
import 'license_verification_screen.dart';

/// A guided, step-aware screen for recipients who received a license gift.
///
/// Shows three numbered steps explaining the process, then a form to enter
/// the claim token.  If the user is not yet signed in the claim form is locked
/// and they are invited to verify/sign in first.
class ClaimGiftScreen extends StatefulWidget {
  /// Pre-fill the token field (e.g. parsed from a deep-link).
  final String? initialToken;

  const ClaimGiftScreen({super.key, this.initialToken});

  @override
  State<ClaimGiftScreen> createState() => _ClaimGiftScreenState();
}

class _ClaimGiftScreenState extends State<ClaimGiftScreen> {
  final _tokenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) {
      _tokenCtrl.text = widget.initialToken!.toUpperCase();
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<LicenseBackendService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Claim a License Gift')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.redeem_outlined,
                    size: 48,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You received a license!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Follow the steps below to add it to your Vetviona account.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 28),

              // ── Steps ─────────────────────────────────────────────────────
              _StepCard(
                number: 1,
                title: 'Download the Vetviona app',
                subtitle:
                    'Available on iOS, Android, Windows, macOS and Linux.',
                isDone: true, // They're already here
                icon: Icons.download_outlined,
              ),
              const SizedBox(height: 10),
              _StepCard(
                number: 2,
                title: svc.isSignedIn
                    ? 'Signed in as ${svc.accountEmail}'
                    : 'Sign in or create a Vetviona license account',
                subtitle: svc.isSignedIn
                    ? 'You are ready to claim.'
                    : 'Use the same email address that received the gift, then come back here.',
                isDone: svc.isSignedIn,
                icon: Icons.account_circle_outlined,
                action: svc.isSignedIn
                    ? null
                    : FilledButton.tonalIcon(
                        icon: const Icon(Icons.login_outlined, size: 16),
                        label: const Text('Sign In / Verify License'),
                        onPressed: () => Navigator.push(
                          context,
                          fadeSlideRoute(
                            builder: (_) => const LicenseVerificationScreen(),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              _StepCard(
                number: 3,
                title: 'Enter your claim token',
                subtitle:
                    'Find the code in the gift email (8 characters, e.g. AB12CD34).',
                isDone: false,
                icon: Icons.key_outlined,
                isActive: svc.isSignedIn,
              ),

              const SizedBox(height: 20),

              // ── Claim form ────────────────────────────────────────────────
              AnimatedOpacity(
                opacity: svc.isSignedIn ? 1.0 : 0.45,
                duration: const Duration(milliseconds: 250),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Claim token',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _tokenCtrl,
                          enabled: svc.isSignedIn,
                          decoration: InputDecoration(
                            labelText: 'e.g. AB12CD34',
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: _tokenCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () =>
                                        setState(() => _tokenCtrl.clear()),
                                  )
                                : null,
                          ),
                          autocorrect: false,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => setState(() {}),
                        ),
                        if (svc.errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            svc.errorMessage!,
                            style: TextStyle(color: cs.error, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: svc.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.redeem_outlined),
                          label: const Text('Claim License'),
                          onPressed: (!svc.isSignedIn || svc.isLoading)
                              ? null
                              : _claim,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── FAQ ───────────────────────────────────────────────────────
              _FaqSection(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claim() async {
    final tok = _tokenCtrl.text.trim();
    if (tok.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a claim token.')),
      );
      return;
    }
    final svc = context.read<LicenseBackendService>();
    final ok = await svc.claimGift(token: tok);
    if (!mounted) return;
    if (ok) {
      // Navigate back to account management (or back to wherever we came from).
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 License claimed and added to your account!'),
        ),
      );
    }
  }
}

// ── Step card ─────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final bool isDone;
  final bool isActive;
  final IconData icon;
  final Widget? action;

  const _StepCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.icon,
    this.isActive = true,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color tintColor;
    final IconData displayIcon;
    if (isDone) {
      tintColor = Colors.green;
      displayIcon = Icons.check_circle_outline;
    } else if (isActive) {
      tintColor = cs.primary;
      displayIcon = icon;
    } else {
      tintColor = cs.onSurfaceVariant;
      displayIcon = icon;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tintColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isDone
                  ? Icon(displayIcon, size: 18, color: tintColor)
                  : Text(
                      '$number',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tintColor,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDone ? Colors.green : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (action != null) ...[const SizedBox(height: 10), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAQ section ───────────────────────────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Card(
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(Icons.help_outline, size: 18, color: cs.primary),
          title: const Text('Frequently asked questions'),
          children: [
            for (final faq in _faqs)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                title: Text(
                  faq.$1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    faq.$2,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  static const _faqs = [
    (
      "What if I don't have a Vetviona account?",
      'Ask the sender to gift the license to your email address. '
          'When you register a Vetviona license account with that same email, '
          'the license is automatically applied.',
    ),
    (
      'My claim token expired — what now?',
      'Contact the person who sent the gift. They can cancel the expired transfer '
          '(the license returns to them automatically after 72 hours) and initiate a new one.',
    ),
    (
      'I entered the token but got an error.',
      "Make sure you're signed in with the same email the gift was sent to, "
          'and that the token is entered exactly as shown (case-insensitive). '
          'Open voucher codes can be claimed by any account.',
    ),
    (
      'Can I gift a license I just received?',
      'Yes — once you claim a license it is yours. '
          'You can gift it again from Settings → License Account.',
    ),
  ];
}
