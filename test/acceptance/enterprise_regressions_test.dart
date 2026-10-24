import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/composition.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/features/identity/data/repository.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/attendance/domain/correction_time.dart';
import 'package:hrflow_mobile/core/leave_quantity.dart';
import 'package:hrflow_mobile/features/leave/domain/models.dart';
import 'package:hrflow_mobile/features/requests/data/repository.dart';
import 'package:hrflow_mobile/features/settings/domain/preferences_gateway.dart';
import 'package:hrflow_mobile/features/workflows/presentation/workflow_pages.dart';
import 'package:hrflow_mobile/shared/domain/cases.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

// Red tests: each assertion states the required behavior, never the known defect.
// Keep these in the normal test tree so later fixes must turn them green.
class _Preferences implements PreferencesGateway {
  const _Preferences();
  @override
  Future<bool?> read(String key) async => false;
  @override
  Future<void> write(String key, bool value) async {}
}

class _PagedRequests extends RequestsDataRepository {
  int reads = 0;
  String lastSearch = '', lastStatus = '';
  int lastPage = 0;
  _PagedRequests(super.client);

  @override
  Future<RecordPage> recordsPage(
    String kind, {
    bool pending = false,
    int page = 0,
    int size = 25,
    String search = '',
    String status = '',
    String sort = '',
  }) async {
    reads++;
    lastSearch = search;
    lastStatus = status;
    lastPage = page;
    if (search.toLowerCase() == 'special laptop') {
      return RecordPage(
        [
          WorkflowRecord(
            id: 'acceptance-25',
            employeeId: 'demo-employee',
            title: 'Special laptop',
            status: 'DRAFT',
            reason: 'Equipment',
            kind: 'request',
            version: 1,
            fields: const {},
            employeeName: 'Sok Dara',
          ),
        ],
        1,
        page,
        size,
      );
    }
    if (status == 'APPROVED') {
      return RecordPage(
        [
          WorkflowRecord(
            id: 'acceptance-approved',
            employeeId: 'demo-employee',
            title: 'Approved conference',
            status: 'APPROVED',
            reason: 'Business event',
            kind: 'request',
            version: 1,
            fields: const {},
            employeeName: 'Sok Dara',
          ),
        ],
        1,
        page,
        size,
      );
    }
    return RecordPage(
      List.generate(
        page == 0 ? 25 : 1,
        (i) => WorkflowRecord(
          id: 'acceptance-${page * 25 + i}',
          employeeId: 'demo-employee',
          title: page == 0 ? 'Routine request $i' : 'Special laptop',
          status: 'DRAFT',
          reason: 'Equipment',
          kind: 'request',
          version: 1,
          fields: const {},
          employeeName: 'Sok Dara',
        ),
      ),
      26,
      page,
      size,
    );
  }
}

class _PagedPeople extends IdentityDataRepository {
  String lastSearch = '';
  _PagedPeople(super.client);

  @override
  Future<List<CaseRecord>> cases(
    String collection, {
    Map<String, String> filters = const {},
  }) async {
    if (collection != 'identity.people') {
      return super.cases(collection, filters: filters);
    }
    lastSearch = filters['search'] ?? '';
    final page = int.parse(filters['page'] ?? '0');
    if (lastSearch == 'Special Person') {
      return [
        const CaseRecord(
          id: 'special-person',
          title: 'Special Person',
          status: 'ACTIVE',
          version: 1,
          values: {
            'id': 'special-person',
            'name': 'Special Person',
            'version': 1,
          },
        ),
      ];
    }
    return List.generate(
      page == 0 ? 25 : 1,
      (i) => CaseRecord(
        id: 'person-${page * 25 + i}',
        title: 'Routine Person $i',
        status: 'ACTIVE',
        version: 1,
        values: {
          'id': 'person-${page * 25 + i}',
          'name': 'Routine Person $i',
          'version': 1,
        },
      ),
    );
  }
}

class _QueryServer implements DataSource {
  @override
  String get mode => 'remote';
  DataRequest? last;
  @override
  Future<DataResponse> send(DataRequest request) async {
    last = request;
    return DataResponse(200, {'items': <Map<String, dynamic>>[], 'total': 0});
  }

