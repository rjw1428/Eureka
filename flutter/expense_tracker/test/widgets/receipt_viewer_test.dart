import 'package:expense_tracker/widgets/receipt_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpViewer(
  WidgetTester tester, {
  required String url,
  Size surface = const Size(400, 800),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showReceipt(context, url),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
}

void main() {
  testWidgets('opens a dialog with a close action', (tester) async {
    await pumpViewer(tester, url: 'https://example.com/receipt.jpg');

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('constrains itself to the viewport rather than overflowing',
      (tester) async {
    // A tall receipt on a short screen is the case that produced a RenderFlex
    // overflow in the earlier prototype.
    await pumpViewer(
      tester,
      url: 'https://example.com/tall-receipt.jpg',
      surface: const Size(320, 480),
    );

    final box = tester.getRect(find.byType(Dialog));
    expect(box.height, lessThanOrEqualTo(480));
    expect(box.width, lessThanOrEqualTo(320));
    // pumpViewer would have recorded an overflow exception if one occurred.
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an error state when the image cannot be fetched',
      (tester) async {
    // In the test binding, Image.network requests fail, which drives the
    // errorBuilder — exactly the path a dead URL takes in production.
    await pumpViewer(tester, url: 'https://example.com/missing.jpg');
    await tester.pumpAndSettle();

    expect(find.text('This receipt could not be loaded.'), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('is dismissible', (tester) async {
    await pumpViewer(tester, url: 'https://example.com/receipt.jpg');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('supports zooming for a receipt that needs a closer look',
      (tester) async {
    await pumpViewer(tester, url: 'https://example.com/receipt.jpg');

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.maxScale, greaterThan(1));
  });
}
