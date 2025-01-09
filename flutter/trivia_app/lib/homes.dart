import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen(this.startTrigger, {super.key});
  final void Function() startTrigger;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Opacity is performance intensive:
          // - renders in an offscreen buffer, does the blending, and then adds to screen)
          // Opacity(
          //   opacity: .6,
          //   child: Image.asset(
          //     'assets/images/quiz-logo.png',
          //     width: 400,
          //   ),
          // ),
          // - Using a transparent color skips the offscreen rendering step
          Image.asset(
            'assets/images/quiz-logo.png',
            width: 400,
            color: Colors.white.withAlpha(100),
          ),
          Text(
            'Can you answer them all?!',
            style: GoogleFonts.oswald(color: Colors.white, fontSize: 24),
          ),
          OutlinedButton.icon(
            onPressed: startTrigger,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            label: const Text('Start Quiz'),
            icon: const Icon(Icons.arrow_right_alt),
          )
        ],
      ),
    );
  }
}
