"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.tts = exports.flashcards = exports.quizzes = exports.summaries = exports.transcriptions = void 0;
// Export all API endpoints
var transcriptions_1 = require("./api/transcriptions");
Object.defineProperty(exports, "transcriptions", { enumerable: true, get: function () { return transcriptions_1.transcriptions; } });
var summaries_1 = require("./api/summaries");
Object.defineProperty(exports, "summaries", { enumerable: true, get: function () { return summaries_1.summaries; } });
var quizzes_1 = require("./api/quizzes");
Object.defineProperty(exports, "quizzes", { enumerable: true, get: function () { return quizzes_1.quizzes; } });
var flashcards_1 = require("./api/flashcards");
Object.defineProperty(exports, "flashcards", { enumerable: true, get: function () { return flashcards_1.flashcards; } });
var tts_1 = require("./api/tts");
Object.defineProperty(exports, "tts", { enumerable: true, get: function () { return tts_1.tts; } });
//# sourceMappingURL=index.js.map