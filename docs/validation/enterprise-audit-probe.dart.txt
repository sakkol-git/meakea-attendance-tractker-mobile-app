// Diagnostic snapshot, 24 October 2026. Observes current behavior; passing does not mean UX acceptance.
// Run by copying into test/_enterprise_audit_probe_test.dart, then flutter test that file.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/composition.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/requests/data/repository.dart';
import 'package:hrflow_mobile/features/identity/data/repository.dart';
import 'package:hrflow_mobile/features/settings/domain/preferences_gateway.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

class Prefs implements PreferencesGateway {
  final bool dark;
  Prefs([this.dark=false]);
  Future<bool?> read(String key) async => key=='hrflow.dark' && dark;
  Future<void> write(String key, bool value) async {}
}
class PagedRequests extends RequestsDataRepository {
  int reads=0;
  PagedRequests(super.client);
  Future<RecordPage> recordsPage(String kind,{bool pending=false,int page=0,int size=25}) async {
    reads++;
    return RecordPage(List.generate(page==0 ? 25:1,(i)=>WorkflowRecord(id:'audit-${page*25+i}',employeeId:'demo-employee',title:page==0?'Routine request $i':'Special laptop',status:'DRAFT',reason:'Business equipment',kind:'request',version:1,fields:const{},employeeName:'Sok Dara')),26,page,size);
  }
}
ClientData client()=>ClientData.forTest(LocalDataSource(jsonDecode(File('assets/data/demo-seed.json').readAsStringSync()) as JsonMap,populate:true,now:()=>DateTime.utc(2026,10,23,3)));
double contrast(Color a,Color b){final x=a.computeLuminance(),y=b.computeLuminance();return ((x>y?x:y)+.05)/((x>y?y:x)+.05);}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('KantumruyPro')..addFont(rootBundle.load('assets/fonts/KantumruyPro[wght].ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test('audit: legacy HR editor fields are accepted without applying them',() async {
    final c=client(); await c.demoLogin('HR_ADMIN'); final repo=IdentityDataRepository(c);
    final before=(await repo.collection('/employees')).firstWhere((r)=>r['id']=='demo-employee');
    await repo.saveEntity('/employees',{'name':before['name'],'email':before['email'],'department':'Audit changed department','position':'Audit changed position','managerId':before['managerId']??''},existing:before);
    final after=(await repo.collection('/employees')).firstWhere((r)=>r['id']=='demo-employee');
    print('AUDIT_HR_EDITOR: commandSucceeded=true; departmentApplied=${after['department']=='Audit changed department'}; positionApplied=${after['position']=='Audit changed position'}');
    final shift=(await repo.collection('/shifts')).first;
    await repo.saveEntity('/shifts',{'name':shift['name'],'startTime':shift['startTime'],'endTime':shift['endTime'],'days':'Sat, Sun'},existing:shift);
    final result=(await repo.collection('/shifts')).firstWhere((r)=>r['id']==shift['id']);
    print('AUDIT_SHIFT_EDITOR: commandSucceeded=true; enteredDays=Sat, Sun; savedDays=${result['days']}');
    c.close();
  });
  testWidgets('audit: paginated request search', (tester) async {
    tester.view.physicalSize=const Size(402,874); tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final c=client(), repo=PagedRequests(client());
    final container=ProviderContainer(overrides:[...composeFeatures(c,preferences:Prefs()).where((o)=>o.origin!=requestsRepositoryProvider),requestsRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container:container,child:const HrFlowApp())); await tester.pumpAndSettle();
    await container.read(sessionProvider.notifier).demo('EMPLOYEE');container.read(routerProvider).go('/requests');await tester.pumpAndSettle();
    expect(container.read(recordsProvider('request').notifier).canLoadMore,true);
    await tester.enterText(find.byType(TextField).first,'Special laptop');await tester.pumpAndSettle();
    print('AUDIT_SEARCH: empty=${find.text('Nothing here yet').evaluate().isNotEmpty}; loadMoreVisible=${find.text('Load more requests').evaluate().isNotEmpty}; repositoryPagesRead=${repo.reads}; controllerHasMore=${container.read(recordsProvider('request').notifier).canLoadMore}');
  });
  testWidgets('audit: dark contrast and screenshot', (tester) async {
    tester.view.physicalSize=const Size(402,874);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final c=client(), theme=appTheme(dark:true);
    final background=theme.colorScheme.surfaceContainer;
    final pill=Color.alphaBlend(const Color(0xFF17613F).withValues(alpha:.09),background);
    print('AUDIT_CONTRAST: darkSurface=${theme.colorScheme.surface.toARGB32().toRadixString(16)}, darkCard=${background.toARGB32().toRadixString(16)}, mutedOnSurface=${contrast(Palette.muted,theme.colorScheme.surface).toStringAsFixed(2)}, mutedOnCard=${contrast(Palette.muted,background).toStringAsFixed(2)}, approvedStatus=${contrast(const Color(0xFF17613F),pill).toStringAsFixed(2)}, errorOnCard=${contrast(Palette.danger,background).toStringAsFixed(2)}');
    final container=ProviderContainer(overrides:composeFeatures(c,preferences:Prefs(true)));addTearDown(container.dispose);
    const key=Key('audit-screen');
    await tester.pumpWidget(UncontrolledProviderScope(container:container,child:const RepaintBoundary(key:key,child:HrFlowApp())));await tester.pumpAndSettle();
    await container.read(sessionProvider.notifier).demo('EMPLOYEE');container.read(routerProvider).go('/leave');await tester.pumpAndSettle();
    final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    await tester.runAsync(() async {final img=await boundary.toImage();final bytes=await img.toByteData(format:ui.ImageByteFormat.png);await File('docs/screenshots/audit-dark-leave.png').writeAsBytes(bytes!.buffer.asUint8List());img.dispose();});
  });
  testWidgets('audit: approval dialog at 200 percent text with keyboard', (tester) async {
    tester.view.physicalSize=const Size(360,740);tester.view.devicePixelRatio=1;tester.platformDispatcher.textScaleFactorTestValue=2;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c=client(), container=ProviderContainer(overrides:composeFeatures(client(),preferences:Prefs()));addTearDown(container.dispose);c.close();
    await tester.pumpWidget(UncontrolledProviderScope(container:container,child:const HrFlowApp()));await tester.pumpAndSettle();
    await container.read(sessionProvider.notifier).demo('MANAGER');container.read(routerProvider).go('/approvals');await tester.pumpAndSettle();
    await tester.tap(find.text('Personal leave'));await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Approve request'),300,scrollable:find.byType(Scrollable).first);await tester.pumpAndSettle();
    await tester.tap(find.text('Approve request'));await tester.pump(const Duration(milliseconds:400));
    tester.view.viewInsets=const FakeViewPadding(bottom:300);addTearDown(tester.view.resetViewInsets);await tester.pump(const Duration(milliseconds:400));
    print('AUDIT_DIALOG_EXCEPTION: ${tester.takeException()}');
  });
}
