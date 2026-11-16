import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PickedFile {
  PickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class ApiClient {
  ApiClient({String? baseUrl})
      : root = (baseUrl ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8000'))
            .replaceAll(RegExp(r'/$'), '');

  final String root;
  String? token;
  final http.Client _client = http.Client();

  String get baseUrl => '$root/api/v1';

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Token $token',
      };

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else {
          body = {'data': decoded};
        }
      } catch (_) {
        body = {'detail': response.body};
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final detail = body['detail'] ?? body['message'] ?? 'Request failed (${response.statusCode})';
    throw ApiException(detail.toString(), statusCode: response.statusCode);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _client
        .get(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  Future<Map<String, dynamic>> login(String email) async {
    final body = await post('/auth/demo-login', {'email': email});
    token = body['token']?.toString();
    return body;
  }

  void logout() {
    token = null;
  }

  Future<Map<String, dynamic>> health() => get('/health');
  Future<Map<String, dynamic>> overview() => get('/overview');
  Future<Map<String, dynamic>> me() => get('/organizations/me');
  Future<Map<String, dynamic>> policy() => get('/risk/policy');
  Future<Map<String, dynamic>> seedDemo() => post('/dev/seed', {'reset': false});
  Future<Map<String, dynamic>> renameDemo() => post('/dev/seed', {'reset': true});

  Future<List<dynamic>> assets({bool includeBaseline = false}) async {
    final body = await get('/assets${includeBaseline ? '?include_baseline=1' : ''}');
    return body['results'] as List<dynamic>? ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> asset(String id) => get('/assets/$id');

  Future<List<dynamic>> incidents() async {
    final body = await get('/incidents');
    return body['results'] as List<dynamic>? ?? <dynamic>[];
  }

  Future<Map<String, dynamic>> incident(String id) => get('/incidents/$id');

  Future<Map<String, dynamic>> updateStatus(String id, String status) =>
      post('/incidents/$id/status', {'status': status});

  Future<Map<String, dynamic>> regenerateReport(String id) =>
      post('/incidents/$id/report');

  Future<Map<String, dynamic>> runSimulator() =>
      post('/simulator/run', {'scenario': 'ghost_copy'});

  Future<Map<String, dynamic>> investigate(PickedFile file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/investigations'));
    request.headers.addAll(_headers);
    request.files.add(http.MultipartFile.fromBytes('file', file.bytes, filename: file.name));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<List<dynamic>> events({String? assetId, int limit = 100}) async {
    final query = StringBuffer('?limit=$limit');
    if (assetId != null) query.write('&asset_id=$assetId');
    final body = await get('/events$query');
    return body['results'] as List<dynamic>? ?? <dynamic>[];
  }
}
