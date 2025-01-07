import 'package:flutter/material.dart';
import 'package:trivia_app/homes.dart';
import 'package:trivia_app/questions.dart';

class Quiz extends StatefulWidget {
  const Quiz({super.key});

  @override
  State<Quiz> createState() {
    return _QuizState();
  }
}

class _QuizState extends State<Quiz> {
  Widget? activeScreen;

  @override
  void initState() {
    activeScreen = HomeScreen(switchScreen);
    super.initState();
  }

  void switchScreen() {
    setState(() {
      activeScreen = const QuestionScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Super Trivia'),
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
        ),
        body: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.red, Colors.red[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
          child: activeScreen,
        ),
      ),
    );
  }
}
