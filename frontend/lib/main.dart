import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

void main() {
  runApp(const SalusApp());
}

class SalusApp extends StatefulWidget {
  const SalusApp({super.key});

  @override
  State<SalusApp> createState() => _SalusAppState();
}

class _SalusAppState extends State<SalusApp> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _session;

  void _handleAuthenticated(Map<String, dynamic> session) {
    setState(() => _session = session);
  }

  void _logout() {
    _api.logout();
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SALUS',
      debugShowCheckedModeBanner: false,
      theme: buildSalusTheme(),
      home: _session == null
          ? LoginScreen(api: _api, onAuthenticated: _handleAuthenticated)
          : Shell(api: _api, session: _session!, onLogout: _logout),
    );
  }
}
