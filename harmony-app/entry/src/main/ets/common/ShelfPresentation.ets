import { PlanItem } from './Models';
import { LocalShelfBook, RemoteShelfSession, ShelfHistoryRecord, ShelfStoreState, ShelfSourceType } from './ShelfStore';
import { Theme } from './Theme';

export type ShelfTabMode = 'continue' | 'history';

export interface ShelfCardItem {
  key: string;
  sourceType: ShelfSourceType;
  title: string;
  author: string;
  tag: string;
  progress: number;
  progressText: string;
  accent: string;
  lastRead: string;
  coverTone: string;
  updatedAt: string;
  actionLabel: string;
  remoteBookId?: number;
  chapterId?: string;
  localBookKey?: string;
  openCount?: number;
  inShelf: boolean;
  downloaded: boolean;
  pinned: boolean;
}

interface ShelfDownloadTarget {
  sourceType: ShelfSourceType;
  remoteBookId?: number;
}

export function pickedTag(rawTags: string, fallback: string): string {
  const text: string = rawTags ? rawTags.trim() : '';
  if (!text) {
    return fallback;
  }
  const separators: string[] = [',', '，', '/', ' '];
  for (let i = 0; i < separators.length; i++) {
    const index: number = text.indexOf(separators[i]);
    if (index > 0) {
      return text.substring(0, index).trim();
    }
  }
  return text;
}

export function accentBySeed(seed: string): string {
  const palette: string[] = [Theme.mobileRed, Theme.mobileBlue, Theme.mobilePurple, Theme.mobileOrange];
  let score: number = 0;
  for (let i = 0; i < seed.length; i++) {
    score += seed.charCodeAt(i);
  }
  return palette[score % palette.length];
}

export function toneBySeed(seed: string): string {
  const tones: string[] = ['#EEF2FF', '#FFF3EC', '#F2F5FF', '#EEF8F4', '#FFF6E9'];
  let score: number = 0;
  for (let i = 0; i < seed.length; i++) {
    score += seed.charCodeAt(i);
  }
  return tones[score % tones.length];
}

export function formatDateLabel(isoText: string): string {
  if (!isoText) {
    return '刚刚';
  }
  const date: Date = new Date(isoText);
  if (Number.isNaN(date.getTime())) {
    return isoText;
  }
  const month: string = `${date.getMonth() + 1}`.padStart(2, '0');
  const day: string = `${date.getDate()}`.padStart(2, '0');
  const hour: string = `${date.getHours()}`.padStart(2, '0');
  const minute: string = `${date.getMinutes()}`.padStart(2, '0');
  return `${month}-${day} ${hour}:${minute}`;
}

export function formatReadingDuration(totalSeconds: number): string {
  const safeSeconds: number = Number.isFinite(totalSeconds) && totalSeconds > 0 ? Math.floor(totalSeconds) : 0;
  const hours: number = Math.floor(safeSeconds / 3600);
  const minutes: number = Math.floor((safeSeconds % 3600) / 60);
  const seconds: number = safeSeconds % 60;
  return `${`${hours}`.padStart(2, '0')}:${`${minutes}`.padStart(2, '0')}:${`${seconds}`.padStart(2, '0')}`;
}

export function findRemoteSession(sessions: RemoteShelfSession[], bookId: number): RemoteShelfSession | null {
  for (let i = 0; i < sessions.length; i++) {
    if (sessions[i].bookId === bookId) {
      return sessions[i];
    }
  }
  return null;
}

function isRemoteHidden(storeState: ShelfStoreState, bookId: number): boolean {
  for (let i = 0; i < storeState.hiddenRemoteBookIds.length; i++) {
    if (storeState.hiddenRemoteBookIds[i] === bookId) {
      return true;
    }
  }
  return false;
}

export function isRemoteBookInShelf(storeState: ShelfStoreState, plans: PlanItem[], bookId: number): boolean {
  if (bookId <= 0 || isRemoteHidden(storeState, bookId)) {
    return false;
  }
  for (let i = 0; i < storeState.remoteSessions.length; i++) {
    if (storeState.remoteSessions[i].bookId === bookId) {
      return true;
    }
  }
  for (let i = 0; i < plans.length; i++) {
    if (plans[i].bookId === bookId && !(plans[i].status === 'finished' && plans[i].progress >= 100)) {
      return true;
    }
  }
  return false;
}

function isPinned(storeState: ShelfStoreState, sourceKey: string): boolean {
  return storeState.pinnedSourceKeys.includes(sourceKey);
}

function isDownloaded(storeState: ShelfStoreState, item: ShelfDownloadTarget): boolean {
  if (item.sourceType === 'local') {
    return true;
  }
  return !!item.remoteBookId && storeState.downloadedRemoteBookIds.includes(item.remoteBookId);
}

