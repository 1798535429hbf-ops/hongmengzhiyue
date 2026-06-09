import router from '@ohos.router';

export const ACTIVE_TAB_KEY: string = 'smartread_active_tab';
export const STORE_TAB_INDEX: number = 1;
export const PLAN_DATA_REFRESH_KEY: string = 'smartread_plan_data_refresh_seed';
export const PLAN_PROGRESS_BOOK_ID_KEY: string = 'smartread_plan_progress_book_id';
export const PLAN_PROGRESS_VALUE_KEY: string = 'smartread_plan_progress_value';
export const PLAN_PROGRESS_CHAPTER_ID_KEY: string = 'smartread_plan_progress_chapter_id';
export const PLAN_PROGRESS_SCROLL_OFFSET_KEY: string = 'smartread_plan_progress_scroll_offset';
export const PLAN_PROGRESS_STATUS_KEY: string = 'smartread_plan_progress_status';
export const PLAN_PROGRESS_UPDATED_AT_KEY: string = 'smartread_plan_progress_updated_at';

export function notifyPlanDataChanged(): void {
  const current = AppStorage.get<number>(PLAN_DATA_REFRESH_KEY);
  AppStorage.setOrCreate(PLAN_DATA_REFRESH_KEY, (typeof current === 'number' ? current : 0) + 1);
}

export function notifyPlanProgressChanged(
  bookId: number,
  progress: number,
  chapterId: string = '',
  scrollOffset: number = 0,
  status: string = ''
): void {
  if (bookId <= 0) {
    return;
  }
  const safeProgress: number = Math.max(0, Math.min(100, Math.round(progress || 0)));
  AppStorage.setOrCreate(PLAN_PROGRESS_BOOK_ID_KEY, bookId);
  AppStorage.setOrCreate(PLAN_PROGRESS_VALUE_KEY, safeProgress);
  AppStorage.setOrCreate(PLAN_PROGRESS_CHAPTER_ID_KEY, chapterId || '');
  AppStorage.setOrCreate(PLAN_PROGRESS_SCROLL_OFFSET_KEY, Math.max(0, Math.round(scrollOffset || 0)));
  AppStorage.setOrCreate(PLAN_PROGRESS_STATUS_KEY, status || (safeProgress >= 100 ? 'finished' : 'reading'));
  AppStorage.setOrCreate(PLAN_PROGRESS_UPDATED_AT_KEY, new Date().toISOString());
  notifyPlanDataChanged();
}

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

export function openAccountSecurity(): void {
  router.pushUrl({
    url: 'pages/AccountSecurityPage',
  });
}

export function openPreferenceSettings(): void {
  router.pushUrl({
    url: 'pages/PreferenceSettingsPage',
  });
}

export function openGeneralSettings(): void {
  router.pushUrl({
    url: 'pages/GeneralSettingsPage',
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
