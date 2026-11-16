import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onAuthenticated});

  final ApiClient api;
  final void Function(Map<String, dynamic> session) onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController(text: 'meera@acmetraders.test');
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.9),
            radius: 1.5,
            colors: [Color(0xFF10243C), SalusColors.background],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 820;
                      final brand = _brandPanel(context);
                      final form = _loginPanel(context);
                      if (!wide) {
                        return Column(
                          children: [brand, const SizedBox(height: 24), form],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 6, child: brand),
                          const SizedBox(width: 48),
                          Expanded(flex: 5, child: form),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: SalusColors.mint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SalusColors.mint.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.shield_outlined, color: SalusColors.mint, size: 26),
            ),
            const SizedBox(width: 14),
            const Text(
              'SALUS',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text(
          'Your data does not disappear.\nIt leaves a trail.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 38,
                height: 1.15,
                letterSpacing: -1.0,
              ),
        ),
        const SizedBox(height: 20),
        const Text(
          'A data identity and investigation desk for small businesses in India. '
          'See what left, who moved it, and what to do next.',
          style: TextStyle(color: SalusColors.muted, fontSize: 15, height: 1.55),
        ),
        const SizedBox(height: 34),
        const _Point(
          icon: Icons.fingerprint,
          title: 'Cell level Data DNA',
          body: 'Finds partial copies after rename, format change, deleted columns and dropped rows.',
        ),
        const _Point(
          icon: Icons.account_tree_outlined,
          title: 'Lineage from real records',
          body: 'Every edge points to a logged event or a stored match. Nothing is invented.',
        ),
        const _Point(
          icon: Icons.psychology_outlined,
          title: 'Explainable risk and next steps',
          body: 'A deterministic score, a behaviour model, and a plain language incident report.',
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            SalusBadge(label: 'Aadhaar with Verhoeff', color: SalusColors.mint),
            SalusBadge(label: 'PAN, GSTIN, UPI', color: SalusColors.blue),
            SalusBadge(label: 'Synthetic data only', color: SalusColors.violet),
          ],
        ),
      ],
    );
  }

  Widget _loginPanel(BuildContext context) {
    return SalusCard(
      padding: const EdgeInsets.all(28),
      borderColor: SalusColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Command center access',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SalusColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline, size: 18, color: SalusColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Demo login for the Acme Traders workspace.',
            style: TextStyle(color: SalusColors.muted),
          ),
          const SizedBox(height: 24),
          const Text(
            'WORK EMAIL',
            style: TextStyle(
              color: SalusColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _busy ? null : _login(),
            decoration: const InputDecoration(
              hintText: 'you@company.test',
              prefixIcon: Icon(Icons.alternate_email, size: 18),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _login(),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: SalusColors.background),
                  )
                : const Icon(Icons.arrow_forward, size: 18),
            label: Text(_busy ? 'Opening' : 'Enter command center'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _login(seedFirst: true),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Initialize demo data'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SalusColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SalusColors.red.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 16, color: SalusColors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: SalusColors.red, fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SalusColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: SalusColors.muted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo build. All records are synthetic. Simulated activity is labelled in the UI.',
                    style: TextStyle(color: SalusColors.muted, fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: SalusColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: SalusColors.mint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(color: SalusColors.muted, fontSize: 12.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SalusColors.mint.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const spacing = 56.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
