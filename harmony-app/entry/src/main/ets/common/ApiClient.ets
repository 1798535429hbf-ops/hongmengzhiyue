import { http } from '@kit.NetworkKit';
import {
  AnalyticsEvent,
  ApiEnvelope,
  Book,
  CommerceResult,
  PlanItem,
  ProfileBundle,
  ReaderBundle,
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
  llm_status: string;
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
  response_mode?: string;
  require_sources?: boolean;
  allow_partial_answer?: boolean;
}

interface CreatePlanRequest {
  user_id: number;
  book_id: number;
  target_days: number;
}

interface SaveNoteRequest {
  user_id: number;
  book_id: number;
  content: string;
  type: string;
}

interface FavoriteRequest {
  user_id: number;
  book_id: number;
}

interface SaveProfileRequest {
  user_id: number;
  account: string;
  phone: string;
  name: string;
  major: string;
  grade: string;
  interests: string;
  goal: string;
  channels: string;
}

interface PhoneAuthRequest {
  phone: string;
  password: string;
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
  progress: number;
  scroll_offset: number;
  status: string;
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

export class ApiClient {
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

  private static normalizeRecommendResult(result: RecommendResult, query: string): RecommendResult {
    const books: RecommendationBook[] = (result.book_list || []).filter((book: RecommendationBook) => {
      return !!book && book.id > 0 && !!book.title;
    });
    const reason: string = ApiClient.isWeakAiText(result.reason || '')
      ? ''
      : (result.reason || '');
    return {
      intent: result.intent || 'recommend',
      book_list: books,
      reason: reason || (books.length > 0
        ? ApiClient.recommendationLead(books)
        : ''),
      difficulty: result.difficulty || (books.length > 0 ? books[0].difficulty : ''),
      follow_up_suggestion: result.follow_up_suggestion || '可以点开一本看详情，或者补充专业、难度、阅读目的，我再缩小范围。',
      sources: result.sources || [],
      tool_trace: result.tool_trace || [],
      llm_status: ApiClient.isWeakAiStatus(result.llm_status || '') ? 'recovered' : (result.llm_status || 'ok'),
    };
  }

  private static recommendFromRealBooks(query: string, books: Book[]): RecommendResult {
    const list: RecommendationBook[] = books.slice(0, 6).map((book: Book) => {
      const item: RecommendationBook = {
        id: book.id,
        title: book.title,
        author: book.author,
        difficulty: book.difficulty,
        reason: book.summary
          ? `${book.summary.slice(0, 72)}${book.summary.length > 72 ? '...' : ''}`
          : '这本书和你刚才的方向比较接近，可以继续进入详情、阅读或伴读。',
        coverColor: book.coverColor,
      };
      return item;
    });
    return {
      intent: 'recommend',
      book_list: list,
      reason: list.length > 0
        ? ApiClient.recommendationLead(list)
        : '这次没找到足够合适、可点击的书。你可以换个更具体的关键词，比如专业、考试目标或想读的难度。',
      difficulty: list.length > 0 ? list[0].difficulty : '',
      follow_up_suggestion: list.length > 0 ? '先点开第一本看详情；如果不是这个方向，换一个更具体的关键词。' : '可以补充专业、用途、难度或具体主题，我再帮你缩小范围。',
      sources: [],
      tool_trace: [
        { tool: 'ai_recommend', status: 'recovered', detail: 'used_book_search_results' },
        { tool: 'books_search', status: list.length > 0 ? 'ok' : 'empty' },
      ],
      llm_status: list.length > 0 ? 'recovered' : 'insufficient_data',
    };
  }

  private static recommendationLead(books: RecommendationBook[]): string {
    if (books.length <= 0) {
      return '';
    }
    const first: RecommendationBook = books[0];
    if (books.length === 1) {
      return `我推荐先读《${first.title}》。${first.reason || '它和你现在的方向比较贴近，适合先点进详情看一眼。'}`;
    }
    const second: RecommendationBook = books[1];
    return `我推荐先读《${first.title}》，理由是${first.reason || '它最贴近你现在的方向'}；再把《${second.title}》作为对照，理由是${second.reason || '它能补上另一个角度'}。`;
  }

  private static fallbackSearchQuery(query: string): string {
    const normalized: string = (query || '').trim();
    if (!normalized || normalized.startsWith('换一批')) {
      return '';
    }
    const topicHints: string[] = [
      '人工智能', '机器学习', '深度学习', '算法', '计算机', '数据结构', '数据库', '操作系统',
      'Python', 'Go', 'Linux', '英语', '考研', '人文', '文学', '历史', '地理', '哲学',
      '心理学', '设计', '经济', '创业', '物理', '数学'
    ];
    for (let i = 0; i < topicHints.length; i++) {
      if (normalized.indexOf(topicHints[i]) >= 0) {
        return topicHints[i];
      }
    }
    const cleaned = normalized
      .replace('推荐适合我的书', '')
      .replace('最近有什么好书', '')
      .replace('帮我制定阅读计划', '')
      .replace('帮我挑书', '')
      .trim();
    if (!cleaned || cleaned.indexOf('推荐') >= 0 || cleaned.indexOf('好书') >= 0 || cleaned.length > 12) {
      return '';
    }
    return cleaned;
  }

  static async searchBooks(keyword: string, tag: string = '', page: number = 0, size: number = 30): Promise<Book[]> {
    const path = `/books/search?keyword=${encodeURIComponent(keyword)}&tag=${encodeURIComponent(tag)}&page=${page}&size=${size}`;
    return await ApiClient.get<Book[]>(path);
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
    return await ApiClient.get<ReaderBundle>(`/books/${bookId}/reader?userId=${userId}${suffix}`);
  }

