import { getSonioxApiKey } from '../config/soniox';
import { getSignedUrl } from './storage-helpers';
import * as functions from 'firebase-functions';

const SONIOX_BASE_URL = 'https://api.soniox.com/v1';
const SONIOX_TRANSCRIPTIONS_ENDPOINT = `${SONIOX_BASE_URL}/transcriptions`;
const DEFAULT_TIMEOUT_MS = 30_000;
const POLL_INTERVAL_MS = 5_000; // Poll every 5 seconds
const MAX_POLL_ATTEMPTS = 3600; // Max 5 hours of polling (3600 * 5 seconds)

type SonioxApiResponse = {
  transcription_id?: string;
  status?: string;
  result?: {
    text?: string;
    confidence?: number;
  };
  text?: string;
  confidence?: number;
  segments?: Array<{
    text?: string;
    confidence?: number;
  }>;
  error?: {
    message?: string;
    code?: string;
  };
  [key: string]: unknown;
};

export type SonioxTranscription = {
  text: string;
  confidence?: number;
  raw: SonioxApiResponse;
};

export type SonioxErrorCode =
  | 'bad_audio'
  | 'too_long'
  | 'quota_exceeded'
  | 'provider_down'
  | 'timeout'
  | 'unauthorized'
  | 'unknown';

export class SonioxError extends Error {
  constructor(
    message: string,
    public options: { status?: number; code?: SonioxErrorCode } = {},
  ) {
    super(message);
    this.name = 'SonioxError';
  }

  get status(): number | undefined {
    return this.options.status;
  }

  get code(): SonioxErrorCode {
    return this.options.code ?? 'unknown';
  }
}

const safeJson = async (response: globalThis.Response) => {
  try {
    return await response.json();
  } catch {
    return null;
  }
};

const mapStatusToCode = (
  status: number,
  providerCode?: string,
): SonioxErrorCode => {
  if (providerCode) {
    switch (providerCode) {
      case 'audio-too-long':
        return 'too_long';
      case 'audio-invalid':
      case 'audio-too-quiet':
        return 'bad_audio';
      case 'quota-exceeded':
        return 'quota_exceeded';
      default:
        break;
    }
  }

  if (status === 401 || status === 403) {
    return 'unauthorized';
  }

  if (status >= 500) {
    return 'provider_down';
  }

  if (status === 408) {
    return 'timeout';
  }

  return 'unknown';
};

/**
 * Create async transcription job using audio URL.
 *
 * According to Soniox docs, async jobs are created via:
 *   POST /v1/transcriptions  with model: "stt-async-v3" and audio_url.
 */
