import 'package:flutter/material.dart';
import 'package:trivia_app/quizes/dart_quiz.dart';

class Results extends StatelessWidget {
  Results({super.key, required this.resultsList, required this.onBack});

  List<String> resultsList;
  void Function() onBack;

  List<Map<String, String>> getSummaryData() {
    final List<Map<String, String>> summary = [];

    for (int i = 0; i < resultsList.length; i++) {
      summary.add({
        'index': (i + 1).toString(),
        'question': questions[i].question,
        'selectedAnswer': resultsList[i],
        'correctAnswer': questions[i].answers[0],
        'color': questions[i].answers[0] == resultsList[i] ? 'green' : 'red'
      });
    }

    return summary;
  }

  @override
  Widget build(BuildContext context) {
    final summary = getSummaryData();
    final correctAnswerCount =
        summary.where((element) => element['selectedAnswer'] == element['correctAnswer']).length;
    final totalAnswerCOunt = questions.length;

    return SizedBox(
      width: double.infinity,
      child: Container(
        margin: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'You got $correctAnswerCount out of $totalAnswerCOunt correct!',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 30),
            ResultsSummary(data: summary),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              label: const Text('Back to Home'),
              icon: const Icon(Icons.replay_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultsSummary extends StatelessWidget {
  const ResultsSummary({super.key, required this.data});

  final List<Map<String, String>> data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: SingleChildScrollView(
        child: Column(
          children: data.map((data) {
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: data['color'] == 'green' ? Colors.green : Colors.red[900],
                  child: Text(data['index'] as String),
                ),
                Expanded(
                  // Restricts the column to the width of the row (and will wrap overflow content)
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['question'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        Text(
                          data['correctAnswer'] as String,
                          style: const TextStyle(
                              color: Color.fromARGB(255, 154, 154, 154), fontSize: 14),
                        ),
                        Text(
                          data['selectedAnswer'] as String,
                          style: TextStyle(
                              color: data['color'] == 'green' ? Colors.green : Colors.red[900],
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
