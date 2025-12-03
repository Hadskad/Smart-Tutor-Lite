import * as functions from 'firebase-functions';

const config = functions.config();

export const getSonioxApiKey = (): string => {
  const apiKey = config.soniox?.api_key || process.env.SONIOX_API_KEY;

  if (!apiKey) {
    throw new Error(
      'Soniox API key not found. Set it via firebase functions config (soniox.api_key) or SONIOX_API_KEY env var.',
    );
  }

  return apiKey;
};


