"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.transcribeWithSoniox = exports.SonioxError = void 0;
const soniox_1 = require("../config/soniox");
const SONIOX_ENDPOINT = 'https://api.soniox.com/v1/cloud/transcribe';
const DEFAULT_TIMEOUT_MS = 30000;
class SonioxError extends Error {
    constructor(message, status) {
        super(message);
        this.status = status;
        this.name = 'SonioxError';
    }
}
exports.SonioxError = SonioxError;
const transcribeWithSoniox = async (audioBuffer, { language = 'en', timeoutMs = DEFAULT_TIMEOUT_MS, } = {}) => {
    if (!audioBuffer?.length) {
        throw new SonioxError('Audio buffer is empty.');
    }
    const apiKey = (0, soniox_1.getSonioxApiKey)();
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
            throw new SonioxError(`Soniox request failed with status ${response.status}`, response.status);
        }
        const data = (await response.json());
        const bestText = data.result?.text ||
            data.text ||
            data.segments?.map((segment) => segment.text ?? '').join(' ').trim();
        if (!bestText) {
            throw new SonioxError('Soniox response did not include any text.');
        }
        const confidence = data.result?.confidence ??
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
    }
    catch (error) {
        if (error instanceof SonioxError) {
            throw error;
        }
        if (error instanceof Error && error.name === 'AbortError') {
            throw new SonioxError('Soniox request timed out.');
        }
        throw new SonioxError(error instanceof Error ? error.message : 'Unknown Soniox error.');
    }
    finally {
        clearTimeout(timeout);
    }
};
exports.transcribeWithSoniox = transcribeWithSoniox;
const safeJson = async (response) => {
    try {
        return await response.json();
    }
    catch {
        return null;
    }
};
//# sourceMappingURL=soniox-helpers.js.map