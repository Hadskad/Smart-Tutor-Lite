/// Central location for REST endpoints and query params used by the app.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://us-central1-smart-tutor-lite-a66b5.cloudfunctions.net';

  // Endpoints
  static const String summarize = '/summaries';
  static const String transcription = '/transcriptions';
  static const String quiz = '/quizzes';
  static const String textToSpeech = '/tts';
  static const String flashcards = '/flashcards';

  // Query parameter keys
  static const String maxLength = 'max_length';
  static const String useGpu = 'use_gpu';
  static const String pdfUrl = 'pdf_url';
}
