import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import {
  AnalyticsEvent,
  ApiEnvelope,
  BookmarkItem,
  Book,
  BookTagsBundle,
  ChatRecord,
  CommerceResult,
  NoteItem,
  PlanItem,
  ProfileBundle,
  ReaderBundle,
  ReaderComment,
  ReaderHighlight,
  ReadingStats,
  ReadingChapter,
  ReadingContent,
  ReadingProgress,
  RecommendationBook,
  SourceRef,
  UserProfile,
} from './Models';

const API_BASE_URLS: string[] = [
  'http://127.0.0.1:8081/api',
  'http://10.0.2.2:8081/api',
  'http://192.168.123.89:8081/api',
];
const API_ERROR_PREFIX: string = '__API_ERROR__:';
let activeApiBaseUrl: string = API_BASE_URLS[0];

function isRouteMissingMessage(message: string): boolean {
  return message.includes('No static resource') || message.includes('404') || message.includes('Not Found');
}

export interface RecommendResult {
  intent: string;
  book_list: RecommendationBook[];
  reason: string;
  difficulty: string;
  follow_up_suggestion: string;
  sources: SourceRef[];
  tool_trace?: ToolTrace[];
  reasoning?: string;
  reasoning_content?: string;
  hidden_reasoning?: string;
  stream_id?: string;
  response_mode?: string;
  llm_status: string;
}

export interface ToolTrace {
  tool: string;
  status: string;
  detail?: string;
  details?: string;
}

export interface ChatResult {
  answer: string;
  sources: SourceRef[];
  follow_up_suggestion: string;
  tool_trace?: ToolTrace[];
  reasoning?: string;
  reasoning_content?: string;
  hidden_reasoning?: string;
  stream_id?: string;
  response_mode?: string;
  llm_status: string;
}

export interface AiStreamCallbacks<T> {
  onDelta?: (text: string) => void;
  onReasoning?: (text: string) => void;
  onStatus?: (text: string) => void;
  onResult?: (result: T) => void;
  onError?: (message: string) => void;
}

export interface ChatOptions {
  chapterId?: string;
  paragraph?: string;
  allowExternalSearch?: boolean;
  tone?: string;
}

export interface CommerceBundle {
  intent: string;
  results: CommerceResult[];
  message: string;
}

export interface ImportBookResult {
  book_id: number;
  bookId?: number;
  status: string;
  message: string;
  chapter_count: number;
  chapterCount?: number;
  source_type: string;
  sourceType?: string;
}

interface RecommendRequest {
  user_id: number;
  query: string;
  response_mode?: string;
  require_sources?: boolean;
  allow_external_search?: boolean;
  auto_import_missing_books?: boolean;
  persist_missing_books?: boolean;
  import_policy?: string;
  offset?: number;
}

interface ChatRequest {
  user_id: number;
  book_id: number;
  question: string;
  chapter_id?: string;
  paragraph?: string;
  allow_external_search?: boolean;
  tone?: string;
  reasoning_policy?: string;
  answer_scope?: string;
  response_mode?: string;
  require_sources?: boolean;
  allow_partial_answer?: boolean;
}

export interface PlanTargetOptions {
  targetDays?: number;
  dailyMinutesTarget?: number;
  weeklyMinutesTarget?: number;
}

interface CreatePlanRequest {
  user_id: number;
  book_id: number;
  target_days: number;
  daily_minutes_target?: number;
  weekly_minutes_target?: number;
}

interface SaveNoteRequest {
  user_id: number;
  book_id: number;
  content: string;
  type: string;
}

interface ReaderHighlightRequest {
  user_id: number;
  book_id: number;
  chapter_id: string;
  paragraph_index: number;
  start_offset?: number;
  end_offset?: number;
  selected_text: string;
  book_title: string;
  chapter_title: string;
}

interface ReaderCommentRequest {
  user_id: number;
  book_id: number;
  chapter_id: string;
  paragraph_index: number;
  selected_text: string;
  content: string;
}

interface FavoriteRequest {
  user_id: number;
  book_id: number;
}

interface SaveProfileRequest {
  user_id: number;
  account: string;
  phone: string;
  email?: string;
  name: string;
  nickname?: string;
  major: string;
  grade: string;
  interests: string;
  goal: string;
  intro?: string;
  avatarUrl?: string;
  channels: string;
}

interface PhoneAuthRequest {
  phone: string;
  password: string;
}

interface ChangePasswordRequest {
  user_id: number;
  old_password: string;
  new_password: string;
}

interface ResetPasswordRequest {
  phone: string;
}

interface BindEmailRequest {
  user_id: number;
  email: string;
}

interface DeleteAccountRequest {
  user_id: number;
}

export interface ResetPasswordResult {
  phone: string;
  generatedPassword: string;
  message: string;
}

interface ProviderAuthRequest {
  provider: string;
  subject: string;
}

interface CommerceSearchRequest {
  user_id: number;
  book_id: number;
  isbn: string;
  channels: string[];
}

interface ConfirmPurchaseRequest {
  user_id: number;
  book_id: number;
  platform: string;
  action: string;
  amount: number;
  confirmed: boolean;
}

interface UpdateProgressRequest {
  user_id: number;
  book_id: number;
  chapter_id: string;
  target_days?: number;
  progress: number;
  scroll_offset: number;
  status: string;
  daily_minutes_target?: number;
  weekly_minutes_target?: number;
}

interface ImportBookRequest {
  user_id: number;
  file_name: string;
  source_type: string;
  content?: string;
  base64?: string;
  file_path?: string;
  tags?: string;
  target_reader?: string;
}

interface AnalyticsBatchRequest {
  events: AnalyticsEvent[];
}

interface RebuildProfileAnalysisRequest {
  force?: boolean;
}

interface BookSearchPage {
  items?: Book[];
  records?: Book[];
  list?: Book[];
  content?: Book[];
}

