import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

String dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class Chore {
  final String id, title, room, due, repeat;
  final String? assigneeId, completedAt;
  final bool done;
  Chore(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      room = json['room'] as String,
      due = json['due'] as String,
      repeat = json['repeat'] as String? ?? 'none',
      assigneeId = json['assignee_id'] as String?,
      completedAt = json['completed_at'] as String?,
      done = json['done'] == 1 || json['done'] == true;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'room': room,
    'due': due,
    'repeat': repeat,
    'assignee_id': assigneeId,
    'done': done,
    'completed_at': completedAt,
  };
}

class DwellStore extends ChangeNotifier {
  DwellStore({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;
  String server = const String.fromEnvironment('API_URL');
  static const _offlineDataKey = 'offlineData';
  static const _offlineModeKey = 'offlineMode';
  static const _darkModeKey = 'darkMode';
  String? _token;
  Map<String, dynamic>? user, household;
  List<Map<String, dynamic>> households = [], members = [];
  List<Chore> chores = [];
  bool ready = false, demo = false, offline = false, darkMode = false;
  String? startupError;
  String get userId => user?['id'] as String? ?? '';
  String get firstName =>
      (user?['name'] as String? ?? 'there').split(' ').first;
  String get today => dayKey(DateTime.now());
  String memberName(String? id) => id == null
      ? 'Anyone'
      : id == userId
      ? 'You'
      : members
                .where((m) => m['id'] == id)
                .map((m) => m['name'] as String)
                .firstOrNull ??
            'Housemate';

  Future<void> initialize() async {
    if (server.isEmpty) {
      server = kIsWeb
          ? Uri.base.origin
          : defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8080'
          : '';
    }
    try {
      server = await _storage.read(key: 'server') ?? server;
      offline = await _storage.read(key: _offlineModeKey) == 'true';
      darkMode = await _storage.read(key: _darkModeKey) == 'true';
      if (offline) {
        await _loadOfflineHome();
      } else {
        _token = await _storage.read(key: 'token');
        if (_token != null) await refresh();
      }
    } catch (e) {
      startupError = e.toString();
    }
    ready = true;
    notifyListeners();
  }

  Future<void> loadDarkMode() async {
    darkMode = await _storage.read(key: _darkModeKey) == 'true';
  }

  Future<void> setDarkMode(bool enabled) async {
    await _storage.write(key: _darkModeKey, value: enabled ? 'true' : 'false');
    darkMode = enabled;
    notifyListeners();
  }

  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      final response = await _client
          .send(
            http.Request(method, Uri.parse('$server/api$path'))
              ..headers.addAll({
                'Content-Type': 'application/json',
                if (_token != null) 'Authorization': 'Bearer $_token',
              })
              ..body = body == null ? '' : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      final text = await response.stream.bytesToString().timeout(
        const Duration(seconds: 15),
      );
      dynamic data;
      try {
        data = jsonDecode(text);
      } catch (_) {
        throw const ApiException(
          'This address is not a Dwell server. Check your server URL.',
        );
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 &&
            path != '/login' &&
            path != '/register') {
          _token = null;
          user = null;
          await _storage.delete(key: 'token');
          notifyListeners();
        }
        throw ApiException(
          data is Map
              ? data['error'] as String? ?? 'Request failed.'
              : 'Request failed.',
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Your server took too long to respond. Try again.',
      );
    } catch (_) {
      throw const ApiException(
        'Could not reach your server. Check the address and your connection.',
      );
    }
  }

  Future<void> setServer(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const ApiException(
        'Enter a server address such as https://dwell.example.com.',
      );
    }
    final next = value.trim().replaceFirst(RegExp(r'/+$'), '');
    // Probe without credentials: a new host must never receive the old session.
    try {
      final response = await _client
          .get(Uri.parse('$next/api/health'))
          .timeout(const Duration(seconds: 15));
      final health = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          health is! Map ||
          health['service'] != 'dwell') {
        throw const ApiException('This address is not a Dwell server.');
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Could not reach a Dwell server at this address.',
      );
    }
    if (next != server) {
      await signOut();
      server = next;
      await _storage.write(key: 'server', value: server);
    }
    notifyListeners();
  }

  Future<void> authenticate({
    required String email,
    required String password,
    String? name,
  }) async {
    final data = await request('POST', name == null ? '/login' : '/register', {
      'email': email,
      'password': password,
      'name': ?name,
    });
    _token = data['token'] as String;
    await _storage.write(key: 'token', value: _token);
    await _storage.write(key: 'server', value: server);
    await _storage.write(key: _offlineModeKey, value: 'false');
    demo = false;
    offline = false;
    await refresh();
  }

  Future<void> refresh() async {
    if (demo || offline) {
      notifyListeners();
      return;
    }
    final data = await request('GET', '/me');
    user = Map<String, dynamic>.from(data['user'] as Map);
    households = (data['households'] as List)
        .map((g) => Map<String, dynamic>.from(g as Map))
        .toList();
    final selected = household?['id'] ?? await _storage.read(key: 'household');
    if (households.isNotEmpty) {
      await selectHousehold(
        households.where((g) => g['id'] == selected).firstOrNull ??
            households.first,
      );
    } else {
      household = null;
      members = [];
      chores = [];
      notifyListeners();
    }
  }

  Future<void> selectHousehold(Map<String, dynamic> group) async {
    if (demo || offline) return;
    final data = await request('GET', '/households/${group['id']}');
    household = Map<String, dynamic>.from(data['household'] as Map);
    members = (data['members'] as List)
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
    chores = (data['chores'] as List)
        .map((c) => Chore(Map<String, dynamic>.from(c as Map)))
        .toList();
    await _storage.write(key: 'household', value: group['id'] as String);
    notifyListeners();
  }

  Future<void> createHousehold(String name) async {
    if (demo || offline) {
      throw const ApiException('Create an account to add your own household.');
    }
    final group = await request('POST', '/households', {'name': name});
    household = Map<String, dynamic>.from(group as Map);
    await refresh();
  }

  Future<void> joinHousehold(String code) async {
    if (demo || offline) {
      throw const ApiException('Create an account to join your household.');
    }
    final group = await request('POST', '/join', {'code': code});
    household = Map<String, dynamic>.from(group as Map);
    await refresh();
  }

  Future<void> saveChore(Map<String, dynamic> values, {String? id}) async {
    if (demo || offline) {
      final index = chores.indexWhere((c) => c.id == id);
      final chore = Chore({
        ...values,
        'id': id ?? 'demo-${DateTime.now().microsecondsSinceEpoch}',
      });
      if (index == -1) {
        chores.add(chore);
      } else {
        chores[index] = chore;
      }
      if (offline) await _saveOfflineHome();
      notifyListeners();
      return;
    }
    await request(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/households/${household!['id']}/chores' : '/chores/$id',
      values,
    );
    await refresh();
  }

  Future<void> complete(Chore chore) async {
    if (demo || offline) {
      if (chore.done && chore.repeat != 'none') {
        throw const ApiException(
          'Edit the next occurrence of this repeating chore.',
        );
      }
      final index = chores.indexWhere((c) => c.id == chore.id);
      chores[index] = Chore({
        ...chore.toJson(),
        'done': !chore.done,
        'completed_at': chore.done ? null : today,
      });
      if (!chore.done && chore.repeat != 'none') {
        final due = DateTime.parse(chore.due);
        final now = DateTime.parse(today);
        chores.add(
          Chore({
            ...chore.toJson(),
            'id': 'demo-${DateTime.now().microsecondsSinceEpoch}',
            'done': false,
            'completed_at': null,
            'due': dayKey(
              (due.isAfter(now) ? due : now).add(
                Duration(days: chore.repeat == 'daily' ? 1 : 7),
              ),
            ),
          }),
        );
      }
      if (offline) await _saveOfflineHome();
      notifyListeners();
      return;
    }
    await request('PATCH', '/chores/${chore.id}', {'done': !chore.done});
    await refresh();
  }

  Future<void> deleteChore(Chore chore) async {
    if (demo || offline) {
      chores.removeWhere((c) => c.id == chore.id);
      if (offline) await _saveOfflineHome();
      notifyListeners();
      return;
    }
    await request('DELETE', '/chores/${chore.id}');
    await refresh();
  }

  Future<void> signOut() async {
    if (!demo && _token != null) {
      try {
        await request('POST', '/logout');
      } on ApiException {
        // Local sign-out must also work when the home server is offline.
      }
    }
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'household');
    await _storage.write(key: _offlineModeKey, value: 'false');
    _token = null;
    user = null;
    household = null;
    households = [];
    members = [];
    chores = [];
    demo = false;
    offline = false;
    startupError = null;
    notifyListeners();
  }

  Future<void> startOffline() async {
    demo = false;
    offline = true;
    _token = null;
    await _loadOfflineHome();
    await _storage.write(key: _offlineModeKey, value: 'true');
    ready = true;
    notifyListeners();
  }

  Future<void> _loadOfflineHome() async {
    final raw = await _storage.read(key: _offlineDataKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        user = Map<String, dynamic>.from(data['user'] as Map);
        household = Map<String, dynamic>.from(data['household'] as Map);
        members = (data['members'] as List)
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
        chores = (data['chores'] as List)
            .map((c) => Chore(Map<String, dynamic>.from(c as Map)))
            .toList();
        households = [household!];
        return;
      } catch (_) {
        throw const ApiException(
          'Your saved offline home could not be read. Its data is still stored on this device.',
        );
      }
    }
    user = {
      'id': 'offline-user',
      'name': 'You',
      'email': 'Saved on this device',
    };
    household = {
      'id': 'offline-home',
      'name': 'My home',
      'owner_id': 'offline-user',
    };
    households = [household!];
    members = [
      {'id': 'offline-user', 'name': 'You'},
    ];
    chores = [];
    await _saveOfflineHome();
  }

  Future<void> _saveOfflineHome() async {
    await _storage.write(
      key: _offlineDataKey,
      value: jsonEncode({
        'user': user,
        'household': household,
        'members': members,
        'chores': chores.map((chore) => chore.toJson()).toList(),
      }),
    );
  }

  void startDemo() {
    demo = true;
    offline = false;
    user = {'id': 'alex', 'name': 'Alex Morgan', 'email': 'alex@example.com'};
    household = {
      'id': 'demo',
      'name': 'The Willow apartment',
      'code': 'DEMO2026',
      'owner_id': 'alex',
    };
    households = [household!];
    members = [
      {'id': 'alex', 'name': 'Alex'},
      {'id': 'jamie', 'name': 'Jamie'},
      {'id': 'sam', 'name': 'Sam'},
    ];
    final now = DateTime.now();
    chores = [
      Chore({
        'id': '1',
        'title': 'Give the kitchen a little love',
        'room': 'Kitchen',
        'assignee_id': 'alex',
        'due': today,
        'repeat': 'daily',
      }),
      Chore({
        'id': '2',
        'title': 'Take out the recycling',
        'room': 'Shared spaces',
        'assignee_id': 'jamie',
        'due': today,
        'repeat': 'weekly',
      }),
      Chore({
        'id': '3',
        'title': 'Water our green friends',
        'room': 'Living room',
        'assignee_id': 'alex',
        'due': today,
        'repeat': 'weekly',
      }),
      Chore({
        'id': '4',
        'title': 'Fresh towels, fresh start',
        'room': 'Bathroom',
        'assignee_id': 'sam',
        'due': today,
        'repeat': 'weekly',
        'done': true,
        'completed_at': today,
      }),
      Chore({
        'id': '5',
        'title': 'Vacuum the living room',
        'room': 'Living room',
        'assignee_id': 'sam',
        'due': dayKey(now.add(const Duration(days: 1))),
        'repeat': 'weekly',
      }),
      Chore({
        'id': '6',
        'title': 'Change the bedsheets',
        'room': 'Bedroom',
        'assignee_id': 'alex',
        'due': dayKey(now.add(const Duration(days: 2))),
        'repeat': 'weekly',
      }),
    ];
    ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
