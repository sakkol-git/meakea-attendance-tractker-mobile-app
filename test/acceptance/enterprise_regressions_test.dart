import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/composition.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/app/cases.dart';
import 'package:hrflow_mobile/app/feature_panels.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/core/data/cache/cached_source.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/features/identity/data/repository.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/attendance/domain/correction_time.dart';
import 'package:hrflow_mobile/core/leave_quantity.dart';
import 'package:hrflow_mobile/features/leave/domain/models.dart';
import 'package:hrflow_mobile/features/leave/data/repository.dart';
import 'package:hrflow_mobile/features/requests/data/repository.dart';
import 'package:hrflow_mobile/features/settings/domain/preferences_gateway.dart';
import 'package:hrflow_mobile/features/workflows/presentation/workflow_pages.dart';
import 'package:hrflow_mobile/shared/domain/cases.dart';
import 'package:hrflow_mobile/shared/presentation/case_page.dart';
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

class _CompetingReviewerLeave extends LeaveDataRepository {
  _CompetingReviewerLeave(super.client);
  WorkflowRecord? changed;
  int attempts = 0;
  final keys = <String>[];

  @override
  Future<WorkflowRecord> detail(String kind, String id) async =>
      changed ?? super.detail(kind, id);

  @override
  Future<WorkflowRecord> decide(
    WorkflowRecord record,
    String action,
    String note,
    String key,
  ) async {
    attempts++;
    keys.add(key);
    if (attempts == 1) {
      changed = WorkflowRecord(
        id: record.id,
        employeeId: record.employeeId,
        title: record.title,
        status: record.status,
        reason: record.reason,
        kind: record.kind,
        version: record.version + 1,
        fields: record.fields,
        employeeName: record.employeeName,
      );
      throw const DataFailure(
        412,
        'STALE_VERSION',
        'Another reviewer changed it.',
      );
    }
    changed = WorkflowRecord(
      id: record.id,
      employeeId: record.employeeId,
      title: record.title,
      status: 'APPROVED',
      reason: record.reason,
      kind: record.kind,
      version: record.version + 1,
      fields: record.fields,
      employeeName: record.employeeName,
    );
    return changed!;
  }
}

class _LongHistoryLeave extends LeaveDataRepository {
  _LongHistoryLeave(super.client);
  @override
  Future<WorkflowRecord> detail(String kind, String id) async {
    final record = await super.detail(kind, id);
    return WorkflowRecord(
      id: record.id,
      employeeId: record.employeeId,
      title: record.title,
      status: record.status,
      reason: record.reason,
      kind: record.kind,
      version: record.version,
      employeeName: record.employeeName,
      fields: {
        ...record.fields,
        'decisions': List.generate(
          60,
          (index) => {
            'actor': 'Reviewer $index',
            'action': 'COMMENT',
            'note': 'History event $index',
            'at': '2026-10-23T03:00:00Z',
          },
        ),
      },
    );
  }
}

class _TwoPendingLeave extends LeaveDataRepository {
  _TwoPendingLeave(super.client);
  WorkflowRecord? second;
  @override
  Future<RecordPage> recordsPage(
    String kind, {
    bool pending = false,
    int page = 0,
    int size = 25,
    String search = '',
    String status = '',
    String sort = '',
    int minAgeDays = 0,
  }) async {
    final original = await super.recordsPage(
      kind,
      pending: pending,
      page: page,
      size: size,
      search: search,
      status: status,
      sort: sort,
      minAgeDays: minAgeDays,
    );
    if (!pending || kind != 'leave' || original.records.isEmpty) {
      return original;
    }
    final first = original.records.first;
    second = WorkflowRecord(
      id: 'leave-second',
      employeeId: first.employeeId,
      employeeName: first.employeeName,
      title: 'Second leave',
      status: first.status,
      reason: first.reason,
      kind: first.kind,
      version: first.version,
      fields: first.fields,
    );
    return RecordPage([first, second!], 2, page, size);
  }

