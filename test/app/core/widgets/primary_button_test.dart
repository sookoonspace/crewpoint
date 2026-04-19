import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';

void main() {
  Widget buildSubject({
    String label = 'Test',
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PrimaryButton(
          label: label,
          onPressed: onPressed ?? () {},
          isLoading: isLoading,
        ),
      ),
    );
  }

  testWidgets('renders with sage green background color', (tester) async {
    await tester.pumpWidget(buildSubject());

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final style = button.style!;
    final bgColor = style.backgroundColor!.resolve({});

    expect(bgColor, equals(AppColors.sage));
  });

  testWidgets('displays label text', (tester) async {
    await tester.pumpWidget(buildSubject(label: 'Sign In'));

    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('calls onPressed when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildSubject(onPressed: () => tapped = true));

    await tester.tap(find.byType(ElevatedButton));
    expect(tapped, isTrue);
  });

  testWidgets('shows loading indicator when isLoading is true', (tester) async {
    await tester.pumpWidget(buildSubject(isLoading: true));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Test'), findsNothing);
  });
}
