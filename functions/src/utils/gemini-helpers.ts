import { genAI } from '../config/gemini';

const GEMINI_MODEL = 'gemini-2.5-flash';

// Study-notes specific config
const STUDY_NOTES_TIMEOUT_MS = 10 * 60 * 1000; // ~10 minutes
const STUDY_NOTES_MAX_RETRIES = 3;
const MIN_TRANSCRIPT_CHARS = 20;

export interface SummarizeOptions {
  text: string;
  isPdf?: boolean; // Indicates if the content is from a PDF (study notes)
}

export interface GenerateQuizOptions {
  content: string;
  numQuestions: number;
  difficulty: 'easy' | 'medium' | 'hard';
}

export interface GenerateFlashcardsOptions {
  content: string;
  numFlashcards: number;
}

export interface StudyNote {
  title: string;
  summary: string;
  keyPoints: string[];
  actionItems: string[];
  studyQuestions: string[];
}

export interface GenerationMeta {
  model: string;
  requestId?: string;
  createdAt: string; // ISO
  attempts: number;
  sanitized: boolean;
  warnings?: string[];
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  usage?: any; // raw usage object from Gemini (optional)
}

export interface GenerationResult {
  note: StudyNote;
  meta: GenerationMeta;
}

/**
 * Summarize text using Gemini
 */
export async function summarizeText(options: SummarizeOptions): Promise<string> {
  const { text, isPdf = false } = options;

  let systemPrompt: string;
  let userPrompt: string;

  if (isPdf) {
    // Specialized prompt for PDF study notes
    systemPrompt = 'You are an expert academic summarizer specializing in creating comprehensive, well-structured summaries of study notes and educational materials. Your summaries must be perfectly balanced: include ALL important information without adding unnecessary details, maintain clear structure, and preserve the logical flow of the original content.';
    userPrompt = `The following content is extracted from a PDF document containing study notes. Your task is to create a perfect summary that:

1. Preserves ALL important information - no key concepts, facts, definitions, or critical details should be omitted
2. Maintains excellent structure with clear sections, headings, and logical organization
3. Excludes unnecessary filler, redundant information, or irrelevant details
4. Uses clear, concise language while retaining the educational value
5. Follows the original content's structure and flow when appropriate

Create a comprehensive, well-structured summary that a student can study from effectively:\n\n${text}`;
  } else {
    // Standard prompt for general text summarization
    systemPrompt = 'You summarize content clearly, accurately, and in a way that preserves key ideas, main arguments, and essential details. You avoid unnecessary filler and maintain the author\'s intent and meaning.';
    userPrompt = `Summarize the following text. Keep the length appropriate to the content. If it is long, produce a detailed multi-paragraph summary. If it is short, use a concise paragraph.\n\nText:\n${text}`;
  }

  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });
  
  const result = await model.generateContent({
    contents: [
      {
        role: 'user',
        parts: [
          { text: `${systemPrompt}\n\n${userPrompt}` }
        ]
      }
    ],
    generationConfig: {
      temperature: 0.3,
    },
  });

  const summary = result.response.text();
  if (!summary) throw new Error('Summary generation failed: empty response');
  return summary;
}


/**
 * Generate quiz questions from content using Gemini
 */
export async function generateQuiz(
  options: GenerateQuizOptions
): Promise<{
  questions: Array<{
    question: string;
    options: string[];
    correctAnswer: number;
    explanation: string;
  }>;
}> {
  const { content, numQuestions, difficulty } = options;

  const systemPrompt = `You generate high-quality multiple-choice questions directly from the given content. Follow these rules strictly:

1. Every question must be fully answerable ONLY using the provided content.
2. No invented facts, no hallucinations.
3. Each question must have exactly four options.
4. Options must be plausible and not obviously wrong.
5. Correct answer index must match the correct option.
6. Difficulty must match the requested level ("easy", "medium", "hard").
7. Output ONLY valid JSON. No explanations, no Markdown, no text outside the JSON.
8. Keep questions clear, unambiguous, and well-written.`;

  const userPrompt = `Generate ${numQuestions} ${difficulty} multiple-choice questions based strictly on the text below.
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
${content}`;

  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });
  
  const result = await model.generateContent({
    contents: [
      {
        role: 'user',
        parts: [
          { text: `${systemPrompt}\n\n${userPrompt}` }
        ]
      }
    ],
    generationConfig: {
      temperature: 0.2,
    },
  });

  const text = result.response.text();
  if (!text) throw new Error('Failed to generate quiz');

  try {
    const parsed = JSON.parse(text);
    const questions = parsed.questions ?? parsed;
    const normalized = normalizeQuizQuestions(questions, numQuestions);
    return { questions: normalized };
  } catch (error) {
    throw new Error(
      `Failed to parse quiz response: ${
        error instanceof Error ? error.message : error
      }`
    );
  }
}


