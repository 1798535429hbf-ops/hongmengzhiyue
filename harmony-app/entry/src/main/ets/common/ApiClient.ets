import { http } from '@kit.NetworkKit';
import {
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

export interface RecommendResult {
  intent: string;
  book_list: RecommendationBook[];
  reason: string;
  difficulty: string;
  follow_up_suggestion: string;
  sources: SourceRef[];
  llm_status: string;
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

interface RecommendRequest {
  user_id: number;
  query: string;
}

interface ChatRequest {
  user_id: number;
  book_id: number;
  question: string;
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
  name: string;
  major: string;
  grade: string;
  interests: string;
  goal: string;
  budget: number;
  channels: string;
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

export class ApiClient {
  static async searchBooks(keyword: string, tag: string = ''): Promise<Book[]> {
    const path = `/books/search?keyword=${encodeURIComponent(keyword)}&tag=${encodeURIComponent(tag)}&page=0&size=30`;
    return await ApiClient.get<Book[]>(path);
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

  static async recommend(userId: number, query: string): Promise<RecommendResult> {
    const payload: RecommendRequest = { user_id: userId, query };
    return await ApiClient.post<RecommendResult>('/ai/recommend', payload);
  }

  static async chat(userId: number, bookId: number, question: string): Promise<ChatResult> {
    const payload: ChatRequest = { user_id: userId, book_id: bookId, question };
    return await ApiClient.post<ChatResult>('/ai/chat', payload);
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
      name: profile.name,
      major: profile.major,
      grade: profile.grade,
      interests: profile.interests,
      goal: profile.goal,
      budget: profile.budget,
      channels: profile.channels,
    };
    return await ApiClient.post<UserProfile>('/users/profile', payload);
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
          connectTimeout: 5000,
          readTimeout: 30000,
        });
        const text = response.result as string;
        const envelope = JSON.parse(text) as ApiEnvelope<T>;
        if (envelope.code !== 0) {
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
