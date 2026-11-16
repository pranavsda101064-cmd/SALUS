import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/lineage_graph.dart';

class IncidentDetailScreen extends StatefulWidget {
  const IncidentDetailScreen({
    super.key,
    required this.api,
    required this.incidentId,
    required this.onBack,
    this.initialBundle,
  });

  final ApiClient api;
  final String incidentId;
  final VoidCallback onBack;
  final Map<String, dynamic>? initialBundle;

  @override
  State<IncidentDetailScreen> createState() => IncidentDetailScreenState();
}

class IncidentDetailScreenState extends State<IncidentDetailScreen> {
  Map<String, dynamic>? _bundle;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBundle != null) {
      _bundle = widget.initialBundle;
      _loading = false;
    } else {
      load();
    }
  }

  Future<void> load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final bundle = await widget.api.incident(widget.incidentId);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
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

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await widget.api.updateStatus(widget.incidentId, status);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Incident marked $status.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerate() async {
    setState(() => _busy = true);
    try {
      await widget.api.regenerateReport(widget.incidentId);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report regenerated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(28),
        child: LoadingBox(label: 'Opening investigation'),
      );
    }
    if (_error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            ErrorBox(message: _error!, onRetry: load),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back'),
            ),
          ],
        ),
      );
    }

    final bundle = _bundle ?? {};
    final incident = asMap(bundle['incident']);
    final source = asMap(bundle['source_asset']);
    final suspect = asMap(bundle['suspect_asset']);
    final match = asMap(bundle['match']);
    final risk = asMap(bundle['risk']);
    final report = asMap(bundle['report']);
    final timeline = asList(bundle['timeline']).map(asMap).toList();
    final lineage = asMap(bundle['lineage']);
    final limits = asList(bundle['limits']);
    final canary = asMap(match['canary']);
    final factors = asMap(risk['factors']);
    final weights = asMap(risk['weights']);
    final band = asString(risk['band'], asString(incident['severity'], 'LOW'));
    final status = asString(incident['status'], 'OPEN');
    final provider = asString(report['provider'], 'SALUS_TEMPLATE');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
              ),
              const SizedBox(width: 12),
              SalusBadge(label: band, color: SalusColors.band(band), icon: Icons.priority_high),
              const SizedBox(width: 8),
              SalusBadge(label: status, color: SalusColors.blue, small: false),
              const Spacer(),
              if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                onSelected: _busy ? null : _setStatus,
                color: SalusColors.surfaceAlt,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'OPEN', child: Text('Mark open')),
                  PopupMenuItem(value: 'TRIAGED', child: Text('Mark triaged')),
                  PopupMenuItem(value: 'CONTAINED', child: Text('Mark contained')),
                  PopupMenuItem(value: 'CLOSED', child: Text('Mark closed')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: SalusColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SalusColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Change status', style: TextStyle(fontSize: 12.5)),
                      SizedBox(width: 6),
                      Icon(Icons.expand_more, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: load,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            asString(incident['incident_id']),
            style: const TextStyle(
              color: SalusColors.mint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            asString(incident['title']),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 8),
          Text(
            'Source ${asString(source['asset_id'])}  |  Suspect ${asString(suspect['asset_id'])}  |  '
            'Opened ${shortDate(incident['created_at'])}  |  Policy ${asString(risk['policy_version'])}',
            style: const TextStyle(color: SalusColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final tile = width > 1000 ? (width - 54) / 4 : width > 680 ? (width - 36) / 3 : width;
              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  SizedBox(
                    width: tile,
                    child: MetricCard(
                      label: 'Risk score',
                      value: formatInt(risk['total']),
                      hint: '$band, ${asString(risk['policy_version'])}',
                      color: SalusColors.band(band),
                      icon: Icons.speed,
                    ),
                  ),
                  SizedBox(
                    width: tile,
                    child: MetricCard(
                      label: 'Match score',
                      value: formatPercent(match['match_score'], decimals: 1),
                      hint: 'Containment ${formatPercent(match['containment'])}',
                      color: SalusColors.mint,
                      icon: Icons.join_inner,
                    ),
                  ),
                  SizedBox(
                    width: tile,
                    child: MetricCard(
                      label: 'Records corroborated',
                      value: formatInt(match['matched_rows']),
                      hint: '${formatPercent(match['recall_vs_original'])} of ${formatInt(source['row_count'])} source rows',
                      color: SalusColors.amber,
                      icon: Icons.table_rows_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tile,
                    child: MetricCard(
                      label: 'Canary',
                      value: asBool(canary['found']) ? 'Found' : 'Missing',
                      hint: asBool(canary['found'])
                          ? asString(canary['canary_id'])
                          : 'Can be stripped from a copy',
                      color: asBool(canary['found']) ? SalusColors.violet : SalusColors.muted,
                      icon: Icons.wifi_tethering,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _summaryCard(context, report, provider, band),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 980;
              final matchCard = _matchCard(context, match, source, suspect);
              final riskCard = _riskCard(context, risk, factors, weights, band);
              if (!wide) return Column(children: [matchCard, const SizedBox(height: 18), riskCard]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: matchCard),
                  const SizedBox(width: 18),
                  Expanded(flex: 6, child: riskCard),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _canaryCard(context, canary, match),
          const SizedBox(height: 20),
          LineageGraph(lineage: lineage),
          const SizedBox(height: 20),
          _timelineCard(context, timeline),
          const SizedBox(height: 20),
          _reportDetails(context, report, provider),
          const SizedBox(height: 20),
          _actionsCard(context, report),
          const SizedBox(height: 20),
          _limitsCard(context, limits, report),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, Map<String, dynamic> report, String provider, String band) {
    return SalusCard(
      highlight: SalusColors.band(band),
      borderColor: SalusColors.band(band).withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 18, color: SalusColors.mint),
              const SizedBox(width: 8),
              const Text('Incident report', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              SalusBadge(
                label: provider == 'GEMINI' ? 'GEMINI' : 'SALUS TEMPLATE',
                color: provider == 'GEMINI' ? SalusColors.blue : SalusColors.mint,
                icon: Icons.auto_awesome,
                small: true,
              ),
              if (asString(report['model']).isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  asString(report['model']),
                  style: const TextStyle(color: SalusColors.muted, fontSize: 11),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : _regenerate,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Regenerate'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            asString(report['summary'], 'No report has been generated.'),
            style: const TextStyle(fontSize: 15, height: 1.55),
          ),
          if (asString(report['engine_note']).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              asString(report['engine_note']),
              style: const TextStyle(color: SalusColors.amber, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: asList(report['grounding_refs']).map((ref) {
              final id = asString(ref);
              return RefChip(type: _refType(id), id: id);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _matchCard(
    BuildContext context,
    Map<String, dynamic> match,
    Map<String, dynamic> source,
    Map<String, dynamic> suspect,
  ) {
    final evidence = asMap(match['evidence']);
    final matchedColumns = asList(match['matched_columns']);
    final droppedColumns = asList(match['dropped_columns']);
    final score = asDouble(match['match_score']);
    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Match evidence',
            subtitle: 'Rare cell overlap, not a row hash.',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPercent(score, decimals: 1),
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: SalusColors.mint),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('match score', style: TextStyle(color: SalusColors.muted, fontSize: 12)),
              ),
              const Spacer(),
              Text(
                asString(match['method'], 'CELL_HASH_WEIGHTED_V1'),
                style: const TextStyle(color: SalusColors.muted, fontSize: 10.5, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: score.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: SalusColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(SalusColors.mint),
            ),
          ),
          const SizedBox(height: 18),
          KeyValueRow(label: 'Source', value: asString(source['name'])),
          KeyValueRow(label: 'Suspect file', value: asString(suspect['name'])),
          KeyValueRow(label: 'Matched rows', value: formatInt(match['matched_rows'])),
          KeyValueRow(label: 'Matched cells', value: formatInt(match['matched_cells'])),
          KeyValueRow(label: 'Row coverage', value: formatPercent(match['recall_vs_original'])),
          KeyValueRow(label: 'Weighted cell recall', value: formatPercent(evidence['cell_recall'], decimals: 1)),
          KeyValueRow(label: 'Rare values shared', value: formatInt(evidence['rare_shared_values'])),
          KeyValueRow(
            label: 'Watermark',
            value: asBool(evidence['watermark_stripped'])
                ? 'Stripped (${asString(evidence['watermark_on_source'])})'
                : (asString(evidence['watermark_on_query']).isEmpty
                    ? 'Not present'
                    : asString(evidence['watermark_on_query'])),
            valueColor: asBool(evidence['watermark_stripped']) ? SalusColors.amber : null,
          ),
          const SizedBox(height: 12),
          const Text(
            'MATCHED COLUMNS',
            style: TextStyle(color: SalusColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: matchedColumns
                .map((column) => SalusBadge(label: column.toString(), color: SalusColors.mint, small: true))
                .toList(),
          ),
          if (droppedColumns.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'DROPPED COLUMNS',
              style: TextStyle(color: SalusColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: droppedColumns
                  .map((column) => SalusBadge(label: column.toString(), color: SalusColors.amber, small: true))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'A match is a lead, not proof of intent.',
            style: TextStyle(color: SalusColors.muted, fontSize: 11.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _riskCard(
    BuildContext context,
    Map<String, dynamic> risk,
    Map<String, dynamic> factors,
    Map<String, dynamic> weights,
    String band,
  ) {
    final labels = {
      'S': 'Sensitivity',
      'D': 'Destination trust risk',
      'B': 'Behaviour unusualness',
      'E': 'Event sequence severity',
    };
    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'Explainable risk',
            subtitle: 'R = 0.35*S + 0.30*D + 0.20*B + 0.15*E',
            trailing: SalusBadge(label: band, color: SalusColors.band(band)),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatInt(risk['total']),
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: SalusColors.band(band),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'of 100',
                  style: TextStyle(color: SalusColors.muted, fontSize: 12),
                ),
              ),
              const Spacer(),
              const Text(
                'DEMO POLICY',
                style: TextStyle(
                  color: SalusColors.muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...['S', 'D', 'B', 'E'].map((factor) {
            final data = asMap(factors[factor]);
            final score = asInt(data['score']);
            final weight = asDouble(weights[factor]);
            final points = score * weight;
            var reason = asString(data['basis']);
            if (factor == 'E') reason = asList(data['reasons']).join(', ');
            if (factor == 'D') {
              reason = '${asString(data['destination'], 'unknown')}  |  ${asString(data['basis'])}';
            }
            return RiskFactorBar(
              factor: factor,
              label: labels[factor]!,
              score: score,
              points: points,
              weight: weight,
              reason: reason,
            );
          }),
          const SizedBox(height: 2),
          const Text(
            'Weights are demo policy values, not validated standards. The deterministic engine computes the score. '
            'The language model only explains it.',
            style: TextStyle(color: SalusColors.muted, fontSize: 11, height: 1.45),
          ),
          if (asList(asMap(factors['B'])['top_features']).isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'BEHAVIOUR CONTRIBUTORS',
              style: TextStyle(color: SalusColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            ...asList(asMap(factors['B'])['top_features']).map((raw) {
              final feature = asMap(raw);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${asString(feature['feature'])}  ${(asDouble(feature['contribution']) * 100).toStringAsFixed(0)}% of reconstruction error',
                  style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _canaryCard(BuildContext context, Map<String, dynamic> canary, Map<String, dynamic> match) {
    final found = asBool(canary['found']);
    return SalusCard(
      borderColor: (found ? SalusColors.violet : SalusColors.amber).withValues(alpha: 0.4),
      highlight: found ? SalusColors.violet : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            found ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            color: found ? SalusColors.violet : SalusColors.amber,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      found ? 'Canary record matched' : 'Canary not found',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    if (found) const SimulatedBadge(small: false),
                  ],
                ),
                const SizedBox(height: 6),
                if (found)
                  Text(
                    'Issuance ${asString(canary['canary_id'])} was assigned to ${asString(canary['recipient'])} '
                    'on ${shortDate(canary['issued_at'])}. ${formatInt(canary['matched_values'])} canary values '
                    'appear across ${formatInt(canary['matched_rows'])} rows of this copy.',
                    style: const TextStyle(color: SalusColors.text, fontSize: 13, height: 1.5),
                  )
                else
                  const Text(
                    'No canary values were found. A canary can be stripped or the rows can be dropped. '
                    'Treat the match as the primary evidence.',
                    style: TextStyle(color: SalusColors.muted, fontSize: 13, height: 1.5),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'A canary shows which issuance a copy came from. It does not prove who leaked it next.',
                  style: TextStyle(color: SalusColors.muted, fontSize: 11.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineCard(BuildContext context, List<Map<String, dynamic>> timeline) {
    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Event sequence',
            subtitle: 'Only stored events appear here. A similarity match never creates one.',
          ),
          const SizedBox(height: 16),
          if (timeline.isEmpty)
            const Text('No events were correlated with this match.', style: TextStyle(color: SalusColors.muted))
          else
            ...List.generate(timeline.length, (index) {
              final event = timeline[index];
              final action = asString(event['action']);
              final color = SalusColors.action(action);
              final simulated = asBool(event['simulated']);
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 26,
                      child: Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_actionIcon(action), size: 13, color: color),
                          ),
                          if (index < timeline.length - 1)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: SalusColors.border,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  prettyAction(action),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(width: 8),
                                if (simulated) const SimulatedBadge(),
                                const Spacer(),
                                Text(
                                  shortDate(event['timestamp']),
                                  style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${asString(event['actor_id'])} to ${asString(event['destination'], 'no destination')}',
                              style: const TextStyle(color: SalusColors.muted, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                RefChip(type: 'EVENT', id: asString(event['event_id']), simulated: simulated),
                                if (asMap(event['evidence'])['rows'] != null)
                                  Text(
                                    '${formatInt(asMap(event['evidence'])['rows'])} rows',
                                    style: const TextStyle(color: SalusColors.muted, fontSize: 11),
                                  ),
                                if (asString(asMap(event['evidence'])['recipient']).isNotEmpty)
                                  Text(
                                    'recipient ${asString(asMap(event['evidence'])['recipient'])}',
                                    style: const TextStyle(color: SalusColors.muted, fontSize: 11),
                                  ),
                                SalusBadge(
                                  label: asString(event['source'], 'SOURCE'),
                                  color: simulated ? SalusColors.violet : SalusColors.mint,
                                  small: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _reportDetails(BuildContext context, Map<String, dynamic> report, String provider) {
    final who = asMap(report['who_moved_it']);
    final confidence = asString(who['confidence'], 'LOW');
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 980;
        final left = SalusCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'What left', subtitle: 'Plain language evidence.'),
              const SizedBox(height: 14),
              ...asList(report['what_left']).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right, size: 18, color: SalusColors.mint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.toString(),
                          style: const TextStyle(fontSize: 13, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              const SectionTitle(title: 'Who moved it', subtitle: 'Derived only from stored events.'),
              const SizedBox(height: 12),
              Row(
                children: [
                  SalusBadge(
                    label: '$confidence confidence',
                    color: confidence == 'HIGH'
                        ? SalusColors.red
                        : confidence == 'MEDIUM'
                            ? SalusColors.amber
                            : SalusColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                asString(who['assessment'], 'No actor evidence.'),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              if (asList(who['basis']).isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: asList(who['basis']).map((ref) {
                    final id = asString(ref);
                    return RefChip(type: _refType(id), id: id);
                  }).toList(),
                ),
              ],
            ],
          ),
        );
        final right = SalusCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Why it was flagged', subtitle: 'Points are weight times factor score.'),
              const SizedBox(height: 14),
              ...asList(report['why_flagged']).map((raw) {
                final item = asMap(raw);
                final factor = asString(item['factor']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SalusColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          factor,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          asString(item['reason']),
                          style: const TextStyle(fontSize: 12.5, height: 1.45),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${asDouble(item['points']).toStringAsFixed(1)}',
                        style: const TextStyle(color: SalusColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              Text(
                'Report provider: ${provider == 'GEMINI' ? 'Gemini, grounded in the evidence JSON' : 'deterministic SALUS template'}',
                style: const TextStyle(color: SalusColors.muted, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        );
        if (!wide) return Column(children: [left, const SizedBox(height: 18), right]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: left),
            const SizedBox(width: 18),
            Expanded(flex: 5, child: right),
          ],
        );
      },
    );
  }

  Widget _actionsCard(BuildContext context, Map<String, dynamic> report) {
    final actions = asList(report['recommended_actions']).map(asMap).toList();
    return SalusCard(
      borderColor: SalusColors.mint.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'What do I do now',
            subtitle: 'Practical next steps, ordered by priority.',
          ),
          const SizedBox(height: 14),
          if (actions.isEmpty)
            const Text('No actions were generated.', style: TextStyle(color: SalusColors.muted))
          else
            ...actions.map((action) {
              final number = asInt(action['priority']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: SalusColors.mint.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: SalusColors.mint.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '$number',
                        style: const TextStyle(
                          color: SalusColors.mint,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asString(action['action']),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            asString(action['why']),
                            style: const TextStyle(color: SalusColors.muted, fontSize: 12, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _limitsCard(BuildContext context, List<dynamic> limits, Map<String, dynamic> report) {
    final all = limits.isEmpty ? asList(report['limitations']) : limits;
    return SalusCard(
      borderColor: SalusColors.amber.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility_off_outlined, size: 17, color: SalusColors.amber),
              SizedBox(width: 8),
              Text('Limits of this investigation', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ...all.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: SalusColors.amber)),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: const TextStyle(color: SalusColors.muted, fontSize: 12.5, height: 1.45),
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

  static IconData _actionIcon(String action) {
    switch (action) {
      case 'EXTERNAL_SHARE':
        return Icons.public;
      case 'FILE_DOWNLOADED':
        return Icons.download;
      case 'FILE_COPIED':
        return Icons.content_copy;
      case 'SUSPECT_UPLOAD':
        return Icons.upload_file;
      default:
        return Icons.visibility;
    }
  }

  static String _refType(String id) {
    if (id.startsWith('MT')) return 'MATCH';
    if (id.startsWith('RS')) return 'RISK';
    if (id.startsWith('EV')) return 'EVENT';
    if (id.startsWith('INC')) return 'INCIDENT';
    if (id.startsWith('RP')) return 'REPORT';
    return 'REF';
  }
}
