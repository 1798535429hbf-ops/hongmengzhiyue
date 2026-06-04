export interface ReadingSessionState {
  bookId: number;
  chapterId: string;
  progress: number;
  scrollOffset: number;
  updatedAt: string;
  activeSinceMs: number;
  isActive: boolean;
}

export interface ReadingDurationRange {
  startedAtMs: number;
  endedAtMs: number;
}

function createSessionState(): ReadingSessionState {
  return {
    bookId: 0,
    chapterId: '',
    progress: 0,
    scrollOffset: 0,
    updatedAt: '',
    activeSinceMs: 0,
    isActive: false,
  };
}

export const ReadingSession: ReadingSessionState = createSessionState();

export function setReadingSession(bookId: number, chapterId: string, progress: number, scrollOffset: number = 0): void {
  ReadingSession.bookId = bookId;
  ReadingSession.chapterId = chapterId;
  ReadingSession.progress = progress;
  ReadingSession.scrollOffset = scrollOffset;
  if (!ReadingSession.isActive) {
    ReadingSession.activeSinceMs = Date.now();
    ReadingSession.isActive = true;
  }
  ReadingSession.updatedAt = new Date().toISOString();
}

export function finishReadingSession(): ReadingDurationRange | null {
  if (!ReadingSession.isActive || ReadingSession.activeSinceMs <= 0) {
    return null;
  }
  const endedAtMs: number = Date.now();
  const startedAtMs: number = ReadingSession.activeSinceMs;
  clearReadingSession();
  const range: ReadingDurationRange = {
    startedAtMs,
    endedAtMs,
  };
  return range;
}

export function clearReadingSession(): void {
  const fresh = createSessionState();
  ReadingSession.bookId = fresh.bookId;
  ReadingSession.chapterId = fresh.chapterId;
  ReadingSession.progress = fresh.progress;
  ReadingSession.scrollOffset = fresh.scrollOffset;
  ReadingSession.updatedAt = fresh.updatedAt;
  ReadingSession.activeSinceMs = fresh.activeSinceMs;
  ReadingSession.isActive = fresh.isActive;
}

export function isSameReadingBook(bookId: number): boolean {
  return ReadingSession.bookId === bookId && bookId !== 0;
}