/**
 * Generate flashcards from content using Gemini
 */
export async function generateFlashcards(
  options: GenerateFlashcardsOptions
): Promise<Array<{ front: string; back: string }>> {
  const { content, numFlashcards } = options;

  const systemPrompt = `You are an expert educational assistant specialized in creating effective flashcards for active recall and spaced repetition learning. Follow these principles:

1. Extract key concepts, definitions, and important facts from the content
2. Front of card: Clear, concise question or key term
3. Back of card: Complete, informative answer or definition
4. Focus on atomic knowledge - one concept per card
5. Avoid overly complex or compound questions
6. Use clear, student-friendly language
7. Ensure flashcards are directly answerable from the given content`;

  const userPrompt = `Generate exactly ${numFlashcards} high-quality flashcards from the following educational content.

Return ONLY a valid JSON array with this exact structure (no markdown, no additional text):
[
  {
    "front": "Key concept, term, or question",
    "back": "Complete definition, explanation, or answer"
  }
]

Content to extract flashcards from:
${content}`;

  const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });
  
  const result = await model.generateContent({
    contents: [
      {
        role: 'user',
        parts: [
          { text: `${systemPrompt}\n\n${userPrompt}` }
        ]
      }
    ],
    generationConfig: {
      temperature: 0.4,
    },
  });

  const contentText = result.response.text();
  if (!contentText || !contentText.trim()) {
    throw new Error('Failed to generate flashcards: Gemini returned empty response');
  }

  // Try multiple parsing strategies
  let parsed: any;
  let parseError: Error | null = null;

  // Strategy 1: Direct JSON parse
  try {
    parsed = JSON.parse(contentText.trim());
  } catch (e) {
    parseError = e instanceof Error ? e : new Error(String(e));
    
    // Strategy 2: Extract JSON from markdown code blocks
    const jsonMatch = contentText.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
    if (jsonMatch && jsonMatch[1]) {
      try {
        parsed = JSON.parse(jsonMatch[1].trim());
        parseError = null;
      } catch (e2) {
        // Continue to next strategy
      }
    }
    
    // Strategy 3: Extract JSON object from text
    if (parseError) {
      const firstBrace = contentText.indexOf('[');
      const lastBrace = contentText.lastIndexOf(']');
      if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
        try {
          const jsonCandidate = contentText.substring(firstBrace, lastBrace + 1);
          parsed = JSON.parse(jsonCandidate);
          parseError = null;
        } catch (e3) {
          // All strategies failed
        }
      }
    }
  }

  if (parseError || !parsed) {
    throw new Error(
      `Failed to parse flashcards response: ${parseError?.message || 'Invalid JSON format'}. ` +
      `Response preview: ${contentText.substring(0, 200)}...`
    );
  }

  // Extract flashcards array from response
  let flashcards: any;
  if (Array.isArray(parsed)) {
    flashcards = parsed;
  } else if (parsed.flashcards && Array.isArray(parsed.flashcards)) {
    flashcards = parsed.flashcards;
  } else if (parsed.data && Array.isArray(parsed.data)) {
    flashcards = parsed.data;
  } else {
    throw new Error(
      `Invalid flashcard response structure. Expected array or object with 'flashcards' property. ` +
      `Got: ${typeof parsed}`
    );
  }

  return normalizeFlashcards(flashcards, numFlashcards);
}

export async function generateStudyNotes(content: string): Promise<StudyNote> {
  const { note } = await generateStudyNotesWithMeta(content);
  return note;
}

