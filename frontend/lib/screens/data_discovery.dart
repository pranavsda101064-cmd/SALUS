import '../icons.dart';

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
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
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
    final suspects = _assets
        .map(asMap)
        .where((asset) => asString(asset['kind']) == 'SUSPECT')
        .length;
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
            mark: 'about your data',
            subtitle: 'Metadata, sensitivity labels and fingerprints. No raw file contents are stored.',
            actions: [
              OutlinedButton.icon(
                onPressed: load,
                icon: const Icon(SalusIcons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StatStrip(
            items: [
              StatItem(
                label: 'Datasets',
                value: formatInt(_assets.length),
                hint: '$suspects suspect files',
                color: SalusColors.text,
              ),
              StatItem(
                label: 'Critical datasets',
                value: formatInt(critical),
                hint: 'Identity or financial data',
                color: SalusColors.yellow,
              ),
              StatItem(
                label: 'PII types',
                value: formatInt(piiTypes.length),
                hint: piiTypes.map(prettyPii).take(3).join(' · '),
                color: SalusColors.cobalt,
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (_loading)
            const LoadingBox(label: 'Reading asset metadata')
          else if (_error != null)
            ErrorBox(message: _error!, onRetry: load)
          else if (_assets.isEmpty)
            const EmptyState(
              icon: SalusIcons.folder,
              title: 'No datasets yet',
              message: 'Run the demo seed to register the synthetic customer master, or upload a CSV or XLSX dataset.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 980;
                final cardWidth = wide
                    ? (constraints.maxWidth - 20) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: _assets.map((raw) {
                    final asset = asMap(raw);
                    return SizedBox(
                      width: cardWidth,
                      child: _AssetCard(asset: asset, api: widget.api),
                    );
                  }).toList(),
                );
              },
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
      borderColor: SalusColors.sensitivity(label).withValues(alpha: 0.3),
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
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SalusColors.border),
                ),
                child: Icon(
                  kind == 'SUSPECT' ? SalusIcons.search : SalusIcons.table,
                  size: 20,
                  color: kind == 'SUSPECT'
                      ? SalusColors.ink
                      : SalusColors.secondary,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${asString(asset['asset_id'])}  ·  ${asString(asset['original_filename'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SalusColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    kind,
                    style: const TextStyle(
                      color: SalusColors.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SalusBadge(
                    label: label,
                    color: SalusColors.sensitivity(label),
                    small: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(value: formatInt(asset['row_count']), label: 'rows'),
              _Stat(value: formatInt(asset['column_count']), label: 'columns'),
              _Stat(
                value: formatInt(dna['unique_cells']),
                label: 'unique cells',
              ),
              _Stat(value: formatInt(dna['canary_rows']), label: 'canaries'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            piiTypes.isEmpty
                ? 'No PII detected'
                : piiTypes.map(prettyPii).join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SalusColors.muted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  asset['watermark'] != null &&
                          asString(asset['watermark']).isNotEmpty
                      ? 'Watermark ${asString(asset['watermark'])}'
                      : 'No watermark recorded',
                  style: const TextStyle(
                    color: SalusColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => showAssetSheet(context, api, asset),
                icon: const Icon(SalusIcons.external, size: 14),
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
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          Text(
            label,
            style: const TextStyle(color: SalusColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

Future<void> showAssetSheet(
  BuildContext context,
  ApiClient api,
  Map<String, dynamic> asset,
) {
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
      final events = await widget.api.events(
        assetId: asString(widget.asset['asset_id']),
        limit: 20,
      );
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
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
                        style: const TextStyle(
                          color: SalusColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SalusBadge(label: label, color: SalusColors.sensitivity(label)),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(SalusIcons.x),
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
                        final sensitivity = asString(
                          column['sensitivity'],
                          'LOW',
                        );
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
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  prettyPii(type),
                                  style: const TextStyle(
                                    color: SalusColors.muted,
                                    fontSize: 12,
                                  ),
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
                                  style: const TextStyle(
                                    color: SalusColors.muted,
                                    fontSize: 11.5,
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
                final sideCard = SalusCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Data DNA'),
                      const SizedBox(height: 12),
                      KeyValueRow(
                        label: 'Version',
                        value: asString(dna['version'], 'dna-v1'),
                      ),
                      KeyValueRow(
                        label: 'Cell fingerprints',
                        value: formatInt(dna['cell_fingerprints']),
                      ),
                      KeyValueRow(
                        label: 'Unique values',
                        value: formatInt(dna['unique_cells']),
                      ),
                      KeyValueRow(
                        label: 'Canary rows',
                        value: formatInt(dna['canary_rows']),
                      ),
                      KeyValueRow(
                        label: 'Watermark',
                        value: asString(asset['watermark']).isEmpty
                            ? 'None'
                            : asString(asset['watermark']),
                      ),
                      const Divider(height: 22),
                      const Text(
                        'Weights come from in file rarity. A value that appears once carries far more evidence '
                        'than a city repeated across the file.',
                        style: TextStyle(
                          color: SalusColors.muted,
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                );
                if (!wide) {
                  return Column(
                    children: [
                      columnsCard,
                      const SizedBox(height: 16),
                      sideCard,
                    ],
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
                  const SectionTitle(
                    title: 'Recent events',
                    subtitle: 'Events that reference this asset.',
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Text(
                      'Loading events',
                      style: TextStyle(color: SalusColors.muted),
                    )
                  else if (_events.isEmpty)
                    const Text(
                      'No events for this asset.',
                      style: TextStyle(color: SalusColors.muted),
                    )
                  else
                    ..._events.take(8).map((raw) {
                      final event = asMap(raw);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              SalusIcons.circle,
                              size: 7,
                              color: SalusColors.action(
                                asString(event['action']),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 145,
                              child: Text(
                                prettyAction(asString(event['action'])),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                asString(event['actor_id']),
                                style: const TextStyle(
                                  color: SalusColors.muted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                asString(event['destination']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SalusColors.muted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            Text(
                              shortDate(event['timestamp']),
                              style: const TextStyle(
                                color: SalusColors.muted,
                                fontSize: 11,
                              ),
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
