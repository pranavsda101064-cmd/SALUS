import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salus_frontend/theme.dart';
import 'package:salus_frontend/widgets/motion.dart';

void main() {
  testWidgets('CountingText settles on the grouped final value', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSalusTheme(),
        home: const Scaffold(
          body: CountingText(text: '1000', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1,000'), findsOneWidget);
  });

  testWidgets('CountingText leaves non numeric text alone', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSalusTheme(),
        home: const Scaffold(
          body: CountingText(text: 'Template', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
    expect(find.text('Template'), findsOneWidget);
  });

  testWidgets('ParallaxCarousel moves to the next slide', (tester) async {
    final slides = [
      const CarouselSlide(
        asset: 'assets/photos/shared-desk.jpg',
        eyebrow: 'Step 1',
        title: 'First slide',
        body: 'First body',
        actionLabel: 'Go one',
      ),
      const CarouselSlide(
        asset: 'assets/photos/typing-laptop.jpg',
        eyebrow: 'Step 2',
        title: 'Second slide',
        body: 'Second body',
        actionLabel: 'Go two',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSalusTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: ParallaxCarousel(slides: slides)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('First slide'), findsOneWidget);

    await tester.tap(find.byTooltip('Next slide'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Second slide'), findsWidgets);

    // Tear the carousel down so its autoplay timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}