const STUDY_NOTES_JSON_SCHEMA_PROMPT = `Respond ONLY with a single valid JSON object EXACTLY matching this schema (no surrounding text):
{
  "title": "a short descriptive title based on the transcript content",
  "summary": "a multi-paragraph overview that scales with transcript length",
  "key_points": ["concise bullets capturing main ideas and sections"],
  "action_items": ["practical steps or concrete recommendations"],
  "study_questions": ["thoughtful questions for reflection or comprehension"]
}

Guidelines:
- Use ONLY information from the provided transcript. Do NOT fabricate.
- For short transcripts, keep the summary and lists brief. For long transcripts, write a more detailed, multi-paragraph summary that still stays concise and focused.
- Key points should capture major ideas and sections. It is fine to have as much items as NEEDED, depending on the transcript length.
- Action items should be concrete, learner-focused steps. It is fine to have as much items as NEEDED, depending on the transcript length.
- Study questions should help the learner review, apply, and reflect. It is fine to have as much items as NEEDED, depending on the transcript length.
- Keep individual sentences reasonably short and clear (around 30 words or fewer when possible).`;

export async function generateStudyNotesWithMeta(
  content: string,
  opts?: {
    saveToFirestore?: (note: StudyNote, meta: GenerationMeta) => Promise<void>;
  },
): Promise<GenerationResult> {
  if (!content || typeof content !== 'string') {
    throw new Error('Transcript content must be a non-empty string');
  }

  const startedAt = new Date();
  const meta: GenerationMeta = {
    model: GEMINI_MODEL,
    createdAt: startedAt.toISOString(),
    attempts: 0,
    sanitized: false,
  };

  const { text: sanitized, warnings } = sanitizeTranscript(content);
  meta.sanitized = true;
  if (warnings.length) {
    meta.warnings = warnings;
  }

  if (sanitized.trim().length < MIN_TRANSCRIPT_CHARS) {
    throw new Error('Transcript too short to generate meaningful notes');
  }

  const systemPrompt = `You create accurate, student-friendly study notes strictly from the provided transcript.\n\n${STUDY_NOTES_JSON_SCHEMA_PROMPT}`;
  const userPrompt = `Generate structured study notes strictly from the transcript below. Use only the transcript information. 
Output must be valid JSON matching the schema.

Transcript:
"""
${sanitized}
"""`;

  let lastError: unknown = null;

  for (let attempt = 1; attempt <= STUDY_NOTES_MAX_RETRIES; attempt++) {
    meta.attempts = attempt;

    try {
      const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });
      
      const result = await callGeminiWithTimeout(
        model,
        systemPrompt,
        userPrompt,
        STUDY_NOTES_TIMEOUT_MS,
      );

      const rawText = result.response.text();
      const parsed = await parseModelJson(rawText);
      const note = normalizeStudyNoteFromModel(parsed);

      if (opts?.saveToFirestore) {
        try {
          await opts.saveToFirestore(note, meta);
        } catch (saveErr) {
          meta.warnings = meta.warnings ?? [];
          meta.warnings.push(
            'Failed to save study note: ' + String(saveErr),
          );
        }
      }

      return { note, meta };
    } catch (err) {
      lastError = err;

      if (
        err instanceof Error &&
        /Could not parse JSON from model response|Unexpected token/.test(
          err.message,
        )
      ) {
        try {
          const repairPrompt = jsonRepairPrompt(
            (err as any).rawText ?? (err as Error).message,
          );
          
          const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });
          const repairResult = await callGeminiWithTimeout(
            model,
            '',
            repairPrompt,
            STUDY_NOTES_TIMEOUT_MS,
          );
          
          const repairText = repairResult.response.text();
          const repairedParsed = await parseModelJson(repairText);
          const repairedNote = normalizeStudyNoteFromModel(repairedParsed);

          if (opts?.saveToFirestore) {
            try {
              await opts.saveToFirestore(repairedNote, meta);
            } catch (saveErr) {
              meta.warnings = meta.warnings ?? [];
              meta.warnings.push(
                'Failed to save study note after repair: ' +
                  String(saveErr),
              );
            }
          }

          return { note: repairedNote, meta };
        } catch (repairErr) {
          meta.warnings = meta.warnings ?? [];
          meta.warnings.push(
            'JSON repair attempt failed: ' + String(repairErr),
          );
        }
      }

      const backoffMs = Math.pow(2, attempt) * 500;
      await new Promise((resolve) => setTimeout(resolve, backoffMs));
    }
  }

  throw new Error('Failed to generate study notes: ' + String(lastError));
}

