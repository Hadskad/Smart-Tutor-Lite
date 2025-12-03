"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_VOICE_ID = exports.PREMADE_VOICES = exports.ELEVENLABS_API_URL = void 0;
exports.getElevenLabsApiKey = getElevenLabsApiKey;
exports.isPremadeVoice = isPremadeVoice;
const functions = __importStar(require("firebase-functions"));
// ElevenLabs API Configuration
exports.ELEVENLABS_API_URL = 'https://api.elevenlabs.io/v1';
// Popular premade voices from ElevenLabs
exports.PREMADE_VOICES = {
    '21m00Tcm4TlvDq8ikWAM': {
        name: 'Rachel',
        description: 'Professional female voice',
        category: 'premade',
    },
    'pNInz6obpgDQGcFmaJgB': {
        name: 'Adam',
        description: 'Professional male voice',
        category: 'premade',
    },
    'EXAVITQu4vr4xnSDxMaL': {
        name: 'Bella',
        description: 'Casual female voice',
        category: 'premade',
    },
    'ErXwobaYiN019PkySvjV': {
        name: 'Antoni',
        description: 'Casual male voice',
        category: 'premade',
    },
};
// Default voice ID (Rachel)
exports.DEFAULT_VOICE_ID = '21m00Tcm4TlvDq8ikWAM';
/**
 * Get ElevenLabs API key from Firebase Functions config or environment variables
 */
function getElevenLabsApiKey() {
    const apiKey = functions.config().elevenlabs?.api_key || process.env.ELEVENLABS_API_KEY;
    if (!apiKey) {
        throw new Error('ELEVENLABS_API_KEY is not set in Firebase Functions config or environment variables.');
    }
    return apiKey;
}
/**
 * Check if a voice ID is a known premade voice
 */
function isPremadeVoice(voiceId) {
    return voiceId in exports.PREMADE_VOICES;
}
//# sourceMappingURL=elevenlabs-tts.js.map