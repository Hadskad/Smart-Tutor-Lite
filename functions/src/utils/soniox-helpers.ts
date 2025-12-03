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
  [key: string]: unknown;
};

export type SonioxTranscription = {
  text: string;
  confidence?: number;
  raw: SonioxApiResponse;
};

export class SonioxError extends Error {
  constructor(message: string, public status?: number) {
    super(message);
    this.name = 'SonioxError';
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
    throw new SonioxError('Audio buffer is empty.');
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
      await safeJson(response);
      throw new SonioxError(
        `Soniox request failed with status ${response.status}`,
        response.status,
      );
    }

    const data = (await response.json()) as SonioxApiResponse;
    const bestText =
      data.result?.text ||
      data.text ||
      data.segments?.map((segment) => segment.text ?? '').join(' ').trim();

    if (!bestText) {
      throw new SonioxError('Soniox response did not include any text.');
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
      throw new SonioxError('Soniox request timed out.');
    }
    throw new SonioxError(
      error instanceof Error ? error.message : 'Unknown Soniox error.',
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