interface QuizQuestion {
  question: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
}

interface Flashcard {
  front: string;
  back: string;
}

function ensureString(value: unknown, field: string): string {
  if (typeof value !== 'string') {
    throw new Error(`${field} must be a string`);
  }
  const trimmed = value.trim();
  if (!trimmed) {
    throw new Error(`${field} cannot be empty`);
  }
  return trimmed;
}

function ensureStringArray(
  value: unknown,
  field: string,
  min = 0,
  max = Number.POSITIVE_INFINITY,
): string[] {
  if (!Array.isArray(value)) {
    throw new Error(`${field} must be an array`);
  }

  const normalized = value
    .map((item, index) => ensureString(item, `${field}[${index}]`))
    .filter(Boolean);

  if (normalized.length < min) {
    throw new Error(
      `${field} must contain at least ${min} items (received ${normalized.length})`,
    );
  }

  if (normalized.length > max) {
    return normalized.slice(0, max);
  }

  return normalized;
}

function normalizeQuizQuestions(
  raw: unknown,
  expectedCount: number,
): QuizQuestion[] {
  const list = Array.isArray(raw) ? raw : [raw];
  if (!list.length) {
    throw new Error('Quiz generation returned no questions');
  }

  const normalized = list.map((item, index) => {
    if (!item || typeof item !== 'object') {
      throw new Error(`questions[${index}] must be an object`);
    }
    const question = ensureString(
      (item as any).question,
      `questions[${index}].question`,
    );
    const options = ensureStringArray(
      (item as any).options,
      `questions[${index}].options`,
    );
    if (options.length < 2) {
      throw new Error(`questions[${index}].options must include at least 2 values`);
    }

    const correctAnswer = (item as any).correctAnswer;
    if (
      typeof correctAnswer !== 'number' ||
      correctAnswer < 0 ||
      correctAnswer >= options.length
    ) {
      throw new Error(
        `questions[${index}].correctAnswer must be a valid option index`,
      );
    }

    const explanation = ensureString(
      (item as any).explanation,
      `questions[${index}].explanation`,
    );

    return {
      question,
      options,
      correctAnswer,
      explanation,
    };
  });

  if (normalized.length < expectedCount) {
    
  }

  return normalized;
}

function normalizeFlashcards(
  raw: unknown,
  expectedCount: number,
): Flashcard[] {
  const list = Array.isArray(raw) ? raw : [raw];
  if (!list.length) {
    throw new Error('Flashcard generation returned no cards');
  }

  const normalized = list.map((item, index) => {
    if (!item || typeof item !== 'object') {
      throw new Error(`flashcards[${index}] must be an object`);
    }
    return {
      front: ensureString((item as any).front, `flashcards[${index}].front`),
      back: ensureString((item as any).back, `flashcards[${index}].back`),
    };
  });

  if (normalized.length < expectedCount) {
    
  }

  return normalized;
}

/**
 * Study note helpers
 */

function redactPII(text: string): { text: string; redacted: boolean } {
  let redacted = false;
  let result = text ?? '';

  // Emails
  const emailRegex =
    /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
  if (emailRegex.test(result)) {
    result = result.replace(emailRegex, '[REDACTED_EMAIL]');
    redacted = true;
  }

  // Phone numbers (very loose)
  const phoneRegex = /\+?\d{7,15}/g;
  if (phoneRegex.test(result)) {
    result = result.replace(phoneRegex, '[REDACTED_PHONE]');
    redacted = true;
  }

  // Simple removal of <system>, <user>, <assistant> style tags
  const tagRegex = /<\/?(system|user|assistant)[^>]*>/gi;
  if (tagRegex.test(result)) {
    result = result.replace(tagRegex, '');
    redacted = true;
  }

  return { text: result, redacted };
}