  static async listChapters(bookId: number): Promise<ReadingChapter[]> {
    return await ApiClient.get<ReadingChapter[]>(`/books/${bookId}/chapters`);
  }

  static async getReadingContent(bookId: number, chapterId: string): Promise<ReadingContent> {
    return await ApiClient.get<ReadingContent>(`/books/${bookId}/content?chapterId=${encodeURIComponent(chapterId)}`);
  }

  static async recommend(userId: number, query: string, offset: number = 0): Promise<RecommendResult> {
    const payload: RecommendRequest = {
      user_id: userId,
      query,
      response_mode: 'strict_json_grounded',
      require_sources: true,
      allow_external_search: true,
      auto_import_missing_books: true,
      persist_missing_books: true,
      import_policy: 'insert_missing_metadata_and_chunks_before_return',
      offset,
    };
    const first: RecommendResult = await ApiClient.post<RecommendResult>('/ai/recommend', payload);
    const normalized: RecommendResult = ApiClient.normalizeRecommendResult(first, query);
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
    } catch (_) {
    }

    const books: Book[] = await ApiClient.searchBooks(ApiClient.fallbackSearchQuery(query), '', Math.max(0, offset), 6);
    return ApiClient.recommendFromRealBooks(query, books);
  }

  static async chat(userId: number, bookId: number, question: string): Promise<ChatResult> {
    const payload: ChatRequest = {
      user_id: userId,
      book_id: bookId,
      question,
      response_mode: 'strict_json_grounded',
      require_sources: true,
      allow_partial_answer: true,
    };
    const result: ChatResult = await ApiClient.post<ChatResult>('/ai/chat', payload);
    if (!ApiClient.isWeakAiText(result.answer || '') && !ApiClient.isWeakAiStatus(result.llm_status || '')) {
      return result;
    }
    const sources: SourceRef[] = result.sources || [];
    if (sources.length > 0) {
      return {
        answer: `我先看这本书里已经能追溯到的片段：${sources.slice(0, 2).map((source: SourceRef) => source.text).join(' ')} 所以这次建议你先围绕这些已经出现的概念和章节线索读，再点开参考依据核对细节。`,
        sources,
        follow_up_suggestion: result.follow_up_suggestion || '可以把问题缩小到某一章、某个概念或某段摘录，我会给出更精确的伴读回答。',
        llm_status: 'recovered',
      };
    }
    return {
      answer: '这次没有拿到足够可靠的来源片段，我不会编造答案。请先进入阅读器确认章节已入库，或换成更具体的问题，比如“第一章的核心概念是什么”。',
      sources: [],
      follow_up_suggestion: '确认图书章节和 book_chunk 已入库后再提问，伴读回答会更稳。',
      llm_status: 'insufficient_data',
    };
  }

  static async createPlan(userId: number, bookId: number, targetDays: number = 14): Promise<object> {
    const payload: CreatePlanRequest = { user_id: userId, book_id: bookId, target_days: targetDays };
    return await ApiClient.post<object>('/plans', payload);
  }

  static async listPlans(userId: number): Promise<PlanItem[]> {
    return await ApiClient.get<PlanItem[]>(`/plans?userId=${userId}`);
  }

  static async updatePlanProgress(
    userId: number,
    planId: number,
    bookId: number,
    chapterId: string,
    progress: number,
    scrollOffset: number = 0,
    status: string = 'reading'
  ): Promise<ReadingProgress> {
    const payload: UpdateProgressRequest = {
      user_id: userId,
      book_id: bookId,
      chapter_id: chapterId,
      progress,
      scroll_offset: scrollOffset,
      status,
    };
    return await ApiClient.patch<ReadingProgress>(`/plans/${planId}`, payload);
  }

  static async saveNote(userId: number, bookId: number, content: string): Promise<object> {
    const payload: SaveNoteRequest = { user_id: userId, book_id: bookId, content, type: 'ai_answer' };
    return await ApiClient.post<object>('/notes', payload);
  }

  static async saveReadingNote(userId: number, bookId: number, content: string): Promise<object> {
    const payload: SaveNoteRequest = { user_id: userId, book_id: bookId, content, type: 'reading_excerpt' };
    return await ApiClient.post<object>('/notes', payload);
  }

  static async favorite(userId: number, bookId: number): Promise<Book[]> {
    const payload: FavoriteRequest = { user_id: userId, book_id: bookId };
    return await ApiClient.post<Book[]>('/favorites', payload);
  }

  static async profile(userId: number): Promise<ProfileBundle> {
    return await ApiClient.get<ProfileBundle>(`/users/profile?userId=${userId}`);
  }

  static async saveProfile(profile: UserProfile): Promise<UserProfile> {
    const payload: SaveProfileRequest = {
      user_id: profile.id,
      account: profile.account,
      phone: profile.phone,
      name: profile.name,
      major: profile.major,
      grade: profile.grade,
      interests: profile.interests,
      goal: profile.goal,
      channels: profile.channels,
    };
    return await ApiClient.post<UserProfile>('/users/profile', payload);
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

  private static async get<T>(path: string): Promise<T> {
    return await ApiClient.request<T>(path, http.RequestMethod.GET);
  }

  private static async post<T>(path: string, body: object): Promise<T> {
    return await ApiClient.request<T>(path, http.RequestMethod.POST, body);
  }

  private static async patch<T>(path: string, body: object): Promise<T> {
    return await ApiClient.request<T>(path, 'PATCH' as http.RequestMethod, body);
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