interface PlanItemPayload {
  id?: number;
  bookId?: number;
  book_id?: number;
  title?: string;
  author?: string;
  targetDays?: number;
  target_days?: number;
  dailyMinutesTarget?: number;
  daily_minutes_target?: number;
  weeklyMinutesTarget?: number;
  weekly_minutes_target?: number;
  progress?: number;
  status?: string;
  chapterId?: string;
  chapter_id?: string;
  scrollOffset?: number;
  scroll_offset?: number;
  createdAt?: string;
  created_at?: string;
  updatedAt?: string;
  updated_at?: string;
  completedAt?: string;
  completed_at?: string;
  completedDates?: string[];
  completed_dates?: string[];
  coverColor?: string;
  cover_color?: string;
}

interface ReadingProgressPayload {
  planId?: number;
  plan_id?: number;
  bookId?: number;
  book_id?: number;
  chapterId?: string;
  chapter_id?: string;
  progress?: number;
  scrollOffset?: number;
  scroll_offset?: number;
  status?: string;
  updatedAt?: string;
  updated_at?: string;
}

interface ProfileBundlePayload {
  profile: UserProfile;
  favorites?: Book[];
  notes?: NoteItem[];
  plans?: PlanItemPayload[];
  chat_records?: ChatRecord[];
  chats?: ChatRecord[];
}

interface ReaderBundlePayload {
  book: Book;
  plan: PlanItemPayload | null;
  chapters?: ReadingChapter[];
  content: ReadingContent | null;
  progress: ReadingProgressPayload | null;
  bookmarks?: BookmarkItem[];
}

interface AiStreamRawEvent {
  type?: string;
  event?: string;
  delta?: string;
  text?: string;
  content?: string;
  status?: string;
  message?: string;
  data?: object | string;
  result?: object;
  final?: object;
  done?: boolean;
  code?: number;
  answer?: string;
  reason?: string;
  intent?: string;
  book_list?: RecommendationBook[];
  llm_status?: string;
}

