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
  summary: string;
  difficulty: string;
  targetReader: string;
  coverColor: string;
}

export interface RecommendationBook {
  id: number;
  title: string;
  author: string;
  difficulty: string;
  reason: string;
}

export interface SourceRef {
  chunk_id: number;
  book_id: number;
  title: string;
  source: string;
  text: string;
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
  progress: number;
  status: string;
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
  name: string;
  major: string;
  grade: string;
  interests: string;
  goal: string;
  budget: number;
  channels: string;
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
    summary: '',
    difficulty: '',
    targetReader: '',
    coverColor: '#151A22',
  };
}

export function emptyProfile(): UserProfile {
  return {
    id: 10086,
    name: '测试同学',
    major: '计算机科学',
    grade: '大二',
    interests: '人工智能,算法,英语备考',
    goal: '课程拓展与竞赛入门',
    budget: 80,
    channels: 'library,jd,dangdang,second_hand',
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
