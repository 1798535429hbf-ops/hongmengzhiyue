import router from '@ohos.router';

export const ACTIVE_TAB_KEY: string = 'smartread_active_tab';
export const STORE_TAB_INDEX: number = 1;

function toNumber(value: Object | undefined, fallback: number = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return fallback;
}

export function currentBookId(fallback: number = 0): number {
  const params = router.getParams() as Record<string, Object>;
  return toNumber(params.bookId || params.book_id || params.id, fallback);
}

export function currentChapterId(fallback: string = ''): string {
  const params = router.getParams() as Record<string, Object>;
  const value = params.chapterId || params.chapter_id || params.cid;
  return typeof value === 'string' ? value : fallback;
}

export function currentSourceTab(fallback: string = ''): string {
  const params = router.getParams() as Record<string, Object>;
  const value = params.from || params.tab || params.source;
  return typeof value === 'string' ? value : fallback;
}

export function currentKeyword(fallback: string = ''): string {
  const params = router.getParams() as Record<string, Object>;
  const value = params.keyword || params.query || params.q;
  return typeof value === 'string' ? value : fallback;
}

export function openBookDetail(bookId: number): void {
  router.pushUrl({
    url: 'pages/BookDetailPage',
    params: { bookId },
  });
}

export function openReader(bookId: number, chapterId: string = ''): void {
  router.pushUrl({
    url: 'pages/ReaderPage',
    params: { bookId, chapterId },
  });
}

export function openChat(bookId: number): void {
  router.pushUrl({
    url: 'pages/ChatPage',
    params: { bookId },
  });
}

export function openCommerce(bookId: number): void {
  router.pushUrl({
    url: 'pages/CommercePage',
    params: { bookId },
  });
}

export function openSearch(keyword: string = ''): void {
  router.pushUrl({
    url: 'pages/SearchPage',
    params: { keyword },
  });
}

export function openStoreTab(): void {
  AppStorage.setOrCreate(ACTIVE_TAB_KEY, STORE_TAB_INDEX);
}

export function openShelfManage(): void {
  router.pushUrl({
    url: 'pages/ShelfManagePage',
  });
}

export function openLogin(): void {
  router.pushUrl({
    url: 'pages/LoginPage',
  });
}

export function openProfileEdit(): void {
  router.pushUrl({
    url: 'pages/ProfileEditPage',
  });
}

export function openSettings(): void {
  router.pushUrl({
    url: 'pages/SettingsPage',
  });
}

export function openCatalog(bookId: number): void {
  router.pushUrl({
    url: 'pages/CatalogPage',
    params: { bookId },
  });
}

export function goBack(): void {
  router.back();
}
