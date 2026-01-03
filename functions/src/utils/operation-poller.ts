import { getGCPProjectNumber } from '../config/google-tts';
import { GoogleAuth } from 'google-auth-library';

/**
 * Result of a completed operation
 */
export interface OperationResult {
  done: boolean;
  error?: {
    code: number;
    message: string;
    details?: any[];
  };
  response?: any;
  name: string;
}

/**
 * Cancel a long-running operation
 * This stops the operation and releases resources
 * @param operationName - The operation name to cancel
 * @returns true if cancelled successfully, false otherwise
 */
export async function cancelOperation(
  operationName: string,
): Promise<boolean> {
  try {
    const projectNumber = getGCPProjectNumber();

    if (!/^\d+$/.test(projectNumber)) {
      throw new Error('Invalid GCP project number');
    }

    const auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    });
    const authClient = await auth.getClient();

    // Normalize operation name
    let fullOperationName = operationName;
    if (!operationName.startsWith('projects/')) {
      const operationId = operationName.split('/').pop();
      fullOperationName = `projects/${projectNumber}/locations/global/operations/${operationId}`;
    }

    const apiBaseUrl = 'https://texttospeech.googleapis.com/v1';
    const { token } = await authClient.getAccessToken();
    
    if (!token) {
      throw new Error('Failed to obtain access token');
    }

    const response = await fetch(`${apiBaseUrl}/${fullOperationName}:cancel`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (response.ok) {
      console.log(`Successfully cancelled operation: ${fullOperationName}`);
      return true;
    } else {
      const text = await response.text();
      console.warn(
        `Failed to cancel operation ${fullOperationName}: HTTP ${response.status} - ${text}`,
      );
      return false;
    }
  } catch (error) {
    console.warn(`Error cancelling operation ${operationName}:`, error);
    return false;
  }
}

/**
 * Poll a Google Cloud long-running operation until it completes
 * Uses REST API + exponential backoff with jitter
 *
 * NOTE:
 * - Requires Node.js 18+ (global fetch)
 * - Handles OAuth token refresh automatically
 */
export async function pollOperationUntilDone(
  operationName: string,
  maxWaitTimeMs: number = 24 * 60 * 60 * 1000, // 24h
  jobId?: string,
): Promise<OperationResult> {
  const projectNumber = getGCPProjectNumber();

  if (!/^\d+$/.test(projectNumber)) {
    throw new Error('Invalid GCP project number');
  }

  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });
  const authClient = await auth.getClient();

  const startTime = Date.now();
  let pollInterval = 5000;
  const maxPollInterval = 60000;
  const backoffMultiplier = 1.5;
  let pollCount = 0;
  let lastLogTime = 0;

  const logContext = jobId ? `[Job ${jobId}]` : '';

  // Normalize operation name
  let fullOperationName = operationName;
  if (!operationName.startsWith('projects/')) {
    const operationId = operationName.split('/').pop();
    fullOperationName = `projects/${projectNumber}/locations/global/operations/${operationId}`;
  }

  const apiBaseUrl = 'https://texttospeech.googleapis.com/v1';

  console.log(`${logContext} Polling operation: ${fullOperationName}`);

  while (true) {
    const elapsed = Date.now() - startTime;
    if (elapsed > maxWaitTimeMs) {
      throw new Error(
        `Operation did not complete within ${Math.round(maxWaitTimeMs / 1000)}s ` +
        `(${pollCount} polls)`,
      );
    }

    pollCount++;

    try {
      // 🔑 Refresh access token on every poll (handles expiration safely)
      const { token } = await authClient.getAccessToken();
      if (!token) {
        throw new Error('Failed to obtain access token');
      }

      const response = await fetch(`${apiBaseUrl}/${fullOperationName}`, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      });

      // Retry on auth errors (token may have expired mid-request)
      if (response.status === 401 || response.status === 403) {
        throw new Error(`AUTH_${response.status}`);
      }

      if (!response.ok) {
        const text = await response.text();
        throw new Error(`HTTP_${response.status}: ${text}`);
      }

      const operation = await response.json();

      if (!operation) {
        throw new Error('Operation not found');
      }

      // Controlled progress logging
      const now = Date.now();
      if (now - lastLogTime > 5 * 60 * 1000 || pollCount % 10 === 0) {
        console.log(
          `${logContext} Poll #${pollCount} | ` +
          `Elapsed: ${Math.round(elapsed / 1000)}s | ` +
          `Interval: ${pollInterval}ms`,
        );
        lastLogTime = now;
      }

      if (operation.done) {
        const result: OperationResult = {
          done: true,
          name: operation.name || fullOperationName,
        };

        if (operation.error) {
          result.error = {
            code: operation.error.code ?? 0,
            message: operation.error.message ?? 'Unknown error',
            details: operation.error.details ?? [],
          };
        } else {
          result.response = operation.response ?? null;
        }

        console.log(
          `${logContext} Operation completed after ${pollCount} polls ` +
          `(${Math.round(elapsed / 1000)}s)`,
        );

        return result;
      }

    } catch (error: any) {
      const message = String(error?.message ?? '').toLowerCase();

      const isRetryable =
        message.includes('network') ||
        message.includes('timeout') ||
        message.includes('econnreset') ||
        message.includes('etimedout') ||
        message.includes('fetch failed') ||
        message.includes('http_5') ||
        message.includes('auth_401') ||
        message.includes('auth_403');

      if (!isRetryable) {
        console.error(`${logContext} Non-retryable polling error`, error);
        throw error;
      }

      console.warn(
        `${logContext} Transient polling error (${error.message}). Retrying...`,
      );
    }

    // ⏱ Exponential backoff with jitter
    await new Promise((r) => setTimeout(r, pollInterval));
    const jitter = Math.random() * 0.2 + 0.9; // ±10%
    pollInterval = Math.min(
      Math.floor(pollInterval * backoffMultiplier * jitter),
      maxPollInterval,
    );
  }
}
