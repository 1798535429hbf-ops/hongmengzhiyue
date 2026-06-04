import { common, Want, wantConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { ApiClient, ImportBookResult } from './ApiClient';
import { UserSession } from './UserSession';

const SHELF_PREFERENCES_NAME: string = 'smartread_shelf_store';
const SHELF_STATE_KEY: string = 'shelf_state_json';
const SHELF_IMPORT_DIR: string = 'imported-books';
const MAX_HISTORY_COUNT: number = 60;

export type ShelfSourceType = 'remote' | 'local';
export type ShelfHistoryKind = 'detail' | 'reader' | 'local-open' | 'local-import';
export type LocalPreviewMode = 'external' | 'text';

export interface RemoteShelfSession {
  key: string;
  bookId: number;
  title: string;
  author: string;
  tags: string;
  difficulty: string;
  chapterId: string;
  chapterTitle: string;
  progress: number;
  updatedAt: string;
  coverColor: string;
}

export interface LocalShelfBook {
  key: string;
  remoteBookId?: number;
  title: string;
  displayName: string;
  extension: string;
  fileType: string;
  uri: string;
  path: string;
  importedAt: string;
  lastOpenedAt: string;
  openCount: number;
  previewMode: LocalPreviewMode;
}

export interface ShelfHistoryRecord {
  key: string;
  sourceType: ShelfSourceType;
  sourceKey: string;
  title: string;
  subtitle: string;
  actionText: string;
  updatedAt: string;
  coverTone: string;
  tags?: string;
  difficulty?: string;
  coverColor?: string;
  remoteBookId?: number;
  localBookKey?: string;
}

export interface TodayReadingState {
  dateKey: string;
  seconds: number;
}

export interface ShelfStoreState {
  remoteSessions: RemoteShelfSession[];
  localBooks: LocalShelfBook[];
  browseHistory: ShelfHistoryRecord[];
  hiddenRemoteBookIds: number[];
  pinnedSourceKeys: string[];
  downloadedRemoteBookIds: number[];
  todayReading: TodayReadingState;
}

export interface RemoteBrowsePayload {
  bookId: number;
  title: string;
  author: string;
  tags?: string;
  difficulty?: string;
  coverColor?: string;
  actionText?: string;
  updatedAt?: string;
}

export interface RemoteReadingPayload extends RemoteBrowsePayload {
  chapterId?: string;
  chapterTitle?: string;
  progress?: number;
}

export interface LocalBookImportResult {
  imported: LocalShelfBook[];
  skipped: LocalShelfBook[];
}

function emptyState(): ShelfStoreState {
  return {
    remoteSessions: [],
    localBooks: [],
    browseHistory: [],
    hiddenRemoteBookIds: [],
    pinnedSourceKeys: [],
    downloadedRemoteBookIds: [],
    todayReading: {
      dateKey: todayKey(),
      seconds: 0,
    },
  };
}

function stateKeyForUser(userId: number): string {
  const suffix: string = userId > 0 ? `${userId}` : 'guest';
  return `${SHELF_STATE_KEY}_${suffix}`;
}

function nowIso(): string {
  return new Date().toISOString();
}

function todayKey(date: Date = new Date()): string {
  const year: string = `${date.getFullYear()}`;
  const month: string = `${date.getMonth() + 1}`.padStart(2, '0');
  const day: string = `${date.getDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function normalizeText(value: string | undefined): string {
  return value ? value.trim() : '';
}

function lowerExtension(fileName: string): string {
  const index: number = fileName.lastIndexOf('.');
  if (index < 0 || index >= fileName.length - 1) {
    return '';
  }
  return fileName.substring(index + 1).toLowerCase();
}

function baseTitle(fileName: string): string {
  const index: number = fileName.lastIndexOf('.');
  if (index <= 0) {
    return fileName;
  }
  return fileName.substring(0, index);
}

function sanitizeFileName(fileName: string): string {
  const normalized: string = normalizeText(fileName).replace(/[\\/:*?"<>|]/g, '_');
  if (normalized) {
    return normalized;
  }
  return `book-${Date.now()}.bin`;
}

function ensureHistorySize(records: ShelfHistoryRecord[]): ShelfHistoryRecord[] {
  const next: ShelfHistoryRecord[] = records.slice();
  next.sort((left: ShelfHistoryRecord, right: ShelfHistoryRecord) => {
    return right.updatedAt.localeCompare(left.updatedAt);
  });
  if (next.length <= MAX_HISTORY_COUNT) {
    return next;
  }
  return next.slice(0, MAX_HISTORY_COUNT);
}

function guessLocalFileType(extension: string): string {
  if (extension === 'pdf') {
    return 'application/pdf';
  }
  if (extension === 'txt' || extension === 'md' || extension === 'markdown') {
    return 'text/plain';
  }
  if (extension === 'json') {
    return 'application/json';
  }
  if (extension === 'csv') {
    return 'text/csv';
  }
  if (extension === 'html' || extension === 'htm') {
    return 'text/html';
  }
  if (extension === 'epub') {
    return 'application/epub+zip';
  }
  if (extension === 'doc') {
    return 'application/msword';
  }
  if (extension === 'docx') {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  return 'application/octet-stream';
}

function guessPreviewMode(extension: string): LocalPreviewMode {
  if (extension === 'txt' || extension === 'md' || extension === 'markdown' || extension === 'json' || extension === 'csv') {
    return 'text';
  }
  return 'external';
}

function sourceTypeForExtension(extension: string): string {
  if (extension === 'epub') {
    return 'local_epub';
  }
  return 'local_txt';
}

function canImportToBackend(extension: string): boolean {
  return extension === 'txt' || extension === 'md' || extension === 'markdown' || extension === 'epub';
}

function historyTone(sourceType: ShelfSourceType, accent: string): string {
  if (sourceType === 'local') {
    return '#EEF4FF';
  }
  if (accent === 'history') {
    return '#FFF3EC';
  }
  return '#EEF1FF';
}

function clampProgress(value: number | undefined): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return 0;
  }
  if (value < 0) {
    return 0;
  }
  if (value > 100) {
    return 100;
  }
  return Math.floor(value);
}

function clampPositiveInteger(value: number): number {
  if (!Number.isFinite(value) || value <= 0) {
    return 0;
  }
  return Math.floor(value);
}

function normalizeTodayReading(raw: TodayReadingState | undefined): TodayReadingState {
  const currentKey: string = todayKey();
  if (!raw || typeof raw !== 'object') {
    return {
      dateKey: currentKey,
      seconds: 0,
    };
  }
  if (normalizeText(raw.dateKey) !== currentKey) {
    return {
      dateKey: currentKey,
      seconds: 0,
    };
  }
  return {
    dateKey: currentKey,
    seconds: clampPositiveInteger(raw.seconds),
  };
}

function parseState(raw: string): ShelfStoreState {
  if (!raw) {
    return emptyState();
  }
  try {
    const parsed = JSON.parse(raw) as ShelfStoreState;
    if (!parsed || typeof parsed !== 'object') {
      return emptyState();
    }
    return {
      remoteSessions: Array.isArray(parsed.remoteSessions) ? parsed.remoteSessions : [],
      localBooks: Array.isArray(parsed.localBooks) ? parsed.localBooks : [],
      browseHistory: Array.isArray(parsed.browseHistory) ? parsed.browseHistory : [],
      hiddenRemoteBookIds: Array.isArray(parsed.hiddenRemoteBookIds) ? parsed.hiddenRemoteBookIds : [],
      pinnedSourceKeys: Array.isArray(parsed.pinnedSourceKeys) ? parsed.pinnedSourceKeys : [],
      downloadedRemoteBookIds: Array.isArray(parsed.downloadedRemoteBookIds) ? parsed.downloadedRemoteBookIds : [],
      todayReading: normalizeTodayReading(parsed.todayReading),
    };
  } catch (_) {
    return emptyState();
  }
}

function nextLocalKey(): string {
  return `local-${Date.now()}-${Math.floor(Math.random() * 100000)}`;
}

export class ShelfStore {
  private static async preferences(context: common.UIAbilityContext): Promise<preferences.Preferences> {
    return await preferences.getPreferences(context, SHELF_PREFERENCES_NAME);
  }

  private static stateKey(userId: number = UserSession.currentUserId()): string {
    return stateKeyForUser(userId);
  }

  static async load(context: common.UIAbilityContext, userId: number = UserSession.currentUserId()): Promise<ShelfStoreState> {
    const prefs = await ShelfStore.preferences(context);
    let raw = await prefs.get(ShelfStore.stateKey(userId), '') as string;
    if (!raw && userId === 10086) {
      raw = await prefs.get(SHELF_STATE_KEY, '') as string;
    }
    return parseState(raw);
  }

  private static async save(
    context: common.UIAbilityContext,
    state: ShelfStoreState,
    userId: number = UserSession.currentUserId()
  ): Promise<void> {
    const prefs = await ShelfStore.preferences(context);
    await prefs.put(ShelfStore.stateKey(userId), JSON.stringify(state));
    await prefs.flush();
  }

  static async recordRemoteBrowse(context: common.UIAbilityContext, payload: RemoteBrowsePayload): Promise<void> {
    const userId: number = UserSession.currentUserId();
    const state = await ShelfStore.load(context, userId);
    const updatedAt: string = payload.updatedAt || nowIso();
    const sourceKey: string = `remote:${payload.bookId}`;
    const historyKey: string = `history:${sourceKey}`;
    const nextRecord: ShelfHistoryRecord = {
      key: historyKey,
      sourceType: 'remote',
      sourceKey,
      title: payload.title,
      subtitle: normalizeText(payload.author) || '云端图书',
      actionText: normalizeText(payload.actionText) || '查看图书',
      updatedAt,
      coverTone: historyTone('remote', 'history'),
      tags: normalizeText(payload.tags),
      difficulty: normalizeText(payload.difficulty),
      coverColor: normalizeText(payload.coverColor),
      remoteBookId: payload.bookId,
    };
    let replaced: boolean = false;
    const nextHistory: ShelfHistoryRecord[] = [];
    for (let i = 0; i < state.browseHistory.length; i++) {
      const current = state.browseHistory[i];
      if (current.key === historyKey) {
        nextHistory.push(nextRecord);
        replaced = true;
      } else {
        nextHistory.push(current);
      }
    }
    if (!replaced) {
      nextHistory.unshift(nextRecord);
    }
    state.browseHistory = ensureHistorySize(nextHistory);
    await ShelfStore.save(context, state, userId);
  }

  static async recordRemoteReading(context: common.UIAbilityContext, payload: RemoteReadingPayload): Promise<void> {
    const userId: number = UserSession.currentUserId();
    const state = await ShelfStore.load(context, userId);
    const updatedAt: string = payload.updatedAt || nowIso();
    const sourceKey: string = `remote:${payload.bookId}`;
    const nextSession: RemoteShelfSession = {
      key: sourceKey,
      bookId: payload.bookId,
      title: payload.title,
      author: payload.author,
      tags: normalizeText(payload.tags),
      difficulty: normalizeText(payload.difficulty),
      chapterId: normalizeText(payload.chapterId),
      chapterTitle: normalizeText(payload.chapterTitle),
      progress: clampProgress(payload.progress),
      updatedAt,
      coverColor: normalizeText(payload.coverColor),
    };

    const nextSessions: RemoteShelfSession[] = [];
    let replaced: boolean = false;
    for (let i = 0; i < state.remoteSessions.length; i++) {
      const current = state.remoteSessions[i];
      if (current.bookId === payload.bookId) {
        nextSessions.push(nextSession);
        replaced = true;
      } else {
        nextSessions.push(current);
      }
    }
    if (!replaced) {
      nextSessions.unshift(nextSession);
    }
    nextSessions.sort((left: RemoteShelfSession, right: RemoteShelfSession) => {
      return right.updatedAt.localeCompare(left.updatedAt);
    });
    state.remoteSessions = nextSessions;

    const nextHiddenIds: number[] = [];
    for (let i = 0; i < state.hiddenRemoteBookIds.length; i++) {
      if (state.hiddenRemoteBookIds[i] !== payload.bookId) {
        nextHiddenIds.push(state.hiddenRemoteBookIds[i]);
      }
    }
    state.hiddenRemoteBookIds = nextHiddenIds;

    await ShelfStore.recordRemoteBrowse(context, {
      bookId: payload.bookId,
      title: payload.title,
      author: payload.author,
      tags: payload.tags,
      difficulty: payload.difficulty,
      coverColor: payload.coverColor,
      actionText: payload.chapterTitle ? `阅读到 ${payload.chapterTitle}` : '开始阅读',
      updatedAt,
    });

    state.browseHistory = (await ShelfStore.load(context, userId)).browseHistory;
    await ShelfStore.save(context, state, userId);
  }

  static async importLocalBooks(context: common.UIAbilityContext, sourceUris: string[]): Promise<LocalBookImportResult> {
    const userId: number = UserSession.currentUserId();
    const state = await ShelfStore.load(context, userId);
    const importDir: string = `${context.filesDir}/${SHELF_IMPORT_DIR}`;
    try {
      await fileIo.mkdir(importDir, true);
    } catch (_) {
    }

    const imported: LocalShelfBook[] = [];
    const skipped: LocalShelfBook[] = [];

    for (let i = 0; i < sourceUris.length; i++) {
      const sourceUri: string = sourceUris[i];
      try {
        const sourceFile = new fileUri.FileUri(sourceUri);
        const safeName: string = sanitizeFileName(sourceFile.name || `book-${Date.now()}.bin`);
        const extension: string = lowerExtension(safeName);
        if (!canImportToBackend(extension)) {
          throw new Error('当前仅支持 TXT/MD 和 EPUB 入库解析；PDF/DOCX 暂不做静默导入。');
        }
        let existed: LocalShelfBook | null = null;
        for (let index = 0; index < state.localBooks.length; index++) {
          if (state.localBooks[index].displayName === safeName) {
            existed = state.localBooks[index];
            break;
          }
        }
        if (existed) {
          skipped.push(existed);
          continue;
        }

        const uniqueName: string = `${Date.now()}-${i}-${safeName}`;
        const destinationPath: string = `${importDir}/${uniqueName}`;
        const destinationUri: string = fileUri.getUriFromPath(destinationPath);
        await fileIo.copy(sourceUri, destinationUri);
        const importResult = await ShelfStore.importLocalBookToBackend(userId, safeName, extension, destinationPath);
        const remoteBookId: number = importResult.bookId || importResult.book_id || 0;
        const nextBook: LocalShelfBook = {
          key: nextLocalKey(),
          remoteBookId,
          title: baseTitle(safeName),
          displayName: safeName,
          extension,
          fileType: guessLocalFileType(extension),
          uri: destinationUri,
          path: destinationPath,
          importedAt: nowIso(),
          lastOpenedAt: '',
          openCount: 0,
          previewMode: guessPreviewMode(extension),
        };
        state.localBooks.unshift(nextBook);
        if (remoteBookId > 0) {
          state.remoteSessions.unshift({
            key: `remote:${remoteBookId}`,
            bookId: remoteBookId,
            title: nextBook.title,
            author: '本地导入',
            tags: '本地导入,可读,AI伴读',
            difficulty: '本地导入',
            chapterId: '',
            chapterTitle: '',
            progress: 0,
            updatedAt: nextBook.importedAt,
            coverColor: '#EEF4FF',
          });
        }
        imported.push(nextBook);
      } catch (err) {
        throw new Error(`导入 ${sourceUri} 失败：${err}`);
      }
    }

    for (let i = 0; i < imported.length; i++) {
      const item = imported[i];
      state.browseHistory.unshift({
        key: `history:${item.key}`,
        sourceType: 'local',
        sourceKey: item.key,
        title: item.title,
        subtitle: item.displayName,
        actionText: '导入到本地书架',
        updatedAt: item.importedAt,
        coverTone: historyTone('local', 'import'),
        remoteBookId: item.remoteBookId,
        localBookKey: item.key,
      });
    }
    state.browseHistory = ensureHistorySize(state.browseHistory);
    await ShelfStore.save(context, state, userId);
    return { imported, skipped };
  }

  private static async importLocalBookToBackend(
    userId: number,
    fileName: string,
    extension: string,
    path: string
  ): Promise<ImportBookResult> {
    const sourceType: string = sourceTypeForExtension(extension);
    if (sourceType === 'local_epub') {
      const base64: string = ShelfStore.readFileAsBase64(path);
      return await ApiClient.importBook(userId, fileName, sourceType, '', base64);
    }
    const content: string = fileIo.readTextSync(path);
    return await ApiClient.importBook(userId, fileName, sourceType, content, '');
  }

  private static readFileAsBase64(path: string): string {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(path);
      const size = Number(stat.size);
      const data = new ArrayBuffer(size);
      fileIo.readSync(file.fd, data);
      const helper = new util.Base64Helper();
      return helper.encodeToStringSync(new Uint8Array(data));
    } finally {
      fileIo.closeSync(file);
    }
  }

  static async openLocalBook(context: common.UIAbilityContext, bookKey: string): Promise<LocalShelfBook> {
    const userId: number = UserSession.currentUserId();
    const state = await ShelfStore.load(context, userId);
    let target: LocalShelfBook | null = null;
    for (let i = 0; i < state.localBooks.length; i++) {
      if (state.localBooks[i].key === bookKey) {
        state.localBooks[i].lastOpenedAt = nowIso();
        state.localBooks[i].openCount = state.localBooks[i].openCount + 1;
        target = state.localBooks[i];
        break;
      }
    }
    if (!target) {
      throw new Error('本地书籍不存在或已被移除');
    }

    const historyKey: string = `history:${bookKey}`;
    const nextRecord: ShelfHistoryRecord = {
      key: historyKey,
      sourceType: 'local',
      sourceKey: bookKey,
      title: target.title,
      subtitle: target.displayName,
      actionText: '打开本地文件',
      updatedAt: target.lastOpenedAt,
      coverTone: historyTone('local', 'open'),
      localBookKey: target.key,
    };

    const nextHistory: ShelfHistoryRecord[] = [];
    let replaced: boolean = false;
    for (let i = 0; i < state.browseHistory.length; i++) {
      const current = state.browseHistory[i];
      if (current.key === historyKey) {
        nextHistory.push(nextRecord);
        replaced = true;
      } else {
        nextHistory.push(current);
      }
    }
    if (!replaced) {
      nextHistory.unshift(nextRecord);
    }
    state.browseHistory = ensureHistorySize(nextHistory);
    await ShelfStore.save(context, state, userId);

    if (target.remoteBookId && target.remoteBookId > 0) {
      return target;
    }

    const openWant: Want = {
      action: 'ohos.want.action.viewData',
      uri: target.uri,
      type: target.fileType,
      flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION,
    };
    await context.startAbility(openWant);
    return target;
  }

  static async deleteHistoryRecords(context: common.UIAbilityContext, historyKeys: string[]): Promise<void> {
    const userId: number = UserSession.currentUserId();
    const state = await ShelfStore.load(context, userId);
    const nextHistory: ShelfHistoryRecord[] = [];
    for (let i = 0; i < state.browseHistory.length; i++) {
      let shouldDelete: boolean = false;
      for (let index = 0; index < historyKeys.length; index++) {
        if (state.browseHistory[i].key === historyKeys[index]) {
          shouldDelete = true;
          break;
        }
      }
      if (!shouldDelete) {
        nextHistory.push(state.browseHistory[i]);
      }
    }
    state.browseHistory = nextHistory;
    await ShelfStore.save(context, state, userId);
  }

  static async restoreHistoryBookToShelf(context: common.UIAbilityContext, historyKey: string): Promise<void> {
    const userId: number = UserSession.currentUserId();
    const state = await ShelfStore.load(context, userId);
    let target: ShelfHistoryRecord | null = null;
    for (let i = 0; i < state.browseHistory.length; i++) {
      if (state.browseHistory[i].key === historyKey) {
        target = state.browseHistory[i];
        break;
      }
    }
    if (!target) {
      throw new Error('未找到对应的浏览记录');
    }
    if (target.sourceType !== 'remote' || !target.remoteBookId) {
      return;
    }

    const updatedAt: string = nowIso();
    const nextSession: RemoteShelfSession = {
      key: `remote:${target.remoteBookId}`,
      bookId: target.remoteBookId,
      title: target.title,
      author: target.subtitle,
      tags: normalizeText(target.tags),
      difficulty: normalizeText(target.difficulty),
      chapterId: '',
      chapterTitle: '',
      progress: 0,
      updatedAt,
      coverColor: normalizeText(target.coverColor),
    };

    const nextSessions: RemoteShelfSession[] = [];
    let replaced: boolean = false;
    for (let i = 0; i < state.remoteSessions.length; i++) {
      if (state.remoteSessions[i].bookId === target.remoteBookId) {
        const current: RemoteShelfSession = state.remoteSessions[i];
        const mergedSession: RemoteShelfSession = {
          key: current.key,
          bookId: current.bookId,
          title: current.title,
          author: current.author,
          tags: current.tags || nextSession.tags,
          difficulty: current.difficulty || nextSession.difficulty,
          chapterId: current.chapterId,
          chapterTitle: current.chapterTitle,
          progress: current.progress,
          updatedAt,
          coverColor: current.coverColor || nextSession.coverColor,
        };
        nextSessions.push(mergedSession);
        replaced = true;
      } else {
        nextSessions.push(state.remoteSessions[i]);
      }
    }
    if (!replaced) {
      nextSessions.unshift(nextSession);
    }
    state.remoteSessions = nextSessions;

    const nextHiddenIds: number[] = [];
    for (let i = 0; i < state.hiddenRemoteBookIds.length; i++) {
      if (state.hiddenRemoteBookIds[i] !== target.remoteBookId) {
        nextHiddenIds.push(state.hiddenRemoteBookIds[i]);
      }
    }
    state.hiddenRemoteBookIds = nextHiddenIds;
    await ShelfStore.save(context, state, userId);
  }

  static async pinShelfItems(context: common.UIAbilityContext, sourceKeys: string[]): Promise<void> {
    const userId: number = UserSession.currentUserId();
    const state = await ShelfStore.load(context, userId);
    state.pinnedSourceKeys = sourceKeys.filter((key: string) => !!key);
    await ShelfStore.save(context, state, userId);
  }

  static async markRemoteBooksDownloaded(context: common.UIAbilityContext, bookIds: number[]): Promise<void> {
    const userId: number = UserSession.currentUserId();
    const state = await ShelfStore.load(context, userId);
    const nextIds: number[] = state.downloadedRemoteBookIds.slice();
    for (let i = 0; i < bookIds.length; i++) {
      const bookId: number = bookIds[i];
      if (bookId > 0 && !nextIds.includes(bookId)) {
        nextIds.push(bookId);
      }
    }
    state.downloadedRemoteBookIds = nextIds;
    await ShelfStore.save(context, state, userId);
  }

  static async addTodayReadingDuration(
    context: common.UIAbilityContext,
    startedAtMs: number,
    endedAtMs: number = Date.now()
  ): Promise<number> {
    const userId: number = UserSession.currentUserId();
    const safeEnd: number = Number.isFinite(endedAtMs) ? endedAtMs : Date.now();
    const safeStart: number = Number.isFinite(startedAtMs) ? startedAtMs : safeEnd;
    if (safeEnd <= safeStart) {
      const currentState = await ShelfStore.load(context, userId);
      return currentState.todayReading.seconds;
    }

    const state = await ShelfStore.load(context, userId);
    const todayStart: Date = new Date(safeEnd);
    todayStart.setHours(0, 0, 0, 0);
    const overlapStart: number = Math.max(safeStart, todayStart.getTime());
    const overlapSeconds: number = clampPositiveInteger((safeEnd - overlapStart) / 1000);
    state.todayReading = normalizeTodayReading(state.todayReading);
    state.todayReading.seconds = state.todayReading.seconds + overlapSeconds;
    await ShelfStore.save(context, state, userId);
    return state.todayReading.seconds;
  }

  static async removeFromShelf(context: common.UIAbilityContext, sourceKeys: string[]): Promise<void> {
    const userId: number = UserSession.currentUserId();
    const state = await ShelfStore.load(context, userId);
    const nextRemoteSessions: RemoteShelfSession[] = [];
    const nextLocalBooks: LocalShelfBook[] = [];
    const nextHistory: ShelfHistoryRecord[] = [];
    const nextHiddenIds: number[] = state.hiddenRemoteBookIds.slice();

    for (let i = 0; i < state.remoteSessions.length; i++) {
      let shouldRemove: boolean = false;
      for (let index = 0; index < sourceKeys.length; index++) {
        if (state.remoteSessions[i].key === sourceKeys[index]) {
          shouldRemove = true;
          if (!nextHiddenIds.includes(state.remoteSessions[i].bookId)) {
            nextHiddenIds.push(state.remoteSessions[i].bookId);
          }
          break;
        }
      }
      if (!shouldRemove) {
        nextRemoteSessions.push(state.remoteSessions[i]);
      }
    }

    for (let i = 0; i < state.localBooks.length; i++) {
      let shouldRemove: boolean = false;
      for (let index = 0; index < sourceKeys.length; index++) {
        if (state.localBooks[i].key === sourceKeys[index]) {
          shouldRemove = true;
          break;
        }
      }
      if (!shouldRemove) {
        nextLocalBooks.push(state.localBooks[i]);
      }
    }

    for (let i = 0; i < state.browseHistory.length; i++) {
      let shouldRemove: boolean = false;
      for (let index = 0; index < sourceKeys.length; index++) {
        if (state.browseHistory[i].sourceKey === sourceKeys[index] && state.browseHistory[i].sourceType === 'local') {
          shouldRemove = true;
          break;
        }
      }
      if (!shouldRemove) {
        nextHistory.push(state.browseHistory[i]);
      }
    }

    const nextPinnedKeys: string[] = [];
    for (let i = 0; i < state.pinnedSourceKeys.length; i++) {
      let shouldRemove: boolean = false;
      for (let index = 0; index < sourceKeys.length; index++) {
        if (state.pinnedSourceKeys[i] === sourceKeys[index]) {
          shouldRemove = true;
          break;
        }
      }
      if (!shouldRemove) {
        nextPinnedKeys.push(state.pinnedSourceKeys[i]);
      }
    }

    const nextDownloadedIds: number[] = [];
    for (let i = 0; i < state.downloadedRemoteBookIds.length; i++) {
      let shouldRemove: boolean = false;
      for (let index = 0; index < sourceKeys.length; index++) {
        if (sourceKeys[index] === `remote:${state.downloadedRemoteBookIds[i]}`) {
          shouldRemove = true;
          break;
        }
      }
      if (!shouldRemove) {
        nextDownloadedIds.push(state.downloadedRemoteBookIds[i]);
      }
    }

    state.remoteSessions = nextRemoteSessions;
    state.localBooks = nextLocalBooks;
    state.browseHistory = nextHistory;
    state.hiddenRemoteBookIds = nextHiddenIds;
    state.pinnedSourceKeys = nextPinnedKeys;
    state.downloadedRemoteBookIds = nextDownloadedIds;
    await ShelfStore.save(context, state, userId);
  }
}
