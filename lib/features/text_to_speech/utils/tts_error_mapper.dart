/// Maps TTS error codes and messages to user-friendly messages
class TtsErrorMapper {
  TtsErrorMapper._();

  /// Error patterns and their user-friendly messages
  static const Map<String, String> _errorPatterns = {
    // PDF-related errors
    'no text content': 'This PDF has no readable text. It may be image-only or scanned.',
    'empty pdf': 'This PDF appears to be empty.',
    'pdf too large': 'PDF is too large. Maximum size is 25MB.',
    'failed to extract': 'Could not extract text from this PDF.',
    
    // API errors
    'quota exceeded': 'Service limit reached. Please try again later.',
    'rate limit': 'Too many requests. Please wait a moment.',
    '503': 'Audio service is temporarily unavailable.',
    '502': 'Audio service is temporarily unavailable.',
    '504': 'The request timed out. Please try again.',
    '429': 'Too many requests. Please wait a moment.',
    
    // Network errors
    'network': 'Check your internet connection and try again.',
    'timeout': 'The request timed out. Please try again.',
    'connection': 'Could not connect to the server.',
    'econnrefused': 'Could not connect to the server.',
    'econnreset': 'Connection was interrupted. Please try again.',
    'etimedout': 'The request timed out. Please try again.',
    
    // Google TTS errors
    'synthesize': 'Failed to generate audio. Please try again.',
    'audio generation': 'Failed to generate audio. Please try again.',
    'invalid voice': 'Selected voice is not available.',
    
    // General errors
    'unknown': 'Something went wrong. Please try again.',
  };

  /// Default fallback message
  static const String _defaultMessage = 'Audio conversion failed. Please try again.';

  /// Converts a technical error message to a user-friendly message
  static String toFriendlyMessage(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) {
      return _defaultMessage;
    }

    final lowerError = errorMessage.toLowerCase();

    // Check for pattern matches
    for (final entry in _errorPatterns.entries) {
      if (lowerError.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    // If no pattern matches, return a cleaned-up version
    // Remove technical prefixes like "Error:", "Exception:", etc.
    String cleaned = errorMessage
        .replaceAll(RegExp(r'^(error|exception|failure):\s*', caseSensitive: false), '')
        .trim();

    // If still too technical, return default
    if (cleaned.length > 100 || 
        cleaned.contains('Exception') || 
        cleaned.contains('Stack') ||
        cleaned.contains('at line') ||
        cleaned.contains('null')) {
      return _defaultMessage;
    }

    // Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
      // Add period if missing
      if (!cleaned.endsWith('.') && !cleaned.endsWith('!') && !cleaned.endsWith('?')) {
        cleaned += '.';
      }
    }

    return cleaned.isEmpty ? _defaultMessage : cleaned;
  }
}

