import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

class DataDiscoveryScreen extends StatefulWidget {
  const DataDiscoveryScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<DataDiscoveryScreen> createState() => DataDiscoveryScreenState();
}

class DataDiscoveryScreenState extends State<DataDiscoveryScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _assets = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final assets = await widget.api.assets();
      if (!mounted) return;
      setState(() {
        _assets = assets;
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

  @override
  Widget build(BuildContext context) {
    final critical = _assets
        .map(asMap)
        .where((asset) => asString(asset['sensitivity_label']) == 'CRITICAL')
        .length;
    final suspects = _assets.map(asMap).where((asset) => asString(asset['kind']) == 'SUSPECT').length;
    final piiTypes = <String>{
      for (final asset in _assets.map(asMap))
        for (final column in asList(asset['columns']))
          if (asString(asMap(column)['pii_type'], 'OTHER') != 'OTHER')
            asString(asMap(column)['pii_type']),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            eyebrow: 'Data discovery',
            title: 'What SALUS knows about your data',
            subtitle: 'Metadata, sensitivity labels and fingerprints. No raw file contents are stored.',
            actions: [
              OutlinedButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final tileWidth = width > 1000 ? (width - 36) / 3 : width > 620 ? (width - 18) / 2 : width;
              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: MetricCard(
                      label: 'Datasets',
                      value: formatInt(_assets.length),
                      hint: '$suspects suspect files',
                      color: SalusColors.blue,
                      icon: Icons.dataset_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricCard(
                      label: 'Critical datasets',
                      value: formatInt(critical),
                      hint: 'Identity or financial data',
                      color: SalusColors.red,
                      icon: Icons.gpp_maybe_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricCard(
                      label: 'PII types found',
                      value: formatInt(piiTypes.length),
                      hint: piiTypes.map(prettyPii).take(3).join(', '),
                      color: SalusColors.violet,
                      icon: Icons.fingerprint,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          if (_loading)
            const LoadingBox(label: 'Reading asset metadata')
          else if (_error != null)
            ErrorBox(message: _error!, onRetry: load)
          else if (_assets.isEmpty)
            const EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'No datasets yet',
              message: 'Run the demo seed to register the synthetic customer master, or upload a CSV or XLSX dataset.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 980;
                final cardWidth = wide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: _assets.map((raw) {
                    final asset = asMap(raw);
                    return SizedBox(
                      width: cardWidth,
                      child: _AssetCard(
                        asset: asset,
                        api: widget.api,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 24),
          SalusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'Privacy by design',
                  subtitle: 'What is stored, and what is thrown away.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: const [
                    _PrivacyItem(
                      icon: Icons.delete_sweep_outlined,
                      title: 'Raw files are temporary',
                      body: 'Parsed in memory, then dropped. Only hashes and aggregates persist.',
                    ),
                    _PrivacyItem(
                      icon: Icons.key_outlined,
                      title: 'Organization salted hashes',
                      body: 'The same value hashes differently in another tenant.',
                    ),
                    _PrivacyItem(
                      icon: Icons.hub_outlined,
                      title: 'Tenant scoped queries',
                      body: 'Every asset, event, match and incident is filtered by organization.',
                    ),
                    _PrivacyItem(
                      icon: Icons.info_outline,
                      title: 'Honest limits',
                      body: 'A match is a lead. It is not proof of intent.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, required this.api});
  final Map<String, dynamic> asset;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final label = asString(asset['sensitivity_label'], 'LOW');
    final kind = asString(asset['kind'], 'ORIGINAL');
    final dna = asMap(asset['dna']);
    final columns = asList(asset['columns']);
    final piiTypes = <String>[];
    for (final raw in columns) {
      final type = asString(asMap(raw)['pii_type'], 'OTHER');
      if (type != 'OTHER' && !piiTypes.contains(type)) piiTypes.add(type);
    }

    return SalusCard(
      borderColor: kind == 'SUSPECT'
          ? SalusColors.red.withValues(alpha: 0.4)
          : SalusColors.sensitivity(label).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SalusColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  kind == 'SUSPECT' ? Icons.search : Icons.table_chart_outlined,
                  size: 20,
                  color: kind == 'SUSPECT' ? SalusColors.red : SalusColors.mint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asString(asset['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${asString(asset['asset_id'])}  |  ${asString(asset['original_filename'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SalusBadge(label: kind, color: kind == 'SUSPECT' ? SalusColors.red : SalusColors.mint, small: true),
                  const SizedBox(height: 6),
                  SalusBadge(label: label, color: SalusColors.sensitivity(label), small: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(value: formatInt(asset['row_count']), label: 'rows'),
              _Stat(value: formatInt(asset['column_count']), label: 'columns'),
              _Stat(value: formatInt(dna['unique_cells']), label: 'unique cells'),
              _Stat(value: formatInt(dna['canary_rows']), label: 'canaries'),
            ],
          ),
          const SizedBox(height: 14),
          if (piiTypes.isEmpty)
            const Text('No PII detected', style: TextStyle(color: SalusColors.muted, fontSize: 12))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: piiTypes
                  .map((type) => SalusBadge(label: prettyPii(type), color: SalusColors.blue, small: true))
                  .toList(),
            ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  asset['watermark'] != null && asString(asset['watermark']).isNotEmpty
                      ? 'Watermark ${asString(asset['watermark'])}'
                      : 'No watermark recorded',
                  style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
                ),
              ),
              TextButton.icon(
                onPressed: () => showAssetSheet(context, api, asset),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Inspect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(label, style: const TextStyle(color: SalusColors.muted, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  const _PrivacyItem({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
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
                Text(body, style: const TextStyle(color: SalusColors.muted, fontSize: 11.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAssetSheet(BuildContext context, ApiClient api, Map<String, dynamic> asset) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AssetSheet(api: api, asset: asset),
  );
}

class _AssetSheet extends StatefulWidget {
  const _AssetSheet({required this.api, required this.asset});
  final ApiClient api;
  final Map<String, dynamic> asset;

  @override
  State<_AssetSheet> createState() => _AssetSheetState();
}

class _AssetSheetState extends State<_AssetSheet> {
  List<dynamic> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await widget.api.events(assetId: asString(widget.asset['asset_id']), limit: 20);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final columns = asList(asset['columns']);
    final dna = asMap(asset['dna']);
    final label = asString(asset['sensitivity_label'], 'LOW');

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: SalusColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: SalusColors.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asString(asset['name']),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${asString(asset['asset_id'])}  |  ${asString(asset['kind'])}  |  '
                        '${formatInt(asset['row_count'])} rows  |  ${formatInt(asset['column_count'])} columns',
                        style: const TextStyle(color: SalusColors.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                SalusBadge(label: label, color: SalusColors.sensitivity(label)),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 900;
                final columnsCard = SalusCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        title: 'Column scan',
                        subtitle: 'India PII checks include the Aadhaar Verhoeff checksum.',
                      ),
                      const SizedBox(height: 14),
                      ...columns.map((raw) {
                        final column = asMap(raw);
                        final type = asString(column['pii_type'], 'OTHER');
                        final sensitivity = asString(column['sensitivity'], 'LOW');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 150,
                                child: Text(
                                  asString(column['name']),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  prettyPii(type),
                                  style: const TextStyle(color: SalusColors.muted, fontSize: 12),
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: SalusBadge(
                                  label: sensitivity,
                                  color: SalusColors.sensitivity(sensitivity),
                                  small: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  type == 'AADHAAR'
                                      ? '${formatInt(column['valid_count'])} valid, ${formatInt(column['invalid_count'])} invalid'
                                      : '${formatInt(column['unique_count'])} unique',
                                  style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
                final sideCard = SalusCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Data DNA'),
                      const SizedBox(height: 12),
                      KeyValueRow(label: 'Version', value: asString(dna['version'], 'dna-v1')),
                      KeyValueRow(label: 'Cell fingerprints', value: formatInt(dna['cell_fingerprints'])),
                      KeyValueRow(label: 'Unique values', value: formatInt(dna['unique_cells'])),
                      KeyValueRow(label: 'Canary rows', value: formatInt(dna['canary_rows'])),
                      KeyValueRow(
                        label: 'Watermark',
                        value: asString(asset['watermark']).isEmpty ? 'None' : asString(asset['watermark']),
                      ),
                      const Divider(height: 22),
                      const Text(
                        'Weights come from in file rarity. A value that appears once carries far more evidence '
                        'than a city repeated across the file.',
                        style: TextStyle(color: SalusColors.muted, fontSize: 11.5, height: 1.45),
                      ),
                    ],
                  ),
                );
                if (!wide) {
                  return Column(
                    children: [columnsCard, const SizedBox(height: 16), sideCard],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: columnsCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: sideCard),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            SalusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(title: 'Recent events', subtitle: 'Events that reference this asset.'),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Text('Loading events', style: TextStyle(color: SalusColors.muted))
                  else if (_events.isEmpty)
                    const Text('No events for this asset.', style: TextStyle(color: SalusColors.muted))
                  else
                    ..._events.take(8).map((raw) {
                      final event = asMap(raw);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 7,
                              color: SalusColors.action(asString(event['action'])),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 145,
                              child: Text(
                                prettyAction(asString(event['action'])),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                asString(event['actor_id']),
                                style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                asString(event['destination']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
                              ),
                            ),
                            Text(
                              shortDate(event['timestamp']),
                              style: const TextStyle(color: SalusColors.muted, fontSize: 11),
                            ),
                            if (asBool(event['simulated'])) ...[
                              const SizedBox(width: 8),
                              const SimulatedBadge(),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
