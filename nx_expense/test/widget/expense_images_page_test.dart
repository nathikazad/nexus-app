import 'package:nx_expense/data/sync/expense_sync_providers.dart';
import 'package:nx_expense/features/desktop/desktop_shell.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_expense/data/images/expense_images.dart';
import 'package:nx_expense/domain/images/expense_image.dart';
import 'package:nx_expense/features/images/expense_images_page.dart';

class _Picker extends Mock implements ImagePicker {}

class _Client extends Mock implements NexusAuthenticatedClient {}

class _Auth extends AuthController {
  @override
  Future<User?> build() async =>
      User(userId: '1', preset: BackendPreset.localhost, domainId: 1);
}

final _images = [
  ExpenseImage(id: '1', time: DateTime(2026, 9, 16), filename: 'a.jpg'),
  ExpenseImage(
    id: '2',
    time: DateTime(2026, 9, 15),
    filename: 'b.jpg',
    links: const [
      ImageModelLink(id: 8, name: 'Trader Joes', type: 'Expense'),
      ImageModelLink(id: 9, name: 'Order 9', type: 'Order'),
    ],
  ),
];
void main() {
  setUpAll(
    () => registerFallbackValue(
      http.MultipartRequest('POST', Uri.parse('https://example.com/snapshots')),
    ),
  );
  for (final size in [const Size(320, 740), const Size(1100, 740)]) {
    testWidgets('Images navigation fits ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/images',
        routes: [
          GoRoute(
            path: '/images',
            builder: (_, state) => DesktopShell(
              uri: state.uri,
              child: const ExpenseImagesScreen(),
              buildDestination: (_) => const SizedBox(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [expenseImagesProvider.overrideWith((ref) async => [])],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(find.text('Add receipt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('All, Unlinked, Linked filters and image detail links', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/images',
      routes: [
        GoRoute(
          path: '/images',
          builder: (_, state) => ExpenseImagesScreen(
            filter: state.uri.queryParameters['filter'] ?? 'all',
          ),
        ),
        GoRoute(
          path: '/images/:id',
          builder: (_, state) => ExpenseImageDetailScreen(
            id: state.pathParameters['id']!,
            time: state.uri.queryParameters['time'],
          ),
        ),
        GoRoute(
          path: '/expense/:id',
          builder: (_, _) => const Scaffold(body: Text('Expense destination')),
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (_, _) => const Scaffold(body: Text('Order destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageBaseUrlProvider.overrideWith((ref) => null),
          expenseImagesProvider.overrideWith((ref) async => _images),
          expenseImageProvider.overrideWith(
            (ref, key) async => _images.firstWhere((e) => e.id == key.id),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNWidgets(2));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Unlinked'));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Linked'));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsOneWidget);
    await tester.tap(find.byType(Card));
    await tester.pumpAndSettle();
    expect(find.text('Trader Joes'), findsOneWidget);
    expect(find.text('Order 9'), findsOneWidget);
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trader Joes'));
    await tester.pumpAndSettle();
    expect(find.text('Expense destination'), findsOneWidget);
  });
  testWidgets(
    'upload creates a standalone timeline image and refreshes gallery',
    (tester) async {
      final picker = _Picker();
      final client = _Client();
      var uploaded = false;
      http.MultipartRequest? request;
      when(
        () => picker.pickImage(source: ImageSource.gallery, imageQuality: 85),
      ).thenAnswer(
        (_) async =>
            XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'receipt.png'),
      );
      when(() => client.send(any())).thenAnswer((call) async {
        request = call.positionalArguments.first as http.MultipartRequest;
        uploaded = true;
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'status': 'applied',
                'filename': 'a.jpg',
                'entity': {'event_id': '1', 'event_time': '2026-09-16T10:15:00'},
              }),
            ),
          ),
          200,
        );
      });
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ExpenseImagesScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            expenseAssetsProvider.overrideWithValue(null),
            imageBaseUrlProvider.overrideWith((ref) => 'https://example.com'),
            userIdProvider.overrideWith((ref) => '1'),
            nexusHttpClientProvider.overrideWithValue(client),
            nexusRequestHeadersProvider.overrideWith((ref) async => {}),
            expenseImagePickerProvider.overrideWithValue(picker),
            expenseImagesProvider.overrideWith(
              (ref) async => uploaded ? [_images.first] : [],
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await ProviderScope.containerOf(
        tester.element(find.byType(ExpenseImagesScreen)),
      ).read(authProvider.future);
      await tester.tap(find.text('Add receipt'));
      await tester.pumpAndSettle();
      expect(find.text('Choose PDF'), findsOneWidget);
      await tester.tap(find.text('Choose image'));
      await tester.pumpAndSettle();
      expect(uploaded, isTrue);
      expect(request!.url.path, '/apps/expense/receipts');
      expect(request!.fields['domain_id'], '1');
      expect(request!.fields['operation_id'], isNotEmpty);
      expect(request!.fields.containsKey('modelId'), isFalse);
      expect(find.byType(Card), findsOneWidget);
      expect(
        find.text('Receipt uploaded. Ready to reconcile later.'),
        findsOneWidget,
      );
    },
  );
}