function withPinnedState(storeState: ShelfStoreState, item: ShelfCardItem): ShelfCardItem {
  const nextItem: ShelfCardItem = {
    key: item.key,
    sourceType: item.sourceType,
    title: item.title,
    author: item.author,
    tag: item.tag,
    progress: item.progress,
    progressText: item.progressText,
    accent: item.accent,
    lastRead: item.lastRead,
    coverTone: item.coverTone,
    updatedAt: item.updatedAt,
    actionLabel: item.actionLabel,
    inShelf: item.inShelf,
    downloaded: item.downloaded,
    pinned: isPinned(storeState, item.key),
  };
  if (item.remoteBookId !== undefined) {
    nextItem.remoteBookId = item.remoteBookId;
  }
  if (item.chapterId !== undefined) {
    nextItem.chapterId = item.chapterId;
  }
  if (item.localBookKey !== undefined) {
    nextItem.localBookKey = item.localBookKey;
  }
  if (item.openCount !== undefined) {
    nextItem.openCount = item.openCount;
  }
  return nextItem;
}

function sortItems(storeState: ShelfStoreState, items: ShelfCardItem[]): ShelfCardItem[] {
  const pinnedOrder: Record<string, number> = {};
  for (let i = 0; i < storeState.pinnedSourceKeys.length; i++) {
    pinnedOrder[storeState.pinnedSourceKeys[i]] = i;
  }
  const nextItems: ShelfCardItem[] = items.slice();
  nextItems.sort((left: ShelfCardItem, right: ShelfCardItem) => {
    const leftPinned: boolean = isPinned(storeState, left.key);
    const rightPinned: boolean = isPinned(storeState, right.key);
    if (leftPinned && rightPinned) {
      return pinnedOrder[left.key] - pinnedOrder[right.key];
    }
    if (leftPinned) {
      return -1;
    }
    if (rightPinned) {
      return 1;
    }
    return right.updatedAt.localeCompare(left.updatedAt);
  });
  return nextItems.map((item: ShelfCardItem) => {
    return withPinnedState(storeState, item);
  });
}

function localContinueItem(storeState: ShelfStoreState, item: LocalShelfBook): ShelfCardItem {
  const accent: string = accentBySeed(item.extension || item.title);
  const updatedAt: string = item.lastOpenedAt || item.importedAt;
  return {
    key: item.key,
    sourceType: 'local',
    title: item.title,
    author: item.displayName,
    tag: item.remoteBookId ? '已入库' : (item.extension ? item.extension.toUpperCase() : 'LOCAL'),
    progress: 0,
    progressText: item.remoteBookId ? '可搜索 / 可 AI 伴读' : (item.openCount > 0 ? `已打开 ${item.openCount} 次` : '未开始阅读'),
    accent,
    lastRead: item.lastOpenedAt ? `上次打开：${formatDateLabel(item.lastOpenedAt)}` : `入库时间：${formatDateLabel(item.importedAt)}`,
    coverTone: toneBySeed(item.displayName),
    updatedAt,
    actionLabel: item.remoteBookId ? '开始阅读' : '打开文件',
    remoteBookId: item.remoteBookId,
    localBookKey: item.key,
    openCount: item.openCount,
    inShelf: true,
    downloaded: true,
    pinned: isPinned(storeState, item.key),
  };
}

function remotePlanItem(storeState: ShelfStoreState, plan: PlanItem, session: RemoteShelfSession | null): ShelfCardItem {
  const seed: string = `${plan.title}-${plan.author}`;
  const updatedAt: string = session ? session.updatedAt : `1970-01-01T00:${`${plan.id % 60}`.padStart(2, '0')}:00.000Z`;
  const downloadTarget: ShelfDownloadTarget = {
    sourceType: 'remote',
    remoteBookId: plan.bookId,
  };
  return {
    key: session ? session.key : `remote:${plan.bookId}`,
    sourceType: 'remote',
    title: plan.title,
    author: plan.author,
    tag: pickedTag(session ? session.tags : '', '在读'),
    progress: session ? session.progress : plan.progress,
    progressText: `${session ? session.progress : plan.progress}%`,
    accent: accentBySeed(seed),
    lastRead: session && session.chapterTitle ? `上次阅读：${session.chapterTitle}` : `当前进度：${plan.progress}%`,
    coverTone: session && session.coverColor ? session.coverColor : (plan.coverColor || toneBySeed(seed)),
    updatedAt,
    actionLabel: '继续阅读',
    remoteBookId: plan.bookId,
    chapterId: session ? session.chapterId : '',
    inShelf: true,
    downloaded: isDownloaded(storeState, downloadTarget),
    pinned: isPinned(storeState, session ? session.key : `remote:${plan.bookId}`),
  };
}