  @override
  Future<WorkflowRecord> detail(String kind, String id) async =>
      id == 'leave-second' ? second! : super.detail(kind, id);
  @override
  Future<WorkflowRecord> decide(
    WorkflowRecord record,
    String action,
    String note,
    String key,
  ) async => WorkflowRecord(
    id: record.id,
    employeeId: record.employeeId,
    employeeName: record.employeeName,
    title: record.title,
    status: 'APPROVED',
    reason: record.reason,
    kind: record.kind,
    version: record.version + 1,
    fields: record.fields,
  );
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
    int minAgeDays = 0,
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

  test(
    'acceptance F05 rollover preview returns explainable rows and totals',
    () async {
      final c = _client();
      addTearDown(c.close);
      await c.demoLogin('HR_ADMIN');
      final result = await c.request(
        DataRequest(
          'POST',
          '/leave/admin/year-end/preview',
          body: {
            'fromYear': 2026,
            'carryLimit': 2.25,
            'reason': 'Year-end review',
          },
          idempotencyKey: commandKey(),
        ),
      );
      final body = result.data as Map;
      final rows = (body['rows'] as List).cast<Map>();
      expect(rows, isNotEmpty);
      expect(body['previewId'], isNotEmpty);
      expect(body['affectedEmployees'], greaterThan(0));
      for (final row in rows) {
        expect(row['employeeName'], isNotEmpty);
        expect(row['leaveTypeName'], isNotEmpty);
        expect(
          (row['currentBalance'] as num) - (row['carriedOver'] as num),
          closeTo(row['forfeited'] as num, .001),
        );
        expect(row['newBalance'], isA<num>());
      }
      expect(
        (body['totalCarried'] as num),
        closeTo(
          rows.fold<num>(0, (sum, row) => sum + (row['carriedOver'] as num)),
          .001,
        ),
      );
    },
  );

