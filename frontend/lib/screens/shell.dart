import '../icons.dart';

import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../utils.dart';
import 'command_center.dart';
import 'data_discovery.dart';
import '../incident/incident_screen.dart';
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
          color: SalusColors.background,
          image: DecorationImage(
            image: AssetImage('assets/paper.png'),
            repeat: ImageRepeat.repeat,
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

  Widget _sidebar(
    BuildContext context,
    Map<String, dynamic> org,
    Map<String, dynamic> user,
  ) {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: SalusColors.surface,
        border: Border(right: BorderSide(color: SalusColors.border)),
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
                    color: SalusColors.cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: SalusColors.cobalt.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    SalusIcons.shield,
                    color: SalusColors.cobalt,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALUS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                      ),
                    ),
                    Text(
                      'INVESTIGATION DESK',
                      style: TextStyle(
                        fontSize: 8,
                        color: SalusColors.muted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
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
                    backgroundColor: SalusColors.cobalt.withValues(alpha: 0.16),
                    child: Text(
                      initials(asString(user['name'], 'S')),
                      style: const TextStyle(
                        color: SalusColors.cobalt,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        Text(
                          '${asString(user['name'])}  |  ${asString(user['role'])}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SalusColors.muted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _navItem(context, 0, SalusIcons.dashboard, 'Command center'),
          _navItem(context, 1, SalusIcons.database, 'Data discovery'),
          _navItem(context, 2, SalusIcons.investigate, 'Investigation'),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SalusColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SalusColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        SalusIcons.flask,
                        size: 13,
                        color: SalusColors.secondary,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Demo mode',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Synthetic data. Simulated events are labelled.',
                    style: TextStyle(
                      color: SalusColors.muted,
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(SalusIcons.signOut, size: 15),
              label: const Text('Sign out'),
              style: TextButton.styleFrom(foregroundColor: SalusColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final selected = _index == index && _incidentId == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => _go(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? SalusColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? SalusColors.ink.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? SalusColors.ink : SalusColors.muted,
              ),
              const SizedBox(width: 11),
              Text(
                label,
                style: TextStyle(
                  color: selected ? SalusColors.ink : SalusColors.muted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (selected)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: SalusColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileBar(BuildContext context, Map<String, dynamic> org) {
    final items = [
      (SalusIcons.dashboard, 'Home'),
      (SalusIcons.database, 'Data'),
      (SalusIcons.investigate, 'Investigate'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: SalusColors.surface,
        border: Border(bottom: BorderSide(color: SalusColors.border)),
      ),
      child: Row(
        children: [
          const Icon(SalusIcons.shield, color: SalusColors.cobalt, size: 20),
          const SizedBox(width: 8),
          const Text(
            'SALUS',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 2.5),
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
                color: _index == index ? SalusColors.ink : SalusColors.muted,
              ),
              tooltip: items[index].$2,
            );
          }),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(
              SalusIcons.signOut,
              size: 18,
              color: SalusColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