function remoteSessionItem(storeState: ShelfStoreState, session: RemoteShelfSession): ShelfCardItem {
  const seed: string = `${session.title}-${session.author}`;
  const downloadTarget: ShelfDownloadTarget = {
    sourceType: 'remote',
    remoteBookId: session.bookId,
  };
  return {
    key: session.key,
    sourceType: 'remote',
    title: session.title,
    author: session.author,
    tag: pickedTag(session.tags, '在读'),
    progress: session.progress,
    progressText: `${session.progress}%`,
    accent: accentBySeed(seed),
    lastRead: session.chapterTitle ? `上次阅读：${session.chapterTitle}` : `最近阅读：${formatDateLabel(session.updatedAt)}`,
    coverTone: session.coverColor || toneBySeed(seed),
    updatedAt: session.updatedAt,
    actionLabel: '继续阅读',
    remoteBookId: session.bookId,
    chapterId: session.chapterId,
    inShelf: true,
    downloaded: isDownloaded(storeState, downloadTarget),
    pinned: isPinned(storeState, session.key),
  };
}

function historyItem(
  storeState: ShelfStoreState,
  plans: PlanItem[],
  history: ShelfHistoryRecord,
  localBook: LocalShelfBook | null,
  session: RemoteShelfSession | null
): ShelfCardItem {
  const inShelf: boolean = history.sourceType === 'local' ? !!localBook : (!!history.remoteBookId && isRemoteBookInShelf(storeState, plans, history.remoteBookId));
  const downloadTarget: ShelfDownloadTarget = {
    sourceType: 'remote',
    remoteBookId: history.remoteBookId,
  };
  return {
    key: history.key,
    sourceType: history.sourceType,
    title: history.title,
    author: history.subtitle,
    tag: history.sourceType === 'local'
      ? '浏览记录'
      : pickedTag(session ? session.tags : (history.tags || ''), '浏览记录'),
    progress: session ? session.progress : 0,
    progressText: session ? `${session.progress}%` : (localBook ? `已打开 ${localBook.openCount} 次` : history.actionText),
    accent: history.sourceType === 'local' ? Theme.mobileBlue : Theme.mobileOrange,
    lastRead: `${history.actionText} · ${formatDateLabel(history.updatedAt)}`,
    coverTone: history.coverColor || history.coverTone || toneBySeed(history.title),
    updatedAt: history.updatedAt,
    actionLabel: history.sourceType === 'local' ? '打开文件' : '查看书籍',
    remoteBookId: history.remoteBookId,
    chapterId: session ? session.chapterId : '',
    localBookKey: history.localBookKey,
    openCount: localBook ? localBook.openCount : 0,
    inShelf,
    downloaded: history.sourceType === 'local' ? true : isDownloaded(storeState, downloadTarget),
    pinned: false,
  };
}

export function buildContinueItems(storeState: ShelfStoreState, plans: PlanItem[]): ShelfCardItem[] {
  const nextItems: ShelfCardItem[] = [];
  for (let i = 0; i < storeState.localBooks.length; i++) {
    nextItems.push(localContinueItem(storeState, storeState.localBooks[i]));
  }

  for (let i = 0; i < plans.length; i++) {
    const plan: PlanItem = plans[i];
    if ((plan.status === 'finished' && plan.progress >= 100) || isRemoteHidden(storeState, plan.bookId)) {
      continue;
    }
    nextItems.push(remotePlanItem(storeState, plan, findRemoteSession(storeState.remoteSessions, plan.bookId)));
  }

  for (let i = 0; i < storeState.remoteSessions.length; i++) {
    const session: RemoteShelfSession = storeState.remoteSessions[i];
    if (isRemoteHidden(storeState, session.bookId)) {
      continue;
    }
    let existsInPlans: boolean = false;
    for (let index = 0; index < plans.length; index++) {
      if (plans[index].bookId === session.bookId) {
        existsInPlans = true;
        break;
      }
    }
    if (!existsInPlans) {
      nextItems.push(remoteSessionItem(storeState, session));
    }
  }

  return sortItems(storeState, nextItems);
}

export function buildHistoryItems(storeState: ShelfStoreState, plans: PlanItem[]): ShelfCardItem[] {
  const nextItems: ShelfCardItem[] = [];
  for (let i = 0; i < storeState.browseHistory.length; i++) {
    const history: ShelfHistoryRecord = storeState.browseHistory[i];
    const session: RemoteShelfSession | null = history.remoteBookId ? findRemoteSession(storeState.remoteSessions, history.remoteBookId) : null;
    let localBook: LocalShelfBook | null = null;
    if (history.localBookKey) {
      for (let index = 0; index < storeState.localBooks.length; index++) {
        if (storeState.localBooks[index].key === history.localBookKey) {
          localBook = storeState.localBooks[index];
          break;
        }
      }
    }
    nextItems.push(historyItem(storeState, plans, history, localBook, session));
  }
  nextItems.sort((left: ShelfCardItem, right: ShelfCardItem) => {
    return right.updatedAt.localeCompare(left.updatedAt);
  });
  return nextItems;
}