  @override
  void close() {}
}

ClientData _client() => ClientData.forTest(
  LocalDataSource(
    jsonDecode(File('assets/data/demo-seed.json').readAsStringSync())
        as JsonMap,
    populate: true,
    now: () => DateTime.utc(2026, 10, 23, 3),
  ),
);

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

Future<ProviderContainer> _app(
  WidgetTester tester,
  ClientData client, {
  List<Override> additional = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      ...composeFeatures(client, preferences: const _Preferences()).where(
        (base) =>
            !additional.any((replacement) => replacement.origin == base.origin),
      ),
      ...additional,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HrFlowApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('acceptance F09 leave quantities preserve hundredths and units', () {
    const cases = <(num?, String)>[
      (0, '0 days'),
      (0.01, '0.01 days'),
      (0.25, '0.25 days'),
      (0.5, '0.5 days'),
      (1, '1 day'),
      (1.05, '1.05 days'),
      (2.25, '2.25 days'),
      (10, '10 days'),
      (-1, '-1 day'),
      (-2.25, '-2.25 days'),
      (null, '— days'),
      (double.nan, '— days'),
    ];
    for (final (input, expected) in cases) {
      expect(formatLeaveDays(input), expected, reason: '$input');
    }
    expect(leaveBalancePeriod(2026), 'Valid through 31 Dec 2026');
    expect(leaveBalancePeriod(null), 'Balance period unavailable');
  });

  test('acceptance F09 presentation does not format leave days ad hoc', () {
    for (final path in [
      'lib/features/dashboard/presentation/home_page.dart',
      'lib/features/workflows/presentation/workflow_pages.dart',
      'lib/features/leave/presentation/case_pages.dart',
      'lib/features/reporting/presentation/case_pages.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('toStringAsFixed(')), reason: path);
      expect(
        source,
        isNot(matches(RegExp(r"\$\{[^}]+\}\s+days"))),
        reason: path,
      );
    }
  });

  test('acceptance F04 correction timestamps cover overnight, midnight and boundaries', () {
    final day = DateTime(2026, 10, 22);
    final next = DateTime(2026, 10, 23);
    final now = DateTime.utc(2026, 10, 24);
    final start = CorrectionTime.instant(day, 22, 0);
    final overnight = CorrectionTime.instant(next, 6, 0);
    final midnight = CorrectionTime.instant(next, 0, 0);
    expect(overnight.difference(start), const Duration(hours: 8));
    expect(CorrectionTime.validate(start, overnight, now), isNull);
    expect(CorrectionTime.validate(start, midnight, now), isNull);
    expect(
      CorrectionTime.validate(start, CorrectionTime.instant(day, 23, 0), now),
      isNull,
    );
    expect(
      CorrectionTime.validate(start, CorrectionTime.instant(day, 6, 0), now),
      contains('next date'),
    );
    expect(
      CorrectionTime.validate(
        start,
        CorrectionTime.instant(DateTime(2026, 10, 24), 1, 0),
        now,
      ),
      contains('24 hours'),
    );
    expect(
      CorrectionTime.validate(
        CorrectionTime.instant(DateTime(2026, 10, 25), 8, 0),
        CorrectionTime.instant(DateTime(2026, 10, 25), 9, 0),
        now,
      ),
      contains('future'),
    );
    expect(CorrectionTime.display(overnight), '23/10/2026 06:00');
  });

  test('acceptance F01 employee edit persists selected department and position IDs', () async {
    final c = _client();
    addTearDown(c.close);
    await c.demoLogin('HR_ADMIN');
    final repo = IdentityDataRepository(c);
    final before = (await repo.collection('/employees'))
        .firstWhere((r) => r['id'] == 'demo-employee');
    await repo.changeCase(
      'identity.employee.edit',
      'demo-employee',
      {
        'name': before['name'],
        'email': before['email'],
        'departmentId': 'people',
        'positionId': 'designer',
        'managerId': before['managerId'],
      },
      key: commandKey(),
      etag: '"${before['version']}"',
    );
    final stored = (await repo.collection('/employees'))
        .firstWhere((r) => r['id'] == 'demo-employee');
    expect(stored['departmentId'], 'people');
    expect(stored['positionId'], 'designer');
    expect(stored['department'], 'People & Culture');
    expect(stored['position'], 'Product designer');
  });

  test('acceptance F01 shift edit persists weekend workdays', () async {
    final c = _client();
    addTearDown(c.close);
    await c.demoLogin('HR_ADMIN');
    final repo = IdentityDataRepository(c);
    final before = (await repo.collection('/shifts')).first;
    await repo.changeCase(
      'identity.shift.edit',
      before['id'] as String,
      {
        'name': before['name'],
        'startTime': before['startTime'],
        'endTime': before['endTime'],
        'workingDays': 96,
        'graceMinutes': 10,
        'earlyToleranceMinutes': 0,
        'reason': 'Weekend coverage',
      },
      key: commandKey(),
      etag: '"${before['version']}"',
    );
    final stored = (await repo.collection('/shifts'))
        .firstWhere((r) => r['id'] == before['id']);
    expect(stored['days'], 'Sat, Sun');
    expect(stored['workingDays'], 96);
    final assignment = await repo.assignShift(
      'demo-employee',
      'shift-standard',
      '2026-11-01',
      null,
      commandKey(),
    );
    expect(assignment.shiftId, 'shift-standard');
    final assigned = (await repo.collection('/employees/demo-employee/shifts'))
        .first;
    expect((assigned['shiftSnapshot'] as Map)['workingDays'], 96);
  });

  test('acceptance F01 unknown employee edit field fails instead of claiming success', () async {
    final c = _client();
    addTearDown(c.close);
    await c.demoLogin('HR_ADMIN');
    final repo = IdentityDataRepository(c);
    final before = (await repo.collection('/employees'))
        .firstWhere((r) => r['id'] == 'demo-employee');
    await expectLater(
      repo.saveEntity('/employees', {
        'unknownEditorField': 'ignored',
      }, existing: before),
      throwsA(
        isA<DataFailure>().having((e) => e.code, 'code', 'VALIDATION_ERROR'),
      ),
    );
  });

  testWidgets(
    'acceptance F01 directory edit uses typed lookups and reloads saved IDs',
    (tester) async {
      final c = _client();
      final container = await _app(tester, c);
      await container.read(sessionProvider.notifier).demo('HR_ADMIN');
      container.read(routerProvider).go('/directory');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sok Dara').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit employee'));
      await tester.pumpAndSettle();
      expect(
        find.byType(DropdownButtonFormField<String>),
        findsAtLeastNWidgets(2),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('People & Culture').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Product designer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      final stored = (await IdentityDataRepository(c).collection('/employees'))
          .firstWhere((r) => r['id'] == 'demo-employee');
      expect(stored['departmentId'], 'people');
      expect(stored['positionId'], 'designer');
    },
  );

  testWidgets(
    'acceptance F01 shift rules edit saves weekend chips through the shared editor',
    (tester) async {
      final c = _client();
      final container = await _app(tester, c);
      await container.read(sessionProvider.notifier).demo('HR_ADMIN');
      container.read(routerProvider).go('/manage/shifts');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Standard workday'));
      await tester.pumpAndSettle();
      expect(find.text('Working days'), findsOneWidget);
      for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
        await tester.tap(find.widgetWithText(FilterChip, day));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byType(TextFormField).last,
        'Weekend coverage',
      );
      await tester.tap(find.text('Review changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      final stored = (await IdentityDataRepository(c).collection('/shifts'))
          .firstWhere((r) => r['id'] == 'shift-standard');
      expect(stored['workingDays'], 96);
      expect(stored['days'], 'Sat, Sun');
    },
  );

  test('acceptance F01 department and position typed editors persist exact catalog values', () async {
    final c = _client();
    addTearDown(c.close);
    await c.demoLogin('HR_ADMIN');
    final repo = IdentityDataRepository(c);
    for (final spec in [
      ('identity.department', '/departments', 'Field Operations'),
      ('identity.position', '/positions', 'Field Supervisor'),
    ]) {
      final created = await repo.changeCase('${spec.$1}.create', null, {
        'name': spec.$3,
      }, key: commandKey());
      final id = created['id'] as String;
      await repo.changeCase(
        '${spec.$1}.edit',
        id,
        {'name': '${spec.$3} II'},
        key: commandKey(),
        etag: '"1"',
      );
      final stored = (await repo.collection(spec.$2))
          .firstWhere((r) => r['id'] == id);
      expect(stored['name'], '${spec.$3} II');
      expect(stored['version'], 2);
      await expectLater(
        repo.saveEntity(spec.$2, {'ignored': 'field'}, existing: stored),
        throwsA(
          isA<DataFailure>().having((e) => e.code, 'code', 'VALIDATION_ERROR'),
        ),
      );
    }
  });

  testWidgets('acceptance F02 search finds a request beyond the first page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = _client();
    final repo = _PagedRequests(c);
    final container = await _app(
      tester,
      c,
      additional: [requestsRepositoryProvider.overrideWithValue(repo)],
    );
    await container.read(sessionProvider.notifier).demo('EMPLOYEE');
    container.read(routerProvider).go('/requests');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Special laptop');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsNothing);
    expect(find.widgetWithText(WorkflowTile, 'Special laptop'), findsOneWidget);
    expect(repo.lastSearch, 'Special laptop');
    expect(
      repo.reads,
      greaterThan(1),
      reason: 'Search must query beyond the first page.',
    );
  });

  testWidgets(
    'acceptance F02 status filter resets paging and queries the full dataset',
    (tester) async {
      final c = _client();
      final repo = _PagedRequests(c);
      final container = await _app(
        tester,
        c,
        additional: [requestsRepositoryProvider.overrideWithValue(repo)],
      );
      await container.read(sessionProvider.notifier).demo('EMPLOYEE');
      container.read(routerProvider).go('/requests');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approved').first);
      await tester.pumpAndSettle();
      expect(repo.lastStatus, 'APPROVED');
      expect(repo.lastPage, 0);
      expect(
        find.widgetWithText(WorkflowTile, 'Approved conference'),
        findsOneWidget,
      );
      expect(find.text('Nothing here yet'), findsNothing);
    },
  );

  testWidgets(
    'acceptance F02 directory search queries beyond the loaded people',
    (tester) async {
      final c = _client();
      final repo = _PagedPeople(c);
      final container = await _app(
        tester,
        c,
        additional: [identityRepositoryProvider.overrideWithValue(repo)],
      );
      await container.read(sessionProvider.notifier).demo('HR_ADMIN');
      container.read(routerProvider).go('/directory');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Special Person');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repo.lastSearch, 'Special Person');
      expect(find.text('Special Person'), findsWidgets);
      expect(find.text('No matches'), findsNothing);
    },
  );

  test(
    'acceptance F02 remote adapter sends server-side query before paging',
    () async {
      final server = _QueryServer();
      final client = ClientData.forTest(server);
      addTearDown(client.close);
      await RequestsDataRepository(client).recordsPage(
        'request',
        page: 2,
        size: 25,
        search: 'laptop',
        status: 'APPROVED',
        sort: 'oldest',
      );
      expect(server.last?.path, '/requests/me');
      expect(server.last?.query, {
        'page': '2',
        'size': '25',
        'search': 'laptop',
        'status': 'APPROVED',
        'sort': 'oldest',
      });
    },
  );

  testWidgets(
    'acceptance F02 approval search sends the query to its repositories',
    (tester) async {
      final c = _client();
      final repo = _PagedRequests(c);
      final container = await _app(
        tester,
        c,
        additional: [requestsRepositoryProvider.overrideWithValue(repo)],
      );
      await container.read(sessionProvider.notifier).demo('MANAGER');
      container.read(routerProvider).go('/approvals');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Special laptop');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repo.lastSearch, 'Special laptop');
      expect(
        find.widgetWithText(WorkflowTile, 'Special laptop'),
        findsOneWidget,
      );
    },
  );

  test('acceptance F03 every semantic text and control pair has contrast', () {
    for (final dark in [false, true]) {
      final colors = appTheme(dark: dark).extension<SemanticColors>()!;
      final textPairs = <String, (Color, Color)>{
        'primary/surface': (colors.textPrimary, colors.surface),
        'primary/card': (colors.textPrimary, colors.card),
        'muted/surface': (colors.textMuted, colors.surface),
        'muted/card': (colors.textMuted, colors.card),
        'error/card': (colors.error, colors.card),
        'success/pill': (colors.success, colors.successBackground),
        'error/pill': (colors.error, colors.errorBackground),
        'warning/pill': (colors.warning, colors.warningBackground),
        'info/pill': (colors.info, colors.infoBackground),
        'muted/neutral pill': (colors.textMuted, colors.card),
        'onError/error': (colors.onError, colors.error),
        'onSuccess/success': (colors.onSuccess, colors.success),
        'onWarning/warning': (colors.onWarning, colors.warning),
        'onInfo/info': (colors.onInfo, colors.info),
        'onHero/hero': (colors.onHero, colors.heroBackground),
        'onHeroMuted/hero': (colors.onHeroMuted, colors.heroBackground),
        'hero button text/button': (colors.heroBackground, colors.onHero),
      };
      for (final entry in textPairs.entries) {
        final ratio = _contrast(entry.value.$1, entry.value.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${dark ? 'dark' : 'light'} ${entry.key}: ${ratio.toStringAsFixed(2)}:1',
        );
      }
      final controlPairs = <String, (Color, Color)>{
        'selected nav/indicator': (
          colors.selectedNav,
          colors.successBackground,
        ),
        'unselected nav/card': (colors.textMuted, colors.card),
        'focus/card': (colors.focusRing, colors.card),
        'focus/surface': (colors.focusRing, colors.surface),
        'divider/card': (colors.divider, colors.card),
        'disabled/card': (colors.disabled, colors.card),
        'hero indicator/hero': (colors.heroSubtle, colors.heroBackground),
      };
      for (final entry in controlPairs.entries) {
        final ratio = _contrast(entry.value.$1, entry.value.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(3),
          reason:
              '${dark ? 'dark' : 'light'} ${entry.key}: ${ratio.toStringAsFixed(2)}:1',
        );
      }
    }
  });

  test('acceptance F03 feature code contains no literal ARGB colors', () {
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          file.path.endsWith('/core/theme.dart')) {
        continue;
      }
      expect(
        File(file.path).readAsStringSync(),
        isNot(contains('Color(0x')),
        reason: file.path,
      );
    }
  });

  testWidgets('acceptance F04 correction exposes a next-day checkout date', (
    tester,
  ) async {
    final c = _client();
    final container = await _app(tester, c);
    await container.read(sessionProvider.notifier).demo('EMPLOYEE');
    container.read(routerProvider).go('/new/correction');
    await tester.pumpAndSettle();
    expect(
      find.text('Correct clock-out date'),
      findsOneWidget,
      reason: '22:00–06:00 must be expressible with an explicit next-day end.',
    );
  });

  test(
    'acceptance F04 overnight correction survives data-layer reload',
    () async {
      final c = _client();
      addTearDown(c.close);
      await c.demoLogin('EMPLOYEE');
      const start = '2026-10-23T15:00:00Z'; // 22:00 in Phnom Penh.
      const end = '2026-10-23T23:00:00Z'; // 06:00 on 24 October.
      final created = await c.request(
        DataRequest(
          'POST',
          '/attendance/corrections',
          body: {
            'workDate': '2026-10-23',
            'newCheckIn': start,
            'newCheckOut': end,
            'reason': 'Overnight shift correction',
          },
          idempotencyKey: commandKey(),
        ),
      );
      final id = (created.data as Map)['id'];
      final reloaded = await c.request(
        DataRequest('GET', '/attendance/corrections/$id'),
      );
      final stored = reloaded.data as Map;
      expect(stored['newCheckIn'], start);
      expect(stored['newCheckOut'], end);
      expect(
        DateTime.parse(stored['newCheckIn'])
            .toUtc()
            .add(const Duration(hours: 7))
            .day,
        23,
      );
      expect(
        DateTime.parse(stored['newCheckOut'])
            .toUtc()
            .add(const Duration(hours: 7))
            .day,
        24,
      );
    },
  );

  testWidgets(
    'acceptance F04 reviewer sees original and proposed dated times',
    (tester) async {
      final c = _client();
      addTearDown(c.close);
      await c.demoLogin('EMPLOYEE');
      final created = await c.request(
        DataRequest(
          'POST',
          '/attendance/corrections',
          body: {
            'workDate': '2026-10-22',
            'newCheckIn': '2026-10-22T15:00:00Z',
            'newCheckOut': '2026-10-22T23:00:00Z',
            'reason': 'Correct overnight session',
          },
          idempotencyKey: commandKey(),
        ),
      );
      final row = created.data as Map;
      expect(row['previousSessions'], isNotEmpty);
      final container = await _app(tester, c);
      await container.read(sessionProvider.notifier).demo('MANAGER');
      container.read(routerProvider).go('/record/correction/${row['id']}');
      await tester.pumpAndSettle();
      expect(find.text('Original recorded time'), findsOneWidget);
      expect(find.text('Proposed correction'), findsOneWidget);
      expect(find.text('22/10/2026 22:00'), findsOneWidget);
      expect(find.text('23/10/2026 06:00'), findsOneWidget);
    },
  );

  testWidgets('acceptance F09 home displays hundredth-day balance unchanged', (
    tester,
  ) async {
    final c = _client();
    final container = await _app(
      tester,
      c,
      additional: [
        balancesProvider.overrideWith(
          (ref) async => const [
            LeaveBalance('annual', 'Annual leave', 20, 17.75, 0, 2.25),
          ],
        ),
      ],
    );
    await container.read(sessionProvider.notifier).demo('EMPLOYEE');
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Annual leave'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Annual leave'), findsWidgets);
    expect(find.textContaining('2.25'), findsWidgets);
  });

  testWidgets('acceptance F08 audit rows retain time of day', (tester) async {
    final c = _client();
    final container = await _app(
      tester,
      c,
      additional: [
        collectionProvider('/audit-logs').overrideWith(
          (ref) async => [
            {
              'action': 'EMPLOYEE_UPDATED',
              'actor': 'HR',
              'at': '2026-10-23T09:15:00+07:00',
            },
            {
              'action': 'EMPLOYEE_UPDATED',
              'actor': 'HR',
              'at': '2026-10-23T16:45:00+07:00',
            },
          ],
        ),
      ],
    );
    await container.read(sessionProvider.notifier).demo('HR_ADMIN');
    container.read(routerProvider).go('/audit');
    await tester.pumpAndSettle();
    expect(find.textContaining('HR ·'), findsNWidgets(2));
    expect(find.textContaining('09:15'), findsOneWidget);
    expect(find.textContaining('16:45'), findsOneWidget);
  });

  testWidgets(
    'acceptance F07 approval dialog keeps decision action visible with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = _client();
      final container = await _app(tester, c);
      await container.read(sessionProvider.notifier).demo('MANAGER');
      container.read(routerProvider).go('/approvals');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal leave'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Approve request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve request'));
      await tester.pump(const Duration(milliseconds: 400));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      final action = find.text('Confirm');
      expect(action, findsOneWidget);
      expect(
        tester.getBottomRight(action).dy,
        lessThanOrEqualTo(440),
        reason:
            'The decision action must remain above the keyboard at 200% text.',
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Personal leave'),
        ),
        findsOneWidget,
        reason: 'The focused decision dialog must identify the request under review.',
      );
    },
  );
  testWidgets('acceptance F10 dirty admin dialog asks before discard', (
    tester,
  ) async {
    final c = _client();
    final container = await _app(tester, c);
    await container.read(sessionProvider.notifier).demo('HR_ADMIN');
    container.read(routerProvider).go('/manage/departments');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add record'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'New department');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this draft?'), findsOneWidget);
  });
}
