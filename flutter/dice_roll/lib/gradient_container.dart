import 'package:dice_roll/dice.dart';
import 'package:flutter/material.dart';

class GradientContainer extends StatelessWidget {
  const GradientContainer({
    required this.title,
    required this.colors,
    this.subtitle = '',
    super.key,
  });

  // Default convenience constructor
  const GradientContainer.start({super.key})
      : title = 'Test',
        subtitle = 'Start',
        colors = const [Color.fromARGB(255, 255, 192, 84), Color.fromARGB(255, 255, 162, 0)];

  final String title;
  final String subtitle;
  final List<Color> colors;

  @override
  Widget build(context) {
    return baseBody(title, subtitle, Colors.white, colors);
  }

  Widget baseBody(String inputText, String subText, Color textColor, List<Color> background) {
    return Container(
      decoration: BoxDecoration(gradient: backgroundGradient(background)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            styledText(inputText, 64, textColor),
            if (subText != '') styledText(subText, 28, textColor),
            const Dice(),
          ],
        ),
      ),
    );
  }

  Text styledText(String t, double s, Color c) {
    return Text(
      t,
      style: TextStyle(
          color: c,
          fontSize: s,
          shadows: const [Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 2)]),
    );
  }

  Gradient backgroundGradient(List<Color> colors) {
    return LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }
}
