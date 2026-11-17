import '../icons.dart';

import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
          content: Text(
            'Simulated download and share replayed. Simulated events are labelled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
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

    final slides = [
      CarouselSlide(
        asset: 'assets/photos/shared-desk.jpg',
        semanticLabel: 'Laptops on a shared desk',
        eyebrow: 'Step 1',
        icon: SalusIcons.flask,
        title: 'Replay the activity',
        body: 'Replays a simulated download and an external share. Simulated events stay labelled.',
        actionLabel: _simulating ? 'Replaying' : 'Replay activity',
        onAction: _simulating ? null : _replay,
      ),
      CarouselSlide(
        asset: 'assets/photos/typing-laptop.jpg',
        semanticLabel: 'A person typing on a laptop',
        eyebrow: 'Step 2',
        icon: SalusIcons.upload,
        title: 'Investigate a suspect file',
        body: 'Upload the ghost copy. SALUS matches it back to the source and checks for canary rows.',
        actionLabel: 'Investigate a file',
        onAction: widget.onStartInvestigation,
      ),
      CarouselSlide(
        asset: 'assets/photos/window-office.jpg',
        semanticLabel: 'An office with tall windows',
        eyebrow: 'Step 3',
        icon: SalusIcons.tree,
        title: 'Read the latest incident',
        body: 'Open the trail, the four risk factors, and the grounded report with next actions.',
        actionLabel: 'Open latest incident',
        onAction: latestIncident == null
            ? null
            : () => widget.onOpenIncident(
                asString(latestIncident['incident_id']),
                _latest,
              ),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            child: PageHeader(
              eyebrow: 'Command center',
              mark: asString(asMap(widget.session['user'])['name'], 'owner'),
              title:
                  'Good to see you, ${asString(asMap(widget.session['user'])['name'], 'owner')}',
              subtitle:
                  '${asString(org['name'], 'Your workspace')}. Review incidents, replay the demo, and open an investigation.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _simulating ? null : _replay,
                  icon: _simulating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(SalusIcons.flask, size: 16),
                  label: Text(_simulating ? 'Replaying' : 'Replay activity'),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onStartInvestigation,
                  icon: const Icon(SalusIcons.investigate, size: 16),
                  label: const Text('Investigate a file'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: ParallaxCarousel(slides: slides),
          ),
          const SizedBox(height: 24),
          FadeSlideIn(
            delay: const Duration(milliseconds: 220),
            child: StatStrip(
              items: [
                StatItem(
                  label: 'Open incidents',
                  value: formatInt(_overview['open_incidents']),
                  hint:
                      '${formatInt(_overview['critical_incidents'])} critical',
                  color: SalusColors.yellow,
                ),
                StatItem(
                  label: 'Sensitive assets',
                  value: formatInt(_overview['sensitive_assets']),
                  hint: '${formatInt(_overview['assets'])} datasets',
                  color: SalusColors.cobalt,
                ),
                StatItem(
                  label: 'Events observed',
                  value: formatInt(_overview['events']),
                  hint: '${formatInt(_overview['simulated_events'])} simulated',
                  color: SalusColors.text,
                ),
                StatItem(
                  label: 'Report engine',
                  value: _overview['report_provider'] == 'GEMINI'
                      ? 'Gemini'
                      : 'Template',
                  hint: _overview['report_provider'] == 'GEMINI'
                      ? 'Grounded report'
                      : 'Deterministic fallback',
                  color: SalusColors.text,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 980;
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (latestIncident != null)
                    _IncidentCard(
                      incident: latestIncident,
                      risk: latestRisk,
                      match: latestMatch,
                      onOpen: () => widget.onOpenIncident(
                        asString(latestIncident['incident_id']),
                        _latest,
                      ),
                    )
                  else
                    EmptyState(
                      icon: SalusIcons.checkCircle,
                      title: 'No incidents yet',
                      message: 'Replay the simulated activity, then upload the ghost copy to open the first incident.',
                      action: ElevatedButton(
                        onPressed: widget.onStartInvestigation,
                        child: const Text('Open investigation intake'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _RecentIncidents(
                    incidents: _incidents,
                    onOpen: (id) => widget.onOpenIncident(id, null),
                  ),
                ],
              );
              final right = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DemoSteps(
                    simulating: _simulating,
                    onReplay: _replay,
                    onInvestigate: widget.onStartInvestigation,
                    hasIncident: _incidents.isNotEmpty,
                  ),
                  const SizedBox(height: 24),
                  _LimitsCard(limits: asList(_overview['limits'])),
                ],
              );
              if (!wide) {
                return Column(
                  children: [left, const SizedBox(height: 24), right],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: left),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.incident,
    required this.risk,
    required this.match,
    required this.onOpen,
  });

  final Map<String, dynamic> incident;
  final Map<String, dynamic>? risk;
  final Map<String, dynamic>? match;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final band = asString(risk?['band'], asString(incident['severity'], 'LOW'));
    final canary = asMap(match?['canary']);
    final found = asBool(canary['found']);

    return SalusCard(
      borderColor: SalusColors.yellow.withValues(alpha: 0.35),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SalusBadge(
                label: band,
                color: SalusColors.band(band),
                icon: SalusIcons.warning,
              ),
              const SizedBox(width: 10),
              Text(
                asString(incident['incident_id']),
                style: const TextStyle(color: SalusColors.muted, fontSize: 12),
              ),
              const Spacer(),
              const SimulatedBadge(small: false),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            asString(incident['title']),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${shortDate(incident['created_at'])}  ·  ${asString(incident['status'], 'OPEN')}',
            style: const TextStyle(color: SalusColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _MiniStat(
                label: 'Risk',
                value: formatInt(risk?['total']),
                color: SalusColors.yellow,
              ),
              _Divider(),
              _MiniStat(
                label: 'Match',
                value: formatPercent(match?['match_score'], decimals: 1),
                color: SalusColors.cobalt,
              ),
              _Divider(),
              _MiniStat(
                label: 'Records',
                value: formatInt(match?['matched_rows']),
                color: SalusColors.text,
              ),
              _Divider(),
              _MiniStat(
                label: 'Canary',
                value: found ? 'Found' : 'None',
                color: found ? SalusColors.ink : SalusColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: found
                  ? SalusColors.yellow.withValues(alpha: 0.06)
                  : SalusColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: found
                    ? SalusColors.yellow.withValues(alpha: 0.25)
                    : SalusColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  found ? SalusIcons.broadcast : SalusIcons.broadcastOff,
                  size: 16,
                  color: found ? SalusColors.ink : SalusColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    found
                        ? 'Canary ${asString(canary['canary_id'])} links this copy to ${asString(canary['recipient'])}.'
                        : 'No canary values in this copy. The match is the primary evidence.',
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(SalusIcons.arrowRight, size: 15),
                label: const Text('Open investigation'),
              ),
              const Spacer(),
              Text(
                '${formatPercent(match?['recall_vs_original'])} of source records',
                style: const TextStyle(
                  color: SalusColors.muted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isPrimary = color == SalusColors.primary;
    final valueText = Text(
      value,
      style: TextStyle(
        color: isPrimary ? SalusColors.onPrimary : color,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: SalusColors.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          if (isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: SalusColors.primary,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: SalusColors.ink.withValues(alpha: 0.16),
                ),
              ),
              child: valueText,
            )
          else
            valueText,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: SalusColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class _RecentIncidents extends StatelessWidget {
  const _RecentIncidents({required this.incidents, required this.onOpen});
  final List<dynamic> incidents;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    return SalusCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: SectionTitle(
              title: 'Recent incidents',
              subtitle: 'All activity in this workspace.',
            ),
          ),
          if (incidents.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'No incidents recorded.',
                style: TextStyle(color: SalusColors.muted, fontSize: 12.5),
              ),
            )
          else
            for (var index = 0; index < incidents.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              _IncidentRow(
                incident: asMap(incidents[index]),
                onTap: () =>
                    onOpen(asString(asMap(incidents[index])['incident_id'])),
              ),
            ],
        ],
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.incident, required this.onTap});
  final Map<String, dynamic> incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final band = asString(incident['risk_band'], 'LOW');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: SalusColors.band(band),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asString(incident['title']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${asString(incident['incident_id'])}  ·  ${formatPercent(incident['match_score'], decimals: 1)} match  ·  ${shortDate(incident['created_at'])}',
                    style: const TextStyle(
                      color: SalusColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Builder(
              builder: (context) {
                final high = band == 'CRITICAL' || band == 'HIGH';
                final value = Text(
                  formatInt(incident['risk_total']),
                  style: TextStyle(
                    color: high
                        ? SalusColors.onPrimary
                        : SalusColors.band(band),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
                if (!high) return value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: SalusColors.primary,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: SalusColors.ink.withValues(alpha: 0.16),
                    ),
                  ),
                  child: value,
                );
              },
            ),
            const SizedBox(width: 6),
            const Icon(
              SalusIcons.caretRight,
              size: 16,
              color: SalusColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoSteps extends StatelessWidget {
  const _DemoSteps({
    required this.simulating,
    required this.onReplay,
    required this.onInvestigate,
    required this.hasIncident,
  });

  final bool simulating;
  final VoidCallback onReplay;
  final VoidCallback onInvestigate;
  final bool hasIncident;

  @override
  Widget build(BuildContext context) {
    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Demo steps',
            subtitle: 'The Ghost Copy in four moves.',
          ),
          const SizedBox(height: 16),
          _StepRow(
            number: '01',
            title: 'Seed the workspace',
            body: '1,000 synthetic customers and 5 canary rows.',
            done: true,
          ),
          _StepRow(
            number: '02',
            title: 'Replay activity',
            body: 'A download and an external share.',
            done: hasIncident,
          ),
          const _StepRow(
            number: '03',
            title: 'Generate the ghost copy',
            body: 'Run scripts/generate_dataset.py and scripts/ghost_copy.py.',
          ),
          const _StepRow(
            number: '04',
            title: 'Upload the suspect file',
            body: 'Match it back to customer_master_v1.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: simulating ? null : onReplay,
                  icon: const Icon(SalusIcons.flask, size: 15),
                  label: Text(simulating ? 'Replaying' : 'Replay'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onInvestigate,
                  icon: const Icon(SalusIcons.upload, size: 15),
                  label: const Text('Investigate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.body,
    this.done = false,
  });

  final String number;
  final String title;
  final String body;
  final bool done;

  @override
  Widget build(BuildContext context) {
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
              color: done
                  ? SalusColors.cobalt.withValues(alpha: 0.14)
                  : SalusColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: done
                    ? SalusColors.cobalt.withValues(alpha: 0.3)
                    : SalusColors.border,
              ),
            ),
            child: done
                ? const Icon(
                    SalusIcons.check,
                    size: 13,
                    color: SalusColors.cobalt,
                  )
                : Text(
                    number,
                    style: const TextStyle(
                      color: SalusColors.muted,
                      fontSize: 9.5,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  body,
                  style: const TextStyle(
                    color: SalusColors.muted,
                    fontSize: 11.5,
                    height: 1.4,
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

class _LimitsCard extends StatelessWidget {
  const _LimitsCard({required this.limits});
  final List<dynamic> limits;

  @override
  Widget build(BuildContext context) {
    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(SalusIcons.eyeOff, size: 16, color: SalusColors.muted),
              SizedBox(width: 8),
              Text('Limits', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ...limits.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 7),
                    color: SalusColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: const TextStyle(
                        color: SalusColors.muted,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
