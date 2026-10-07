import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurkha_guides/app/app.dart';
import 'package:gurkha_guides/core/services/language_preferences.dart';

class MemoryLanguagePreferences implements LanguagePreferences {
  String? language;
  bool failRead = false;
  bool failWrite = false;
  Completer<String?>? pendingRead;

  @override
  Future<String?> readLanguageCode() async {
    if (failRead) throw StateError('Read failed');
    return pendingRead == null ? language : pendingRead!.future;
  }

  @override
  Future<void> writeLanguageCode(String code) async {
    if (failWrite) throw StateError('Write failed');
    language = code;
  }
}

void main() {
  late MemoryLanguagePreferences preferences;

  setUp(() => preferences = MemoryLanguagePreferences());

  Widget createApp() => ProviderScope(
    overrides: [languagePreferencesProvider.overrideWithValue(preferences)],
    child: const GurkhaGuidesApp(),
  );

  Future<void> openLanguageSelector(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('settingsButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('localeSelector')));
    await tester.pumpAndSettle();
  }

  testWidgets('starts at home with English copy', (tester) async {
    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();
    expect(find.text('Gurkha Guides'), findsOneWidget);
    expect(find.text('One Platform, All of Nepal.'), findsOneWidget);
    expect(find.text('Explore Nepal'), findsOneWidget);
  });

  testWidgets('settings changes locale and a fresh app restores Nepali', (
    tester,
  ) async {
    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();
    await openLanguageSelector(tester);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Nepali').last);
    await tester.pumpAndSettle();
    expect(find.text('भाषा परिवर्तन गर्नुहोस्'), findsOneWidget);
    expect(preferences.language, 'ne');

    await tester.tap(find.byTooltip('गृहपृष्ठ'));
    await tester.pumpAndSettle();
    expect(find.text('नेपाल घुम्नुहोस्'), findsOneWidget);

    // Dispose the provider state and router, while retaining persisted storage.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();
    expect(find.text('गोरखा गाइड्स'), findsOneWidget);
    expect(find.text('एउटै प्लेटफर्ममा सम्पूर्ण नेपाल'), findsOneWidget);
  });

  testWidgets('waits for saved language before displaying home', (
    tester,
  ) async {
    preferences.pendingRead = Completer<String?>();
    await tester.pumpWidget(createApp());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Explore Nepal'), findsNothing);
    preferences.pendingRead!.complete('ne');
    await tester.pumpAndSettle();
    expect(find.text('नेपाल घुम्नुहोस्'), findsOneWidget);
  });

  testWidgets('preferences read failure offers a working retry', (
    tester,
  ) async {
    preferences.failRead = true;
    await tester.pumpWidget(createApp());
    // Riverpod retries failed reads automatically by default. Wait for the
    // first error view without waiting for those scheduled retries.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Couldn't load your preferences."), findsOneWidget);
    preferences.failRead = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Explore Nepal'), findsOneWidget);
  });

  testWidgets('a failed language write keeps the current locale', (
    tester,
  ) async {
    preferences.failWrite = true;
    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();
    await openLanguageSelector(tester);
    await tester.tap(find.text('Nepali').last);
    await tester.pumpAndSettle();
    expect(find.text('Change Language'), findsOneWidget);
    expect(
      find.text("Couldn't save your language. Please try again."),
      findsOneWidget,
    );
    expect(preferences.language, isNull);
  });
}
