import 'package:flutter/material.dart';
import 'package:trivia_app/homes.dart';
import 'package:trivia_app/questions.dart';
import 'package:trivia_app/quizzes/dart_quiz.dart';
import 'package:trivia_app/results.dart';

// COMPONENT LIFECYCLE:
// initState() - Runs once on init
// build() - Runs to create initial view & after every setState call
// dispose() - Runs just before removing

class Quiz extends StatefulWidget {
  const Quiz({super.key});

  @override
  State<Quiz> createState() {
    return _QuizState();
  }
}

class _QuizState extends State<Quiz> {
  String? activeScreen = 'home';
  List<String> selectedAnswers = [];

  void switchScreen() {
    setState(() {
      activeScreen = 'questions';
    });
  }

  void storeAnswer(String answer) {
    print(answer);
    selectedAnswers.add(answer);

    if (selectedAnswers.length == questions.length) {
      setState(() {
        activeScreen = 'results';
      });
    }
  }

  void goHome() {
    setState(() {
      selectedAnswers = [];
      activeScreen = 'home';
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget selectedScreen = HomeScreen(switchScreen);

    if (activeScreen == 'home') {
      selectedScreen = HomeScreen(switchScreen);
    } else if (activeScreen == 'questions') {
      selectedScreen = QuestionScreen(onStoreAnswer: storeAnswer);
    } else if (activeScreen == 'results') {
      selectedScreen = Results(resultsList: selectedAnswers, onBack: goHome);
    }

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
          child: selectedScreen,
        ),
      ),
    );
  }
}
