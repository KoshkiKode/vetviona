import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/page_routes.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

// ── EULA text ─────────────────────────────────────────────────────────────────

/// Full End User License Agreement text, embedded inline so it is always
/// available even when the device has no internet connection.
const String eulaText = '''
END USER LICENSE AGREEMENT

Vetviona — Private Family History App
Copyright © KoshkiKode. All rights reserved.

Last updated: 2026

PLEASE READ THIS END USER LICENSE AGREEMENT ("AGREEMENT" OR "EULA")
CAREFULLY BEFORE INSTALLING OR USING VETVIONA. BY TAPPING "ACCEPT" OR BY
INSTALLING, COPYING, OR OTHERWISE USING THE SOFTWARE, YOU AGREE TO BE BOUND
BY THE TERMS OF THIS AGREEMENT. IF YOU DO NOT AGREE, DO NOT INSTALL OR USE
VETVIONA.

──────────────────────────────────────────────────────────────────────────────
1. OWNERSHIP AND INTELLECTUAL PROPERTY
──────────────────────────────────────────────────────────────────────────────

Vetviona (the "Software") and all copies thereof are proprietary to
KoshkiKode ("KoshkiKode", "we", "our", "us") and title thereto remains in
KoshkiKode. All rights in the Software, including but not limited to
copyrights, patents, trade secrets, trademarks, and any other intellectual
property rights, are reserved exclusively by KoshkiKode.

"Vetviona" and "RootLoop" are trademarks of KoshkiKode. No right or license
is granted to use any KoshkiKode trade name, trademark, service mark, or
product name, except as explicitly set out in this Agreement.

──────────────────────────────────────────────────────────────────────────────
2. GRANT OF LICENSE
──────────────────────────────────────────────────────────────────────────────

Subject to the terms of this Agreement, KoshkiKode grants you a limited,
non-exclusive, non-transferable, non-sublicensable, revocable license to:

  (a) Install and use one (1) copy of the Software on devices that you own or
      control, solely for your personal, non-commercial genealogical research;
  (b) Make one (1) archival backup copy of the Software, provided that the
      backup copy contains all copyright and other proprietary notices
      contained in the original.

Paid tier licenses may permit additional device installations as described in
the applicable license documentation at the time of purchase.

This license does not constitute a sale of the Software or any copy thereof.

──────────────────────────────────────────────────────────────────────────────
3. RESTRICTIONS
──────────────────────────────────────────────────────────────────────────────

You may NOT:

  (a) Copy, modify, translate, adapt, or create derivative works based upon
      the Software without the prior written consent of KoshkiKode;
  (b) Reverse engineer, disassemble, decompile, decode, or otherwise attempt
      to derive or gain access to the source code of the Software;
  (c) Sell, rent, lease, lend, sublicense, distribute, transfer, or otherwise
      make the Software or any license granted herein available to any third
      party;
  (d) Remove, alter, or obscure any copyright notice, trademark, or other
      proprietary rights notice on or in the Software;
  (e) Use the Software for any unlawful purpose or in violation of any
      applicable law or regulation;
  (f) Use the Software to infringe the intellectual property, privacy, or
      other rights of any third party.

──────────────────────────────────────────────────────────────────────────────
4. YOUR DATA AND PRIVACY
──────────────────────────────────────────────────────────────────────────────

Vetviona is designed as a local-first, offline-capable application. All
genealogical data you enter is stored in a private SQLite database on your
own device. KoshkiKode does not have access to and does not collect your
family tree data.

Certain optional features (e.g., online license verification, WikiTree
integration, GeoNames place lookup) may require an internet connection and
may involve communication with third-party services subject to their own
privacy policies. You use such features at your own discretion.

For the full Privacy Policy, visit: https://vetviona.koshkikode.com/privacy

──────────────────────────────────────────────────────────────────────────────
5. PAID TIERS AND LICENSE VERIFICATION
──────────────────────────────────────────────────────────────────────────────

The "Mobile Free" tier is provided at no charge with limited functionality.
Upgrading to "Mobile Paid" or "Desktop Pro" requires either an in-app
purchase through the applicable platform store (Apple App Store / Google Play)
or purchase and activation of a license key through KoshkiKode's licensing
system.

License verification is performed once per device installation over an
internet connection. You must not circumvent, disable, or interfere with the
license-verification mechanism. Licenses are non-refundable except as required
by applicable consumer law.

──────────────────────────────────────────────────────────────────────────────
6. UPDATES AND SUPPORT
──────────────────────────────────────────────────────────────────────────────

KoshkiKode may, but is not obligated to, provide updates, patches, bug fixes,
or new features. Any such updates will be subject to this Agreement unless
accompanied by a separate license agreement. KoshkiKode has no obligation to
provide technical support under this Agreement.

──────────────────────────────────────────────────────────────────────────────
7. OPEN-SOURCE COMPONENTS
──────────────────────────────────────────────────────────────────────────────

The Software incorporates open-source components that are distributed under
their respective licenses. A list of open-source components and their licenses
is available within the app under Settings → Open Source Licenses. This
Agreement does not limit any rights granted to you by those open-source
licenses.

──────────────────────────────────────────────────────────────────────────────
8. DISCLAIMER OF WARRANTIES
──────────────────────────────────────────────────────────────────────────────

THE SOFTWARE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTY OF ANY
KIND. TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, KOSHKIKODE EXPRESSLY
DISCLAIMS ALL WARRANTIES, EXPRESS, IMPLIED, STATUTORY, OR OTHERWISE,
INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT.

KOSHKIKODE DOES NOT WARRANT THAT THE SOFTWARE WILL BE UNINTERRUPTED, ERROR-
FREE, OR FREE OF VIRUSES OR OTHER HARMFUL COMPONENTS. YOU ASSUME ALL RISK
ARISING FROM YOUR USE OF THE SOFTWARE.

──────────────────────────────────────────────────────────────────────────────
9. LIMITATION OF LIABILITY
──────────────────────────────────────────────────────────────────────────────

TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL
KOSHKIKODE OR ITS DIRECTORS, EMPLOYEES, AGENTS, OR LICENSORS BE LIABLE FOR
ANY INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, CONSEQUENTIAL, OR PUNITIVE
DAMAGES (INCLUDING LOSS OF PROFITS, DATA, OR GOODWILL) ARISING OUT OF OR IN
CONNECTION WITH THIS AGREEMENT OR THE USE OR INABILITY TO USE THE SOFTWARE,
EVEN IF KOSHKIKODE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

KOSHKIKODE'S TOTAL LIABILITY FOR ANY CLAIM ARISING UNDER OR RELATING TO THIS
AGREEMENT SHALL NOT EXCEED THE AMOUNT YOU PAID FOR THE LICENSE TO USE THE
SOFTWARE IN THE TWELVE (12) MONTHS PRECEDING THE CLAIM.

──────────────────────────────────────────────────────────────────────────────
10. TERMINATION
──────────────────────────────────────────────────────────────────────────────

This Agreement is effective until terminated. KoshkiKode may terminate this
Agreement immediately and without notice if you breach any provision hereof.
Upon termination you must destroy all copies of the Software in your possession
or control. Sections 1, 3, 8, 9, 10, 11, and 12 survive termination.

──────────────────────────────────────────────────────────────────────────────
11. GOVERNING LAW AND DISPUTE RESOLUTION
──────────────────────────────────────────────────────────────────────────────

This Agreement is governed by and construed in accordance with applicable law.
Any dispute arising out of or in connection with this Agreement shall be
subject to the exclusive jurisdiction of the competent courts of KoshkiKode's
place of business. If any provision of this Agreement is held invalid or
unenforceable, that provision shall be modified to the minimum extent necessary
and the remaining provisions shall continue in full force and effect.

──────────────────────────────────────────────────────────────────────────────
12. GENERAL
──────────────────────────────────────────────────────────────────────────────

This Agreement constitutes the entire agreement between you and KoshkiKode
with respect to the Software and supersedes all prior and contemporaneous
understandings, agreements, representations, and warranties. KoshkiKode's
failure to exercise any right or remedy under this Agreement shall not
constitute a waiver of that right or remedy. You may not assign this Agreement
or any rights or obligations hereunder without KoshkiKode's prior written
consent. KoshkiKode may assign this Agreement freely.

For licensing inquiries or legal notices, contact:
  KoshkiKode — https://vetviona.koshkikode.com
''';

