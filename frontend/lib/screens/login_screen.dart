import 'package:flutter/material.dart';

import '../api.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });

  final ApiClient api;
  final void Function(Map<String, dynamic> session) onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController(
    text: 'meera@acmetraders.test',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _login({bool seedFirst = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (seedFirst) {
        await widget.api.seedDemo();
      }
      final session = await widget.api.login(_email.text.trim());
      if (!mounted) return;
      widget.onAuthenticated(session);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SalusColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: _brandPanel(context, wide: true)),
                Expanded(flex: 5, child: _formPanel(context)),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _brandPanel(context, wide: false),
                _formPanel(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _brandPanel(BuildContext context, {required bool wide}) {
    return Container(
      decoration: BoxDecoration(
        color: SalusColors.primary,
        image: DecorationImage(
          image: const AssetImage('assets/photos/typing-laptop.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            SalusColors.primary.withValues(alpha: 0.9),
            BlendMode.srcOver,
          ),
        ),
      ),
      padding: EdgeInsets.all(wide ? 56 : 28),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: SalusColors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: SalusColors.ink.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        SalusIcons.shield,
                        color: SalusColors.ink,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SALUS',
                          style: TextStyle(
                            color: SalusColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.5,
                          ),
                        ),
                        Text(
                          'INVESTIGATION DESK',
                          style: TextStyle(
                            color: SalusColors.ink,
                            fontSize: 8,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: wide ? 56 : 32),
                const Text(
                  'SMALL BUSINESS DATA INVESTIGATION',
                  style: TextStyle(
                    color: SalusColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Open the investigation desk.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: SalusColors.ink,
                    fontSize: wide ? 44 : 32,
                    height: wide ? 50 / 44 : 38 / 32,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'See what left, who moved it, and what to do next. Built for Indian teams of 10 to 100 with no security staff.',
                  style: TextStyle(
                    color: SalusColors.ink.withValues(alpha: 0.78),
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                SizedBox(height: wide ? 40 : 28),
                _Point(
                  icon: SalusIcons.fingerprint,
                  title: 'Partial copies',
                  body: 'Cell level fingerprints survive renamed files, deleted columns, and dropped rows.',
                ),
                _Point(
                  icon: SalusIcons.sealCheck,
                  title: 'India PII',
                  body:
                      'Aadhaar, PAN, GSTIN, UPI, phone, and financial fields.',
                ),
                _Point(
                  icon: SalusIcons.tree,
                  title: 'Evidence trail',
                  body:
                      'Every edge points to a stored event or a stored match.',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: SalusColors.ink,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Synthetic demo. Simulated activity is labelled.',
                      style: TextStyle(
                        color: SalusColors.ink.withValues(alpha: 0.7),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formPanel(BuildContext context) {
    return Container(
      color: SalusColors.canvas,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SalusCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Command center access',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: SalusColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      SalusIcons.lock,
                      size: 17,
                      color: SalusColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Demo login for the Acme Traders workspace.',
                style: TextStyle(color: SalusColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'WORK EMAIL',
                style: TextStyle(
                  color: SalusColors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _busy ? null : _login(),
                decoration: const InputDecoration(
                  hintText: 'you@company.test',
                  prefixIcon: Icon(SalusIcons.at, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _busy ? null : () => _login(),
                icon: _busy
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SalusColors.onPrimary,
                        ),
                      )
                    : const Icon(SalusIcons.arrowRight, size: 17),
                label: Text(_busy ? 'Opening' : 'Enter command center'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _login(seedFirst: true),
                icon: const Icon(SalusIcons.sparkle, size: 15),
                label: const Text('Initialize demo data'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SalusColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: SalusColors.ink.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        SalusIcons.warningCircle,
                        size: 16,
                        color: SalusColors.ink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: SalusColors.ink,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text(
                'No password in this demo. All records are synthetic.',
                style: TextStyle(
                  color: SalusColors.muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: SalusColors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: SalusColors.ink.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(icon, size: 16, color: SalusColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: SalusColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      color: SalusColors.ink.withValues(alpha: 0.72),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
