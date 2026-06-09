export interface ApiEnvelope<T> {
  code: number;
  message: string;
  data: T;
}

export interface Book {
  id: number;
  isbn: string;
  title: string;
  author: string;
  tags: string;
  category?: string;
  summary: string;
  difficulty: string;
  targetReader: string;
  coverColor: string;
  sourceType?: string;
  readable?: number | boolean;
  importStatus?: string;
  sourceNote?: string;
  chapterCount?: number;
  rating?: number;
  ratingCount?: number;
  wordCount?: number;
  readerCount?: number;
  publisher?: string;
  publishDate?: string;
  translator?: string;
  editionNote?: string;
  bookInfo?: string;
  catalogVolumes?: CatalogVolume[];
}

export interface BookTagsBundle {
  study: string[];
  general: string[];
  all: string[];
}

export interface CatalogVolume {
  id: string;
  title: string;
  chapterCount?: number;
}

export interface VolumeItem {
  id: string;
  title: string;
  chapterCount?: number;
}

export interface RecommendationBook {
  id: number;
  title: string;
  author?: string;
  difficulty?: string;
  reason?: string;
  highlight?: string;
  coverColor?: string;
  subtitle?: string;
  titleOnly?: boolean;
}

export interface SourceRef {
  chunk_id: number;
  book_id: number;
  bookId?: number;
  title: string;
  source: string;
  text: string;
  chapterId?: string;
  chapter_id?: string;
  url?: string;
}

export interface ReadingChapter {
  id: string;
  chapterId?: string;
  bookId: number;
  title: string;
  order: number;
  summary: string;
  pageCount: number;
  isCurrent?: boolean;
}

export interface ReadingContent {
  bookId: number;
  chapterId: string;
  chapterTitle: string;
  content: string;
  paragraphs: string[];
  sources?: SourceRef[];
  sourceRefs: SourceRef[];
}

export interface ReadingProgress {
  planId: number;
  bookId: number;
  chapterId: string;
  progress: number;
  scrollOffset: number;
  status: string;
  updatedAt?: string;
}

export interface BookmarkItem {
  id: number;
  bookId: number;
  chapterId: string;
  title: string;
  excerpt: string;
  createdAt: string;
}

export interface ReaderHighlight {
  id: number;
  userId: number;
  bookId: number;
  chapterId: string;
  paragraphIndex: number;
  startOffset?: number;
  endOffset?: number;
  selectedText: string;
  bookTitle: string;
  chapterTitle: string;
  createdAt: string;
}

export interface ReaderComment {
  id: number;
  userId: number;
  userName: string;
  avatarUrl: string;
  bookId: number;
  chapterId: string;
  paragraphIndex: number;
  selectedText: string;
  content: string;
  createdAt: string;
}

export interface ReaderBundle {
  book: Book;
  plan: PlanItem | null;
  chapters: ReadingChapter[];
  content: ReadingContent | null;
  progress: ReadingProgress | null;
  bookmarks: BookmarkItem[];
}

export interface CommerceResult {
  platform: string;
  price: number;
  stock: number;
  url: string;
  status: string;
  delivery: string;
  title: string;
  isbn: string;
}

export interface PlanItem {
  id: number;
  bookId: number;
  title: string;
  author: string;
  targetDays: number;
  dailyMinutesTarget?: number;
  weeklyMinutesTarget?: number;
  progress: number;
  status: string;
  chapterId?: string;
  scrollOffset?: number;
  createdAt?: string;
  updatedAt?: string;
  completedAt?: string;
  completedDates?: string[];
  coverColor: string;
}

export interface NoteItem {
  id: number;
  bookId: number;
  title: string;
  content: string;
  type: string;
  createdAt: string;
}

export interface UserProfile {
  id: number;
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

export interface ReadingDayStat {
  day: string;
  seconds: number;
}

export interface ReadingStats {
  todaySeconds: number;
  dailySeconds: ReadingDayStat[];
}

export interface AnalyticsEventExtra {
  sourceCount?: number;
}

export interface AnalyticsEvent {
  user_id: number;
  event_type: string;
  book_id?: number;
  chapter_id?: string;
  keyword?: string;
  tag?: string;
  duration_seconds?: number;
  progress?: number;
  extra?: AnalyticsEventExtra;
}

export interface ProfileBundle {
  profile: UserProfile;
  favorites: Book[];
  notes: NoteItem[];
  plans: PlanItem[];
  chat_records: ChatRecord[];
}

export interface ChatRecord {
  id: number;
  bookId: number;
  question: string;
  answer: string;
  createdAt: string;
  sourceCount?: number;
}

export function emptyBook(): Book {
  return {
    id: 0,
    isbn: '',
    title: '',
    author: '',
    tags: '',
    category: '',
    summary: '',
    difficulty: '',
    targetReader: '',
    coverColor: '#151A22',
    sourceType: 'manual_seed',
    readable: 0,
    importStatus: 'pending',
    sourceNote: '',
    chapterCount: 0,
    rating: 0,
    ratingCount: 0,
    wordCount: 0,
    readerCount: 0,
    publisher: '',
    publishDate: '',
    translator: '',
    editionNote: '',
    bookInfo: '',
    catalogVolumes: [],
  };
}

export function emptyProfile(): UserProfile {
  return {
    id: 0,
    account: '',
    phone: '',
    email: '',
    name: '',
    nickname: '',
    major: '',
    grade: '',
    interests: '',
    goal: '',
    intro: '',
    avatarUrl: '',
    channels: '',
  };
}

export function emptyReaderBundle(): ReaderBundle {
  return {
    book: emptyBook(),
    plan: null,
    chapters: [],
    content: null,
    progress: null,
    bookmarks: [],
  };
}
