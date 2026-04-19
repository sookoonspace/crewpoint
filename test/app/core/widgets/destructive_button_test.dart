import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/widgets/destructive_button.dart';

void main() {
  Widget buildSubject({
    String label = 'Delete',
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DestructiveButton(
          label: label,
          onPressed: onPressed ?? () {},
          isLoading: isLoading,
        ),
      ),
    );
  }

  testWidgets('renders with terracotta background color', (tester) async {
    await tester.pumpWidget(buildSubject());

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final style = button.style!;
    final bgColor = style.backgroundColor!.resolve({});

    expect(bgColor, equals(AppColors.terracotta));
  });

  testWidgets('displays label text', (tester) async {
    await tester.pumpWidget(buildSubject(label: 'Remove'));

    expect(find.text('Remove'), findsOneWidget);
  });
}
