import 'package:flutter/material.dart';

import '../api.dart';
import '../platform/file_picker.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

class InvestigationScreen extends StatefulWidget {
  const InvestigationScreen({
    super.key,
    required this.api,
    required this.onOpenIncident,
  });

  final ApiClient api;
  final void Function(String id, Map<String, dynamic>? bundle) onOpenIncident;

  @override
  State<InvestigationScreen> createState() => InvestigationScreenState();
}

class InvestigationScreenState extends State<InvestigationScreen> {
  PickedFile? _picked;
  bool _uploading = false;
  String? _error;
  Map<String, dynamic>? _noMatch;
  List<dynamic> _incidents = [];
  bool _loadingIncidents = true;

  @override
  void initState() {
    super.initState();
    loadIncidents();
  }

  Future<void> loadIncidents() async {
    try {
      final incidents = await widget.api.incidents();
      if (!mounted) return;
      setState(() {
        _incidents = incidents;
        _loadingIncidents = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingIncidents = false);
    }
  }

  Future<void> _pick() async {
    try {
      final file = await pickInvestigationFile();
      if (file == null || !mounted) return;
      setState(() {
        _picked = file;
        _error = null;
        _noMatch = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _investigate() async {
    final file = _picked;
    if (file == null) return;
    setState(() {
      _uploading = true;
      _error = null;
      _noMatch = null;
    });
    try {
      final result = await widget.api.investigate(file);
      if (!mounted) return;
      if (asBool(result['matched'])) {
        final bundle = asMap(result['bundle']);
        final incident = asMap(bundle['incident']);
        await loadIncidents();
        if (!mounted) return;
        widget.onOpenIncident(asString(incident['incident_id']), bundle);
      } else {
        setState(() => _noMatch = result);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            eyebrow: 'Investigation intake',
            title: 'A file showed up. Find out where it came from.',
            subtitle: 'Upload the suspect CSV or XLSX. SALUS creates Data DNA, matches stored datasets, '
                'checks canaries, correlates events and opens an incident.',
            actions: [
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Select file'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 980;
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _uploadCard(context),
                  if (_noMatch != null) ...[
                    const SizedBox(height: 16),
                    _noMatchCard(context),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    ErrorBox(message: _error!, onRetry: _pick),
                  ],
                  const SizedBox(height: 16),
                  _demoRecipe(context),
                ],
              );
              final right = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _whatHappensCard(context),
                  const SizedBox(height: 16),
                  _recentCard(context),
                ],
              );
              if (!wide) return Column(children: [left, const SizedBox(height: 18), right]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: left),
                  const SizedBox(width: 18),
                  Expanded(flex: 4, child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _uploadCard(BuildContext context) {
    final picked = _picked;
    return SalusCard(
      borderColor: picked == null
          ? SalusColors.border
          : SalusColors.mint.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
            decoration: BoxDecoration(
              color: SalusColors.surfaceAlt.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: SalusColors.mint.withValues(alpha: picked == null ? 0.25 : 0.5),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: SalusColors.mint.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    picked == null ? Icons.upload_file : Icons.description_outlined,
                    color: SalusColors.mint,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  picked == null ? 'Choose the suspect file' : picked.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  picked == null
                      ? 'CSV or XLSX. The file is parsed in memory and not kept as raw content.'
                      : '${formatBytes(picked.bytes.length)}  |  ready for investigation',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SalusColors.muted, fontSize: 12.5, height: 1.45),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pick,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: Text(picked == null ? 'Select file' : 'Choose another'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _uploading || picked == null ? null : _investigate,
                      icon: _uploading
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: SalusColors.background,
                              ),
                            )
                          : const Icon(Icons.travel_explore, size: 16),
                      label: Text(_uploading ? 'Running DNA match' : 'Run investigation'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 14, color: SalusColors.muted),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'The uploaded file becomes a SUSPECT asset with fingerprints and metadata only.',
                  style: TextStyle(color: SalusColors.muted, fontSize: 11.5),
                ),
              ),
              const SimulatedBadge(small: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noMatchCard(BuildContext context) {
    final suspect = asMap(_noMatch?['suspect_asset']);
    return SalusCard(
      borderColor: SalusColors.amber.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.search_off, color: SalusColors.amber, size: 18),
              SizedBox(width: 8),
              Text('No meaningful match', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            asString(_noMatch?['message'], 'The file was scanned but did not overlap enough with a stored dataset.'),
            style: const TextStyle(color: SalusColors.muted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 10),
          Text(
            'Scanned ${formatInt(_noMatch?['scanned_sources'])} source datasets. '
            'Stored as ${asString(suspect['asset_id'], 'a suspect asset')} with metadata only.',
            style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _demoRecipe(BuildContext context) {
    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Ghost Copy recipe',
            subtitle: 'Run these two commands in the repository, then upload the CSV.',
          ),
          const SizedBox(height: 14),
          _code('python scripts/generate_dataset.py'),
          const SizedBox(height: 8),
          _code('python scripts/ghost_copy.py'),
          const SizedBox(height: 12),
          const Text(
            'The script renames the file, converts XLSX to CSV, removes the watermark, deletes three columns, '
            'drops 700 rows and keeps three canary rows. SALUS should still find about 30 percent of the source records.',
            style: TextStyle(color: SalusColors.muted, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 10),
          const Text(
            'Expected file: demo_data/clients_export_final.csv',
            style: TextStyle(color: SalusColors.mint, fontSize: 11.5, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _code(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF060B14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: SalusColors.border),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: SalusColors.text,
        ),
      ),
    );
  }

  Widget _whatHappensCard(BuildContext context) {
    const steps = [
      ('Parse and scan', 'Column types, Verhoeff Aadhaar check, sensitivity labels.'),
      ('Fingerprint', 'Normalized values hashed with the organization salt and weighted by rarity.'),
      ('Match', 'Weighted containment plus row coverage against each source dataset.'),
      ('Correlate', 'Stored download and share events, matched by actor and time.'),
      ('Score and explain', 'Deterministic risk, behaviour model, grounded report.'),
    ];
    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'What runs on upload'),
          const SizedBox(height: 14),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 6, color: SalusColors.mint),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text(
                          step.$2,
                          style: const TextStyle(color: SalusColors.muted, fontSize: 11.5, height: 1.4),
                        ),
                      ],
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

  Widget _recentCard(BuildContext context) {
    return SalusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: 'Recent investigations',
            trailing: _loadingIncidents
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: loadIncidents,
                    icon: const Icon(Icons.refresh, size: 17),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ),
          const SizedBox(height: 12),
          if (_incidents.isEmpty)
            const Text('No investigations yet.', style: TextStyle(color: SalusColors.muted, fontSize: 12.5))
          else
            ..._incidents.take(5).map((raw) {
              final incident = asMap(raw);
              final band = asString(incident['risk_band'], 'LOW');
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: SalusCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  onTap: () => widget.onOpenIncident(asString(incident['incident_id']), null),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: SalusColors.band(band)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asString(incident['incident_id']),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                            ),
                            Text(
                              '${formatPercent(incident['match_score'], decimals: 1)} match  |  risk ${formatInt(incident['risk_total'])}',
                              style: const TextStyle(color: SalusColors.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16, color: SalusColors.muted),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