function sanitizeTranscript(
  content: string,
): { text: string; warnings: string[] } {
  const warnings: string[] = [];
  let text = content ?? '';

  // Normalize whitespace
  text = text.replace(/\r\n/g, '\n').trim();

  // Remove suspicious embedded instruction blocks like </user><system>...
  text = text.replace(/<\/?(system|user|assistant)[\s\S]*?>/gi, '');

  // Remove control characters
  text = text.replace(
    /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]+/g,
    ' ',
  );

  const pii = redactPII(text);
  text = pii.text;
  if (pii.redacted) {
    warnings.push('PII redacted from transcript');
  }

  // Collapse repeated newlines
  text = text.replace(/\n{3,}/g, '\n\n');

  return { text, warnings };
}

function extractJsonObject(text: string): string | null {
  const firstBrace = text.indexOf('{');
  if (firstBrace === -1) return null;

  let depth = 0;
  for (let i = firstBrace; i < text.length; i++) {
    if (text[i] === '{') depth++;
    if (text[i] === '}') depth--;
    if (depth === 0) {
      return text.slice(firstBrace, i + 1);
    }
  }

  return null;
}

function extractJsonFromMarkdown(text: string): string | null {
  // Handles ```json ... ``` and ``` ... ```
  const mdJson = /```\s*(?:json)?([\s\S]*?)```/i.exec(text);
  if (mdJson && mdJson[1]) {
    return mdJson[1].trim();
  }
  return null;
}

async function parseModelJson(responseText: string): Promise<any> {
  const original = responseText ?? '';

  // Attempt 1: direct parse
  try {
    const candidate = original.trim();
    return JSON.parse(candidate);
  } catch {
    // fall through
  }

  // Attempt 2: markdown block
  const md = extractJsonFromMarkdown(original);
  if (md) {
    try {
      return JSON.parse(md);
    } catch {
      // ignore and continue
    }
  }

  // Attempt 3: balanced braces extraction
  const obj = extractJsonObject(original);
  if (obj) {
    try {
      return JSON.parse(obj);
    } catch {
      // ignore and continue
    }
  }

  const error = new Error(
    'Could not parse JSON from model response',
  ) as Error & { rawText?: string };
  error.rawText = original;
  throw error;
}

function jsonRepairPrompt(brokenText: string): string {
  return `You are a JSON fixer.

Extract and return ONLY a single valid JSON object that conforms EXACTLY to the schema below and contains the same data as the broken input. Do not add or remove informational content except to correct escaping, trailing commas or structural issues. If a field is missing, add it with a short explicit placeholder string "(no content available)".

Schema:

${STUDY_NOTES_JSON_SCHEMA_PROMPT}

Broken model output:

${brokenText}

Return ONLY the repaired JSON object.`;
}

function normalizeStudyNoteFromModel(modelPayload: any): StudyNote {
  const title = ensureString(
    modelPayload?.title ?? '(no content available)',
    'title',
  );
  const summary = ensureString(
    modelPayload?.summary ?? '(no content available)',
    'summary',
  );

  const keyPoints = ensureStringArray(
    modelPayload?.key_points ?? modelPayload?.keyPoints ?? [],
    'key_points',
    4,
    20,
  );

  const actionItems = ensureStringArray(
    modelPayload?.action_items ?? modelPayload?.actionItems ?? [],
    'action_items',
    2,
    10,
  );

  const studyQuestions = ensureStringArray(
    modelPayload?.study_questions ?? modelPayload?.studyQuestions ?? [],
    'study_questions',
    3,
    15,
  );

  return {
    title,
    summary,
    keyPoints,
    actionItems,
    studyQuestions,
  };
}

function callGeminiWithTimeout(
  model: any,
  systemPrompt: string,
  userPrompt: string,
  timeoutMs: number,
): Promise<any> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error('Gemini request timed out'));
    }, timeoutMs);

    const fullPrompt = systemPrompt ? `${systemPrompt}\n\n${userPrompt}` : userPrompt;

    model.generateContent({
      contents: [
        {
          role: 'user',
          parts: [{ text: fullPrompt }]
        }
      ],
      generationConfig: {
        temperature: 0,
      },
    })
      .then((res: any) => {
        clearTimeout(timer);
        resolve(res);
      })
      .catch((err: any) => {
        clearTimeout(timer);
        reject(err);
      });
  });
}

