import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trivia_app/models/quiz_question.dart';
import 'package:trivia_app/quizzes/dart_quiz.dart';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({
    super.key,
    required this.onStoreAnswer,
  });

  final void Function(String) onStoreAnswer;

  @override
  State<QuestionScreen> createState() {
    return _QuestionScreenState();
  }
}

class _QuestionScreenState extends State<QuestionScreen> {
  int activeIndex = 0;
  bool isEnd = false;

  selectAnswer(String answer) {
    widget.onStoreAnswer(answer);

    setState(() {
      activeIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final QuizQuestion data = questions[activeIndex];
    return SizedBox(
      width: double.infinity, // be as wide as possible
      child: Container(
        margin: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              data.question,
              style:
                  GoogleFonts.lato(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(width: 30),
            ...data.shuffledAnswers.map((answer) {
              return AnswerButton(label: answer, onPressed: () => selectAnswer(answer));
            }),
          ],
        ),
      ),
    );
  }
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 74, 0, 0),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