async function createTranscriptionJob(
  audioUrl: string,
  apiKey: string,
  timeoutMs: number,
): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(SONIOX_TRANSCRIPTIONS_ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'stt-async-v3',
        audio_url: audioUrl,
        enable_speaker_diarization: true,
        enable_language_identification: true,
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const body = (await safeJson(response)) as SonioxApiResponse | null;
      const errorMessage = body?.error?.message ?? `Soniox request failed with status ${response.status}`;
      const errorCode = body?.error?.code;
      
      // Log the full error for debugging
      functions.logger.error('Soniox API error', {
        status: response.status,
        errorCode,
        errorMessage,
        requestBody: {
          model: 'v3',
          audio_url: audioUrl.substring(0, 100) + '...', // Log partial URL for debugging
        },
        responseBody: body,
      });
      
      const code = mapStatusToCode(response.status, errorCode);
      throw new SonioxError(errorMessage, {
        status: response.status,
        code,
      });
    }

    const data = (await response.json()) as SonioxApiResponse;
    
    // Log the full response to see what Soniox actually returns
    functions.logger.debug('Soniox createTranscriptionJob response', {
      status: response.status,
      responseData: data,
      hasTranscriptionId: !!data.transcription_id,
      allKeys: Object.keys(data),
    });
    
    if (!data.transcription_id) {
      // Check for alternative field names
      const alternativeId = (data as any).id || 
                           (data as any).job_id || 
                           (data as any).transcriptionId ||
                           (data as any).jobId;
      
      if (alternativeId) {
        functions.logger.warn('Found transcription ID with alternative field name', {
          fieldName: alternativeId ? Object.keys(data).find(k => (data as any)[k] === alternativeId) : null,
          value: alternativeId,
        });
        return alternativeId;
      }
      
      // If response has result directly (synchronous), handle it
      if (data.result?.text || data.text) {
        functions.logger.warn('Soniox returned result synchronously (not async)', {
          hasResult: !!data.result,
          hasText: !!data.text,
        });
        throw new SonioxError('Soniox returned synchronous result but async job ID expected', {
          code: 'provider_down',
        });
      }
      
      throw new SonioxError('Soniox did not return transcription_id', {
        code: 'provider_down',
      });
    }

    return data.transcription_id;
  } catch (error) {
    if (error instanceof SonioxError) {
      throw error;
    }
    if (error instanceof Error && error.name === 'AbortError') {
      throw new SonioxError('Soniox job creation timed out', {
        code: 'timeout',
      });
    }
    throw new SonioxError(
      error instanceof Error ? error.message : 'Unknown Soniox error',
      {
        code: 'provider_down',
      },
    );
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Fetch metadata for a transcription job.
 *
 * Docs: GET /v1/transcriptions/{transcription_id}
 */
async function getTranscriptionMetadata(
  transcriptionId: string,
  apiKey: string,
): Promise<SonioxApiResponse> {
  const endpoint = `${SONIOX_TRANSCRIPTIONS_ENDPOINT}/${transcriptionId}`;

  const response = await fetch(endpoint, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
  });

  if (!response.ok) {
    const body = (await safeJson(response)) as SonioxApiResponse | null;
    const code = mapStatusToCode(response.status, body?.error?.code);
    throw new SonioxError(
      body?.error?.message ??
        `Failed to get transcription status: ${response.status}`,
      {
        status: response.status,
        code,
      },
    );
  }

  return (await response.json()) as SonioxApiResponse;
}

/**
 * Fetch the transcript for a completed transcription job.
 *
 * Docs: GET /v1/transcriptions/{transcription_id}/transcript
 * Response includes "text" and optionally "tokens", etc.
 */
async function getTranscriptionTranscript(
  transcriptionId: string,
  apiKey: string,
): Promise<SonioxApiResponse> {
  const endpoint = `${SONIOX_TRANSCRIPTIONS_ENDPOINT}/${transcriptionId}/transcript`;

  const response = await fetch(endpoint, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
  });

  if (!response.ok) {
    const body = (await safeJson(response)) as SonioxApiResponse | null;
    const code = mapStatusToCode(response.status, body?.error?.code);
    throw new SonioxError(
      body?.error?.message ??
        `Failed to get transcription transcript: ${response.status}`,
      {
        status: response.status,
        code,
      },
    );
  }

  // According to Soniox docs this response contains "text" and other fields.
  return (await response.json()) as SonioxApiResponse;
}

/**
 * Poll for transcription result until completed, then fetch transcript.
 */
