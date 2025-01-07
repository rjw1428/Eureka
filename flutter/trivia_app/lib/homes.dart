import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen(this.startTrigger, {super.key});
  final void Function() startTrigger;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
          const Padding(
            padding: EdgeInsets.all(36.0),
            child: Text(
              'Can you answer them all?!',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
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
