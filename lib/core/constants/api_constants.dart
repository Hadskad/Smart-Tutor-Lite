/// Central location for REST endpoints and query params used by the app.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl =
      'https://europe-west2-smart-tutor-lite-a66b5.cloudfunctions.net';

  // Endpoints
  static const String summarize = '/summaries';
  static const String transcription = '/transcriptions';
  static const String quiz = '/quizzes';
  static const String textToSpeech = '/tts';
  static const String flashcards = '/flashcards';

  // Query parameter keys
  static const String useGpu = 'use_gpu';
  static const String pdfUrl = 'pdf_url';

  // Network speed test file URL (to be set after Firebase Storage upload)
  static const String speedTestFileUrl =
      'https://firebasestorage.googleapis.com/v0/b/smart-tutor-lite-a66b5.firebasestorage.app/o/speedtest%2Ftest.json?alt=media&token=697264f6-04ed-4823-84d0-c87a8692e25e';
}
