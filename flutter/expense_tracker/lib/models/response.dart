class Response {
  const Response({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;
}
