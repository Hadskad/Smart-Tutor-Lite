"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.summarizeText = summarizeText;
exports.generateQuiz = generateQuiz;
exports.generateFlashcards = generateFlashcards;
const openai_1 = require("../config/openai");
const GPT_MODEL = 'gpt-4.1-mini';
/**
 * Summarize text using OpenAI
 */
async function summarizeText(options) {
    const { text } = options;
    const input = `
<system>
You summarize content clearly, accurately, and in a way that preserves key ideas,
main arguments, and essential details. You avoid unnecessary filler and maintain
the author’s intent and meaning.
</system>

<user>
Summarize the following text. Keep the length appropriate to the content.
If it is long, produce a detailed multi-paragraph summary. If it is short,
use a concise paragraph.

Text:
${text}
</user>
`;
    const response = await openai_1.openai.responses.create({
        model: GPT_MODEL,
        input,
        temperature: 0.3,
    });
    const summary = extractResponseText(response);
    if (!summary)
        throw new Error('Summary generation failed: empty response');
    return summary;
}
/**
 * Generate quiz questions from content using OpenAI
 */
async function generateQuiz(options) {
    const { content, numQuestions, difficulty } = options;
    const input = `
<system>
You generate high-quality multiple-choice questions directly from the
given content. Follow these rules strictly:

1. Every question must be fully answerable ONLY using the provided content.
2. No invented facts, no hallucinations.
3. Each question must have exactly four options.
4. Options must be plausible and not obviously wrong.
5. Correct answer index must match the correct option.
6. Difficulty must match the requested level (“easy”, “medium”, “hard”).
7. Output ONLY valid JSON. No explanations, no Markdown, no text outside the JSON.
8. Keep questions clear, unambiguous, and well-written.
</system>

<user>
Generate ${numQuestions} ${difficulty} multiple-choice questions based strictly on the text below.
Return a JSON array of objects with this exact structure:

[
  {
    "question": "string",
    "options": ["A", "B", "C", "D"],
    "correctAnswer": 0,
    "explanation": "string"
  }
]

CONTENT:
${content}
</user>
`;
    const response = await openai_1.openai.responses.create({
        model: GPT_MODEL,
        input,
        temperature: 0.2, // better accuracy
    });
    const text = extractResponseText(response);
    if (!text)
        throw new Error('Failed to generate quiz');
    try {
        const parsed = JSON.parse(text);
        const questions = parsed.questions ?? parsed;
        const normalized = normalizeQuizQuestions(questions, numQuestions);
        return { questions: normalized };
    }
    catch (error) {
        throw new Error(`Failed to parse quiz response: ${error instanceof Error ? error.message : error}`);
    }
}
/**
 * Generate flashcards from content using OpenAI
 */
async function generateFlashcards(options) {
    const { content, numFlashcards } = options;
    const prompt = `Generate ${numFlashcards} flashcards based on the following content.
Return a JSON array with this structure:
[
  {
    "front": "Question or term",
    "back": "Answer or definition"
  }
]

Content:
${content}`;
    const response = await openai_1.openai.responses.create({
        model: GPT_MODEL,
        input: [
            {
                role: 'system',
                content: 'You are an educational assistant that creates effective flashcards.',
            },
            {
                role: 'user',
                content: prompt,
            },
        ],
        temperature: 0.7,
    });
    const contentText = extractResponseText(response);
    if (!contentText) {
        throw new Error('Failed to generate flashcards');
    }
    try {
        const parsed = JSON.parse(contentText);
        const flashcards = parsed.flashcards ?? parsed;
        return normalizeFlashcards(flashcards, numFlashcards);
    }
    catch (error) {
        throw new Error(`Failed to parse flashcards response: ${error instanceof Error ? error.message : error}`);
    }
}
function ensureString(value, field) {
    if (typeof value !== 'string') {
        throw new Error(`${field} must be a string`);
    }
    const trimmed = value.trim();
    if (!trimmed) {
        throw new Error(`${field} cannot be empty`);
    }
    return trimmed;
}
function ensureStringArray(value, field) {
    if (!Array.isArray(value)) {
        throw new Error(`${field} must be an array`);
    }
    const normalized = value.map((item, index) => ensureString(item, `${field}[${index}]`));
    return normalized;
}
function normalizeQuizQuestions(raw, expectedCount) {
    const list = Array.isArray(raw) ? raw : [raw];
    if (!list.length) {
        throw new Error('Quiz generation returned no questions');
    }
    const normalized = list.map((item, index) => {
        if (!item || typeof item !== 'object') {
            throw new Error(`questions[${index}] must be an object`);
        }
        const question = ensureString(item.question, `questions[${index}].question`);
        const options = ensureStringArray(item.options, `questions[${index}].options`);
        if (options.length < 2) {
            throw new Error(`questions[${index}].options must include at least 2 values`);
        }
        const correctAnswer = item.correctAnswer;
        if (typeof correctAnswer !== 'number' ||
            correctAnswer < 0 ||
            correctAnswer >= options.length) {
            throw new Error(`questions[${index}].correctAnswer must be a valid option index`);
        }
        const explanation = ensureString(item.explanation, `questions[${index}].explanation`);
        return {
            question,
            options,
            correctAnswer,
            explanation,
        };
    });
    if (normalized.length < expectedCount) {
        console.warn(`Expected ${expectedCount} quiz questions but received ${normalized.length}`);
    }
    return normalized;
}
function normalizeFlashcards(raw, expectedCount) {
    const list = Array.isArray(raw) ? raw : [raw];
    if (!list.length) {
        throw new Error('Flashcard generation returned no cards');
    }
    const normalized = list.map((item, index) => {
        if (!item || typeof item !== 'object') {
            throw new Error(`flashcards[${index}] must be an object`);
        }
        return {
            front: ensureString(item.front, `flashcards[${index}].front`),
            back: ensureString(item.back, `flashcards[${index}].back`),
        };
    });
    if (normalized.length < expectedCount) {
        console.warn(`Expected ${expectedCount} flashcards but received ${normalized.length}`);
    }
    return normalized;
}
function extractResponseText(response) {
    if (!response) {
        throw new Error('Empty response from OpenAI');
    }
    const outputText = Array.isArray(response.output_text)
        ? response.output_text.join('\n').trim()
        : typeof response.output_text === 'string'
            ? response.output_text.trim()
            : '';
    if (outputText) {
        return outputText;
    }
    if (Array.isArray(response.output)) {
        const chunkText = response.output
            .flatMap((item) => Array.isArray(item?.content) ? item.content : [])
            .map((content) => {
            if (typeof content?.text === 'string') {
                return content.text;
            }
            if (typeof content?.content === 'string') {
                return content.content;
            }
            return '';
        })
            .join('')
            .trim();
        if (chunkText) {
            return chunkText;
        }
    }
    throw new Error('OpenAI response did not include any text output');
}
//# sourceMappingURL=openai-helpers.js.map