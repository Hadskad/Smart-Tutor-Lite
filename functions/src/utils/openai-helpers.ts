import { openai } from '../config/openai';

export interface SummarizeOptions {
  text: string;
  maxLength?: number;
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

/**
 * Summarize text using OpenAI
 */
export async function summarizeText(options: SummarizeOptions): Promise<string> {
  const { text, maxLength = 200 } = options;

  const prompt = `Summarize the following text in approximately ${maxLength} words:\n\n${text}`;

  const response = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages: [
      {
        role: 'system',
        content: 'You are a helpful assistant that creates concise summaries.',
      },
      {
        role: 'user',
        content: prompt,
      },
    ],
    max_tokens: Math.min(maxLength * 2, 500),
    temperature: 0.7,
  });

  const summary = response.choices[0]?.message?.content?.trim();
  if (!summary) {
    throw new Error('Summary generation failed: empty response');
  }

  return summary;
}

/**
 * Generate quiz questions from content using OpenAI
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

  const prompt = `Generate ${numQuestions} ${difficulty} multiple-choice questions based on the following content. 
Return a JSON array with this structure:
[
  {
    "question": "Question text",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": 0,
    "explanation": "Why this answer is correct"
  }
]

Content:
${content}`;

  const response = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages: [
      {
        role: 'system',
        content: 'You are an educational assistant that creates high-quality quiz questions.',
      },
      {
        role: 'user',
        content: prompt,
      },
    ],
    response_format: { type: 'json_object' },
    temperature: 0.7,
  });

  const responseContent = response.choices[0]?.message?.content;
  if (!responseContent) {
    throw new Error('Failed to generate quiz');
  }

  try {
    const parsed = JSON.parse(responseContent);
    const questions = parsed.questions ?? parsed;
    const normalized = normalizeQuizQuestions(questions, numQuestions);
    return { questions: normalized };
  } catch (error) {
    throw new Error(`Failed to parse quiz response: ${error instanceof Error ? error.message : error}`);
  }
}

/**
 * Generate flashcards from content using OpenAI
 */
export async function generateFlashcards(
  options: GenerateFlashcardsOptions
): Promise<Array<{ front: string; back: string }>> {
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

  const response = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages: [
      {
        role: 'system',
        content: 'You are an educational assistant that creates effective flashcards.',
      },
      {
        role: 'user',
        content: prompt,
      },
    ],
    response_format: { type: 'json_object' },
    temperature: 0.7,
  });

  const contentText = response.choices[0]?.message?.content;
  if (!contentText) {
    throw new Error('Failed to generate flashcards');
  }

  try {
    const parsed = JSON.parse(contentText);
    const flashcards = parsed.flashcards ?? parsed;
    return normalizeFlashcards(flashcards, numFlashcards);
  } catch (error) {
    throw new Error(`Failed to parse flashcards response: ${error instanceof Error ? error.message : error}`);
  }
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

function ensureStringArray(value: unknown, field: string): string[] {
  if (!Array.isArray(value)) {
    throw new Error(`${field} must be an array`);
  }

  const normalized = value.map((item, index) =>
    ensureString(item, `${field}[${index}]`),
  );

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
    console.warn(
      `Expected ${expectedCount} quiz questions but received ${normalized.length}`,
    );
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
    console.warn(
      `Expected ${expectedCount} flashcards but received ${normalized.length}`,
    );
  }

  return normalized;
}

