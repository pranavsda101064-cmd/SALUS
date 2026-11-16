import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

class CommandCenterScreen extends StatefulWidget {
  const CommandCenterScreen({
    super.key,
    required this.api,
    required this.onOpenIncident,
    required this.onStartInvestigation,
    required this.session,
  });

  final ApiClient api;
  final void Function(String id, Map<String, dynamic>? bundle) onOpenIncident;
  final VoidCallback onStartInvestigation;
  final Map<String, dynamic> session;

  @override
  State<CommandCenterScreen> createState() => CommandCenterScreenState();
}

class CommandCenterScreenState extends State<CommandCenterScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _overview = {};
  Map<String, dynamic>? _latest;
  List<dynamic> _incidents = [];
  bool _simulating = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final overview = await widget.api.overview();
      final incidents = await widget.api.incidents();
      Map<String, dynamic>? latest;
      if (incidents.isNotEmpty) {
        final first = asMap(incidents.first);
        latest = await widget.api.incident(asString(first['incident_id']));
      }
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _incidents = incidents;
        _latest = latest;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _replay() async {
    setState(() => _simulating = true);
    try {
      await widget.api.runSimulator();
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Simulated download and external share replayed. Look for the SIMULATED labels.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(28),
        child: LoadingBox(label: 'Loading command center'),
      );
    }
    if (_error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ErrorBox(message: _error!, onRetry: load),
      );
    }

    final org = asMap(_overview['organization']);
    final latestIncident = _latest == null ? null : asMap(_latest!['incident']);
    final latestRisk = _latest == null ? null : asMap(_latest!['risk']);
    final latestMatch = _latest == null ? null : asMap(_latest!['match']);
    final riskFactors = latestRisk == null ? <String, dynamic>{} : asMap(latestRisk['factors']);
    final weights = latestRisk == null ? <String, dynamic>{} : asMap(latestRisk['weights']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            eyebrow: 'Command center',
            title: 'Good to see you, ${asString(asMap(widget.session['user'])['name'], 'owner')}',
            subtitle: '${asString(org['name'], 'Your workspace')} is being watched for data movement. '
                'Simulated activity is labelled everywhere.',
            actions: [
              OutlinedButton.icon(
                onPressed: _simulating ? null : _replay,
                icon: _simulating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_circle_outline, size: 17),
                label: Text(_simulating ? 'Replaying' : 'Replay simulated activity'),
              ),
              ElevatedButton.icon(
                onPressed: widget.onStartInvestigation,
                icon: const Icon(Icons.travel_explore, size: 17),
                label: const Text('Investigate a file'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _hero(context),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final tileWidth = width > 1100
                  ? (width - 54) / 4
                  : width > 700
                      ? (width - 36) / 3
                      : width;
              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: MetricCard(
                      label: 'Open incidents',
                      value: formatInt(_overview['open_incidents']),
                      hint: '${formatInt(_overview['critical_incidents'])} critical',
                      color: SalusColors.red,
                      icon: Icons.local_fire_department_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricCard(
                      label: 'Sensitive assets',
                      value: formatInt(_overview['sensitive_assets']),
                      hint: '${formatInt(_overview['assets'])} datasets discovered',
                      color: SalusColors.amber,
                      icon: Icons.folder_shared_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricCard(
                      label: 'Events observed',
                      value: formatInt(_overview['events']),
                      hint: '${formatInt(_overview['simulated_events'])} simulated',
                      color: SalusColors.blue,
                      icon: Icons.sensors_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricCard(
                      label: 'Report engine',
                      value: _overview['report_provider'] == 'GEMINI' ? 'Gemini' : 'Template',
                      hint: _overview['report_provider'] == 'GEMINI'
                          ? 'Grounded JSON report'
                          : 'Deterministic composer active',
                      color: SalusColors.violet,
                      icon: Icons.auto_awesome_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 980;
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (latestIncident != null)
                    _latestIncidentCard(
                      context,
                      latestIncident,
                      latestRisk,
                      latestMatch,
                      riskFactors,
                      weights,
                    )
                  else
                    EmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'No incidents yet',
                      message:
                          'Initialize the demo dataset, replay the simulated download and share, then upload the ghost copy to open the first incident.',
                      action: ElevatedButton(
                        onPressed: widget.onStartInvestigation,
                        child: const Text('Open investigation intake'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _dnaCard(context),
                ],
              );
              final right = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _runbook(context),
                  const SizedBox(height: 20),
                  _limitsCard(context),
                ],
              );
              if (!wide) {
                return Column(
                  children: [left, const SizedBox(height: 20), right],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: left),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: right),
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          Text(
            'Recent incidents'.toUpperCase(),
            style: const TextStyle(
              color: SalusColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          if (_incidents.isEmpty)
            const Text('No incidents recorded.', style: TextStyle(color: SalusColors.muted))
          else
            ..._incidents.take(5).map((raw) {
              final incident = asMap(raw);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SalusCard(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  onTap: () => widget.onOpenIncident(
                    asString(incident['incident_id']),
                    null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 42,
                        decoration: BoxDecoration(
                          color: SalusColors.band(asString(incident['risk_band'])),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asString(incident['title']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${asString(incident['incident_id'])}  |  '
                              '${formatPercent(incident['match_score'], decimals: 1)} match  |  '
                              '${shortDate(incident['created_at'])}',
                              style: const TextStyle(color: SalusColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      SalusBadge(
                        label: asString(incident['risk_band']),
                        color: SalusColors.band(asString(incident['risk_band'])),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatInt(incident['risk_total']),
                        style: TextStyle(
                          color: SalusColors.band(asString(incident['risk_band'])),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12352E), Color(0xFF0F1729)],
        ),
        border: Border.all(color: SalusColors.mint.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SalusBadge(
                  label: 'INVESTIGATION FIRST',
                  color: SalusColors.mint,
                  icon: Icons.radar,
                ),
                const SizedBox(height: 14),
                Text(
                  'Your data does not disappear. It leaves a trail.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 8),
                const Text(
                  'When a sensitive file shows up outside the company, SALUS finds the source, '
                  'links the records that moved, and explains the risk in plain language.',
                  style: TextStyle(color: SalusColors.muted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SalusColors.mint.withValues(alpha: 0.08),
              border: Border.all(color: SalusColors.mint.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.fingerprint, size: 48, color: SalusColors.mint),
          ),
        ],
      ),
    );
  }

  Widget _latestIncidentCard(
    BuildContext context,
    Map<String, dynamic> incident,
    Map<String, dynamic>? risk,
    Map<String, dynamic>? match,
    Map<String, dynamic> factors,
    Map<String, dynamic> weights,
  ) {
    final band = asString(risk?['band'], asString(incident['severity']));
    final total = asInt(risk?['total'], 0);
    final canary = asMap(match?['canary']);
    return SalusCard(
      highlight: SalusColors.band(band),
      borderColor: SalusColors.band(band).withValues(alpha: 0.45),
      onTap: () => widget.onOpenIncident(asString(incident['incident_id']), null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SalusBadge(label: band, color: SalusColors.band(band), icon: Icons.priority_high),
              const SizedBox(width: 10),
              Text(
                asString(incident['incident_id']),
                style: const TextStyle(color: SalusColors.muted, fontSize: 12),
              ),
              const Spacer(),
              const Text(
                'LATEST INCIDENT',
                style: TextStyle(
                  color: SalusColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            asString(incident['title']),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Risk $total  |  Match ${formatPercent(match?['match_score'], decimals: 1)}  |  '
            '${formatPercent(match?['recall_vs_original'])} of source records  |  '
            '${asInt(match?['matched_rows'])} rows',
            style: const TextStyle(color: SalusColors.muted, fontSize: 12.5),
          ),
          if (asBool(canary['found'])) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SalusColors.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SalusColors.violet.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_tethering, size: 16, color: SalusColors.violet),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Canary ${asString(canary['canary_id'])} links this copy to ${asString(canary['recipient'])}.',
                      style: const TextStyle(color: SalusColors.text, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (risk != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            ...['S', 'D', 'B', 'E'].map((factor) {
              final data = asMap(factors[factor]);
              final score = asInt(data['score']);
              final weight = asDouble(weights[factor]);
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text(
                        factor,
                        style: const TextStyle(
                          color: SalusColors.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: score / 100,
                          minHeight: 6,
                          backgroundColor: SalusColors.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation(
                            factor == 'S'
                                ? SalusColors.red
                                : factor == 'D'
                                    ? SalusColors.amber
                                    : factor == 'B'
                                        ? SalusColors.blue
                                        : SalusColors.violet,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 54,
                      child: Text(
                        score.toString(),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11.5, color: SalusColors.muted),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 38,
                      child: Text(
                        'w ${weight.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 10, color: SalusColors.muted),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => widget.onOpenIncident(asString(incident['incident_id']), null),
                icon: const Icon(Icons.arrow_forward, size: 15),
                label: const Text('Open investigation'),
              ),
              const Spacer(),
              const SimulatedBadge(small: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dnaCard(BuildContext context) {
    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'How Data DNA survives a ghost copy',
            subtitle: 'Cell level fingerprints, weighted by rarity, not row hashes.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _MiniStep(
                icon: Icons.tag,
                title: 'Normalize each cell',
                body: 'Case, spacing and phone punctuation are removed.',
              ),
              _MiniStep(
                icon: Icons.fingerprint,
                title: 'Hash each value',
                body: 'SHA-256 with an organization salt. Raw values are not stored.',
              ),
              _MiniStep(
                icon: Icons.balance,
                title: 'Weight by rarity',
                body: 'Aadhaar and email count far more than city or first name.',
              ),
              _MiniStep(
                icon: Icons.join_inner,
                title: 'Match the overlap',
                body: 'Dropped rows and columns reduce coverage, not the match.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'MinHash or LSH is the scale path. The demo uses exact set overlap because it is '
            'deterministic and fast at this size.',
            style: TextStyle(color: SalusColors.muted, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _runbook(BuildContext context) {
    final steps = [
      ('Seed the workspace', 'Organization, 1,000 synthetic customers, 5 canary rows, baseline events.'),
      ('Replay activity', 'A download at 22:40 IST and an external share four minutes later.'),
      ('Generate the ghost copy', 'Run scripts/generate_dataset.py then scripts/ghost_copy.py.'),
      ('Upload the suspect file', 'Investigation intake matches it back to customer_master_v1.'),
    ];
    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Ghost Copy runbook',
            subtitle: 'The demo spine, in four steps.',
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final complete = index == 0 || (index == 1 && _incidents.isNotEmpty);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: complete
                          ? SalusColors.mint.withValues(alpha: 0.16)
                          : SalusColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: complete
                            ? SalusColors.mint.withValues(alpha: 0.5)
                            : SalusColors.border,
                      ),
                    ),
                    child: complete
                        ? const Icon(Icons.check, size: 14, color: SalusColors.mint)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 11, color: SalusColors.muted),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          step.$2,
                          style: const TextStyle(color: SalusColors.muted, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _simulating ? null : _replay,
                  icon: const Icon(Icons.science_outlined, size: 15),
                  label: Text(_simulating ? 'Replaying' : 'Step 2'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onStartInvestigation,
                  icon: const Icon(Icons.upload_file, size: 15),
                  label: const Text('Step 4'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _limitsCard(BuildContext context) {
    return SalusCard(
      borderColor: SalusColors.amber.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility_off_outlined, size: 17, color: SalusColors.amber),
              SizedBox(width: 8),
              Text('What SALUS cannot see', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...asList(_overview['limits']).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('  ', style: TextStyle(color: SalusColors.muted)),
                  const Text('• ', style: TextStyle(color: SalusColors.amber)),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: const TextStyle(color: SalusColors.muted, fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Authorized and visible monitoring only. No covert surveillance.',
            style: TextStyle(color: SalusColors.muted, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MiniStep extends StatelessWidget {
  const _MiniStep({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: SalusColors.mint),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(color: SalusColors.muted, fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
