// Basic smoke test for the CLAT Daily Sprint app.
//
// The previous version of this file was Flutter's default counter-app
// template, left over from `flutter create` and never updated — it
// referenced a `MyApp` class that doesn't exist in this project (the real
// root widget is `ClatPacerApp`) and asserted on counter text this app has
// never had. `flutter analyze` flagged it as a real error (creation_with_
// non_type), not just a lint info.
//
// This replaces it with a minimal real smoke test: launch the actual app
// and confirm the Home screen renders its title and headline. Not a
// substitute for real widget/unit test coverage (none of SarvamService's
// parsing, the mock negative-marking math, or the storage round-trips are
// tested anywhere) — just enough that `flutter test` exercises the app
// instead of silently testing nothing real.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clat_pacer/main.dart';

void main() {
  testWidgets('App launches and shows the Home screen', (tester) async {
    // StorageService.loadStats() calls SharedPreferences.getInstance() on
    // first build — without this, the test throws a MissingPluginException
    // before the widget tree ever settles.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ClatPacerApp());
    await tester.pumpAndSettle();

    expect(find.text('Ready to sprint?'), findsOneWidget);
    expect(find.text("Today's Daily Sprint"), findsOneWidget);
  });

  group('Practice by section filters', () {
    Future<void> openHome(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(430, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const ClatPacerApp());
      await tester.pumpAndSettle();
    }

    testWidgets('shows every section by default', (tester) async {
      await openHome(tester);
      expect(find.text('Legal Reasoning'), findsOneWidget);
      expect(find.text('GK / Current Affairs'), findsOneWidget);
    });

    testWidgets('the Verbal chip keeps only verbal sections', (tester) async {
      await openHome(tester);
      await tester.tap(find.text('Verbal'));
      await tester.pumpAndSettle();
      expect(find.text('GK / Current Affairs'), findsOneWidget);
      expect(find.text('English & RC'), findsOneWidget);
      expect(find.text('Legal Reasoning'), findsNothing);
    });

    testWidgets('search filters by title and shows an empty state',
        (tester) async {
      await openHome(tester);
      await tester.enterText(find.byType(TextField), 'logic');
      await tester.pumpAndSettle();
      expect(find.text('Logical Reasoning'), findsOneWidget);
      expect(find.text('Legal Reasoning'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No sections match "zzz".'), findsOneWidget);
    });
  });
}
