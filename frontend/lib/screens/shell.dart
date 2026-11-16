import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'command_center.dart';
import 'data_discovery.dart';
import 'incident_detail.dart';
import 'investigation_screen.dart';

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
  });

  final ApiClient api;
  final Map<String, dynamic> session;
  final VoidCallback onLogout;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  String? _incidentId;
  Map<String, dynamic>? _initialBundle;

  final GlobalKey<CommandCenterScreenState> _commandKey = GlobalKey();
  final GlobalKey<DataDiscoveryScreenState> _discoveryKey = GlobalKey();
  final GlobalKey<InvestigationScreenState> _investigationKey = GlobalKey();

  void _go(int index) {
    setState(() {
      _index = index;
      _incidentId = null;
      _initialBundle = null;
    });
    if (index == 0) _commandKey.currentState?.load();
    if (index == 1) _discoveryKey.currentState?.load();
    if (index == 2) _investigationKey.currentState?.loadIncidents();
  }

  void _openIncident(String id, Map<String, dynamic>? bundle) {
    setState(() {
      _incidentId = id;
      _initialBundle = bundle;
    });
  }

  void _closeIncident() {
    setState(() {
      _incidentId = null;
      _initialBundle = null;
    });
    if (_index == 0) _commandKey.currentState?.load();
    if (_index == 1) _discoveryKey.currentState?.load();
    if (_index == 2) _investigationKey.currentState?.loadIncidents();
  }

  @override
  Widget build(BuildContext context) {
    final org = asMap(widget.session['organization']);
    final user = asMap(widget.session['user']);

    final pages = [
      CommandCenterScreen(
        key: _commandKey,
        api: widget.api,
        onOpenIncident: _openIncident,
        onStartInvestigation: () => _go(2),
        session: widget.session,
      ),
      DataDiscoveryScreen(key: _discoveryKey, api: widget.api),
      InvestigationScreen(
        key: _investigationKey,
        api: widget.api,
        onOpenIncident: _openIncident,
      ),
    ];

    final detail = _incidentId == null
        ? null
        : IncidentDetailScreen(
            api: widget.api,
            incidentId: _incidentId!,
            initialBundle: _initialBundle,
            onBack: _closeIncident,
          );

    final content = detail ?? IndexedStack(index: _index, children: pages);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1.1, -1.1),
            radius: 1.3,
            colors: [Color(0xFF0E2030), SalusColors.background],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1040;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sidebar(context, org, user),
                    Expanded(child: content),
                  ],
                );
              }
              return Column(
                children: [
                  _mobileBar(context, org),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sidebar(BuildContext context, Map<String, dynamic> org, Map<String, dynamic> user) {
    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: SalusColors.background.withValues(alpha: 0.6),
        border: const Border(right: BorderSide(color: SalusColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SalusColors.mint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: SalusColors.mint.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.shield_outlined, color: SalusColors.mint, size: 21),
                ),
                const SizedBox(width: 11),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALUS',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    Text(
                      'DATA UNKNOWN',
                      style: TextStyle(
                        fontSize: 8,
                        color: SalusColors.muted,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SalusColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SalusColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: SalusColors.mint.withValues(alpha: 0.14),
                    child: Text(
                      initials(asString(user['name'], 'S')),
                      style: const TextStyle(
                        color: SalusColors.mint,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asString(org['name'], 'Workspace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                        Text(
                          '${asString(user['name'])}  |  ${asString(user['role'])}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: SalusColors.muted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _navItem(context, 0, Icons.space_dashboard_outlined, 'Command center'),
          _navItem(context, 1, Icons.dataset_outlined, 'Data discovery'),
          _navItem(context, 2, Icons.travel_explore, 'Investigation'),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'DEMO SAFETY',
              style: TextStyle(
                color: SalusColors.muted,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SalusBadge(label: 'Synthetic data', color: SalusColors.violet, small: true),
                SalusBadge(label: 'Labelled events', color: SalusColors.mint, small: true),
                SalusBadge(label: 'No raw files', color: SalusColors.blue, small: true),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SalusColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 15, color: SalusColors.mint),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Report engine: template first, Gemini when a key is present.',
                          style: TextStyle(color: SalusColors.muted, fontSize: 10.5, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout, size: 15),
                  label: const Text('Sign out'),
                  style: TextButton.styleFrom(foregroundColor: SalusColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon, String label) {
    final selected = _index == index && _incidentId == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => _go(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? SalusColors.mint.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? SalusColors.mint.withValues(alpha: 0.3) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? SalusColors.mint : SalusColors.muted,
              ),
              const SizedBox(width: 11),
              Text(
                label,
                style: TextStyle(
                  color: selected ? SalusColors.text : SalusColors.muted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (selected)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: SalusColors.mint, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileBar(BuildContext context, Map<String, dynamic> org) {
    final items = [
      (Icons.space_dashboard_outlined, 'Home'),
      (Icons.dataset_outlined, 'Data'),
      (Icons.travel_explore, 'Investigate'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: SalusColors.surface,
        border: Border(bottom: BorderSide(color: SalusColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: SalusColors.mint, size: 20),
          const SizedBox(width: 8),
          const Text(
            'SALUS',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              asString(org['name']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: SalusColors.muted, fontSize: 11.5),
            ),
          ),
          ...List.generate(items.length, (index) {
            return IconButton(
              onPressed: () => _go(index),
              icon: Icon(
                items[index].$1,
                size: 20,
                color: _index == index && _incidentId == null
                    ? SalusColors.mint
                    : SalusColors.muted,
              ),
              tooltip: items[index].$2,
            );
          }),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, size: 18, color: SalusColors.muted),
          ),
        ],
      ),
    );
  }
}