export class ApiClient {
  private static numberOrFallback(value: number | string | undefined, fallback: number): number {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === 'string') {
      const parsed: number = Number(value);
      return Number.isFinite(parsed) ? parsed : fallback;
    }
    return fallback;
  }

  private static stringOrFallback(value: string | undefined, fallback: string = ''): string {
    return value !== undefined && value !== null ? value : fallback;
  }

  private static normalizePlanItem(item: PlanItemPayload): PlanItem {
    const targetDays: number = ApiClient.numberOrFallback(item.targetDays, ApiClient.numberOrFallback(item.target_days, 14));
    const dailyMinutesTarget: number = ApiClient.numberOrFallback(
      item.dailyMinutesTarget,
      ApiClient.numberOrFallback(item.daily_minutes_target, 30)
    );
    const weeklyMinutesTarget: number = ApiClient.numberOrFallback(
      item.weeklyMinutesTarget,
      ApiClient.numberOrFallback(item.weekly_minutes_target, dailyMinutesTarget * 7)
    );
    const progress: number = ApiClient.numberOrFallback(item.progress, 0);
    return {
      id: ApiClient.numberOrFallback(item.id, 0),
      bookId: ApiClient.numberOrFallback(item.bookId, ApiClient.numberOrFallback(item.book_id, 0)),
      title: ApiClient.stringOrFallback(item.title, '未命名图书'),
      author: ApiClient.stringOrFallback(item.author, '作者待补充'),
      targetDays,
      dailyMinutesTarget,
      weeklyMinutesTarget,
      progress,
      status: ApiClient.stringOrFallback(item.status, progress >= 100 ? 'finished' : 'reading'),
      chapterId: ApiClient.stringOrFallback(item.chapterId, ApiClient.stringOrFallback(item.chapter_id)),
      scrollOffset: ApiClient.numberOrFallback(item.scrollOffset, ApiClient.numberOrFallback(item.scroll_offset, 0)),
      createdAt: ApiClient.stringOrFallback(item.createdAt, ApiClient.stringOrFallback(item.created_at)),
      updatedAt: ApiClient.stringOrFallback(item.updatedAt, ApiClient.stringOrFallback(item.updated_at)),
      completedAt: ApiClient.stringOrFallback(item.completedAt, ApiClient.stringOrFallback(item.completed_at)),
      completedDates: item.completedDates || item.completed_dates || [],
      coverColor: ApiClient.stringOrFallback(item.coverColor, ApiClient.stringOrFallback(item.cover_color, '#DDE8E3')),
    };
  }

  private static normalizePlanList(items: PlanItemPayload[]): PlanItem[] {
    const plans: PlanItem[] = [];
    for (let i = 0; i < (items || []).length; i++) {
      plans.push(ApiClient.normalizePlanItem(items[i]));
    }
    return plans;
  }

  private static normalizeReadingProgress(item: ReadingProgressPayload): ReadingProgress {
    const progress: number = ApiClient.numberOrFallback(item.progress, 0);
    return {
      planId: ApiClient.numberOrFallback(item.planId, ApiClient.numberOrFallback(item.plan_id, 0)),
      bookId: ApiClient.numberOrFallback(item.bookId, ApiClient.numberOrFallback(item.book_id, 0)),
      chapterId: ApiClient.stringOrFallback(item.chapterId, ApiClient.stringOrFallback(item.chapter_id)),
      progress,
      scrollOffset: ApiClient.numberOrFallback(item.scrollOffset, ApiClient.numberOrFallback(item.scroll_offset, 0)),
      status: ApiClient.stringOrFallback(item.status, progress >= 100 ? 'finished' : 'reading'),
      updatedAt: ApiClient.stringOrFallback(item.updatedAt, ApiClient.stringOrFallback(item.updated_at)),
    };
  }

  private static normalizeProfileBundle(bundle: ProfileBundlePayload): ProfileBundle {
    return {
      profile: bundle.profile,
      favorites: bundle.favorites || [],
      notes: bundle.notes || [],
      plans: ApiClient.normalizePlanList(bundle.plans || []),
      chat_records: bundle.chat_records || bundle.chats || [],
    };
  }

  private static normalizeReaderBundle(bundle: ReaderBundlePayload): ReaderBundle {
    return {
      book: bundle.book,
      plan: bundle.plan ? ApiClient.normalizePlanItem(bundle.plan) : null,
      chapters: bundle.chapters || [],
      content: bundle.content,
      progress: bundle.progress ? ApiClient.normalizeReadingProgress(bundle.progress) : null,
      bookmarks: bundle.bookmarks || [],
    };
  }

  private static normalizeBookList(payload: Book[] | BookSearchPage): Book[] {
    if (Array.isArray(payload)) {
      return payload;
    }
    if (!payload) {
      return [];
    }
    if (Array.isArray(payload.items)) {
      return payload.items;
    }
    if (Array.isArray(payload.records)) {
      return payload.records;
    }
    if (Array.isArray(payload.list)) {
      return payload.list;
    }
    if (Array.isArray(payload.content)) {
      return payload.content;
    }
    return [];
  }

  private static markActiveBaseUrl(baseUrl: string): void {
    if (baseUrl) {
      activeApiBaseUrl = baseUrl;
    }
  }

  static resourceUrl(path: string): string {
    if (!path) {
      return '';
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    const base = activeApiBaseUrl.replace(/\/api$/, '');
    return `${base}${path.startsWith('/') ? path : `/${path}`}`;
  }

  private static isWeakAiStatus(status: string): boolean {
    const normalized: string = (status || '').toLowerCase();
    return normalized.includes('parse') || normalized.includes('parser') || normalized.includes('blocked') ||
      normalized.includes('intercept') || normalized.includes('guardrail') || normalized.includes('invalid');
  }

  private static isWeakAiText(text: string): boolean {
    return !text || text.includes('已拦截') || text.includes('结构不完整') || text.includes('未校验') ||
      text.includes('换个关键词再试') || text.includes('无法解析') || text.includes('parser') ||
      text.includes('格式不稳定') || text.includes('保守推荐') || text.includes('解析错误');
  }

  private static cleanFollowUpSuggestion(text: string): string {
    const value: string = (text || '').trim();
    if (!value) {
      return '';
    }
    const noisy: string[] = [
      '告诉我你',
      '发我一段',
      '把你卡住',
      '换成更具体',
      '补充专业',
      '继续追问',
      '问某一章',
      '指定章节',
    ];
    for (let i = 0; i < noisy.length; i++) {
      if (value.indexOf(noisy[i]) >= 0) {
        return '';
      }
    }
    return value;
  }

  static preferStreamText(current: string, candidate: string): string {
    const currentText: string = (current || '').trim();
    const candidateText: string = (candidate || '').trim();
    if (!currentText) {
      return candidateText;
    }
    if (!candidateText) {
      return currentText;
    }
    if (candidateText.length >= currentText.length + 24 ||
      candidateText.length >= Math.floor(currentText.length * 1.25)) {
      return candidateText;
    }
    return currentText;
  }

  private static isReaderAnalysisResult(result: RecommendResult): boolean {
    const intent: string = (result.intent || '').toLowerCase();
    const status: string = (result.llm_status || '').toLowerCase();
    return intent === 'smalltalk' || intent === 'clarify' || intent === 'interest_analysis' || intent === 'chat' ||
      status === 'context_analysis' || status === 'general_guidance';
  }

  private static normalizeRecommendResult(result: RecommendResult, query: string): RecommendResult {
    const books: RecommendationBook[] = [];
    const rawBooks: RecommendationBook[] = result.book_list || [];
    for (let i = 0; i < rawBooks.length; i++) {
      const book: RecommendationBook = rawBooks[i];
      const title: string = (book && book.title ? book.title : '').trim();
      if (!title) {
        continue;
      }
      const bookId: number = book.id || 0;
      if (bookId <= 0 || book.titleOnly) {
        books.push({
          id: 0,
          title,
          titleOnly: true,
        });
      } else {
        books.push({
          id: bookId,
          title,
          author: book.author || '',
          difficulty: book.difficulty || '',
          reason: book.reason || '',
          highlight: book.highlight || '',
          coverColor: book.coverColor || '',
          subtitle: book.subtitle || '',
          titleOnly: false,
        });
      }
    }
    return {
      intent: result.intent || 'recommend',
      book_list: books,
      reason: ApiClient.isWeakAiText(result.reason || '') ? '' : (result.reason || ''),
      difficulty: result.difficulty || (books.length > 0 ? (books[0].difficulty || '') : ''),
      follow_up_suggestion: ApiClient.cleanFollowUpSuggestion(result.follow_up_suggestion || ''),
      sources: result.sources || [],
      tool_trace: result.tool_trace || [],
      reasoning: result.reasoning || result.reasoning_content || result.hidden_reasoning || '',
      reasoning_content: result.reasoning_content || result.reasoning || result.hidden_reasoning || '',
      hidden_reasoning: result.hidden_reasoning || result.reasoning_content || result.reasoning || '',
      stream_id: result.stream_id || '',
      response_mode: result.response_mode || 'final_with_collapsed_reasoning',
      llm_status: ApiClient.isWeakAiStatus(result.llm_status || '') ? 'recovered' : (result.llm_status || 'ok'),
    };
  }

  private static normalizeChatResult(result: ChatResult): ChatResult {
    return {
      answer: result.answer || '',
      sources: result.sources || [],
      follow_up_suggestion: ApiClient.cleanFollowUpSuggestion(result.follow_up_suggestion || ''),
      tool_trace: result.tool_trace || [],
      reasoning: result.reasoning || result.reasoning_content || result.hidden_reasoning || '',
      reasoning_content: result.reasoning_content || result.reasoning || result.hidden_reasoning || '',
      hidden_reasoning: result.hidden_reasoning || result.reasoning_content || result.reasoning || '',
      stream_id: result.stream_id || '',
      response_mode: result.response_mode || 'final_with_collapsed_reasoning',
      llm_status: result.llm_status || 'ok',
    };
  }

  static async searchBooks(keyword: string, tag: string = '', page: number = 0, size: number = 30): Promise<Book[]> {
    const path = `/books/search?keyword=${encodeURIComponent(keyword)}&tag=${encodeURIComponent(tag)}&page=${page}&size=${size}`;
    const payload = await ApiClient.get<Book[] | BookSearchPage>(path);
    return ApiClient.normalizeBookList(payload);
  }

  static async bookTags(): Promise<BookTagsBundle> {
    return await ApiClient.get<BookTagsBundle>('/books/tags');
  }

  static async storeBooks(section: string, userId: number = 10086, page: number = 0, size: number = 30): Promise<Book[]> {
    return await ApiClient.get<Book[]>(
      `/books/store?section=${encodeURIComponent(section)}&userId=${userId}&page=${page}&size=${size}`
    );
  }

  static async getBook(id: number): Promise<Book> {
    return await ApiClient.get<Book>(`/books/${id}`);
  }

  static async readerBundle(userId: number, bookId: number, chapterId: string = ''): Promise<ReaderBundle> {
    const suffix = chapterId ? `&chapterId=${encodeURIComponent(chapterId)}` : '';
    const bundle: ReaderBundlePayload = await ApiClient.get<ReaderBundlePayload>(`/books/${bookId}/reader?userId=${userId}${suffix}`);
    return ApiClient.normalizeReaderBundle(bundle);
  }

  static async listChapters(bookId: number): Promise<ReadingChapter[]> {
    return await ApiClient.get<ReadingChapter[]>(`/books/${bookId}/chapters`);
  }

  static async getReadingContent(bookId: number, chapterId: string): Promise<ReadingContent> {
    return await ApiClient.get<ReadingContent>(`/books/${bookId}/content?chapterId=${encodeURIComponent(chapterId)}`);
  }

  static async recommend(userId: number, query: string, offset: number = 0): Promise<RecommendResult> {
    const payload: RecommendRequest = ApiClient.recommendPayload(userId, query, offset);
    const first: RecommendResult = await ApiClient.post<RecommendResult>('/ai/recommend', payload);
    const normalized: RecommendResult = ApiClient.normalizeRecommendResult(first, query);
    if (ApiClient.isReaderAnalysisResult(normalized) && !ApiClient.isWeakAiText(normalized.reason || '')) {
      return normalized;
    }
    if (normalized.book_list.length > 0 && !ApiClient.isWeakAiStatus(first.llm_status || '') && !ApiClient.isWeakAiText(first.reason || '')) {
      return normalized;
    }

    const retryPayload: RecommendRequest = {
      user_id: payload.user_id,
      query: `${query || '请推荐几本适合我现在阅读的书'}。请用自然中文给出可点击的书名和具体推荐理由。`,
      response_mode: payload.response_mode,
      require_sources: payload.require_sources,
      allow_external_search: payload.allow_external_search,
      auto_import_missing_books: payload.auto_import_missing_books,
      persist_missing_books: payload.persist_missing_books,
      import_policy: payload.import_policy,
      offset: payload.offset,
    };
    try {
      const retry: RecommendResult = await ApiClient.post<RecommendResult>('/ai/recommend', retryPayload);
      const retryNormalized: RecommendResult = ApiClient.normalizeRecommendResult(retry, query);
      if (retryNormalized.book_list.length > 0 && !ApiClient.isWeakAiText(retryNormalized.reason)) {
        return retryNormalized;
      }
      return retryNormalized;
    } catch (_) {
    }
    return normalized;
  }

  static async recommendStream(
    userId: number,
    query: string,
    offset: number = 0,
    callbacks: AiStreamCallbacks<RecommendResult> = {}
  ): Promise<RecommendResult> {
    const payload: RecommendRequest = ApiClient.recommendPayload(userId, query, offset);
    const normalize = (result: object): RecommendResult => ApiClient.normalizeRecommendResult(result as RecommendResult, query);
    const streamCallbacks: AiStreamCallbacks<RecommendResult> = ApiClient.silentStreamErrors(callbacks);
    try {
      return await ApiClient.streamRequest<RecommendResult>('/ai/recommend/stream', payload, streamCallbacks, normalize);
    } catch (streamErr) {
      callbacks.onStatus && callbacks.onStatus('流式连接失败，正在切换普通回答');
      try {
        const fallback: RecommendResult = normalize(await ApiClient.post<RecommendResult>('/ai/recommend', payload));
        callbacks.onResult && callbacks.onResult(fallback);
        return fallback;
      } catch (fallbackErr) {
        const message: string = `AI 连接失败，请确认后端 8081 和 AI 服务可用。${fallbackErr || streamErr}`;
        callbacks.onError && callbacks.onError(message);
        throw new Error(message);
      }
    }
  }

  static async chat(userId: number, bookId: number, question: string, options: ChatOptions = {}): Promise<ChatResult> {
    const payload: ChatRequest = ApiClient.chatPayload(userId, bookId, question, options);
    const result: ChatResult = await ApiClient.post<ChatResult>('/ai/chat', payload);
    return ApiClient.normalizeChatResult(result);
  }

  static async chatStream(
    userId: number,
    bookId: number,
    question: string,
    options: ChatOptions = {},
    callbacks: AiStreamCallbacks<ChatResult> = {}
  ): Promise<ChatResult> {
    const payload: ChatRequest = ApiClient.chatPayload(userId, bookId, question, options);
    const normalize = (result: object): ChatResult => ApiClient.normalizeChatResult(result as ChatResult);
    const streamCallbacks: AiStreamCallbacks<ChatResult> = ApiClient.silentStreamErrors(callbacks);
    try {
      return await ApiClient.streamRequest<ChatResult>('/ai/chat/stream', payload, streamCallbacks, normalize);
    } catch (streamErr) {
      callbacks.onStatus && callbacks.onStatus('流式连接失败，正在切换普通回答');
      try {
        const fallback: ChatResult = normalize(await ApiClient.post<ChatResult>('/ai/chat', payload));
        callbacks.onResult && callbacks.onResult(fallback);
        return fallback;
      } catch (fallbackErr) {
        const message: string = `AI 连接失败，请确认后端 8081 和 AI 服务可用。${fallbackErr || streamErr}`;
        callbacks.onError && callbacks.onError(message);
        throw new Error(message);
      }
    }
  }

  static async createPlan(userId: number, bookId: number, targetDays: number = 14, options: PlanTargetOptions = {}): Promise<object> {
    const payload: CreatePlanRequest = {
      user_id: userId,
      book_id: bookId,
      target_days: targetDays,
      daily_minutes_target: options.dailyMinutesTarget,
      weekly_minutes_target: options.weeklyMinutesTarget,
    };
    return await ApiClient.post<object>('/plans', payload);
  }

  static async listPlans(userId: number): Promise<PlanItem[]> {
    const plans: PlanItemPayload[] = await ApiClient.get<PlanItemPayload[]>(`/plans?userId=${userId}`);
    return ApiClient.normalizePlanList(plans || []);
  }

  static async deletePlanByBook(userId: number, bookId: number): Promise<object> {
    return await ApiClient.delete<object>(`/plans/by-book?userId=${userId}&bookId=${bookId}`);
  }

  static async updatePlanProgress(
    userId: number,
    planId: number,
    bookId: number,
    chapterId: string,
    progress: number,
    scrollOffset: number = 0,
    status: string = 'reading',
    options: PlanTargetOptions = {}
  ): Promise<ReadingProgress> {
    const payload: UpdateProgressRequest = {
      user_id: userId,
      book_id: bookId,
      chapter_id: chapterId,
      target_days: options.targetDays,
      progress,
      scroll_offset: scrollOffset,
      status,
      daily_minutes_target: options.dailyMinutesTarget,
      weekly_minutes_target: options.weeklyMinutesTarget,
    };
    const progressResult: ReadingProgressPayload = await ApiClient.patch<ReadingProgressPayload>(`/plans/${planId}`, payload);
    return ApiClient.normalizeReadingProgress(progressResult);
  }

  static async updatePlanTargets(
    userId: number,
    plan: PlanItem,
    targetDays: number,
    dailyMinutesTarget: number,
    weeklyMinutesTarget: number
  ): Promise<ReadingProgress> {
    return await ApiClient.updatePlanProgress(
      userId,
      plan.id,
      plan.bookId,
      plan.chapterId || '',
      plan.progress || 0,
      plan.scrollOffset || 0,
      plan.status || 'reading',
      { targetDays, dailyMinutesTarget, weeklyMinutesTarget }
    );
  }

  static async saveNote(userId: number, bookId: number, content: string): Promise<object> {
    const payload: SaveNoteRequest = { user_id: userId, book_id: bookId, content, type: 'ai_answer' };
    return await ApiClient.post<object>('/notes', payload);
  }

  static async saveReadingNote(userId: number, bookId: number, content: string): Promise<object> {
    const payload: SaveNoteRequest = { user_id: userId, book_id: bookId, content, type: 'reading_excerpt' };
    return await ApiClient.post<object>('/notes', payload);
  }

  static async listReaderHighlights(userId: number, bookId: number, chapterId: string): Promise<ReaderHighlight[]> {
    return await ApiClient.get<ReaderHighlight[]>(
      `/reader/highlights?userId=${userId}&bookId=${bookId}&chapterId=${encodeURIComponent(chapterId)}`
    );
  }

  static async createReaderHighlight(
    userId: number,
    bookId: number,
    chapterId: string,
    paragraphIndex: number,
    selectedText: string,
    bookTitle: string,
    chapterTitle: string,
    startOffset: number = 0,
    endOffset: number = 0
  ): Promise<ReaderHighlight> {
    const payload: ReaderHighlightRequest = {
      user_id: userId,
      book_id: bookId,
      chapter_id: chapterId,
      paragraph_index: paragraphIndex,
      start_offset: startOffset,
      end_offset: endOffset,
      selected_text: selectedText,
      book_title: bookTitle,
      chapter_title: chapterTitle,
    };
    return await ApiClient.post<ReaderHighlight>('/reader/highlights', payload);
  }

  static async listReaderComments(
    userId: number,
    bookId: number,
    chapterId: string,
    paragraphIndex: number
  ): Promise<ReaderComment[]> {
    return await ApiClient.get<ReaderComment[]>(
      `/reader/comments?userId=${userId}&bookId=${bookId}&chapterId=${encodeURIComponent(chapterId)}&paragraphIndex=${paragraphIndex}`
    );
  }

  static async createReaderComment(
    userId: number,
    bookId: number,
    chapterId: string,
    paragraphIndex: number,
    selectedText: string,
    content: string
  ): Promise<ReaderComment> {
    const payload: ReaderCommentRequest = {
      user_id: userId,
      book_id: bookId,
      chapter_id: chapterId,
      paragraph_index: paragraphIndex,
      selected_text: selectedText,
      content,
    };
    return await ApiClient.post<ReaderComment>('/reader/comments', payload);
  }

  static async favorite(userId: number, bookId: number): Promise<Book[]> {
    const payload: FavoriteRequest = { user_id: userId, book_id: bookId };
    return await ApiClient.post<Book[]>('/favorites', payload);
  }

  static async removeFavorite(userId: number, bookId: number): Promise<Book[]> {
    return await ApiClient.delete<Book[]>(`/favorites?userId=${userId}&bookId=${bookId}`);
  }

  static async profile(userId: number): Promise<ProfileBundle> {
    const bundle: ProfileBundlePayload = await ApiClient.get<ProfileBundlePayload>(`/users/profile?userId=${userId}`);
    return ApiClient.normalizeProfileBundle(bundle);
  }

  static async saveProfile(profile: UserProfile): Promise<UserProfile> {
    const payload: SaveProfileRequest = {
      user_id: profile.id,
      account: profile.account,
      phone: profile.phone,
      email: profile.email || '',
      name: profile.name,
      nickname: profile.nickname || profile.name,
      major: profile.major,
      grade: profile.grade,
      interests: profile.interests,
      goal: profile.goal,
      intro: profile.intro || '',
      avatarUrl: profile.avatarUrl || '',
      channels: profile.channels,
    };
    return await ApiClient.post<UserProfile>('/users/profile', payload);
  }

  static async uploadAvatar(userId: number, filePath: string): Promise<string> {
    interface AvatarUploadResult {
      avatarUrl: string;
    }
    const fileName = ApiClient.fileNameFromPath(filePath, `avatar-${userId}.jpg`);
    const data = await ApiClient.multipart<AvatarUploadResult>('/users/avatar', [
      { name: 'user_id', contentType: 'text/plain', data: `${userId}` },
      { name: 'file', contentType: ApiClient.contentTypeForFile(fileName), remoteFileName: fileName, filePath },
    ]);
    return data.avatarUrl || '';
  }

  static async bindEmail(userId: number, email: string): Promise<UserProfile> {
    const payload: BindEmailRequest = { user_id: userId, email };
    return await ApiClient.post<UserProfile>('/users/email/bind', payload);
  }

  static async changePassword(userId: number, oldPassword: string, newPassword: string): Promise<object> {
    const payload: ChangePasswordRequest = {
      user_id: userId,
      old_password: oldPassword,
      new_password: newPassword,
    };
    return await ApiClient.post<object>('/users/password/change', payload);
  }

  static async resetPassword(phone: string): Promise<ResetPasswordResult> {
    const payload: ResetPasswordRequest = { phone };
    return await ApiClient.post<ResetPasswordResult>('/users/password/reset', payload);
  }

  static async deleteAccount(userId: number): Promise<object> {
    const payload: DeleteAccountRequest = { user_id: userId };
    return await ApiClient.post<object>('/users/account/delete', payload);
  }

  static async trackEvent(event: AnalyticsEvent): Promise<object> {
    return await ApiClient.post<object>('/analytics/events', event);
  }

  static async trackEvents(events: AnalyticsEvent[]): Promise<object> {
    const payload: AnalyticsBatchRequest = { events };
    return await ApiClient.post<object>('/analytics/events/batch', payload);
  }

  static async profileAnalysis(userId: number): Promise<object> {
    return await ApiClient.get<object>(`/analytics/profile?userId=${userId}`);
  }

  static async readingStats(userId: number): Promise<ReadingStats> {
    return await ApiClient.get<ReadingStats>(`/analytics/reading-stats?userId=${userId}`);
  }

  static async rebuildProfileAnalysis(userId: number): Promise<object> {
    const payload: RebuildProfileAnalysisRequest = {};
    return await ApiClient.post<object>(`/analytics/profile/rebuild?userId=${userId}`, payload);
  }

  static async loginWithPhone(phone: string, password: string): Promise<UserProfile> {
    const payload: PhoneAuthRequest = { phone, password };
    return await ApiClient.post<UserProfile>('/users/login', payload);
  }

  static async registerWithPhone(phone: string, password: string): Promise<UserProfile> {
    const payload: PhoneAuthRequest = { phone, password };
    return await ApiClient.post<UserProfile>('/users/register', payload);
  }

  static async providerLogin(provider: string, subject: string): Promise<UserProfile> {
    const payload: ProviderAuthRequest = { provider, subject };
    return await ApiClient.post<UserProfile>('/users/provider-login', payload);
  }

  static async commerceSearch(userId: number, bookId: number, isbn: string): Promise<CommerceBundle> {
    const payload: CommerceSearchRequest = {
      user_id: userId,
      book_id: bookId,
      isbn,
      channels: ['library', 'jd', 'dangdang', 'second_hand'],
    };
    return await ApiClient.post<CommerceBundle>('/commerce/search', payload);
  }

  static async confirmPurchase(userId: number, bookId: number, item: CommerceResult): Promise<object> {
    const action = item.platform === 'library' ? 'reserve' : 'purchase';
    const payload: ConfirmPurchaseRequest = {
      user_id: userId,
      book_id: bookId,
      platform: item.platform,
      action,
      amount: item.price,
      confirmed: true,
    };
    return await ApiClient.post<object>('/purchase/confirm', payload);
  }

  static async importBook(
    userId: number,
    fileName: string,
    sourceType: string,
    content: string = '',
    base64: string = '',
    filePath: string = ''
  ): Promise<ImportBookResult> {
    const payload: ImportBookRequest = {
      user_id: userId,
      file_name: fileName,
      source_type: sourceType,
      tags: '本地导入,可读,AI伴读',
      target_reader: '希望把本地资料纳入搜索、阅读计划和 AI 伴读的学生',
    };
    if (content) {
      payload.content = content;
    }
    if (base64) {
      payload.base64 = base64;
    }
    if (filePath) {
      payload.file_path = filePath;
    }
    return await ApiClient.post<ImportBookResult>('/import/books', payload);
  }

  private static recommendPayload(userId: number, query: string, offset: number = 0): RecommendRequest {
    return {
      user_id: userId,
      query,
      response_mode: 'stream_json_grounded',
      require_sources: true,
      allow_external_search: true,
      auto_import_missing_books: false,
      persist_missing_books: false,
      import_policy: 'title_only_when_database_has_no_available_books',
      offset,
    };
  }

  private static chatPayload(userId: number, bookId: number, question: string, options: ChatOptions = {}): ChatRequest {
    return {
      user_id: userId,
      book_id: bookId,
      question,
      chapter_id: options.chapterId || '',
      paragraph: options.paragraph || '',
      allow_external_search: options.allowExternalSearch === undefined ? true : options.allowExternalSearch,
      tone: options.tone || 'warm_companion',
      reasoning_policy: 'grounded_sources_plus_deepseek_reasoning',
      answer_scope: 'Use retrieved book evidence for book facts, and use DeepSeek general reasoning for explanation, analogies, reading advice, and concept connections. If evidence is insufficient, label the answer as general guidance instead of inventing book content.',
      response_mode: 'stream_json_grounded',
      require_sources: true,
      allow_partial_answer: true,
    };
  }

  private static decodeStreamChunk(decoder: util.TextDecoder, chunk: ArrayBuffer): string {
    try {
      return decoder.decodeWithStream(new Uint8Array(chunk), { stream: true });
    } catch (_) {
      return '';
    }
  }

  private static emitStreamLine<T>(
    line: string,
    callbacks: AiStreamCallbacks<T>,
    normalize: (result: object) => T
  ): T | null {
    const value: string = ApiClient.streamLinePayload(line);
    if (!value) {
      return null;
    }
    let event: AiStreamRawEvent;
    try {
      event = JSON.parse(value) as AiStreamRawEvent;
    } catch (_) {
      callbacks.onDelta && callbacks.onDelta(value);
      return null;
    }
    return ApiClient.emitStreamEvent<T>(event, callbacks, normalize);
  }

  private static emitStreamFrame<T>(
    frame: string,
    callbacks: AiStreamCallbacks<T>,
    normalize: (result: object) => T
  ): T | null {
    const lines: string[] = (frame || '').split('\n');
    const dataLines: string[] = [];
    let hasSseField: boolean = false;
    for (let i = 0; i < lines.length; i++) {
      const line: string = lines[i].trim();
      if (!line) {
        continue;
      }
      if (line.startsWith('data:')) {
        hasSseField = true;
        dataLines.push(line.substring(5).trim());
      } else if (line.startsWith(':') || line.startsWith('event:') ||
        line.startsWith('id:') || line.startsWith('retry:')) {
        hasSseField = true;
      }
    }
    if (dataLines.length > 0) {
      return ApiClient.emitStreamLine<T>(dataLines.join('\n'), callbacks, normalize);
    }
    if (hasSseField) {
      return null;
    }
    return ApiClient.emitStreamLine<T>(frame, callbacks, normalize);
  }

  private static isSseStreamLine(line: string): boolean {
    const value: string = (line || '').trim();
    return value.startsWith('data:') || value.startsWith('event:') ||
      value.startsWith('id:') || value.startsWith('retry:') || value.startsWith(':');
  }

  private static streamLinePayload(line: string): string {
    let value: string = (line || '').trim();
    if (!value || value === '[DONE]') {
      return '';
    }
    if (value.startsWith(':') || value.startsWith('event:') || value.startsWith('id:') || value.startsWith('retry:')) {
      return '';
    }
    if (value.startsWith('data:')) {
      value = value.substring(5).trim();
    }
    return value === '[DONE]' ? '' : value;
  }

  private static emitStreamEvent<T>(
    event: AiStreamRawEvent,
    callbacks: AiStreamCallbacks<T>,
    normalize: (result: object) => T
  ): T | null {
    if (event.code !== undefined && event.code !== 0) {
      callbacks.onError && callbacks.onError(event.message || 'AI 流式响应失败');
      return null;
    }
    if (event.code === 0 && event.data !== undefined) {
      if (typeof event.data === 'string') {
        return ApiClient.emitStreamLine<T>(event.data, callbacks, normalize);
      }
      const nested: AiStreamRawEvent = event.data as AiStreamRawEvent;
      const nestedResult: T | null = ApiClient.emitStreamEvent<T>(nested, callbacks, normalize);
      if (nestedResult || nested.type || nested.event || nested.delta || nested.text || nested.content ||
        nested.status || nested.message || nested.final || nested.result || nested.data ||
        nested.answer || nested.reason || nested.book_list || nested.llm_status) {
        return nestedResult;
      }
      const normalized: T = normalize(event.data as object);
      callbacks.onResult && callbacks.onResult(normalized);
      return normalized;
    }

    const type: string = (event.type || event.event || '').toLowerCase();
    if (type === 'delta' || type === 'answer_delta' || type === 'content_delta' ||
      type === 'message_delta' || type === 'text_delta' || type === 'token' || type === 'reason_delta') {
      callbacks.onDelta && callbacks.onDelta(event.delta || event.text || event.content || '');
      return null;
    }
    if (type === 'reasoning' || type === 'thinking') {
      callbacks.onReasoning && callbacks.onReasoning(event.delta || event.text || event.content || '');
      return null;
    }
    if (type === 'status') {
      callbacks.onStatus && callbacks.onStatus(event.status || event.message || '');
      return null;
    }
    if (type === 'error') {
      callbacks.onError && callbacks.onError(event.message || 'AI 流式响应失败');
      return null;
    }
    if (!type && (event.delta || event.text || event.content) && !event.answer && !event.reason) {
      callbacks.onDelta && callbacks.onDelta(event.delta || event.text || event.content || '');
      return null;
    }
    if (type === 'final' || type === 'result' || type === 'done' || type === 'complete' ||
      event.done || event.final || event.result || event.data ||
      event.answer !== undefined || event.reason !== undefined || event.book_list !== undefined) {
      let raw: object | null = null;
      if (event.final) {
        raw = event.final;
      } else if (event.result) {
        raw = event.result;
      } else if (event.data && typeof event.data !== 'string') {
        raw = event.data as object;
      } else if (event.answer !== undefined || event.reason !== undefined || event.book_list !== undefined) {
        raw = event as object;
      }
      if (!raw) {
        return null;
      }
      const normalized: T = normalize(raw);
      callbacks.onResult && callbacks.onResult(normalized);
      return normalized;
    }
    return null;
  }

  private static async streamRequest<T>(
    path: string,
    body: object,
    callbacks: AiStreamCallbacks<T>,
    normalize: (result: object) => T
  ): Promise<T> {
    let lastError: string = '';
    for (let i = 0; i < API_BASE_URLS.length; i++) {
      const client = http.createHttp();
      const decoder = util.TextDecoder.create('utf-8');
      let buffer: string = '';
      let sseFrame: string = '';
      let finalResult: T | null = null;
      let streamError: string = '';
      try {
        const result = await new Promise<T>((resolve, reject) => {
          const requestCallbacks: AiStreamCallbacks<T> = {
            onDelta: callbacks.onDelta,
            onReasoning: callbacks.onReasoning,
            onStatus: callbacks.onStatus,
            onResult: callbacks.onResult,
            onError: (message: string) => {
              streamError = message || 'AI 流式响应失败';
              callbacks.onError && callbacks.onError(streamError);
            },
          };
          const processLine = (line: string) => {
            if (ApiClient.isSseStreamLine(line) || sseFrame.length > 0) {
              if (line.trim()) {
                sseFrame += `${line}\n`;
                return;
              }
              const next: T | null = ApiClient.emitStreamFrame<T>(sseFrame, requestCallbacks, normalize);
              sseFrame = '';
              if (next) {
                finalResult = next;
              }
              return;
            }
            const next: T | null = ApiClient.emitStreamFrame<T>(line, requestCallbacks, normalize);
            if (next) {
              finalResult = next;
            }
          };
          const flushFrame = () => {
            if (sseFrame) {
              const next: T | null = ApiClient.emitStreamFrame<T>(sseFrame, requestCallbacks, normalize);
              sseFrame = '';
              if (next) {
                finalResult = next;
              }
            }
          };
          client.on('dataReceive', (chunk: ArrayBuffer) => {
            buffer += ApiClient.decodeStreamChunk(decoder, chunk);
            const lines: string[] = buffer.split('\n');
            buffer = lines.pop() || '';
            for (let j = 0; j < lines.length; j++) {
              processLine(lines[j]);
            }
          });
          client.on('dataEnd', () => {
            const tail: string = buffer.trim();
            if (tail) {
              processLine(tail);
            }
            flushFrame();
            if (finalResult) {
              resolve(finalResult);
            } else if (streamError) {
              reject(new Error(streamError));
            } else {
              reject(new Error('AI 流式响应没有返回最终结果'));
            }
          });
          client.requestInStream(`${API_BASE_URLS[i]}${path}`, {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream, application/x-ndjson, application/json',
            },
            extraData: JSON.stringify(body),
            expectDataType: http.HttpDataType.ARRAY_BUFFER,
            connectTimeout: 5000,
            readTimeout: 180000,
          }).then((code: number) => {
            if (code >= 400) {
              streamError = `AI 流式接口返回 ${code}`;
            }
          }).catch((err: Error) => {
            reject(err);
          });
        });
        ApiClient.markActiveBaseUrl(API_BASE_URLS[i]);
        return result;
      } catch (err) {
        lastError = `${err}`;
        callbacks.onError && callbacks.onError(lastError);
      } finally {
        client.off('dataReceive');
        client.off('dataEnd');
        client.destroy();
      }
    }
    throw new Error(`AI 流式连接失败，请确认后端 8081 和 AI 服务可用。${lastError}`);
  }

  private static silentStreamErrors<T>(callbacks: AiStreamCallbacks<T>): AiStreamCallbacks<T> {
    return {
      onDelta: callbacks.onDelta,
      onReasoning: callbacks.onReasoning,
      onStatus: callbacks.onStatus,
      onResult: callbacks.onResult,
    };
  }

  private static async get<T>(path: string): Promise<T> {
    return await ApiClient.request<T>(path, http.RequestMethod.GET);
  }

  private static async post<T>(path: string, body: object): Promise<T> {
    return await ApiClient.request<T>(path, http.RequestMethod.POST, body);
  }

  private static async patch<T>(path: string, body: object): Promise<T> {
    return await ApiClient.request<T>(path, 'PATCH' as http.RequestMethod, body);
  }

  private static async delete<T>(path: string): Promise<T> {
    return await ApiClient.request<T>(path, 'DELETE' as http.RequestMethod);
  }

  private static fileNameFromPath(path: string, fallback: string): string {
    if (!path) {
      return fallback;
    }
    const parts = path.split(/[\\/]/);
    const value = parts.length > 0 ? parts[parts.length - 1] : '';
    return value || fallback;
  }

  private static contentTypeForFile(fileName: string): string {
    const lower = (fileName || '').toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  private static async multipart<T>(path: string, parts: http.MultiFormData[]): Promise<T> {
    let lastError: string = '';
    for (let i = 0; i < API_BASE_URLS.length; i++) {
      const client = http.createHttp();
      try {
        const response = await client.request(`${API_BASE_URLS[i]}${path}`, {
          method: http.RequestMethod.POST,
          multiFormDataList: parts,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 8000,
          readTimeout: 60000,
        });
        const text = response.result as string;
        const envelope = JSON.parse(text) as ApiEnvelope<T>;
        if (envelope.code !== 0) {
          throw new Error(`${API_ERROR_PREFIX}${envelope.message}`);
        }
        ApiClient.markActiveBaseUrl(API_BASE_URLS[i]);
        return envelope.data;
      } catch (err) {
        const message = `${err}`;
        const prefixIndex = message.indexOf(API_ERROR_PREFIX);
        if (prefixIndex >= 0) {
          throw new Error(message.substring(prefixIndex + API_ERROR_PREFIX.length));
        }
        lastError = message;
      } finally {
        client.destroy();
      }
    }
    throw new Error(`头像上传失败，请确认后端 8081 服务可用。${lastError}`);
  }

  private static async request<T>(path: string, method: http.RequestMethod, body?: object): Promise<T> {
    let lastError: string = '';
    const isAiRequest: boolean = path.startsWith('/ai/');
    for (let i = 0; i < API_BASE_URLS.length; i++) {
      const client = http.createHttp();
      try {
        const response = await client.request(`${API_BASE_URLS[i]}${path}`, {
          method,
          header: {
            'Content-Type': 'application/json',
          },
          extraData: body ? JSON.stringify(body) : '',
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: isAiRequest ? 2500 : 5000,
          readTimeout: isAiRequest ? 18000 : 60000,
        });
        const text = response.result as string;
        const envelope = JSON.parse(text) as ApiEnvelope<T>;
        if (envelope.code !== 0) {
          if (isRouteMissingMessage(envelope.message || '')) {
            lastError = envelope.message;
            continue;
          }
          throw new Error(`${API_ERROR_PREFIX}${envelope.message}`);
        }
        ApiClient.markActiveBaseUrl(API_BASE_URLS[i]);
        return envelope.data;
      } catch (err) {
        const message = `${err}`;
        const prefixIndex = message.indexOf(API_ERROR_PREFIX);
        if (prefixIndex >= 0) {
          throw new Error(message.substring(prefixIndex + API_ERROR_PREFIX.length));
        }
        lastError = message;
      } finally {
        client.destroy();
      }
    }
    throw new Error(`无法连接后端，请确认 8081 服务已启动；真机请把 API 地址改为电脑局域网 IP。${lastError}`);
  }
}