  testWidgets(
    'acceptance F05 rollover review shows totals and named confirmation',
    (tester) async {
      final c = _client();
      final container = await _app(tester, c);
      await container.read(sessionProvider.notifier).demo('HR_ADMIN');
      container.read(routerProvider).go('/features/leave.rollovers');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prepare year-end rollover').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Approved maximum carry-over days'),
        '2.25',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason'),
        'Year-end review',
      );
      await tester.tap(find.text('Review changes'));
      await tester.pumpAndSettle();
      expect(find.text('Employees affected'), findsOneWidget);
      expect(find.text('Total carried'), findsOneWidget);
      expect(find.text('Search preview'), findsOneWidget);
      expect(find.text('Prepare year-end rollover').last, findsOneWidget);
    },
  );

  testWidgets('acceptance F05 fractional adjustment shows resulting balance', (
    tester,
  ) async {
    final c = _client();
    final container = await _app(tester, c);
    await container.read(sessionProvider.notifier).demo('HR_ADMIN');
    container.read(routerProvider).go('/features/leave.balances');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adjust entitlement').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjust entitlement').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Adjustment in days (positive or negative)',
      ),
      '-0.25',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reason'),
      'Correct accrual',
    );
    await tester.tap(find.text('Review changes'));
    await tester.pumpAndSettle();
    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Resulting balance'), findsOneWidget);
    expect(find.text('-0.25 days'), findsWidgets);
    expect(find.text('Adjust entitlement').last, findsOneWidget);
  });

  testWidgets('acceptance F05 termination requires reason and shows impact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = _client();
    final container = await _app(tester, c);
    await container.read(sessionProvider.notifier).demo('HR_ADMIN');
    container.read(routerProvider).go('/features/identity.people');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('End employment').first);
    await tester.tap(find.text('End employment').first);
    await tester.pumpAndSettle();
    expect(find.text('Review impact'), findsOneWidget);
    await tester.tap(find.text('Review impact'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reason'),
      'Employment ended',
    );
    await tester.tap(find.text('Review impact'));
    await tester.pumpAndSettle();
    expect(find.text('Employee'), findsWidgets);
    expect(find.text('Pending requests'), findsOneWidget);
    expect(find.text('Assigned materials'), findsOneWidget);
    expect(find.text('Open approvals'), findsOneWidget);
    expect(find.text('End employment').last, findsOneWidget);
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
      expect(find.text('Department · Required'), findsOneWidget);
      expect(find.text('Position · Required'), findsOneWidget);
      await tester.tap(find.text('Search department'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('People & Culture').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search position'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Product designer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit employee').last);
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
        final chip = find.widgetWithText(FilterChip, day);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byType(TextFormField).last,
        'Weekend coverage',
      );
      await tester.ensureVisible(find.text('Review changes'));
      await tester.tap(find.text('Review changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit shift policy'));
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

  test('remote approval inbox uses canonical routes', () async {
    final server = _QueryServer();
    final client = ClientData.forTest(server);
    addTearDown(client.close);
    final repo = RequestsDataRepository(client);
    await repo.recordsPage('request', pending: true, status: 'PENDING');
    expect(server.last?.path, '/requests/inbox');
    await repo.recordsPage('correction', pending: true, status: 'PENDING');
    expect(server.last?.path, '/attendance/corrections');
    expect(server.last?.query['status'], 'PENDING');
  });

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
    addTearDown(c.close);
    await c.demoLogin('OWNER');
    final original = await c.request(
      DataRequest('GET', '/employees/demo-employee'),
    );
    final first = await c.request(
      DataRequest(
        'PATCH',
        '/employees/demo-employee',
        body: {'name': 'Sok Dara One'},
        ifMatch: original.etag,
      ),
    );
    await c.request(
      DataRequest(
        'PATCH',
        '/employees/demo-employee',
        body: {'name': 'Sok Dara Two'},
        ifMatch: first.etag,
      ),
    );
    final auditBefore = await c.request(DataRequest('GET', '/audit-logs'));
    final actor =
        ((auditBefore.data as Map)['items'] as List).first['actor'] as String;
    final container = await _app(tester, c);
    await container.read(sessionProvider.notifier).demo('OWNER');
    container.read(routerProvider).go('/audit');
    await tester.pumpAndSettle();
    expect(find.textContaining(actor), findsNWidgets(2));
    expect(find.textContaining('10:00:00'), findsOneWidget);
    expect(find.textContaining('10:00:01'), findsOneWidget);
    await tester.tap(find.textContaining('10:00:01'));
    await tester.pumpAndSettle();
    expect(find.text('Target'), findsOneWidget);
    expect(find.textContaining('Sok Dara One → Sok Dara Two'), findsOneWidget);
    final filtered = await c.request(
      DataRequest(
        'GET',
        '/audit-logs',
        query: {
          'actor': actor,
          'action': 'EMPLOYEE_UPDATED',
          'target': 'demo-employee',
          'from': '2026-10-23',
          'to': '2026-10-23',
          'page': '0',
          'size': '25',
        },
      ),
    );
    expect((filtered.data as Map)['total'], 2);
  });

  test('acceptance F08 audit filters are sent to the server', () async {
    final server = _QueryServer();
    final client = ClientData.forTest(server);
    addTearDown(client.close);
    await IdentityDataRepository(client).cases(
      'identity.audit',
      filters: {
        'actor': 'Sok',
        'action': 'EMPLOYEE_UPDATED',
        'target': 'demo-employee',
        'from': '2026-10-23',
        'to': '2026-10-24',
        'page': '1',
        'size': '25',
      },
    );
    expect(server.last?.path, '/audit-logs');
    expect(server.last?.query['actor'], 'Sok');
    expect(server.last?.query['target'], 'demo-employee');
    expect(server.last?.query['page'], '1');
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
      await tester.scrollUntilVisible(
        find.text('Personal leave'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
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
        findsWidgets,
        reason: 'The focused decision dialog must identify the request under review.',
      );
    },
  );

  testWidgets(
    'acceptance F11 competing reviewer preserves note and resubmits latest',
    (tester) async {
      final c = _client();
      final competing = _CompetingReviewerLeave(c);
      final container = await _app(
        tester,
        c,
        additional: [
          workflowRepositoryProvider('leave').overrideWithValue(competing),
        ],
      );
      await container.read(sessionProvider.notifier).demo('MANAGER');
      container.read(routerProvider).go('/approvals');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Personal leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal leave'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Approve request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve request'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.byType(TextFormField).last,
        'Coverage checked',
      );
      await tester.tap(find.text('Confirm'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(competing.attempts, 1);
      expect(find.textContaining('Another reviewer changed'), findsOneWidget);
      expect(find.text('Coverage checked'), findsOneWidget);
      expect(find.text('When opened'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
      await tester.tap(find.text('Decide using latest'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(competing.attempts, 2);
      expect(competing.keys[0], isNot(competing.keys[1]));
      expect(
        (await competing.detail('leave', competing.changed!.id)).status,
        'APPROVED',
      );
    },
  );
  testWidgets('acceptance F07 rejection names employee and requires reason', (
    tester,
  ) async {
    final c = _client();
    final container = await _app(tester, c);
    await container.read(sessionProvider.notifier).demo('MANAGER');
    container.read(routerProvider).go('/approvals');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Personal leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject request'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sok Dara'), findsWidgets);
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(
      find.text('Give a reason with at least 5 characters'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });
  testWidgets(
    'acceptance F11 stale resource shows time and disables approval',
    (tester) async {
      final c = _client();
      final container = await _app(
        tester,
        c,
        additional: [
          staleResourcesProvider.overrideWith(
            (ref) => Stream.value([
              StaleResource('/leave/requests', DateTime.utc(2026, 10, 23, 3)),
            ]),
          ),
          cacheStaleProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      await container.read(sessionProvider.notifier).demo('MANAGER');
      container.read(routerProvider).go('/approvals');
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Leave: Last updated 23 Oct 2026 · 10:00:00 UTC+07',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Personal leave'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal leave'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Approve request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve request'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.textContaining('Decision unavailable offline'),
        findsOneWidget,
      );
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm'),
      );
      expect(confirm.onPressed, isNull);
    },
  );
  testWidgets('acceptance F07 next request keeps the queue position', (
    tester,
  ) async {
    final c = _client();
    final repo = _TwoPendingLeave(c);
    final container = await _app(
      tester,
      c,
      additional: [workflowRepositoryProvider('leave').overrideWithValue(repo)],
    );
    await container.read(sessionProvider.notifier).demo('MANAGER');
    container.read(routerProvider).go('/approvals');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Personal leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve request'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Next request'), findsOneWidget);
    await tester.tap(find.text('Next request'));
    await tester.pumpAndSettle();
    expect(find.text('Second leave'), findsWidgets);
  });
  testWidgets('acceptance F06 HR finds a deep task through Work search', (
    tester,
  ) async {
    final c = _client();
    final container = await _app(tester, c);
    await container.read(sessionProvider.notifier).demo('HR_ADMIN');
    container.read(routerProvider).go('/workflows');
    await tester.pumpAndSettle();
    final task = featurePanels.lastWhere(
      (panel) =>
          panel.key.startsWith('reporting.') &&
          canOpenPanel(panel, container.read(sessionProvider).profile!),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Search tasks'),
      task.title,
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, task.title), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, task.title));
    await tester.pumpAndSettle();
    expect(find.byType(FeatureCasesPage), findsOneWidget);
    expect(find.text(task.title), findsWidgets);
  });
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
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard add department?'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
  });

  testWidgets('acceptance F10 legacy admin dialog also guards unsaved work', (
    tester,
  ) async {
    final c = _client();
    final container = await _app(tester, c);
    await container.read(sessionProvider.notifier).demo('HR_ADMIN');
    container.read(routerProvider).go('/manage/holidays');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add record'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Founders Day');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard new Company holidays?'), findsOneWidget);
  });

  test(
    'acceptance F10 leave preview applies workdays and policy warnings',
    () async {
      final c = _client();
      addTearDown(c.close);
      await c.demoLogin('EMPLOYEE');
      Future<Map> preview(
        String from,
        String to, {
        String portion = 'FULL_DAY',
        String type = 'annual',
      }) async =>
          (await c.request(
                DataRequest(
                  'POST',
                  '/leave/requests/preview',
                  body: {
                    'leaveTypeId': type,
                    'startDate': from,
                    'endDate': to,
                    'portion': portion,
                  },
                  idempotencyKey: commandKey(),
                ),
              )).data
              as Map;
      final weekday = await preview('2026-10-26', '2026-10-26');
      expect(weekday['chargeableDays'], 1);
      expect(weekday['balanceAfter'], (weekday['balanceBefore'] as num) - 1);
      final weekend = await preview('2026-10-24', '2026-10-25');
      expect(weekend['chargeableDays'], 0);
      expect(
        weekend['warnings'],
        contains('No scheduled workdays in this period.'),
      );
      await c.demoLogin('HR_ADMIN');
      await c.request(
        DataRequest(
          'PUT',
          '/leave/admin/policies/sick',
          ifMatch: '"1"',
          body: {
            'annualDays': 10,
            'carryOverMax': 0,
            'maxDaysPerRequest': 60,
            'allowHalfDay': false,
            'requiresAttachment': true,
            'minNoticeDays': 3,
            'reason': 'Updated medical policy',
          },
        ),
      );
      await c.demoLogin('EMPLOYEE');
      final policy = await preview(
        '2026-10-26',
        '2026-10-26',
        type: 'sick',
        portion: 'MORNING',
      );
      expect(policy['allowHalfDay'], false);
      expect(policy['evidenceRequired'], true);
      expect(policy['minimumNoticeDays'], 3);
      expect(
        (policy['warnings'] as List).join(' '),
        contains('does not allow half days'),
      );
      expect(
        (policy['warnings'] as List).join(' '),
        contains('requires 3 days of notice'),
      );
    },
  );
  testWidgets(
    'acceptance F06 manager and HR see their work on the first viewport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = _client();
      final container = await _app(tester, c);
      for (final (role, label) in [
        ('MANAGER', 'Needs my decision'),
        ('HR_ADMIN', 'Exceptions to review'),
      ]) {
        await container.read(sessionProvider.notifier).demo(role);
        container.read(routerProvider).go('/home');
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        expect(tester.getBottomLeft(find.text(label)).dy, lessThan(560));
      }
    },
  );

  testWidgets(
    'acceptance F06 detail action stays visible through long history',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = _client();
      final container = await _app(
        tester,
        c,
        additional: [
          workflowRepositoryProvider('leave')
              .overrideWithValue(_LongHistoryLeave(c)),
        ],
      );
      await container.read(sessionProvider.notifier).demo('MANAGER');
      container.read(routerProvider).go('/approvals');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Personal leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal leave'));
      await tester.pumpAndSettle();
      final action = find.text('Approve request');
      expect(action, findsOneWidget);
      final before = tester.getBottomRight(action).dy;
      await tester.drag(find.byType(ListView).last, const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(action).dy, before);
      expect(before, lessThan(640));
    },
  );

  test(
    'acceptance F07 approval age and status filter before pagination',
    () async {
      final c = _client();
      addTearDown(c.close);
      await c.demoLogin('MANAGER');
      final repo = LeaveDataRepository(c);
      final waiting = await repo.recordsPage(
        'leave',
        pending: true,
        status: 'PENDING',
        minAgeDays: 3,
        sort: 'oldest',
      );
      expect(waiting.records.map((row) => row.id), contains('leave-pending'));
      final review = await repo.detail('leave', 'leave-pending');
      final context = review.fields['reviewContext'] as Map;
      expect(context['chargeableDays'], 1.0);
      expect(context['balanceAfter'], isA<num>());
      expect(context['teamMembersOff'], isA<List>());
      final older = await repo.recordsPage(
        'leave',
        pending: true,
        status: 'PENDING',
        minAgeDays: 4,
      );
      expect(older.records, isEmpty);
      final approved = await repo.recordsPage(
        'leave',
        pending: true,
        status: 'APPROVED',
      );
      expect(approved.records.every((row) => row.status == 'APPROVED'), true);
      final server = _QueryServer();
      final remote = ClientData.forTest(server);
      addTearDown(remote.close);
      await LeaveDataRepository(remote).recordsPage(
        'leave',
        pending: true,
        status: 'PENDING',
        sort: 'oldest',
        minAgeDays: 3,
      );
      expect(server.last?.path, '/leave/requests/pending');
      expect(server.last?.query['minAgeDays'], '3');
      expect(server.last?.query['status'], 'PENDING');
    },
  );

  testWidgets('acceptance F10 required leave evidence blocks submission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = _client();
    addTearDown(c.close);
    await c.demoLogin('HR_ADMIN');
    await c.request(
      DataRequest(
        'PUT',
        '/leave/admin/policies/sick',
        ifMatch: '"1"',
        body: {
          'annualDays': 10,
          'carryOverMax': 0,
          'maxDaysPerRequest': 60,
          'allowHalfDay': false,
          'requiresAttachment': true,
          'minNoticeDays': 0,
          'reason': 'Evidence policy',
        },
      ),
    );
    final container = await _app(
      tester,
      c,
      additional: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 10)),
      ],
    );
    await container.read(sessionProvider.notifier).demo('EMPLOYEE');
    container.read(routerProvider).go('/new/leave');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sick leave').last);
    await tester.pumpAndSettle();
    expect(find.text('Day portion'), findsNothing);
    expect(
      find.text('Supporting evidence is required before submission.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reason'),
      'Medical appointment',
    );
    await tester.ensureVisible(find.text('Send for approval'));
    await tester.tap(find.text('Send for approval'));
    await tester.pumpAndSettle();
    expect(
      find.text('Supporting evidence is required before submission.'),
      findsNWidgets(2),
    );
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/new/leave',
    );
  });

  test(
    'acceptance F10 server draft survives reload and is erased on logout',
    () async {
      final c = _client();
      addTearDown(c.close);
      await c.demoLogin('EMPLOYEE');
      const payload = {
        'schema': 1,
        'reason': 'A private draft',
        'type': 'annual',
      };
      await c.request(
        DataRequest('PUT', '/form-drafts/leave', body: {'payload': payload}),
      );
      final seed = jsonDecode(
        File('assets/data/demo-seed.json').readAsStringSync(),
      ) as JsonMap;
      final restoredSource = LocalDataSource(
        seed,
        populate: true,
        now: () => DateTime.utc(2026, 10, 23, 3),
      );
      restoredSource.restore((c.source as LocalDataSource).snapshot());
      final resumed = ClientData.forTest(restoredSource);
      addTearDown(resumed.close);
      await resumed.demoLogin('EMPLOYEE');
      final recovered = await resumed.request(
        const DataRequest('GET', '/form-drafts/leave'),
      );
      expect((recovered.data as Map)['payload']['reason'], 'A private draft');
      await resumed.logout();
      await resumed.demoLogin('EMPLOYEE');
      final afterLogout = await resumed.request(
        const DataRequest('GET', '/form-drafts/leave'),
      );
      expect((afterLogout.data as Map)['payload'], isNull);
    },
  );

  test(
    'acceptance F10 lookup searches the server before selecting a page',
    () async {
      final c = _client();
      addTearDown(c.close);
      final repo = _PagedPeople(c);
      final container = ProviderContainer(
        overrides: [
          ...composeFeatures(
            c,
            preferences: const _Preferences(),
          ).where((base) => base.origin != identityRepositoryProvider),
          identityRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final results = await container.read(
        caseLookupPageProvider((
          collection: 'identity.people',
          search: 'Special Person',
          page: 0,
        )).future,
      );
      expect(repo.lastSearch, 'Special Person');
      expect(results.single.title, 'Special Person');
    },
  );

  testWidgets('acceptance F10 form restores server draft after navigation', (
    tester,
  ) async {
    final c = _client();
    final container = await _app(
      tester,
      c,
      additional: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 10)),
      ],
    );
    await container.read(sessionProvider.notifier).demo('EMPLOYEE');
    container.read(routerProvider).go('/new/leave');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reason'),
      'A remembered reason',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    final stored = await c.request(
      const DataRequest('GET', '/form-drafts/leave'),
    );
    expect((stored.data as Map)['payload']['reason'], 'A remembered reason');
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/new/leave');
    await tester.pumpAndSettle();
    expect(find.text('A remembered reason'), findsOneWidget);
  });
}
