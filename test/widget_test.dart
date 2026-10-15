import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dwell/main.dart';
import 'package:dwell/store.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DwellStore', () {
    test(
      'demo completion marks the chore and schedules the next occurrence',
      () async {
        final store = DwellStore();
        store.startDemo();
        final original = store.chores.firstWhere((c) => c.id == '1');
        final oldLength = store.chores.length;

        await store.complete(original);

        final finished = store.chores.firstWhere((c) => c.id == '1');
        final next = store.chores.singleWhere(
          (c) => c.id != '1' && c.title == original.title,
        );
        expect(finished.done, isTrue);
        expect(finished.completedAt, store.today);
        expect(store.chores, hasLength(oldLength + 1));
        expect(next.done, isFalse);
        expect(
          next.due,
          dayKey(DateTime.parse(store.today).add(const Duration(days: 1))),
        );
        store.dispose();
      },
    );

    test(
      'authentication and membership refresh use the configured server',
      () async {
        final values = <String, String>{};
        _installStorageMock(values);
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(_secureStorageChannel, null),
        );

        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (path.endsWith('/api/register')) {
            return http.Response(
              jsonEncode({
                'token': 'session-token',
                'user': {
                  'id': 'u1',
                  'name': 'Taylor Reed',
                  'email': 'taylor@example.test',
                },
              }),
              201,
            );
          }
          if (path.endsWith('/api/me')) {
            expect(request.headers['authorization'], 'Bearer session-token');
            return http.Response(
              jsonEncode({
                'user': {
                  'id': 'u1',
                  'name': 'Taylor Reed',
                  'email': 'taylor@example.test',
                },
                'households': [
                  {'id': 'h1', 'name': 'Maple apartment', 'code': 'ABC123'},
                ],
              }),
              200,
            );
          }
          if (path.endsWith('/api/households/h1')) {
            return http.Response(
              jsonEncode({
                'household': {
                  'id': 'h1',
                  'name': 'Maple apartment',
                  'code': 'ABC123',
                },
                'members': [
                  {'id': 'u1', 'name': 'Taylor Reed'},
                  {'id': 'u2', 'name': 'Morgan Lane'},
                ],
                'chores': [
                  {
                    'id': 'c1',
                    'title': 'Wipe counters',
                    'room': 'Kitchen',
                    'due': '2026-10-16',
                    'assignee_id': 'u2',
                    'done': 0,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        });
        final store = DwellStore(
          client: client,
          storage: const FlutterSecureStorage(),
        )..server = 'https://dwell.example.test';
        addTearDown(store.dispose);

        await store.authenticate(
          email: 'taylor@example.test',
          password: 'very-secure-pass',
          name: 'Taylor Reed',
        );

        expect(requests.map((r) => '${r.method} ${r.url.path}'), [
          'POST /api/register',
          'GET /api/me',
          'GET /api/households/h1',
        ]);
        expect(jsonDecode(requests.first.body), {
          'email': 'taylor@example.test',
          'password': 'very-secure-pass',
          'name': 'Taylor Reed',
        });
        expect(store.userId, 'u1');
        expect(store.household?['id'], 'h1');
        expect(store.members, hasLength(2));
        expect(store.chores.single.assigneeId, 'u2');
        expect(store.memberName('u2'), 'Morgan Lane');
        expect(values['token'], 'session-token');
        expect(values['household'], 'h1');
      },
    );

    test(
      'a failed server probe preserves the current session and server',
      () async {
        final values = <String, String>{};
        _installStorageMock(values);
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(_secureStorageChannel, null),
        );
        final requests = <http.BaseRequest>[];
        final client = MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/register') {
            return http.Response(
              jsonEncode({
                'token': 'kept-token',
                'user': {
                  'id': 'u1',
                  'name': 'Taylor',
                  'email': 't@example.test',
                },
              }),
              201,
            );
          }
          if (request.url.path == '/api/me') {
            return http.Response(
              jsonEncode({
                'user': {
                  'id': 'u1',
                  'name': 'Taylor',
                  'email': 't@example.test',
                },
                'households': [],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'service': 'other'}), 200);
        });
        final store = DwellStore(
          client: client,
          storage: const FlutterSecureStorage(),
        )..server = 'https://old.example.test';
        addTearDown(store.dispose);
        await store.authenticate(
          email: 't@example.test',
          password: 'password123',
          name: 'Taylor',
        );

        await expectLater(
          store.setServer('https://wrong.example.test'),
          throwsA(isA<ApiException>()),
        );

        expect(store.server, 'https://old.example.test');
        expect(store.userId, 'u1');
        expect(values['token'], 'kept-token');
        final probe = requests.last as http.Request;
        expect(probe.url.host, 'wrong.example.test');
        expect(probe.headers.containsKey('authorization'), isFalse);
        expect(
          requests
              .where((r) => r.url.host == 'wrong.example.test')
              .map((r) => r.url.path),
          ['/api/health'],
        );
      },
    );

    test(
      'sign out clears the local session when logout cannot reach the server',
      () async {
        final values = <String, String>{};
        _installStorageMock(values);
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(_secureStorageChannel, null),
        );
        final client = MockClient((request) async {
          if (request.url.path == '/api/register') {
            return http.Response(
              jsonEncode({
                'token': 'offline-token',
                'user': {
                  'id': 'u1',
                  'name': 'Taylor',
                  'email': 't@example.test',
                },
              }),
              201,
            );
          }
          if (request.url.path == '/api/me') {
            return http.Response(
              jsonEncode({
                'user': {
                  'id': 'u1',
                  'name': 'Taylor',
                  'email': 't@example.test',
                },
                'households': [],
              }),
              200,
            );
          }
          throw const SocketException('offline');
        });
        final store = DwellStore(
          client: client,
          storage: const FlutterSecureStorage(),
        )..server = 'https://offline.example.test';
        addTearDown(store.dispose);
        await store.authenticate(
          email: 't@example.test',
          password: 'password123',
          name: 'Taylor',
        );

        await store.signOut();

        expect(store.user, isNull);
        expect(store.household, isNull);
        expect(values.containsKey('token'), isFalse);
      },
    );
  });

  testWidgets(
    'auth form validates missing name, malformed email, and short password',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = DwellStore()..ready = true;
      await tester.pumpWidget(DwellApp(store: store));

      await tester.tap(find.text('Create account  →'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your name'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your name'),
        'Taylor',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'not-an-email',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'short',
      );
      await tester.tap(find.text('Create account  →'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Use 8–128 characters'), findsOneWidget);
      store.dispose();
    },
  );

  testWidgets('mobile navigation filters chores by assignee and completion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = DwellStore()..startDemo();
    await tester.pumpWidget(DwellApp(store: store));

    await tester.tap(find.text('Chores').last);
    await tester.pumpAndSettle();
    expect(find.text('Take out the recycling'), findsOneWidget);
    await tester.tap(find.text('Assigned to me'));
    await tester.pumpAndSettle();
    expect(find.text('Take out the recycling'), findsNothing);
    expect(find.text('Give the kitchen a little love'), findsOneWidget);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh towels, fresh start'), findsOneWidget);
    expect(find.text('Give the kitchen a little love'), findsNothing);
    store.dispose();
  });

  testWidgets('add and edit chore form persists values in demo home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = DwellStore()..startDemo();
    await tester.pumpWidget(DwellApp(store: store));

    await tester.tap(find.text('Add chore'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What needs doing?'),
      'Feed the cat',
    );
    await tester.ensureVisible(find.text('Add to our home  →'));
    await tester.tap(find.text('Add to our home  →'));
    await tester.pumpAndSettle();
    expect(store.chores.any((c) => c.title == 'Feed the cat'), isTrue);

    await tester.tap(find.text('Chores').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Feed the cat'));
    await tester.tap(find.text('Feed the cat'));
    await tester.pumpAndSettle();
    final titleField = find.widgetWithText(TextFormField, 'What needs doing?');
    await tester.ensureVisible(titleField);
    await tester.enterText(titleField, 'Feed the very happy cat');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(
      store.chores.any((c) => c.title == 'Feed the very happy cat'),
      isTrue,
    );
    expect(store.chores.any((c) => c.title == 'Feed the cat'), isFalse);
    store.dispose();
  });

  testWidgets('render mobile and wide demo screenshots', (tester) async {
    await tester.runAsync(() => _loadSdkFonts(tester));
    final store = DwellStore()..startDemo();
    addTearDown(store.dispose);
    final repaintKey = GlobalKey();

    for (final size in [const Size(430, 932), const Size(1280, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintKey,
          child: DwellApp(store: store),
        ),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(repaintKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final filename = size.width > 900
            ? 'dwell-desktop.png'
            : 'dwell-phone.png';
        final output = File('artifacts/$filename');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        expect(await output.length(), greaterThan(10000));
      });
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _loadSdkFonts(WidgetTester tester) async {
  // Load Flutter's shipped fonts instead of relying on the test-only Ahem font.
  const root = '.tooling/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          await File('$root/Roboto-Regular.ttf').readAsBytes(),
        ),
      ),
    );
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          await File('$root/MaterialIcons-Regular.otf').readAsBytes(),
        ),
      ),
    );
  await icons.load();
}

void _installStorageMock(Map<String, String> values) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
        final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
        switch (call.method) {
          case 'read':
            return values[args['key']];
          case 'write':
            values[args['key'] as String] = args['value'] as String;
            return null;
          case 'delete':
            values.remove(args['key']);
            return null;
          case 'containsKey':
            return values.containsKey(args['key']);
          default:
            return null;
        }
      });
}
