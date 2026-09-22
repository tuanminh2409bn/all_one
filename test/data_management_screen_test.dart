import 'package:all_one/core/app_data.dart';
import 'package:all_one/ui/data_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bottom actions stay above the system navigation area', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(588, 1280);
    tester.view.padding = const FakeViewPadding(bottom: 68);
    tester.view.viewPadding = const FakeViewPadding(bottom: 68);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    final store = AppDataStore.inMemory(withMockData: false);
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(home: DataManagementScreen(store: store)),
    );
    await tester.pumpAndSettle();

    const safeBottom = 1280 - 68;
    expect(
      tester.getBottomRight(find.byKey(const Key('add-account'))).dy,
      lessThanOrEqualTo(safeBottom),
    );

    await tester.tap(find.text('받는 분'));
    await tester.pumpAndSettle();

    expect(
      tester.getBottomRight(find.byKey(const Key('add-recipient'))).dy,
      lessThanOrEqualTo(safeBottom),
    );

    await tester.tap(find.byKey(const Key('add-recipient')));
    await tester.pumpAndSettle();
    final warningToggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('recipient-transfer-warning-toggle')),
    );
    expect(warningToggle.value, isTrue);
  });

  testWidgets('recipient editor remains scrollable above the keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(588, 1280);
    tester.view.viewInsets = const FakeViewPadding(bottom: 500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    final store = AppDataStore.inMemory(withMockData: false);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: DataManagementScreen(store: store, initialTab: 2)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-recipient')));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(
      find.byKey(const Key('recipient-editor-dialog')),
    );
    expect(dialog.scrollable, isTrue);
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomRight(find.widgetWithText(FilledButton, '저장')).dy,
      lessThanOrEqualTo(780),
    );
  });
}