async function pollTranscriptionResult(
  transcriptionId: string,
  apiKey: string,
  timeoutMs: number,
): Promise<SonioxApiResponse> {
  const startTime = Date.now();
  let attempts = 0;

  while (attempts < MAX_POLL_ATTEMPTS) {
    if (Date.now() - startTime > timeoutMs) {
      throw new SonioxError('Transcription polling timed out', {
        code: 'timeout',
      });
    }

    const meta = await getTranscriptionMetadata(transcriptionId, apiKey);

    // Log status for debugging
    functions.logger.debug('Soniox polling status', {
      transcriptionId,
      status: meta.status,
      attempt: attempts + 1,
      elapsed: Date.now() - startTime,
    });

    if (meta.status === 'completed' || meta.status === 'done') {
      // Fetch the actual transcript per Soniox docs.
      const transcript = await getTranscriptionTranscript(
        transcriptionId,
        apiKey,
      );
      return transcript;
    }

    if (meta.status === 'failed' || meta.status === 'error') {
      throw new SonioxError(
        meta.error?.message ?? 'Transcription failed',
        {
          code: 'bad_audio',
        },
      );
    }

    // Status is 'processing', 'pending', 'queued', or any other intermediate state - wait and retry
    if (
      meta.status === 'processing' ||
      meta.status === 'pending' ||
      meta.status === 'queued' ||
      !meta.status
    ) {
      await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
      attempts++;
      continue;
    }

    // Unknown status - log warning but continue polling cautiously.
    functions.logger.warn('Unknown Soniox status, continuing to poll', {
      transcriptionId,
      status: meta.status,
      attempt: attempts + 1,
    });

    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
    attempts++;
  }

  throw new SonioxError('Transcription did not complete in time', {
    code: 'timeout',
  });
}


export const transcribeWithSoniox = async (
  audioStoragePath: string,
  {
    timeoutMs = DEFAULT_TIMEOUT_MS,
  }: {
    timeoutMs?: number;
  } = {},
): Promise<SonioxTranscription> => {
  if (!audioStoragePath) {
    throw new SonioxError('Audio storage path is required', {
      code: 'bad_audio',
    });
  }

  const apiKey = getSonioxApiKey();

  try {
    // Use longer expiry (5 hours) to ensure Soniox has time to process
    const audioUrl = await getSignedUrl(audioStoragePath, 18000); // 5 hours

    // Optional: Validate URL is accessible (can be disabled for production)
    // const isAccessible = await validateUrlAccessibility(audioUrl);
    // if (!isAccessible) {
    //   throw new SonioxError('Generated URL is not accessible', {
    //     code: 'bad_audio',
    //   });
    // }
    
    // Validate URL format
    if (!audioUrl || !audioUrl.startsWith('https://')) {
      throw new SonioxError('Invalid audio URL format', {
        code: 'bad_audio',
      });
    }
    
    // Log the URL for debugging (first 100 chars only)
    functions.logger.debug('Generated signed URL for Soniox', {
      storagePath: audioStoragePath,
      urlLength: audioUrl.length,
      urlPrefix: audioUrl.substring(0, 100),
      urlSuffix: audioUrl.substring(audioUrl.length - 50),
      expiryHours: 5, // 18000 seconds = 5 hours
    });
    
    // Test URL accessibility (optional, can be removed in production)
    try {
      const testResponse = await fetch(audioUrl, { method: 'HEAD' });
      functions.logger.debug('URL accessibility test', {
        accessible: testResponse.ok,
        status: testResponse.status,
      });
    } catch (error) {
      functions.logger.warn('URL accessibility test failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      // Continue anyway - Soniox might still be able to access it
    }
    
    // Create transcription job
    const transcriptionId = await createTranscriptionJob(
      audioUrl,
      apiKey,
      timeoutMs,
    );

    // Poll for result
    const result = await pollTranscriptionResult(
      transcriptionId,
      apiKey,
      timeoutMs,
    );

    // Extract text and confidence
    const text =
      result.result?.text ||
      result.text ||
      result.segments?.map((segment) => segment.text ?? '').join(' ').trim();

    if (!text) {
      throw new SonioxError('Soniox response did not include any text', {
        code: 'bad_audio',
      });
    }

    const confidence = result.result?.confidence ?? result.confidence;

    return {
      text,
      confidence: confidence ? Math.min(Math.max(confidence, 0), 1) : undefined,
      raw: result,
    };
  } catch (error) {
    if (error instanceof SonioxError) {
      throw error;
    }
    throw new SonioxError(
      error instanceof Error ? error.message : 'Unknown Soniox error',
      {
        code: 'provider_down',
      },
    );
  }
};

