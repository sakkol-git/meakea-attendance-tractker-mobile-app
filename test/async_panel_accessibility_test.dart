import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/theme.dart';

void main() {
  testWidgets(
    'reduced-motion loading remains understandable without a moving spinner',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: appTheme(),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: AsyncPanel<int>(
                  value: const AsyncLoading(),
                  retry: () {},
                  builder: (value) => Text('$value'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loading content…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('a failed read announces recovery instead of an empty result', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: AsyncPanel<int>(
              value: AsyncError(
                StateError('Connection interrupted'),
                StackTrace.empty,
              ),
              retry: () {},
              builder: (value) => Text('$value records'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Could not load this information'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('0 records'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsWidgets,
    );
    semantics.dispose();
  });
}
