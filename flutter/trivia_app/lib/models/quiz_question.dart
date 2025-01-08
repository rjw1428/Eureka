class QuizQuestion {
  const QuizQuestion(this.question, this.answers);

  final String question;
  final List<String> answers;

  List<String> get shuffledAnswers {
    final copy = List.of(answers);
    copy.shuffle();
    return copy;
  }
}