// ── Preference key ────────────────────────────────────────────────────────────

/// SharedPreferences key that records whether the user has accepted the EULA.
const String eulaAcceptedKey = 'eulaAccepted';

// ── EulaScreen ────────────────────────────────────────────────────────────────

/// Displays the End User License Agreement.
///
/// Two modes:
///
///  * **First-launch mode** (`readOnly: false`, the default): shown at startup
///    before onboarding.  The user must scroll to the bottom and tap "Accept"
///    before the app continues.  Tapping "Decline" exits the app.
///
///  * **Read-only mode** (`readOnly: true`): shown from Settings → Privacy &
///    Legal.  A single "Close" / back button is shown; no acceptance is needed.
class EulaScreen extends StatefulWidget {
  const EulaScreen({super.key, this.readOnly = false});

  /// When `true` the screen is informational only (no Accept / Decline buttons).
  final bool readOnly;

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  final ScrollController _scroll = ScrollController();
  bool _scrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    if (!widget.readOnly) {
      _scroll.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 64) {
      if (!_scrolledToBottom) {
        setState(() => _scrolledToBottom = true);
      }
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(eulaAcceptedKey, true);
    if (!mounted) return;

    // Navigate to the onboarding / home flow.
    final onboardingDone =
        prefs.getBool('onboardingDone') ?? false;

    Navigator.pushReplacement(
      context,
      fadeRoute(
        builder: (_) => onboardingDone
            ? const HomeScreen()
            : const OnboardingScreen(),
      ),
    );
  }

  Future<void> _decline() async {
    // On mobile, close the app. On desktop, just pop (license check will
    // redirect back here).
    if (!mounted) return;
    // Show a brief confirmation before acting.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline EULA?'),
        content: const Text(
          'You must accept the End User License Agreement to use Vetviona.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline & Exit'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // Pop back to whatever was before (OS will handle process lifecycle).
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('End User License Agreement'),
        // In read-only mode the normal back button is present.
        // In first-launch mode we suppress the back button so the user cannot
        // dismiss the EULA without making a choice.
        automaticallyImplyLeading: widget.readOnly,
      ),
      body: Column(
        children: [
          // ── EULA text ────────────────────────────────────────────────────
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: SelectableText(
                  eulaText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: colorScheme.onSurface,
                        height: 1.6,
                      ),
                ),
              ),
            ),
          ),
          // ── Action bar ───────────────────────────────────────────────────
          if (!widget.readOnly) ...[
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_scrolledToBottom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Scroll to read the full agreement',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    FilledButton(
                      onPressed: _scrolledToBottom ? _accept : null,
                      child: const Text('Accept'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _decline,
                      child: const Text('Decline'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
