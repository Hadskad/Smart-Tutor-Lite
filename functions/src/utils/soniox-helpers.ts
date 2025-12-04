import { getSonioxApiKey } from '../config/soniox';

const SONIOX_ENDPOINT = 'https://api.soniox.com/v1/cloud/transcribe';
const DEFAULT_TIMEOUT_MS = 30_000;

type SonioxApiResponse = {
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

export const transcribeWithSoniox = async (
  audioBuffer: Buffer,
  {
    language = 'en',
    timeoutMs = DEFAULT_TIMEOUT_MS,
  }: {
    language?: string;
    timeoutMs?: number;
  } = {},
): Promise<SonioxTranscription> => {
  if (!audioBuffer?.length) {
    throw new SonioxError('Audio buffer is empty.', {
      code: 'bad_audio',
    });
  }

  const apiKey = getSonioxApiKey();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(SONIOX_ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        config: {
          language,
        },
        audio: {
          content: audioBuffer.toString('base64'),
        },
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const body = (await safeJson(response)) as SonioxApiResponse | null;
      const code = mapStatusToCode(response.status, body?.error?.code);
      throw new SonioxError(
        body?.error?.message ??
          `Soniox request failed with status ${response.status}`,
        {
          status: response.status,
          code,
        },
      );
    }

    const data = (await response.json()) as SonioxApiResponse;
    const bestText =
      data.result?.text ||
      data.text ||
      data.segments?.map((segment) => segment.text ?? '').join(' ').trim();

    if (!bestText) {
      throw new SonioxError('Soniox response did not include any text.', {
        code: 'bad_audio',
      });
    }

    const confidence =
      data.result?.confidence ??
      data.confidence ??
      data.segments?.reduce((acc, segment, index, arr) => {
        if (segment.confidence) {
          const weight = 1 / arr.length;
          return acc + segment.confidence * weight;
        }
        return acc;
      }, 0);

    return {
      text: bestText,
      confidence: confidence ? Math.min(Math.max(confidence, 0), 1) : undefined,
      raw: data,
    };
  } catch (error) {
    if (error instanceof SonioxError) {
      throw error;
    }
    if (error instanceof Error && error.name === 'AbortError') {
      throw new SonioxError('Soniox request timed out.', {
        code: 'timeout',
      });
    }
    throw new SonioxError(
      error instanceof Error ? error.message : 'Unknown Soniox error.',
      {
        code: 'provider_down',
      },
    );
  } finally {
    clearTimeout(timeout);
  }
};

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

