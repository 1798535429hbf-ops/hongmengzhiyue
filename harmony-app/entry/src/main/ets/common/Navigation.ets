import router from '@ohos.router';

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

export function openShelfManage(): void {
  router.pushUrl({
    url: 'pages/ShelfManagePage',
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
