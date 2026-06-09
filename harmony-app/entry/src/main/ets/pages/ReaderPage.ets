import { ApiClient, ChatResult, ToolTrace } from '../common/ApiClient';
import {
  APP_DARK_MODE_KEY,
  APP_FONT_FAMILY_KEY,
  APP_ONE_HAND_MODE_KEY,
  APP_READER_PAGE_MODE_KEY,
  APP_SCRIPT_VARIANT_KEY,
  APP_VOLUME_PAGE_TURN_KEY,
  AppSettings,
} from '../common/AppSettings';
import { AiResponseView } from '../common/AiResponseView';
import {
  BookmarkItem,
  Book,
  PlanItem,
  ReaderBundle,
  ReaderComment,
  ReaderHighlight,
  ReadingChapter,
  ReadingContent,
  SourceRef,
  emptyReaderBundle,
} from '../common/Models';
import { currentBookId, currentChapterId, goBack, notifyPlanDataChanged, notifyPlanProgressChanged } from '../common/Navigation';
import { finishReadingSession, setReadingSession } from '../common/ReaderSession';
import { ShelfStore } from '../common/ShelfStore';
import { UserSession } from '../common/UserSession';
import { common } from '@kit.AbilityKit';

class ReadingThemeDef {
  name: string = '';
  bg: string = '';
  text: string = '';
  secondary: string = '';
  barBg: string = '';
  barText: string = '';
  divider: string = '';
  accent: string = '';
}

class ParagraphUnit {
  paragraphIndex: number = 0;
  text: string = '';
  startOffset: number = 0;
  endOffset: number = 0;
}

class TextRun {
  text: string = '';
  highlighted: boolean = false;
  selected: boolean = false;
}

class HighlightRange {
  start: number = 0;
  end: number = 0;
}

class AutoReadSpeedDef {
  label: string = '';
  seconds: number = 0;
}

class PageCurlMetrics {
  progress: number = 0;
  foldWidth: number = 0;
  foldX: number = 0;
  cornerY: number = 0;
  rotateY: number = 0;
  rotateZ: number = 0;
  depth: number = 0;
  thickness: number = 0;
  shadowWidth: number = 0;
  shadowAlpha: number = 0;
  highlightAlpha: number = 0;
  scaleY: number = 1;
  curvePath: string = '';
}

function makeTheme(name: string, bg: string, text: string, secondary: string, barBg: string, barText: string, divider: string, accent: string): ReadingThemeDef {
  const t = new ReadingThemeDef();
  t.name = name; t.bg = bg; t.text = text; t.secondary = secondary;
  t.barBg = barBg; t.barText = barText; t.divider = divider; t.accent = accent;
  return t;
}

function makeAutoSpeed(label: string, seconds: number): AutoReadSpeedDef {
  const speed = new AutoReadSpeedDef();
  speed.label = label;
  speed.seconds = seconds;
  return speed;
}

function makeParagraphUnit(paragraphIndex: number, text: string, startOffset: number = 0): ParagraphUnit {
  const unit = new ParagraphUnit();
  unit.paragraphIndex = paragraphIndex;
  unit.text = text;
  unit.startOffset = Math.max(0, startOffset);
  unit.endOffset = unit.startOffset + text.length;
  return unit;
}

function makeTextRun(text: string, highlighted: boolean = false, selected: boolean = false): TextRun {
  const run = new TextRun();
  run.text = text;
  run.highlighted = highlighted;
  run.selected = selected;
  return run;
}

function makeHighlightRange(start: number, end: number): HighlightRange {
  const range = new HighlightRange();
  range.start = start;
  range.end = end;
  return range;
}

function clampNumber(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function twoDigits(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

const THEME_PARCHMENT = makeTheme('羊皮纸', '#F5F0E8', '#3C3028', '#8B7D6B', '#EDE6D8', '#5C4A38', '#D4C8B0', '#B8860B');
const THEME_LIGHT = makeTheme('纯白', '#F8F8F8', '#222222', '#999999', '#EEEEEE', '#333333', '#E0E0E0', '#4A90D9');
const THEME_DARK = makeTheme('夜间', '#1A1A1E', '#D5D2CC', '#868078', '#252528', '#D5D2CC', '#393A3D', '#7FA8D8');
const THEME_GREEN = makeTheme('护眼', '#C8DABC', '#3A4A32', '#6B7D5E', '#B8CCAA', '#3A4A32', '#A0B896', '#5A7A4A');

const ALL_THEME_KEYS: string[] = ['parchment', 'light', 'dark', 'green'];
const FONT_SIZES: number[] = [15, 17, 19, 21, 24];
const LINE_SPACINGS: number[] = [1.5, 1.7, 1.9, 2.1, 2.4];
const BRIGHTNESS_STEPS: number[] = [0.3, 0.45, 0.6, 0.75, 0.9, 1.0];
const AUTO_READ_SPEEDS: AutoReadSpeedDef[] = [
  makeAutoSpeed('慢', 24),
  makeAutoSpeed('中', 14),
  makeAutoSpeed('快', 7),
];
const PAGE_CURL_ANIMATION_MS: number = 680;
const TOOLBAR_TAP_GUARD_MS: number = 420;
const AUTO_READ_TOUCH_GUARD_MS: number = 360;

@Entry
@Component
struct ReaderPage {
  @State bookId: number = 0;
  @State chapterId: string = '';
  @State bundle: ReaderBundle = emptyReaderBundle();
  @State content: ReadingContent | null = null;
  @State chapters: ReadingChapter[] = [];
  @State bookmarks: BookmarkItem[] = [];
  @State progress: number = 0;
  @State busyText: string = '';
  @State errorText: string = '';

  @State showCatalog: boolean = false;
  @State showSettings: boolean = false;
  @State catalogSheetProgress: number = 0;
  @State settingsSheetProgress: number = 0;
  @State barsVisible: boolean = false;
  @State toolbarProgress: number = 0;
  @State themeKey: string = 'parchment';
  @State fontSizeIdx: number = 1;
  @State lineSpacingIdx: number = 1;
  @State brightnessIdx: number = 3;
  @State autoReadActive: boolean = false;
  @State autoReadSpeedIdx: number = 1;

  @State pageW: number = 390;
  @State pageH: number = 780;
  @State pageIndex: number = 0;
  @State curlActive: boolean = false;
  @State curlProgress: number = 0;
  @State curlDirection: number = 1;
  @State curlDragging: boolean = false;
  @State curlTouchCount: number = 1;
  @State selectedParagraphIndex: number = -1;
  @State selectedChapterId: string = '';
  @State selectedParagraphTextValue: string = '';
  @State selectedStartOffset: number = 0;
  @State selectedEndOffset: number = 0;
  @State readerHighlights: ReaderHighlight[] = [];
  @State markedParagraphIndexes: number[] = [];
  @State showParagraphToolbar: boolean = false;
  @State showShareSheet: boolean = false;
  @State showCommentSheet: boolean = false;
  @State readerComments: ReaderComment[] = [];
  @State commentInput: string = '';
  @State commentBusy: boolean = false;
  @State commentError: string = '';
  @State shareHint: string = '';
  @State showAiSheet: boolean = false;
  @State aiSheetProgress: number = 0;
  @State aiQuestion: string = '';
  @State aiAnswer: string = '';
  @State aiReasoning: string = '';
  @State aiFollowUp: string = '';
  @State aiSources: SourceRef[] = [];
  @State aiToolTrace: ToolTrace[] = [];
  @State aiStatusText: string = '';
  @State aiBusy: boolean = false;
  @State aiError: string = '';
  @State scrollContents: ReadingContent[] = [];
  @State scrollLoading: boolean = false;
  @StorageLink(APP_DARK_MODE_KEY) @Watch('onGlobalDarkModeChange') appDarkMode: boolean = false;
  @StorageLink(APP_ONE_HAND_MODE_KEY) oneHandMode: boolean = false;
  @StorageLink(APP_VOLUME_PAGE_TURN_KEY) volumePageTurn: boolean = false;
  @StorageLink(APP_READER_PAGE_MODE_KEY) @Watch('onReaderPageModeChange') pageMode: string = 'scroll';
  @StorageLink(APP_FONT_FAMILY_KEY) appFontFamily: string = 'system';
  @StorageLink(APP_SCRIPT_VARIANT_KEY) scriptVariant: string = 'simplified';

  private readerScroller: Scroller = new Scroller();
  private catalogScroller: Scroller = new Scroller();
  private catalogDragBaseOffset: number = 0;
  private readingDurationFlushed: boolean = false;
  private autoReadTimer: number = -1;
  private curlCommitTimer: number = -1;
  private contentTapGuardTimer: number = -1;
  private scrollProgressSyncTimer: number = -1;
  private catalogSheetTimer: number = -1;
  private settingsSheetTimer: number = -1;
  private aiSheetTimer: number = -1;
  private toolbarTimer: number = -1;
  private ignoreNextContentTap: boolean = false;
  private lastSyncedProgressKey: string = '';
  private lastScrollProgressSyncKey: string = '';
  private lastChapterEndSyncKey: string = '';
  private visibleScrollChapterIndex: number = 0;
  private scrollBaseChapterIndex: number = 0;
  private chapterLoading: boolean = false;

  aboutToAppear(): void {
    AppSettings.ensureDefaults();
    this.readingDurationFlushed = false;
    this.bookId = currentBookId();
    this.chapterId = currentChapterId();
    this.syncThemeFromGlobal();
    this.loadReader();
  }

  onPageHide(): void {
    this.flushReadingDuration();
    this.stopAutoRead();
    this.resetCurl();
    clearTimeout(this.scrollProgressSyncTimer);
    clearTimeout(this.catalogSheetTimer);
    clearTimeout(this.settingsSheetTimer);
    clearTimeout(this.aiSheetTimer);
    clearTimeout(this.toolbarTimer);
    this.scrollProgressSyncTimer = -1;
    this.catalogSheetTimer = -1;
    this.settingsSheetTimer = -1;
    this.aiSheetTimer = -1;
    this.toolbarTimer = -1;
  }

  aboutToDisappear(): void {
    this.flushReadingDuration();
    this.stopAutoRead();
    this.resetCurl();
    clearTimeout(this.scrollProgressSyncTimer);
    clearTimeout(this.catalogSheetTimer);
    clearTimeout(this.settingsSheetTimer);
    clearTimeout(this.aiSheetTimer);
    clearTimeout(this.toolbarTimer);
    this.scrollProgressSyncTimer = -1;
    this.catalogSheetTimer = -1;
    this.settingsSheetTimer = -1;
    this.aiSheetTimer = -1;
    this.toolbarTimer = -1;
  }

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  onGlobalDarkModeChange(): void {
    this.syncThemeFromGlobal();
  }

  onReaderPageModeChange(): void {
    const normalized: string = AppSettings.normalizeReaderPageMode(this.pageMode);
    if (normalized !== this.pageMode) {
      this.pageMode = normalized;
      return;
    }
    this.resetPaging();
    if (this.pageMode === 'scroll') {
      void this.loadScrollContents(this.chapterId);
    }
  }

  syncThemeFromGlobal(): void {
    if (this.appDarkMode && this.themeKey !== 'dark') {
      this.themeKey = 'dark';
    } else if (!this.appDarkMode && this.themeKey === 'dark') {
      this.themeKey = 'parchment';
    }
  }

  appFont(): string {
    return AppSettings.fontFamilyValue(this.appFontFamily);
  }

  scriptText(text: string): string {
    return AppSettings.scriptText(text, this.scriptVariant);
  }

  async selectTheme(k: string): Promise<void> {
    this.themeKey = k;
    if (k === 'dark' && !this.appDarkMode) {
      await AppSettings.setDarkMode(this.hostContext(), true);
    } else if (k !== 'dark' && this.appDarkMode) {
      await AppSettings.setDarkMode(this.hostContext(), false);
    }
  }

  async toggleNightTheme(): Promise<void> {
    const nextDark = this.themeKey !== 'dark';
    animateTo({ duration: 320, curve: Curve.EaseInOut }, () => {
      this.appDarkMode = nextDark;
      this.themeKey = nextDark ? 'dark' : 'parchment';
    });
    await AppSettings.setDarkMode(this.hostContext(), nextDark);
  }

  async setReaderMode(mode: string): Promise<void> {
    const nextMode: string = AppSettings.normalizeReaderPageMode(mode);
    if (nextMode === this.pageMode) {
      return;
    }
    this.stopAutoRead();
    this.pageMode = nextMode;
    this.resetPaging();
    if (nextMode === 'scroll') {
      await this.loadScrollContents(this.chapterId);
    }
    await AppSettings.setReaderPageMode(this.hostContext(), nextMode);
  }

  handleVolumeKey(event: KeyEvent): void {
    if (!this.volumePageTurn || this.pageMode !== 'page' || event.type !== KeyType.Down) {
      return;
    }
    const code: number = event.keyCode;
    if (code === 16 || code === 24) {
      this.stopAutoRead();
      this.turnPrevPage();
      return;
    }
    if (code === 17 || code === 25) {
      this.stopAutoRead();
      this.turnNextPage();
    }
  }

  async flushReadingDuration(): Promise<void> {
    if (this.readingDurationFlushed) return;
    const ctx = this.hostContext();
    const range = finishReadingSession();
    this.readingDurationFlushed = true;
    if (!range) return;
    const userId: number = UserSession.currentUserId();
    const durationSeconds: number = Math.max(0, Math.floor((range.endedAtMs - range.startedAtMs) / 1000));
    if (ctx) {
      try {
        const todaySeconds: number = await ShelfStore.addTodayReadingDuration(ctx, range.startedAtMs, range.endedAtMs);
        if (userId > 0) {
          const currentStatsUserId: number = AppStorage.get<number>('smartread_reading_stats_user_id') || 0;
          const currentWeekSeconds: number = currentStatsUserId === userId
            ? Math.max(0, Math.round(AppStorage.get<number>('smartread_week_reading_seconds') || 0))
            : 0;
          AppStorage.setOrCreate('smartread_reading_stats_user_id', userId);
          AppStorage.setOrCreate('smartread_today_reading_seconds', todaySeconds);
          AppStorage.setOrCreate('smartread_week_reading_seconds', Math.max(todaySeconds, currentWeekSeconds + durationSeconds));
          notifyPlanDataChanged();
        }
      } catch (_) {}
    }
    if (userId > 0 && durationSeconds > 0) {
      try {
        await ApiClient.trackEvent({
          user_id: userId,
          event_type: 'READING_SESSION_END',
          book_id: this.bookId,
          chapter_id: this.chapterId,
          duration_seconds: durationSeconds,
          progress: this.progress,
        });
      } catch (_) {}
    }
  }

  async syncShelfTrace(book: Book, chId: string, chTitle: string, prog: number): Promise<void> {
    const ctx = this.hostContext();
    if (!ctx || book.id <= 0) return;
    try {
      await ShelfStore.recordRemoteReading(ctx, {
        bookId: book.id, title: book.title, author: book.author,
        tags: book.tags, difficulty: book.difficulty, coverColor: book.coverColor,
        chapterId: chId, chapterTitle: chTitle, progress: prog,
      });
    } catch (_) {}
  }

  async syncBackendProgress(chId: string, prog: number, scrollOffset: number = 0): Promise<void> {
    const plan = this.bundle.plan;
    if (!plan || plan.id <= 0) {
      return;
    }
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      return;
    }
    const status: string = prog >= 100 ? 'finished' : 'reading';
    const syncKey: string = `${plan.id}:${chId}:${Math.round(prog)}:${scrollOffset}:${status}`;
    if (syncKey === this.lastSyncedProgressKey) {
      return;
    }
    this.lastSyncedProgressKey = syncKey;
    try {
      await ApiClient.updatePlanProgress(userId, plan.id, this.bookId, chId, prog, scrollOffset, status);
      notifyPlanProgressChanged(this.bookId, prog, chId, scrollOffset, status);
      this.bundle.plan = {
        id: plan.id,
        bookId: plan.bookId,
        title: plan.title,
        author: plan.author,
        targetDays: plan.targetDays,
        dailyMinutesTarget: plan.dailyMinutesTarget,
        weeklyMinutesTarget: plan.weeklyMinutesTarget,
        progress: prog,
        status,
        chapterId: chId,
        scrollOffset,
        createdAt: plan.createdAt,
        updatedAt: new Date().toISOString(),
        completedAt: prog >= 100 ? new Date().toISOString() : '',
        completedDates: plan.completedDates,
        coverColor: plan.coverColor,
      };
    } catch (_) {
    }
  }

  async syncReadingState(chId: string, chTitle: string, prog: number, scrollOffset: number = 0): Promise<void> {
    setReadingSession(this.bookId, chId, prog, scrollOffset);
    await this.syncBackendProgress(chId, prog, scrollOffset);
    await this.syncShelfTrace(this.bundle.book, chId, chTitle, prog);
  }

  currentScrollOffset(): number {
    try {
      const offset = this.readerScroller.currentOffset();
      if (!offset || typeof offset.yOffset !== 'number') {
        return 0;
      }
      return Math.max(0, Math.round(Math.abs(offset.yOffset)));
    } catch (_) {
      return 0;
    }
  }

  currentCatalogOffset(): number {
    try {
      const offset = this.catalogScroller.currentOffset();
      if (!offset || typeof offset.yOffset !== 'number') {
        return 0;
      }
      return Math.max(0, Math.round(Math.abs(offset.yOffset)));
    } catch (_) {
      return 0;
    }
  }

  chapterIndexForId(chId: string): number {
    for (let i = 0; i < this.chapters.length; i++) {
      if (this.chKey(this.chapters[i]) === chId) {
        return i;
      }
    }
    return -1;
  }

  chapterWeightAt(index: number): number {
    if (index < 0 || index >= this.chapters.length) {
      return 1;
    }
    return Math.max(1, Math.round(this.chapters[index].pageCount || 1));
  }

  totalChapterWeight(): number {
    let totalWeight: number = 0;
    for (let i = 0; i < this.chapters.length; i++) {
      totalWeight += this.chapterWeightAt(i);
    }
    return Math.max(1, totalWeight);
  }

  estimatedWeightBefore(index: number): number {
    let totalWeight: number = 0;
    for (let i = 0; i < index; i++) {
      totalWeight += this.chapterWeightAt(i);
    }
    return totalWeight;
  }

  contentForChapterId(chId: string): ReadingContent | null {
    if (this.content && this.content.chapterId === chId) {
      return this.content;
    }
    for (let i = 0; i < this.scrollContents.length; i++) {
      if (this.scrollContents[i].chapterId === chId) {
        return this.scrollContents[i];
      }
    }
    return null;
  }

  chapterTitleForId(chId: string): string {
    const nextContent: ReadingContent | null = this.contentForChapterId(chId);
    if (nextContent && nextContent.chapterTitle) {
      return nextContent.chapterTitle;
    }
    const index: number = this.chapterIndexForId(chId);
    if (index >= 0) {
      return this.chapters[index].title || '';
    }
    return '';
  }

  scrollChapterIndexForOffset(scrollOffset: number): number {
    if (this.chapters.length === 0) {
      return -1;
    }
    const pageHeight: number = Math.max(1, this.readingPageHeight());
    const baseIndex: number = clampNumber(this.scrollBaseChapterIndex, 0, this.chapters.length - 1);
    let localWeight: number = Math.max(0, scrollOffset) / pageHeight;
    let chapterIndex: number = baseIndex;
    while (chapterIndex < this.chapters.length - 1 && localWeight >= this.chapterWeightAt(chapterIndex)) {
      localWeight -= this.chapterWeightAt(chapterIndex);
      chapterIndex++;
    }
    return chapterIndex;
  }

  scrollOffsetWithinChapter(scrollOffset: number, chapterIndex: number): number {
    if (chapterIndex < 0) {
      return 0;
    }
    const pageHeight: number = Math.max(1, this.readingPageHeight());
    const baseIndex: number = clampNumber(this.scrollBaseChapterIndex, 0, Math.max(0, this.chapters.length - 1));
    const beforeLocalWeight: number = Math.max(0, this.estimatedWeightBefore(chapterIndex) - this.estimatedWeightBefore(baseIndex));
    const localOffset: number = scrollOffset - beforeLocalWeight * pageHeight;
    return Math.round(clampNumber(localOffset, 0, this.chapterWeightAt(chapterIndex) * pageHeight));
  }

  visibleChapterProgress(): number {
    if (this.pageMode !== 'scroll' || this.chapters.length === 0) {
      return this.estimateProgress(this.chapterId);
    }
    const scrollOffset: number = this.currentScrollOffset();
    const pageHeight: number = Math.max(1, this.readingPageHeight());
    const baseIndex: number = clampNumber(this.scrollBaseChapterIndex, 0, this.chapters.length - 1);
    const progressedWeight: number = this.estimatedWeightBefore(baseIndex) + scrollOffset / pageHeight;
    return clampNumber(Math.round((progressedWeight / this.totalChapterWeight()) * 100), 0, 100);
  }

  monotonicProgress(nextProgress: number): number {
    return clampNumber(Math.max(Math.round(this.progress || 0), Math.round(nextProgress || 0)), 0, 100);
  }

  chapterEndProgress(chId: string): number {
    const chapterIndex: number = this.chapterIndexForId(chId);
    if (chapterIndex < 0 || this.chapters.length === 0) {
      return this.progress;
    }
    const progressedWeight: number = this.estimatedWeightBefore(chapterIndex) + this.chapterWeightAt(chapterIndex);
    return clampNumber(Math.round((progressedWeight / this.totalChapterWeight()) * 100), 0, 100);
  }

  async persistVisibleScrollProgress(force: boolean = false): Promise<void> {
    if (this.pageMode !== 'scroll' || (!this.content && this.scrollContents.length === 0)) {
      return;
    }
    const scrollOffset: number = this.currentScrollOffset();
    const chapterIndex: number = this.scrollChapterIndexForOffset(scrollOffset);
    if (chapterIndex >= 0) {
      this.visibleScrollChapterIndex = chapterIndex;
      const nextChapterId: string = this.chKey(this.chapters[chapterIndex]);
      const previousChapterId: string = this.chapterId;
      this.chapterId = nextChapterId;
      const nextContent: ReadingContent | null = this.contentForChapterId(nextChapterId);
      if (nextContent) {
        this.content = nextContent;
      }
      if (previousChapterId !== nextChapterId) {
        void this.syncReaderHighlights();
      }
    }
    const progress: number = this.monotonicProgress(this.visibleChapterProgress());
    const localScrollOffset: number = this.scrollOffsetWithinChapter(scrollOffset, chapterIndex);
    const syncKey: string = `${this.chapterId}:${progress}:${localScrollOffset}`;
    if (!force && syncKey === this.lastScrollProgressSyncKey) {
      return;
    }
    this.lastScrollProgressSyncKey = syncKey;
    this.progress = progress;
    await this.syncReadingState(this.chapterId, this.chapterTitleForId(this.chapterId), progress, localScrollOffset);
  }

  scheduleVisibleScrollProgressSync(force: boolean = false): void {
    if (this.pageMode !== 'scroll') {
      return;
    }
    clearTimeout(this.scrollProgressSyncTimer);
    this.scrollProgressSyncTimer = setTimeout(() => {
      void this.persistVisibleScrollProgress(force);
    }, force ? 0 : 180);
  }

  restoreScrollOffset(scrollOffset: number): void {
    if (this.pageMode !== 'scroll' || scrollOffset <= 0) {
      return;
    }
    setTimeout(() => {
      try {
        this.readerScroller.scrollTo({ xOffset: 0, yOffset: scrollOffset, animation: false });
      } catch (_) {
      }
    }, 0);
  }

  async syncChapterEndProgress(content: ReadingContent | null): Promise<void> {
    if (!content || !content.chapterId) {
      return;
    }
    const chapterIndex: number = this.chapterIndexForId(content.chapterId);
    if (chapterIndex < 0) {
      return;
    }
    const progress: number = Math.max(this.progress, this.chapterEndProgress(content.chapterId));
    const pageHeight: number = Math.max(1, this.readingPageHeight());
    const scrollOffset: number = this.pageMode === 'page'
      ? Math.max(0, this.pageIndex)
      : Math.round(this.chapterWeightAt(chapterIndex) * pageHeight);
    const syncKey: string = `end:${content.chapterId}:${progress}:${scrollOffset}`;
    if (syncKey === this.lastChapterEndSyncKey) {
      return;
    }
    this.lastChapterEndSyncKey = syncKey;
    this.visibleScrollChapterIndex = chapterIndex;
    this.content = content;
    this.chapterId = content.chapterId;
    this.progress = progress;
    void this.syncReaderHighlights();
    await this.syncReadingState(content.chapterId, content.chapterTitle, progress, scrollOffset);
  }

  async loadReader(): Promise<void> {
    if (this.bookId <= 0) { this.errorText = '缺少 bookId，无法打开阅读器'; return; }
    this.busyText = '正在加载阅读器';
    this.errorText = '';
    try {
      const book: Book = await ApiClient.getBook(this.bookId);
      const chs: ReadingChapter[] = await ApiClient.listChapters(this.bookId);
      let plan: PlanItem | null = null;
      const userId: number = UserSession.currentUserId();
      if (userId > 0) {
        const plans: PlanItem[] = await ApiClient.listPlans(userId);
        plan = this.findPlan(plans);
      }
      const requestedChapterId: string = this.chapterId || (plan ? (plan.chapterId || '') : '');
      const targetChId = this.pickChId(chs, requestedChapterId);
      let nextContent: ReadingContent | null = null;
      if (targetChId) {
        try { nextContent = await ApiClient.getReadingContent(this.bookId, targetChId); }
        catch (e) { this.errorText = `章节正文加载失败：${e}`; }
      }
      const nb: ReaderBundle = {
        book, plan, chapters: chs, content: nextContent,
        progress: plan ? {
          planId: plan.id, bookId: this.bookId, chapterId: targetChId,
          progress: plan.progress, scrollOffset: plan.scrollOffset || 0, status: plan.status,
        } : null,
        bookmarks: [],
      };
      this.bundle = nb;
      this.chapters = chs;
      this.bookmarks = nb.bookmarks;
      this.content = nextContent;
      this.chapterId = nextContent ? nextContent.chapterId : targetChId;
      const inferredProgress: number = this.estimateProgress(this.chapterId);
      const savedProgress: number = plan ? Math.max(0, Math.round(plan.progress || 0)) : 0;
      this.progress = clampNumber(Math.max(savedProgress, inferredProgress), 0, 100);
      this.resetReaderInteraction();
      await this.syncReaderHighlights();
      if (this.pageMode === 'scroll') {
        await this.loadScrollContents(this.chapterId);
      }
      this.lastSyncedProgressKey = '';
      const restoredScrollOffset: number = this.pageMode === 'scroll' && plan ? Math.max(0, Math.round(plan.scrollOffset || 0)) : 0;
      if (plan) {
        this.bundle.progress = {
          planId: plan.id,
          bookId: this.bookId,
          chapterId: this.chapterId,
          progress: this.progress,
          scrollOffset: restoredScrollOffset,
          status: this.progress >= 100 ? 'finished' : (plan.status || 'reading'),
        };
      }
      setReadingSession(this.bookId, this.chapterId, this.progress, restoredScrollOffset);
      if (plan && this.progress > savedProgress) {
        await this.syncBackendProgress(this.chapterId, this.progress, restoredScrollOffset);
      }
      if (userId > 0) {
        try {
          await ApiClient.trackEvent({
            user_id: userId,
            event_type: 'OPEN_READER',
            book_id: this.bookId,
            chapter_id: this.chapterId,
            progress: this.progress,
          });
        } catch (_) {}
      }
      await this.syncShelfTrace(book, this.chapterId, nextContent ? nextContent.chapterTitle : '', this.progress);
      this.restoreScrollOffset(restoredScrollOffset);
    } catch (e) {
      this.errorText = `阅读器加载失败：${e}`;
    } finally { this.busyText = ''; }
  }

  async loadChapter(ch: ReadingChapter): Promise<void> {
    if (this.chapterLoading) {
      return;
    }
    this.chapterLoading = true;
    this.busyText = '正在切换章节';
    this.errorText = '';
    try {
      const tid = this.chKey(ch);
      this.chapterId = tid;
      this.content = await ApiClient.getReadingContent(this.bookId, tid);
      this.closeReaderCatalog(false);
      this.closeReaderSettings(false);
      this.closeAiSheet(false);
      this.setToolbarVisible(false, false);
      this.resetReaderInteraction();
      this.progress = Math.max(this.progress, this.estimateProgress(tid));
      await this.syncReaderHighlights();
      if (this.pageMode === 'scroll') {
        await this.loadScrollContents(tid);
      }
      await this.syncReadingState(this.chapterId, this.content.chapterTitle, this.progress);
    } catch (e) {
      this.errorText = `章节切换失败：${e}`;
    } finally {
      this.busyText = '';
      this.chapterLoading = false;
    }
  }

  async loadScrollContents(startChapterId: string): Promise<void> {
    if (this.scrollLoading) {
      return;
    }
    this.scrollLoading = true;
      this.busyText = '正在拼接连续章节流';
    try {
      const chunks: ReadingContent[] = [];
      const startIndex = this.chapters.findIndex((chapter: ReadingChapter) => this.chKey(chapter) === startChapterId);
      const baseIndex = startIndex >= 0 ? startIndex : 0;
      this.scrollBaseChapterIndex = baseIndex;
      this.visibleScrollChapterIndex = baseIndex;
      const endIndex = Math.min(this.chapters.length, baseIndex + 3);
      for (let i = baseIndex; i < endIndex; i++) {
        const ch = this.chapters[i];
        const chId = this.chKey(ch);
        try {
          const content = i === baseIndex && this.content && this.content.chapterId === chId
            ? this.content
            : await ApiClient.getReadingContent(this.bookId, chId);
          if (content) {
            chunks.push(content);
          }
        } catch (_) {
        }
      }
      this.scrollContents = chunks;
    } finally {
      this.scrollLoading = false;
      this.busyText = '';
    }
  }

  async appendScrollContents(): Promise<void> {
    if (this.scrollLoading || this.pageMode !== 'scroll' || this.chapters.length === 0) {
      return;
    }
    const lastContent: ReadingContent | null = this.scrollContents.length > 0
      ? this.scrollContents[this.scrollContents.length - 1]
      : this.content;
    const lastChapterId: string = lastContent ? lastContent.chapterId : this.chapterId;
    const startIndex = this.chapters.findIndex((chapter: ReadingChapter) => this.chKey(chapter) === lastChapterId);
    if (startIndex < 0 || startIndex >= this.chapters.length - 1) {
      return;
    }
    this.scrollLoading = true;
    try {
      const nextContents: ReadingContent[] = this.scrollContents.length > 0 ? this.scrollContents.slice() : [];
      const endIndex = Math.min(this.chapters.length, startIndex + 3);
      for (let i = startIndex + 1; i < endIndex; i++) {
        const ch = this.chapters[i];
        const chId = this.chKey(ch);
        let exists = false;
        for (let j = 0; j < nextContents.length; j++) {
          if (nextContents[j].chapterId === chId) {
            exists = true;
          }
        }
        if (exists) {
          continue;
        }
        try {
          const content = await ApiClient.getReadingContent(this.bookId, chId);
          if (content) {
            nextContents.push(content);
          }
        } catch (_) {
        }
      }
      this.scrollContents = nextContents;
    } finally {
      this.scrollLoading = false;
    }
  }

  async saveProgress(): Promise<void> {
    if (this.pageMode === 'scroll') {
      const userId: number = UserSession.currentUserId();
      if (userId <= 0) {
        this.errorText = '请先登录后再保存进度';
        return;
      }
      this.busyText = '正在保存进度';
      this.errorText = '';
      try {
        await this.persistVisibleScrollProgress(true);
        try {
          await ApiClient.trackEvent({
            user_id: userId,
            event_type: 'SAVE_PROGRESS',
            book_id: this.bookId,
            chapter_id: this.chapterId,
            progress: this.progress,
          });
        } catch (_) {}
        this.busyText = '';
      } catch (e) { this.errorText = `保存失败：${e}`; this.busyText = ''; }
      return;
    }
    if (!this.bundle.plan) return;
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先登录后再保存进度';
      return;
    }
    this.busyText = '正在保存进度';
    this.errorText = '';
    try {
      await ApiClient.updatePlanProgress(userId, this.bundle.plan.id, this.bookId,
        this.chapterId, this.progress, this.pageMode === 'page' ? this.pageIndex : 0,
        this.progress >= 100 ? 'finished' : 'reading');
      notifyPlanProgressChanged(this.bookId, this.progress, this.chapterId,
        this.pageMode === 'page' ? this.pageIndex : 0, this.progress >= 100 ? 'finished' : 'reading');
      try {
        await ApiClient.trackEvent({
          user_id: userId,
          event_type: 'SAVE_PROGRESS',
          book_id: this.bookId,
          chapter_id: this.chapterId,
          progress: this.progress,
        });
      } catch (_) {}
      await this.syncReadingState(this.chapterId,
        this.content ? this.content.chapterTitle : '', this.progress, this.pageMode === 'page' ? this.pageIndex : 0);
      this.busyText = '';
    } catch (e) { this.errorText = `保存失败：${e}`; this.busyText = ''; }
  }

  async createPlan(): Promise<void> {
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先登录后再创建计划';
      return;
    }
    this.busyText = '正在创建阅读计划';
    this.errorText = '';
    try {
      await ApiClient.createPlan(userId, this.bookId, 14, { dailyMinutesTarget: 30, weeklyMinutesTarget: 210 });
      notifyPlanDataChanged();
      await this.loadReader();
      this.busyText = '已创建';
    } catch (e) { this.errorText = `创建阅读计划失败：${e}`; this.busyText = ''; }
  }

  findPlan(plans: PlanItem[]): PlanItem | null {
    for (let i = 0; i < plans.length; i++) { if (plans[i].bookId === this.bookId) return plans[i]; }
    return null;
  }

  pickChId(chs: ReadingChapter[], preferredChapterId: string = ''): string {
    const candidate: string = preferredChapterId || this.chapterId;
    if (candidate) {
      for (let i = 0; i < chs.length; i++) {
        if (this.chKey(chs[i]) === candidate) return candidate;
      }
    }
    if (chs.length > 0) return this.chKey(chs[0]);
    return '';
  }

  chKey(ch: ReadingChapter): string { return ch.id || ch.chapterId || `${ch.order}`; }

  curIdx(): number {
    for (let i = 0; i < this.chapters.length; i++) { if (this.chKey(this.chapters[i]) === this.chapterId) return i; }
    return -1;
  }

  prevChapter(): void {
    const i = this.curIdx();
    if (i > 0) this.loadChapter(this.chapters[i - 1]);
  }

  nextChapter(): void {
    const i = this.curIdx();
    if (i >= 0 && i < this.chapters.length - 1) this.loadChapter(this.chapters[i + 1]);
  }

  estimateProgress(cid: string): number {
    if (this.chapters.length === 0) return this.progress;
    for (let i = 0; i < this.chapters.length; i++) {
      if (this.chKey(this.chapters[i]) === cid) {
        const total: number = this.pageMode === 'page' ? Math.max(1, this.contentPageCount()) : 1;
        const pageRatio: number = this.pageMode === 'page'
          ? Math.min(1, Math.max(0, (Math.min(this.pageIndex + 1, total)) / total))
          : 0;
        return Math.floor(((i + pageRatio) / this.chapters.length) * 100);
      }
    }
    return this.progress;
  }

  updateVisibleProgress(): void {
    this.progress = this.monotonicProgress(this.estimateProgress(this.chapterId));
    const offset: number = this.pageMode === 'page' ? this.pageIndex : 0;
    this.syncReadingState(this.chapterId, this.content ? this.content.chapterTitle : '', this.progress, offset);
  }

  th(): ReadingThemeDef {
    if (this.themeKey === 'parchment') return THEME_PARCHMENT;
    if (this.themeKey === 'light') return THEME_LIGHT;
    if (this.themeKey === 'dark') return THEME_DARK;
    if (this.themeKey === 'green') return THEME_GREEN;
    return THEME_PARCHMENT;
  }

  themeByKey(k: string): ReadingThemeDef {
    if (k === 'parchment') return THEME_PARCHMENT;
    if (k === 'light') return THEME_LIGHT;
    if (k === 'dark') return THEME_DARK;
    if (k === 'green') return THEME_GREEN;
    return THEME_PARCHMENT;
  }

  fs(): number { return FONT_SIZES[this.fontSizeIdx]; }
  canDecreaseFont(): boolean { return this.fontSizeIdx > 0; }
  canIncreaseFont(): boolean { return this.fontSizeIdx < FONT_SIZES.length - 1; }
  changeFontSize(delta: number): void {
    const nextIndex: number = clampNumber(this.fontSizeIdx + delta, 0, FONT_SIZES.length - 1);
    if (nextIndex === this.fontSizeIdx) {
      return;
    }
    this.fontSizeIdx = nextIndex;
    this.resetPaging();
  }
  ls(): number { return LINE_SPACINGS[this.lineSpacingIdx]; }
  brightValue(): number { return BRIGHTNESS_STEPS[this.brightnessIdx]; }
  autoReadSeconds(): number { return AUTO_READ_SPEEDS[this.autoReadSpeedIdx].seconds; }
  autoReadSpeedLabel(): string { return AUTO_READ_SPEEDS[this.autoReadSpeedIdx].label; }
  autoReadInterval(): number { return this.autoReadSeconds() * 1000; }

  safeTop(): number {
    if (this.pageW >= 720 && this.pageH < 520) return 10;
    return this.pageW >= 720 ? 14 : 24;
  }

  safeBottom(): number {
    if (this.pageW >= 720 && this.pageH < 520) return 8;
    return this.pageW >= 720 ? 12 : 18;
  }

  topBarHeight(): number { return this.safeTop() + 48; }
  bottomBarHeight(): number { return this.safeBottom() + 62; }

  toolbarContentMaxWidth(): number {
    return Math.min(this.pageW, this.contentMaxWidth() + this.contentPad() * 2);
  }

  toolbarDismissTop(): number {
    return this.topBarHeight();
  }

  toolbarDismissHeight(): number {
    return Math.max(0, this.pageH - this.topBarHeight() - this.bottomBarHeight());
  }

  bottomBarTop(): number {
    return Math.max(this.topBarHeight(), this.pageH - this.bottomBarHeight());
  }

  toolbarContentLeft(): number {
    return Math.max(0, Math.floor((this.pageW - this.toolbarContentMaxWidth()) / 2));
  }

  toolbarTopActionTop(): number {
    return this.safeTop();
  }

  toolbarActionWidth(): number {
    return 64;
  }

  toolbarBottomSegmentWidth(): number {
    return Math.max(1, this.toolbarContentMaxWidth() / 4);
  }

  contentPad(): number {
    if (this.pageW >= 1100) return 72;
    if (this.pageW >= 720) return 56;
    if (this.pageW >= 500) return 40;
    return 24;
  }

  contentMaxWidth(): number {
    if (this.pageW >= 1100) return 760;
    if (this.pageW >= 720) return 700;
    return Math.max(280, this.pageW - this.contentPad() * 2);
  }

  readingContentWidth(): number {
    return Math.min(this.contentMaxWidth(), Math.max(260, this.pageW - this.contentPad() * 2));
  }

  pageTurnZoneWidth(): number {
    return Math.min(Math.floor(this.pageW * 0.30), Math.max(82, Math.floor(this.pageW * 0.24)));
  }

  readingPageHeight(): number {
    const chrome = this.safeTop() + this.safeBottom() + 104;
    return Math.max(240, this.pageH - chrome);
  }

  contentSources(): SourceRef[] {
    if (!this.content) return [];
    if (this.content.sourceRefs && this.content.sourceRefs.length > 0) return this.content.sourceRefs;
    if (this.content.sources && this.content.sources.length > 0) return this.content.sources;
    return [];
  }

  readingParagraphs(): string[] {
    if (!this.content) return [];
    return this.paragraphsFor(this.content);
  }

  paragraphsFor(content: ReadingContent | null): string[] {
    if (!content) return [];
    if (content.paragraphs && content.paragraphs.length > 0) {
      return content.paragraphs;
    }
    if (!content.content) return [];
    const parts = content.content.split(/\n+/);
    const values: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const p = parts[i].trim();
      if (p) values.push(p);
    }
    return values.length > 0 ? values : [content.content];
  }

  sourcesFor(content: ReadingContent | null): SourceRef[] {
    if (!content) return [];
    if (content.sourceRefs && content.sourceRefs.length > 0) return content.sourceRefs;
    if (content.sources && content.sources.length > 0) return content.sources;
    return [];
  }

  emptyReadingContent(): ReadingContent {
    return {
      bookId: this.bookId,
      chapterId: this.chapterId,
      chapterTitle: '',
      content: '',
      paragraphs: [],
      sourceRefs: [],
    };
  }

  pagedTextHeight(): number {
    const headerReserve: number = this.pageW >= 720 ? 116 : 132;
    const footerReserve: number = 34;
    const outerPadding: number = this.safeTop() + this.safeBottom() + 42;
    return Math.max(180, this.pageH - headerReserve - footerReserve - outerPadding);
  }

  pageCharLimit(): number {
    const lineHeight: number = Math.max(18, this.fs() * this.ls());
    const lines: number = Math.max(6, Math.floor(this.pagedTextHeight() / lineHeight) - 1);
    const charWidth: number = this.fs() * (this.pageW >= 720 ? 0.82 : 0.90);
    const charsPerLine: number = Math.max(10, Math.floor(this.readingContentWidth() / Math.max(1, charWidth)));
    return Math.max(90, Math.floor(lines * charsPerLine * 0.84));
  }

  allUnits(): ParagraphUnit[] {
    const paragraphs = this.readingParagraphs();
    const units: ParagraphUnit[] = [];
    const unitLimit = Math.max(70, Math.floor(this.pageCharLimit() * 0.82));
    for (let i = 0; i < paragraphs.length; i++) {
      const text = paragraphs[i] || '';
      if (text.length <= unitLimit) {
        units.push(makeParagraphUnit(i, text, 0));
      } else {
        let start = 0;
        while (start < text.length) {
          units.push(makeParagraphUnit(i, text.substring(start, Math.min(text.length, start + unitLimit)), start));
          start += unitLimit;
        }
      }
    }
    return units;
  }

  contentPageCount(): number {
    const units = this.allUnits();
    if (units.length <= 0) return 1;
    const limit = this.pageCharLimit();
    let count = 1;
    let used = 0;
    for (let i = 0; i < units.length; i++) {
      const next = units[i].text.length + Math.max(20, Math.floor(this.fs() * 1.35));
      if (used > 0 && used + next > limit) {
        count++;
        used = 0;
      }
      used += next;
    }
    return Math.max(1, count);
  }

  totalPages(): number {
    return this.contentPageCount();
  }

  pageUnitsAt(pageIndex: number): ParagraphUnit[] {
    const units = this.allUnits();
    const limit = this.pageCharLimit();
    const contentPages = this.contentPageCount();
    const target = Math.min(Math.max(0, pageIndex), contentPages - 1);
    if (pageIndex >= contentPages) {
      return [];
    }
    let page = 0;
    let used = 0;
    const values: ParagraphUnit[] = [];
    for (let i = 0; i < units.length; i++) {
      const next = units[i].text.length + Math.max(20, Math.floor(this.fs() * 1.35));
      if (used > 0 && used + next > limit) {
        if (page === target) break;
        page++;
        used = 0;
      }
      if (page === target) {
        values.push(units[i]);
      }
      used += next;
    }
    return values;
  }

  currentPageUnits(): ParagraphUnit[] {
    return this.pageUnitsAt(this.pageIndex);
  }

  surfacePageIndex(pageIdx: number, interactive: boolean): number {
    return interactive ? this.pageIndex : pageIdx;
  }

  isEndPage(pageIndex: number = this.pageIndex): boolean {
    return pageIndex >= this.contentPageCount();
  }

  resetReaderInteraction(): void {
    clearTimeout(this.scrollProgressSyncTimer);
    this.scrollProgressSyncTimer = -1;
    this.pageIndex = 0;
    this.resetCurl();
    this.selectedParagraphIndex = -1;
    this.selectedChapterId = '';
    this.selectedParagraphTextValue = '';
    this.selectedStartOffset = 0;
    this.selectedEndOffset = 0;
    this.showParagraphToolbar = false;
    this.showShareSheet = false;
    this.showCommentSheet = false;
    this.shareHint = '';
    this.readerComments = [];
    this.commentInput = '';
    this.commentError = '';
    this.lastScrollProgressSyncKey = '';
    this.lastChapterEndSyncKey = '';
    this.visibleScrollChapterIndex = 0;
  }

  resetPaging(): void {
    this.pageIndex = 0;
    this.resetCurl();
    this.showParagraphToolbar = false;
  }

  resetCurl(): void {
    clearTimeout(this.curlCommitTimer);
    this.curlCommitTimer = -1;
    this.curlActive = false;
    this.curlDragging = false;
    this.curlProgress = 0;
    this.curlDirection = 1;
    this.curlTouchCount = 1;
  }

  handleContentTap(): void {
    if (this.ignoreNextContentTap) {
      return;
    }
    if (this.hasActiveReaderOverlay()) {
      return;
    }
    if (this.autoReadActive) {
      this.pauseAutoReadByTouch();
      return;
    }
    if (this.showParagraphToolbar) {
      this.showParagraphToolbar = false;
      return;
    }
    this.toggleToolbar();
    this.guardContentTap(180);
  }

  hasActiveReaderOverlay(): boolean {
    return this.showCatalog || this.showSettings || this.showAiSheet || this.showShareSheet || this.showCommentSheet;
  }

  guardContentTap(durationMs: number): void {
    this.ignoreNextContentTap = true;
    clearTimeout(this.contentTapGuardTimer);
    this.contentTapGuardTimer = -1;
    this.contentTapGuardTimer = setTimeout(() => {
      this.ignoreNextContentTap = false;
      this.contentTapGuardTimer = -1;
    }, durationMs);
  }

  markToolbarTap(): void {
    this.guardContentTap(TOOLBAR_TAP_GUARD_MS);
  }

  runToolbarAction(action: () => void): void {
    this.markToolbarTap();
    action();
  }

  hideBarsFromOverlay(): void {
    this.setToolbarVisible(false);
    this.guardContentTap(180);
  }

  setToolbarVisible(visible: boolean, animated: boolean = true): void {
    clearTimeout(this.toolbarTimer);
    this.toolbarTimer = -1;
    if (visible) {
      this.barsVisible = true;
      if (!animated) {
        this.toolbarProgress = 1;
        return;
      }
      this.toolbarProgress = 0;
      this.toolbarTimer = setTimeout(() => {
        animateTo({ duration: 210, curve: Curve.EaseOut }, () => {
          this.toolbarProgress = 1;
        });
        this.toolbarTimer = -1;
      }, 0);
      return;
    }
    if (!this.barsVisible) {
      this.toolbarProgress = 0;
      return;
    }
    if (!animated) {
      this.toolbarProgress = 0;
      this.barsVisible = false;
      return;
    }
    animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
      this.toolbarProgress = 0;
    });
    this.toolbarTimer = setTimeout(() => {
      this.barsVisible = false;
      this.toolbarTimer = -1;
    }, 200);
  }

  toggleToolbar(): void {
    this.setToolbarVisible(!this.barsVisible || this.toolbarProgress < 0.5);
  }

  openReaderCatalog(): void {
    this.setToolbarVisible(false);
    this.showCatalog = true;
    this.catalogSheetProgress = 0;
    this.closeReaderSettings(false);
    this.closeAiSheet(false);
    clearTimeout(this.catalogSheetTimer);
    this.catalogSheetTimer = setTimeout(() => {
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.catalogSheetProgress = 1;
      });
      this.catalogSheetTimer = -1;
    }, 0);
  }

  closeReaderCatalog(animated: boolean = true): void {
    clearTimeout(this.catalogSheetTimer);
    this.catalogSheetTimer = -1;
    if (!this.showCatalog) {
      this.catalogSheetProgress = 0;
      return;
    }
    if (!animated) {
      this.catalogSheetProgress = 0;
      this.showCatalog = false;
      return;
    }
    this.markToolbarTap();
    animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.catalogSheetProgress = 0;
    });
    this.catalogSheetTimer = setTimeout(() => {
      this.showCatalog = false;
      this.catalogSheetTimer = -1;
    }, 240);
  }

  beginCatalogDrag(): void {
    this.markToolbarTap();
    this.catalogDragBaseOffset = this.currentCatalogOffset();
  }

  updateCatalogDrag(event: GestureEvent): void {
    const dy: number = event.offsetY || 0;
    const nextOffset: number = Math.max(0, this.catalogDragBaseOffset - dy);
    this.catalogScroller.scrollTo({ xOffset: 0, yOffset: nextOffset, animation: false });
  }

  openReaderSettings(): void {
    this.setToolbarVisible(false);
    this.closeReaderCatalog(false);
    this.closeAiSheet(false);
    this.showSettings = true;
    this.settingsSheetProgress = 0;
    clearTimeout(this.settingsSheetTimer);
    this.settingsSheetTimer = setTimeout(() => {
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.settingsSheetProgress = 1;
      });
      this.settingsSheetTimer = -1;
    }, 0);
  }

  closeReaderSettings(animated: boolean = true): void {
    clearTimeout(this.settingsSheetTimer);
    this.settingsSheetTimer = -1;
    if (!this.showSettings) {
      this.settingsSheetProgress = 0;
      return;
    }
    if (!animated) {
      this.settingsSheetProgress = 0;
      this.showSettings = false;
      return;
    }
    this.markToolbarTap();
    animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.settingsSheetProgress = 0;
    });
    this.settingsSheetTimer = setTimeout(() => {
      this.showSettings = false;
      this.settingsSheetTimer = -1;
    }, 240);
  }

  openAiSheet(): void {
    this.showAiSheet = true;
    this.aiSheetProgress = 0;
    this.closeReaderCatalog(false);
    this.closeReaderSettings(false);
    this.setToolbarVisible(false);
    this.showParagraphToolbar = false;
    this.aiError = '';
    clearTimeout(this.aiSheetTimer);
    this.aiSheetTimer = setTimeout(() => {
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.aiSheetProgress = 1;
      });
      this.aiSheetTimer = -1;
    }, 0);
  }

  closeAiSheet(animated: boolean = true): void {
    clearTimeout(this.aiSheetTimer);
    this.aiSheetTimer = -1;
    if (!this.showAiSheet) {
      this.aiSheetProgress = 0;
      return;
    }
    if (!animated) {
      this.aiSheetProgress = 0;
      this.showAiSheet = false;
      return;
    }
    this.markToolbarTap();
    animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.aiSheetProgress = 0;
    });
    this.aiSheetTimer = setTimeout(() => {
      this.showAiSheet = false;
      this.aiSheetTimer = -1;
    }, 240);
  }

  handleToolbarTouch(event: TouchEvent): void {
    if (!this.barsVisible || event.type !== TouchType.Up) {
      return;
    }
    const touches: TouchObject[] = event.changedTouches && event.changedTouches.length > 0
      ? event.changedTouches
      : event.touches;
    if (!touches || touches.length === 0) {
      return;
    }
    const touch: TouchObject = touches[0];
    const x: number = Number.isFinite(touch.windowX) ? touch.windowX : touch.x;
    const y: number = Number.isFinite(touch.windowY) ? touch.windowY : touch.y;
    const topHeight: number = this.topBarHeight();
    const bottomTop: number = Math.max(0, this.pageH - this.bottomBarHeight());

    if (y <= topHeight) {
      const edgeWidth: number = Math.min(160, Math.max(72, this.pageW * 0.22));
      if (x <= edgeWidth) {
        this.markToolbarTap();
        this.stopAutoRead();
        this.saveProgress();
        goBack();
      } else if (x >= this.pageW - edgeWidth) {
        this.openReaderCatalog();
      }
      return;
    }

    if (y >= bottomTop) {
      const segmentWidth: number = Math.max(1, this.pageW / 4);
      const index: number = clampNumber(Math.floor(x / segmentWidth), 0, 3);
      if (index === 0) {
        this.openReaderCatalog();
      } else if (index === 1) {
        this.markToolbarTap();
        this.toggleNightTheme();
      } else if (index === 2) {
        this.openReaderSettings();
      } else {
        this.markToolbarTap();
        this.openAiSheet();
      }
      return;
    }

    this.hideBarsFromOverlay();
  }

  settingsSheetTop(): number {
    return Math.round(this.pageH * 0.36);
  }

  bottomSheetLeft(maxWidth: number): number {
    return this.pageW >= maxWidth ? Math.floor((this.pageW - maxWidth) / 2) : 0;
  }

  bottomSheetWidth(maxWidth: number): number {
    return this.pageW >= maxWidth ? maxWidth : this.pageW;
  }

  startAutoRead(): void {
    if (this.autoReadActive) return;
    this.guardContentTap(AUTO_READ_TOUCH_GUARD_MS);
    this.setToolbarVisible(false, false);
    this.closeReaderCatalog(false);
    this.closeReaderSettings(false);
    this.showShareSheet = false;
    this.closeAiSheet(false);
    this.showCommentSheet = false;
    this.showParagraphToolbar = false;
    this.resetCurl();
    this.autoReadActive = true;
    this.scheduleAutoRead();
  }

  stopAutoRead(): void {
    this.autoReadActive = false;
    clearTimeout(this.autoReadTimer);
    this.autoReadTimer = -1;
  }

  pauseAutoReadByTouch(): void {
    if (!this.autoReadActive) return;
    this.stopAutoRead();
    this.setToolbarVisible(false, false);
    this.guardContentTap(AUTO_READ_TOUCH_GUARD_MS);
  }

  toggleAutoRead(): void {
    if (this.autoReadActive) {
      this.stopAutoRead();
    } else {
      this.startAutoRead();
    }
  }

  scheduleAutoRead(): void {
    if (!this.autoReadActive) return;
    clearTimeout(this.autoReadTimer);
    this.autoReadTimer = setTimeout(() => {
      if (!this.autoReadActive) return;
      if (this.pageMode === 'scroll') {
        this.advanceAutoScroll();
        return;
      }
      if (!this.canTurnPage(1)) {
        this.stopAutoRead();
        return;
      }
      this.playCurlTurn(1, true);
    }, this.autoReadInterval());
  }

  advanceAutoScroll(): void {
    const pageHeight: number = Math.max(180, this.readingPageHeight());
    const currentOffset: number = this.currentScrollOffset();
    const maxOffset: number = Math.max(0,
      (this.totalChapterWeight() - this.estimatedWeightBefore(this.scrollBaseChapterIndex)) * pageHeight);
    if (currentOffset >= maxOffset - pageHeight * 0.52 && this.curIdx() >= this.chapters.length - 1) {
      this.stopAutoRead();
      return;
    }
    const nextOffset: number = Math.min(maxOffset, currentOffset + Math.round(pageHeight * 0.78));
    try {
      this.readerScroller.scrollTo({ xOffset: 0, yOffset: nextOffset, animation: true });
    } catch (_) {
    }
    const nextChapterIndex: number = this.scrollChapterIndexForOffset(nextOffset);
    if (nextChapterIndex >= this.chapters.length - 2) {
      this.appendScrollContents();
    }
    this.scheduleVisibleScrollProgressSync(true);
    this.scheduleAutoRead();
  }

  turnPrevPage(): void {
    this.stopAutoRead();
    this.playCurlTurn(-1, false);
  }

  turnNextPage(): void {
    this.stopAutoRead();
    this.playCurlTurn(1, false);
  }

  canTurnPage(direction: number): boolean {
    if (this.chapterLoading) {
      return false;
    }
    if (direction > 0) {
      return this.pageIndex < this.totalPages() - 1 || this.curIdx() < this.chapters.length - 1;
    }
    return this.pageIndex > 0 || this.curIdx() > 0;
  }

  commitPageTurn(direction: number): void {
    this.showParagraphToolbar = false;
    if (direction > 0) {
      const total = this.totalPages();
      if (this.pageIndex < total - 1) {
        this.pageIndex++;
        this.updateVisibleProgress();
      } else {
        this.nextChapter();
      }
    } else {
      if (this.pageIndex > 0) {
        this.pageIndex--;
        this.updateVisibleProgress();
      } else {
        this.prevChapter();
      }
    }
  }

  playCurlTurn(direction: number, keepAutoReading: boolean): void {
    if (!this.canTurnPage(direction) || this.curlActive) {
      if (keepAutoReading && this.autoReadActive) this.scheduleAutoRead();
      return;
    }
    clearTimeout(this.curlCommitTimer);
    this.curlDirection = direction > 0 ? 1 : -1;
    this.curlTouchCount = 1;
    this.curlDragging = false;
    this.curlActive = true;
    this.curlProgress = 0.04;
    animateTo({ duration: PAGE_CURL_ANIMATION_MS, curve: Curve.EaseInOut }, () => {
      this.curlProgress = 1;
    });
    this.curlCommitTimer = setTimeout(() => {
      this.commitPageTurn(this.curlDirection);
      this.resetCurl();
      if (keepAutoReading && this.autoReadActive) {
        this.scheduleAutoRead();
      }
    }, PAGE_CURL_ANIMATION_MS + 24);
  }

  beginCurlDrag(event: GestureEvent): void {
    this.pauseAutoReadByTouch();
    this.showParagraphToolbar = false;
    this.curlDragging = true;
    this.curlActive = true;
    this.curlTouchCount = Math.max(1, event.fingerList ? event.fingerList.length : 1);
    this.curlProgress = Math.max(0.04, this.curlProgress);
  }

  updateCurlDrag(event: GestureEvent): void {
    this.curlTouchCount = Math.max(1, event.fingerList ? event.fingerList.length : this.curlTouchCount);
    const dx: number = event.offsetX || 0;
    if (Math.abs(dx) < 2) return;
    this.curlDirection = dx < 0 ? 1 : -1;
    if (!this.canTurnPage(this.curlDirection)) {
      this.curlProgress = Math.min(0.16, Math.abs(dx) / Math.max(1, this.pageW));
      return;
    }
    this.curlActive = true;
    this.curlProgress = clampNumber(Math.abs(dx) / Math.max(1, this.pageW * 0.72), 0.04, 0.98);
  }

  finishCurlDrag(): void {
    if (!this.curlActive || !this.curlDragging) {
      this.resetCurl();
      return;
    }
    const shouldCommit: boolean = this.curlProgress > 0.38 && this.canTurnPage(this.curlDirection);
    this.curlDragging = false;
    if (shouldCommit) {
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.curlProgress = 1;
      });
      this.curlCommitTimer = setTimeout(() => {
        this.commitPageTurn(this.curlDirection);
        this.resetCurl();
      }, 284);
    } else {
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.curlProgress = 0;
      });
      this.curlCommitTimer = setTimeout(() => this.resetCurl(), 244);
    }
  }

  handleReaderTouch(event: TouchEvent): void {
    if (this.ignoreNextContentTap) return;
    if (event.type === TouchType.Down || event.type === TouchType.Move) {
      this.curlTouchCount = Math.max(1, event.touches ? event.touches.length : 1);
      this.pauseAutoReadByTouch();
    }
  }

  curlTargetPageIndex(): number {
    return clampNumber(this.pageIndex + this.curlDirection, 0, this.totalPages() - 1);
  }

  curlMetrics(): PageCurlMetrics {
    const m = new PageCurlMetrics();
    const p: number = clampNumber(this.curlProgress, 0, 1);
    const bend: number = Math.sin(p * Math.PI);
    const touchBoost: number = this.curlTouchCount > 1 ? 1.18 : 1;
    m.progress = p;
    m.foldWidth = clampNumber(this.pageW * (0.16 + p * 0.74), 74, this.pageW * 0.92);
    m.foldX = this.curlDirection > 0 ? Math.max(0, this.pageW - m.foldWidth) : 0;
    m.cornerY = this.safeTop() + this.readingPageHeight() * (0.08 + bend * 0.18);
    m.rotateY = this.curlDirection > 0 ? -(18 + p * 154) : (18 + p * 154);
    m.rotateZ = this.curlDirection > 0 ? -(4 + bend * 9) : (4 + bend * 9);
    m.depth = bend * 26 * touchBoost;
    m.thickness = 2 + bend * 7 * touchBoost;
    m.shadowWidth = clampNumber(this.pageW * (0.12 + bend * 0.28), 40, this.pageW * 0.44);
    m.shadowAlpha = 0.12 + bend * 0.30;
    m.highlightAlpha = 0.14 + bend * 0.28;
    m.scaleY = 1 - bend * 0.018;
    const x0: number = this.curlDirection > 0 ? m.foldWidth - m.thickness : m.thickness;
    const c1x: number = this.curlDirection > 0 ? m.foldWidth * (0.62 - p * 0.14) : m.foldWidth * (0.38 + p * 0.14);
    const c2x: number = this.curlDirection > 0 ? m.foldWidth * (0.30 + p * 0.10) : m.foldWidth * (0.70 - p * 0.10);
    const y1: number = this.pageH * (0.22 + bend * 0.08);
    const y2: number = this.pageH * (0.72 - bend * 0.06);
    const xEnd: number = this.curlDirection > 0 ? m.thickness : m.foldWidth - m.thickness;
    m.curvePath = `M ${x0.toFixed(1)} 0 C ${c1x.toFixed(1)} ${y1.toFixed(1)}, ${c2x.toFixed(1)} ${y2.toFixed(1)}, ${xEnd.toFixed(1)} ${this.pageH.toFixed(1)}`;
    return m;
  }

  brightnessPercent(): string { return `${Math.round(this.brightValue() * 100)}%`; }

  highlightHasExactRange(highlight: ReaderHighlight): boolean {
    const start: number = Math.max(0, Math.round(highlight.startOffset || 0));
    const end: number = Math.max(0, Math.round(highlight.endOffset || 0));
    return end > start;
  }

  isMarked(idx: number): boolean {
    for (let i = 0; i < this.markedParagraphIndexes.length; i++) {
      if (this.markedParagraphIndexes[i] === idx) return true;
    }
    return false;
  }

  paragraphHighlightRanges(paragraphIndex: number): HighlightRange[] {
    const paragraph: string = this.selectedParagraphTextFromCurrent(paragraphIndex);
    const ranges: HighlightRange[] = [];
    for (let i = 0; i < this.readerHighlights.length; i++) {
      const highlight: ReaderHighlight = this.readerHighlights[i];
      if (highlight.paragraphIndex !== paragraphIndex) {
        continue;
      }
      let start: number = Math.max(0, Math.round(highlight.startOffset || 0));
      let end: number = Math.max(0, Math.round(highlight.endOffset || 0));
      if (end <= start) {
        const selected: string = highlight.selectedText || '';
        const found: number = selected && paragraph ? paragraph.indexOf(selected) : -1;
        if (found >= 0) {
          start = found;
          end = found + selected.length;
        } else {
          start = 0;
          end = paragraph.length;
        }
      }
      start = clampNumber(start, 0, paragraph.length);
      end = clampNumber(end, start, paragraph.length);
      if (end > start) {
        ranges.push(makeHighlightRange(start, end));
      }
    }
    return this.mergeRanges(ranges);
  }

  mergeRanges(ranges: HighlightRange[]): HighlightRange[] {
    const values: HighlightRange[] = ranges.slice().sort((a: HighlightRange, b: HighlightRange) => a.start - b.start);
    const merged: HighlightRange[] = [];
    for (let i = 0; i < values.length; i++) {
      const current: HighlightRange = values[i];
      if (merged.length === 0 || current.start > merged[merged.length - 1].end) {
        merged.push(makeHighlightRange(current.start, current.end));
      } else {
        merged[merged.length - 1].end = Math.max(merged[merged.length - 1].end, current.end);
      }
    }
    return merged;
  }

  selectionRangeForParagraph(paragraphIndex: number): HighlightRange | null {
    if (!this.showParagraphToolbar || this.selectedParagraphIndex !== paragraphIndex) {
      return null;
    }
    const paragraph: string = this.selectedParagraphTextFromCurrent(paragraphIndex);
    const start: number = clampNumber(this.selectedStartOffset, 0, paragraph.length);
    const end: number = clampNumber(this.selectedEndOffset, start, paragraph.length);
    return end > start ? makeHighlightRange(start, end) : null;
  }

  rangeContains(ranges: HighlightRange[], index: number): boolean {
    for (let i = 0; i < ranges.length; i++) {
      if (index >= ranges[i].start && index < ranges[i].end) {
        return true;
      }
    }
    return false;
  }

  textRunsForUnit(text: string, paragraphIndex: number, unitStartOffset: number): TextRun[] {
    const highlightRanges: HighlightRange[] = this.paragraphHighlightRanges(paragraphIndex);
    const selectedRange: HighlightRange | null = this.selectionRangeForParagraph(paragraphIndex);
    const values: TextRun[] = [];
    let segmentStart: number = 0;
    for (let i = 0; i < text.length; i++) {
      const absolute: number = unitStartOffset + i;
      const highlighted: boolean = this.rangeContains(highlightRanges, absolute);
      const selected: boolean = selectedRange ? absolute >= selectedRange.start && absolute < selectedRange.end : false;
      if (i === 0) {
        continue;
      }
      const previousAbsolute: number = unitStartOffset + i - 1;
      const previousHighlighted: boolean = this.rangeContains(highlightRanges, previousAbsolute);
      const previousSelected: boolean = selectedRange ? previousAbsolute >= selectedRange.start && previousAbsolute < selectedRange.end : false;
      if (highlighted !== previousHighlighted || selected !== previousSelected) {
        values.push(makeTextRun(text.substring(segmentStart, i), previousHighlighted, previousSelected));
        segmentStart = i;
      }
    }
    if (text.length > 0) {
      const absolute: number = unitStartOffset + text.length - 1;
      values.push(makeTextRun(
        text.substring(segmentStart),
        this.rangeContains(highlightRanges, absolute),
        selectedRange ? absolute >= selectedRange.start && absolute < selectedRange.end : false
      ));
    }
    if (values.length === 0) {
      values.push(makeTextRun(text));
    }
    return values;
  }

  async syncReaderHighlights(): Promise<void> {
    const userId: number = UserSession.currentUserId();
    if (userId <= 0 || this.bookId <= 0 || !this.chapterId) {
      this.readerHighlights = [];
      this.markedParagraphIndexes = [];
      return;
    }
    try {
      const highlights: ReaderHighlight[] = await ApiClient.listReaderHighlights(userId, this.bookId, this.chapterId);
      const indexes: number[] = [];
      for (let i = 0; i < highlights.length; i++) {
        if (!this.highlightHasExactRange(highlights[i])) {
          indexes.push(highlights[i].paragraphIndex);
        }
      }
      this.readerHighlights = highlights;
      this.markedParagraphIndexes = indexes;
    } catch (_) {
      this.readerHighlights = [];
      this.markedParagraphIndexes = [];
    }
  }

  selectParagraph(idx: number): void {
    this.selectedParagraphIndex = idx;
    this.selectedChapterId = this.chapterId;
    const text: string = this.selectedParagraphTextFromCurrent(idx);
    this.selectedParagraphTextValue = text;
    this.selectedStartOffset = 0;
    this.selectedEndOffset = text.length;
    this.showParagraphToolbar = true;
    this.setToolbarVisible(false, false);
    this.markToolbarTap();
  }

  selectTextRange(idx: number, text: string, unitStartOffset: number, selectionStart: number, selectionEnd: number): void {
    const start: number = clampNumber(Math.min(selectionStart, selectionEnd), 0, text.length);
    const end: number = clampNumber(Math.max(selectionStart, selectionEnd), start, text.length);
    if (end <= start) {
      return;
    }
    this.selectedParagraphIndex = idx;
    this.selectedChapterId = this.chapterId;
    this.selectedStartOffset = unitStartOffset + start;
    this.selectedEndOffset = unitStartOffset + end;
    this.selectedParagraphTextValue = text.substring(start, end);
    this.showParagraphToolbar = true;
    this.showShareSheet = false;
    this.showCommentSheet = false;
    this.setToolbarVisible(false, false);
    this.markToolbarTap();
  }

  selectTextRangeInContent(
    content: ReadingContent,
    idx: number,
    text: string,
    unitStartOffset: number,
    selectionStart: number,
    selectionEnd: number
  ): void {
    if (content.chapterId !== this.chapterId) {
      this.activateScrollChapter(content);
    }
    this.selectTextRange(idx, text, unitStartOffset, selectionStart, selectionEnd);
  }

  selectParagraphInContent(content: ReadingContent, idx: number): void {
    if (content.chapterId !== this.chapterId) {
      this.activateScrollChapter(content);
    }
    this.selectParagraph(idx);
  }

  activateScrollChapter(content: ReadingContent): void {
    if (!content || !content.chapterId || content.chapterId === this.chapterId) {
      return;
    }
    const chapterIndex: number = this.chapterIndexForId(content.chapterId);
    if (chapterIndex >= 0) {
      this.visibleScrollChapterIndex = chapterIndex;
    }
    this.content = content;
    this.chapterId = content.chapterId;
    this.syncReaderHighlights();
    this.progress = this.monotonicProgress(this.visibleChapterProgress());
    this.scheduleVisibleScrollProgressSync();
  }

  selectedParagraphText(): string {
    if (this.selectedParagraphTextValue) {
      return this.selectedParagraphTextValue;
    }
    return this.selectedParagraphTextFromCurrent(this.selectedParagraphIndex);
  }

  selectedParagraphTextFromCurrent(index: number): string {
    const paragraphs = this.readingParagraphs();
    if (index >= 0 && index < paragraphs.length) {
      return paragraphs[index];
    }
    return '';
  }

  async markSelected(): Promise<void> {
    if (this.selectedParagraphIndex < 0) return;
    const text: string = this.selectedParagraphText();
    if (!text) return;
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先登录后再标记文本';
      return;
    }
    const highlight: ReaderHighlight = {
      id: -Date.now(),
      userId,
      bookId: this.bookId,
      chapterId: this.selectedChapterId || this.chapterId,
      paragraphIndex: this.selectedParagraphIndex,
      startOffset: this.selectedStartOffset,
      endOffset: this.selectedEndOffset,
      selectedText: text,
      bookTitle: this.bundle.book.title || '',
      chapterTitle: this.chapterTitleForId(this.selectedChapterId || this.chapterId),
      createdAt: '',
    };
    const optimisticHighlights: ReaderHighlight[] = this.readerHighlights.slice();
    optimisticHighlights.push(highlight);
    this.readerHighlights = optimisticHighlights;
    this.showParagraphToolbar = false;
    try {
      await ApiClient.createReaderHighlight(
        userId,
        this.bookId,
        this.selectedChapterId || this.chapterId,
        this.selectedParagraphIndex,
        text,
        this.bundle.book.title || '',
        this.chapterTitleForId(this.selectedChapterId || this.chapterId),
        this.selectedStartOffset,
        this.selectedEndOffset
      );
      await this.syncReaderHighlights();
    } catch (err) {
      const rollback: ReaderHighlight[] = this.readerHighlights.slice();
      const lastIndex: number = rollback.findIndex((item: ReaderHighlight) => item.id === highlight.id);
      if (lastIndex >= 0) {
        rollback.splice(lastIndex, 1);
        this.readerHighlights = rollback;
      }
      this.errorText = `标记失败：${err}`;
    }
  }

  openCommentSheet(): void {
    if (this.selectedParagraphIndex < 0) return;
    this.showCommentSheet = true;
    this.showParagraphToolbar = false;
    this.commentInput = '';
    this.commentError = '';
    this.loadReaderComments();
  }

  async loadReaderComments(): Promise<void> {
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.commentError = '请先登录后再查看评论';
      return;
    }
    const chapterId: string = this.selectedChapterId || this.chapterId;
    if (this.bookId <= 0 || !chapterId || this.selectedParagraphIndex < 0) {
      this.commentError = '缺少评论位置，请重新选择文本';
      return;
    }
    this.commentBusy = true;
    this.commentError = '';
    try {
      this.readerComments = await ApiClient.listReaderComments(
        userId,
        this.bookId,
        chapterId,
        this.selectedParagraphIndex
      );
    } catch (err) {
      this.commentError = `评论加载失败：${err}`;
    } finally {
      this.commentBusy = false;
    }
  }

  async submitReaderComment(): Promise<void> {
    const userId: number = UserSession.currentUserId();
    const content: string = this.commentInput.trim();
    if (userId <= 0) {
      this.commentError = '请先登录';
      return;
    }
    if (!content) {
      this.commentError = '请输入评论内容';
      return;
    }
    this.commentBusy = true;
    this.commentError = '';
    const tempId: number = 0 - Date.now();
    const optimistic: ReaderComment = {
      id: tempId,
      userId,
      userName: this.shareUserName(),
      avatarUrl: this.shareAvatarUrl(),
      bookId: this.bookId,
      chapterId: this.selectedChapterId || this.chapterId,
      paragraphIndex: this.selectedParagraphIndex,
      selectedText: this.selectedParagraphText(),
      content,
      createdAt: '刚刚',
    };
    const previous: ReaderComment[] = this.readerComments.slice();
    const next: ReaderComment[] = this.readerComments.slice();
    next.push(optimistic);
    this.readerComments = next;
    this.commentInput = '';
    try {
      const comment: ReaderComment = await ApiClient.createReaderComment(
        userId,
        this.bookId,
        this.selectedChapterId || this.chapterId,
        this.selectedParagraphIndex,
        optimistic.selectedText,
        content
      );
      const replaced: ReaderComment[] = [];
      for (let i = 0; i < this.readerComments.length; i++) {
        replaced.push(this.readerComments[i].id === tempId ? comment : this.readerComments[i]);
      }
      this.readerComments = replaced;
      await this.loadReaderComments();
    } catch (err) {
      this.readerComments = previous;
      this.commentInput = content;
      this.commentError = `评论发送失败：${err}`;
    } finally {
      this.commentBusy = false;
    }
  }

  openAiForParagraph(): void {
    const text = this.selectedParagraphText();
    this.aiQuestion = text ? `解释这段：${text}` : '';
    this.openAiSheet();
    this.showParagraphToolbar = false;
    this.aiError = '';
  }

  waitForThinkingFrame(): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, 650);
    });
  }

  async askAi(): Promise<void> {
    const userId = UserSession.currentUserId();
    if (userId <= 0) {
      this.aiError = '请先登录后再使用 AI 导读';
      return;
    }
    const question = this.aiQuestion.trim();
    if (!question) {
      this.aiError = '请输入想问的问题';
      return;
    }
    if (this.aiBusy) {
      return;
    }
    this.aiBusy = true;
    this.aiError = '';
    this.aiAnswer = '';
    this.aiReasoning = '';
    this.aiFollowUp = '';
    this.aiSources = [];
    this.aiToolTrace = [];
    this.aiStatusText = '正在思考';
    try {
      await this.waitForThinkingFrame();
      const result: ChatResult = await ApiClient.chatStream(userId, this.bookId, question, {
        chapterId: this.chapterId,
        paragraph: this.selectedParagraphText(),
        allowExternalSearch: true,
        tone: 'warm_companion',
      }, {
        onDelta: (text: string) => {
          this.aiAnswer += text;
        },
        onReasoning: (text: string) => {
          this.aiReasoning += text;
        },
        onStatus: (text: string) => {
          this.aiStatusText = text;
        },
        onResult: (value: ChatResult) => {
          this.aiAnswer = ApiClient.preferStreamText(this.aiAnswer, value.answer || '');
          this.aiFollowUp = value.follow_up_suggestion || '';
          this.aiSources = value.sources || [];
          this.aiToolTrace = value.tool_trace || [];
          this.aiReasoning = value.hidden_reasoning || value.reasoning_content || value.reasoning || this.aiReasoning;
        },
        onError: (message: string) => {
          this.aiStatusText = message;
        },
      });
      this.aiAnswer = ApiClient.preferStreamText(this.aiAnswer, result.answer || '');
      this.aiFollowUp = result.follow_up_suggestion || '';
      this.aiSources = result.sources || [];
      this.aiToolTrace = result.tool_trace || [];
      this.aiReasoning = result.hidden_reasoning || result.reasoning_content || result.reasoning || this.aiReasoning;
    } catch (err) {
      this.aiError = `AI 导读失败：${err}`;
    } finally {
      this.aiBusy = false;
      this.aiStatusText = '';
    }
  }

  shareTimeText(): string {
    const d = new Date();
    const y = d.getFullYear();
    const m = twoDigits(d.getMonth() + 1);
    const day = twoDigits(d.getDate());
    const h = twoDigits(d.getHours());
    const min = twoDigits(d.getMinutes());
    return `${y}年${m}月${day}日 ${h}:${min}`;
  }

  shareUserName(): string {
    return UserSession.currentUserName() || '智阅书友';
  }

  shareAvatarUrl(): string {
    const profile = UserSession.currentProfile();
    return profile ? (profile.avatarUrl || '') : '';
  }

  simpleTimeText(value: string): string {
    if (!value) return '';
    return value.replace('T', ' ').substring(0, 16);
  }

  pageIndicatorText(): string {
    if (this.pageMode === 'page') {
      const contentPages = this.contentPageCount();
      return `${Math.min(this.pageIndex + 1, contentPages)}/${contentPages}`;
    }
    return `${this.curIdx() + 1}/${Math.max(1, this.chapters.length)}`;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.th().bg)
        .brightness(this.brightValue())

      if (this.pageMode === 'page') {
        this.PagedReader()
      } else {
        this.ScrollReader()
      }

      if (this.barsVisible && !this.hasActiveReaderOverlay()) {
        this.ToolbarDismissLayer()
        this.TopBar()
        this.BottomBar()
        this.ToolbarHitLayer()
      }

      if (this.showParagraphToolbar) { this.ParagraphToolbar() }
      if (this.showCatalog) { this.CatalogSheet() }
      if (this.showSettings) { this.SettingsSheet() }
      if (this.showAiSheet) { this.AiSheet() }
      if (this.showShareSheet) { this.ShareSheet() }
      if (this.showCommentSheet) { this.CommentSheet() }

      if (this.autoReadActive) {
        Row({ space: 6 }) {
          Text('AUTO').fontColor('#FFFFFF').fontSize(10).fontWeight(FontWeight.Bold)
          Text(`${this.autoReadSpeedLabel()} · ${this.autoReadSeconds()} 秒/页`).fontColor('#FFFFFF').fontSize(11)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('#B0000000').borderRadius(14)
        .position({ x: Math.max(12, Math.floor((this.pageW - 156) / 2)), y: this.safeTop() + 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.th().bg)
    .onKeyEvent((event: KeyEvent) => { this.handleVolumeKey(event); })
    .onAreaChange((_: Area, area: Area) => {
      const w: number = typeof area.width === 'number' ? area.width : Number(area.width);
      const h: number = typeof area.height === 'number' ? area.height : Number(area.height);
      if (Number.isFinite(w) && w > 0) this.pageW = w;
      if (Number.isFinite(h) && h > 0) this.pageH = h;
      if (this.pageIndex >= this.totalPages()) this.pageIndex = Math.max(0, this.totalPages() - 1);
    })
  }

  @Builder
  ScrollReader() {
    Scroll(this.readerScroller) {
      Column({ space: this.ls() * 10 }) {
        this.StatusBlocks()
        if (this.scrollContents.length > 0) {
          ForEach(this.scrollContents, (content: ReadingContent, idx: number) => {
            this.ScrollChapterSection(content, idx, idx === 0)
          }, (content: ReadingContent, idx: number) => `${content.chapterId}-${idx}`)
        } else {
          this.ScrollChapterSection(this.content || this.emptyReadingContent(), 0, true)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth() })
      .padding({
        left: this.contentPad(),
        right: this.contentPad(),
        top: this.safeTop() + 18,
        bottom: this.safeBottom() + 28,
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .enabled(!this.hasActiveReaderOverlay())
    .onScrollEdge((side: Edge) => {
      if (side === Edge.Bottom) {
        this.appendScrollContents();
      }
    })
    .onScroll((_xOffset: number, _yOffset: number) => {
      this.scheduleVisibleScrollProgressSync();
    })
    .onScrollStop(() => {
      void this.persistVisibleScrollProgress(true);
    })
    .onClick(() => this.handleContentTap())
    .onTouch((event: TouchEvent) => this.handleReaderTouch(event))
  }

  @Builder
  PagedReader() {
    Stack() {
      this.PageSurface(this.pageIndex, true, 1)

      if (this.curlActive) {
        this.PageCurlLayer()
      }

      Stack() {
        Column()
          .height('100%')
          .width(this.pageTurnZoneWidth())
          .backgroundColor('#01000000')
          .hitTestBehavior(HitTestMode.Block)
          .position({ x: 0, y: 0 })
          .onClick(() => {
            this.stopAutoRead();
            if (this.oneHandMode) {
              this.turnNextPage();
            } else {
              this.turnPrevPage();
            }
          })
        Column()
          .height('100%')
          .width(this.pageTurnZoneWidth())
          .backgroundColor('#01000000')
          .hitTestBehavior(HitTestMode.Block)
          .position({ x: Math.max(0, this.pageW - this.pageTurnZoneWidth()), y: 0 })
          .onClick(() => { this.stopAutoRead(); this.turnNextPage(); })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .onTouch((event: TouchEvent) => this.handleReaderTouch(event))
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 2 })
          .onActionStart((event: GestureEvent) => this.beginCurlDrag(event))
          .onActionUpdate((event: GestureEvent) => this.updateCurlDrag(event))
          .onActionEnd(() => this.finishCurlDrag())
          .onActionCancel(() => this.finishCurlDrag()),
        PanGesture({ fingers: 2, direction: PanDirection.Horizontal, distance: 2 })
          .onActionStart((event: GestureEvent) => this.beginCurlDrag(event))
          .onActionUpdate((event: GestureEvent) => this.updateCurlDrag(event))
          .onActionEnd(() => this.finishCurlDrag())
          .onActionCancel(() => this.finishCurlDrag())
      )
    )
  }

  @Builder
  PageSurface(pageIdx: number, interactive: boolean, visualOpacity: number) {
    Column({ space: 12 }) {
      if (this.isEndPage(this.surfacePageIndex(pageIdx, interactive))) {
        this.ChapterEndPage(this.content)
      } else {
        this.ReaderHeader()
        this.StatusBlocks()
        if (this.readingParagraphs().length > 0) {
          Column({ space: Math.max(10, this.fs() * 0.8) }) {
            ForEach(this.pageUnitsAt(this.surfacePageIndex(pageIdx, interactive)), (unit: ParagraphUnit, idx: number) => {
              this.ReaderParagraph(
                unit.text,
                unit.paragraphIndex,
                `${this.surfacePageIndex(pageIdx, interactive)}-${idx}-${unit.text.substring(0, 8)}`,
                interactive,
                unit.startOffset,
              )
            }, (unit: ParagraphUnit, idx: number) => `${this.surfacePageIndex(pageIdx, interactive)}-${idx}-${unit.paragraphIndex}-${unit.text.substring(0, 8)}`)
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          Text(!this.busyText && !this.errorText ? '当前章节暂无正文' : '')
            .fontColor(this.th().secondary).fontSize(14).lineHeight(24)
            .width('100%').textAlign(TextAlign.Center).padding({ top: 60 })
            .layoutWeight(1)
        }
        Row() {
          Text(this.pageIndicatorText())
            .fontColor(this.th().secondary)
            .fontSize(12)
          Blank()
          Text(`${Math.round(this.progress)}%`)
            .fontColor(this.th().secondary)
            .fontSize(12)
        }
        .width('100%')
        .padding({ bottom: 4 })
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: this.contentMaxWidth() })
    .padding({
      left: this.contentPad(),
      right: this.contentPad(),
      top: this.safeTop() + 18,
      bottom: this.safeBottom() + 16,
    })
    .backgroundColor(this.th().bg)
    .opacity(visualOpacity)
    .renderGroup(true)
    .onClick(() => { if (interactive) this.handleContentTap(); })
  }

  @Builder
  PageCurlLayer() {
    Stack() {
      Stack() {
        this.PageSurface(this.curlTargetPageIndex(), false, 0.96)
      }
        .width('100%')
        .height('100%')
        .scale({ x: 0.992, y: this.curlMetrics().scaleY, centerX: '50%', centerY: '50%' })

      Column() {}
        .height('100%')
        .width(this.curlMetrics().shadowWidth)
        .linearGradient({
          angle: this.curlDirection > 0 ? 90 : 270,
          colors: [['rgba(0,0,0,0)', 0], [`rgba(0,0,0,${this.curlMetrics().shadowAlpha.toFixed(2)})`, 1]],
        })
        .position({
          x: this.curlDirection > 0
            ? Math.max(0, this.curlMetrics().foldX - this.curlMetrics().shadowWidth * 0.52)
            : Math.min(this.pageW - this.curlMetrics().shadowWidth, this.curlMetrics().foldWidth * 0.48),
          y: 0,
        })
        .blur(1.8)

      Stack() {
        Stack() {
          this.PageSurface(this.pageIndex, false, 0.78)
        }
          .width('100%')
          .height('100%')
          .scale({
            x: this.curlDirection > 0 ? -1 : 1,
            y: 1,
            centerX: this.curlDirection > 0 ? '100%' : '0%',
            centerY: '50%',
          })

        Column() {}
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: this.curlDirection > 0 ? 90 : 270,
            colors: [
              [`rgba(255,255,255,${this.curlMetrics().highlightAlpha.toFixed(2)})`, 0],
              ['rgba(255,255,255,0.06)', 0.34],
              ['rgba(0,0,0,0.18)', 0.72],
              ['rgba(0,0,0,0.04)', 1],
            ],
          })

        Path({
          width: this.curlMetrics().foldWidth,
          height: this.pageH,
          commands: this.curlMetrics().curvePath,
        })
          .fill('transparent')
          .stroke(`rgba(255,255,255,${this.curlMetrics().highlightAlpha.toFixed(2)})`)
          .strokeWidth(2.2)
          .opacity(0.92)

        Column() {}
          .width(this.curlMetrics().thickness)
          .height('100%')
          .linearGradient({
            angle: this.curlDirection > 0 ? 90 : 270,
            colors: [['rgba(255,255,255,0.62)', 0], ['rgba(177,154,113,0.48)', 0.48], ['rgba(0,0,0,0.22)', 1]],
          })
          .position({
            x: this.curlDirection > 0
              ? Math.max(0, this.curlMetrics().foldWidth - this.curlMetrics().thickness)
              : 0,
            y: 0,
          })
      }
      .width(this.curlMetrics().foldWidth)
      .height('100%')
      .clip(true)
      .renderGroup(true)
      .position({ x: this.curlMetrics().foldX, y: 0 })
      .translate({ x: this.curlDirection > 0 ? -this.curlMetrics().depth : this.curlMetrics().depth, y: 0, z: this.curlMetrics().depth })
      .rotate({
        y: this.curlDirection > 0 ? 1 : -1,
        z: 1,
        angle: this.curlMetrics().rotateY,
        centerX: this.curlDirection > 0 ? '100%' : '0%',
        centerY: this.curlMetrics().cornerY,
        perspective: 900,
      })
      .rotate({
        z: 1,
        angle: this.curlMetrics().rotateZ,
        centerX: this.curlDirection > 0 ? '100%' : '0%',
        centerY: this.curlMetrics().cornerY,
      })
      .shadow({
        radius: 22 + this.curlMetrics().depth,
        color: `rgba(0,0,0,${this.curlMetrics().shadowAlpha.toFixed(2)})`,
        offsetX: this.curlDirection > 0 ? -10 : 10,
        offsetY: 8,
      })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  ReaderHeader() {
    if (this.content) {
      Column({ space: 10 }) {
        Text(this.scriptText(this.content.chapterTitle))
          .fontColor(this.th().text)
          .fontFamily(this.appFont())
          .fontSize(this.pageMode === 'page' ? 22 : 24)
          .fontWeight(FontWeight.Bold)
          .lineHeight(this.pageMode === 'page' ? 30 : 34)
          .textAlign(TextAlign.Center)
          .maxLines(this.pageMode === 'page' ? 2 : 3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.bundle.book.author) {
          Text(this.bundle.book.author)
            .fontColor(this.th().secondary)
            .fontSize(14)
        }
      }
      .width('100%')
      .padding({ top: 6, bottom: 8 })
    }
  }

  @Builder
  StatusBlocks() {
    if (this.errorText) {
      Text(this.errorText)
        .fontColor('#B30000').fontSize(13).padding(12)
        .backgroundColor('#FFE8E8').borderRadius(8).width('100%')
    }
    if (this.busyText) {
      Text(this.busyText)
        .fontColor(this.th().secondary).fontSize(12)
        .width('100%').textAlign(TextAlign.Center)
    }
  }

  @Builder
  ScrollChapterSection(content: ReadingContent, idx: number, isFirst: boolean) {
    Column({ space: Math.max(14, this.fs() * 0.9) }) {
      this.ScrollChapterHeader(content, idx)
      if (this.paragraphsFor(content).length > 0) {
        ForEach(this.paragraphsFor(content), (p: string, pIdx: number) => {
          this.ScrollReaderParagraph(content, p, pIdx)
        }, (p: string, pIdx: number) => `${content.chapterId}-${pIdx}-${p.substring(0, 8)}`)
      } else if (!this.busyText && !this.errorText) {
        Text('当前章节暂无正文')
          .fontColor(this.th().secondary).fontSize(14).lineHeight(24)
          .width('100%').textAlign(TextAlign.Center).padding({ top: 40, bottom: 40 })
      }
      this.ChapterEndPage(content)
      if (this.scrollLoading && idx === this.scrollContents.length - 1) {
        Text('正在继续加载后续章节...')
          .fontColor(this.th().secondary)
          .fontSize(12)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
      }
    }
    .width('100%')
    .padding({ top: isFirst ? 0 : 34, bottom: 20 })
    .onAppear(() => {
      if (isFirst && this.pageMode === 'scroll') {
        const chapterIndex: number = this.chapterIndexForId(content.chapterId);
        if (chapterIndex >= 0) {
          this.visibleScrollChapterIndex = chapterIndex;
        }
      }
    })
  }

  @Builder
  ScrollChapterHeader(content: ReadingContent, idx: number) {
    Column({ space: 10 }) {
      if (idx > 0) {
        Divider()
          .color(this.th().divider)
          .strokeWidth(0.5)
          .margin({ bottom: 20 })
      }
      Text(this.scriptText(content.chapterTitle || `第${idx + 1}章`))
        .fontColor(this.th().text)
        .fontFamily(this.appFont())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .lineHeight(34)
        .textAlign(TextAlign.Center)
        .width('100%')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.bundle.book.author) {
        Text(this.bundle.book.author)
          .fontColor(this.th().secondary)
          .fontSize(14)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: idx > 0 ? 8 : 6, bottom: 10 })
  }

  @Builder
  ScrollReaderParagraph(content: ReadingContent, text: string, paragraphIndex: number) {
    Text() {
      ForEach(this.textRunsForUnit(text, paragraphIndex, 0), (run: TextRun, idx: number) => {
        Span(this.scriptText(run.text))
          .textBackgroundStyle({
            color: run.highlighted ? '#F8DCDC' : (run.selected ? '#F6E6E2' : '#00FFFFFF'),
            radius: 4,
          })
      }, (run: TextRun, idx: number) => `${idx}-${run.highlighted}-${run.selected}-${run.text.substring(0, 8)}`)
    }
      .fontColor(this.th().text)
      .fontFamily(this.appFont())
      .fontSize(this.fs())
      .lineHeight(this.fs() * this.ls())
      .textIndent(this.fs() * 2)
      .textAlign(TextAlign.Start)
      .width('100%')
      .padding({ left: 3, right: 3, top: 4, bottom: 4 })
      .backgroundColor(content.chapterId === this.chapterId && this.isMarked(paragraphIndex) ? '#F8DCDC' : 'transparent')
      .borderRadius(4)
      .copyOption(CopyOptions.InApp)
      .onTextSelectionChange((start: number, end: number) => {
        this.selectTextRangeInContent(content, paragraphIndex, text, 0, start, end);
      })
  }

  @Builder
  ScrollParagraphs() {
    if (this.content) {
      if (this.paragraphsFor(this.content).length > 0) {
        ForEach(this.paragraphsFor(this.content), (p: string, idx: number) => {
          this.ReaderParagraph(p, idx, `${idx}-${p.substring(0, 8)}`, true)
        }, (p: string, idx: number) => `${idx}-${p.substring(0, 8)}`)
      } else if (!this.busyText && !this.errorText) {
        Text('当前章节暂无正文')
          .fontColor(this.th().secondary).fontSize(14).lineHeight(24)
          .width('100%').textAlign(TextAlign.Center).padding({ top: 60 })
      }
    } else if (!this.busyText && !this.errorText) {
      Text('当前章节暂无正文')
        .fontColor(this.th().secondary).fontSize(14).lineHeight(24)
        .width('100%').textAlign(TextAlign.Center).padding({ top: 60 })
    }
  }

  @Builder
  ReaderParagraph(text: string, paragraphIndex: number, key: string, interactive: boolean = true, unitStartOffset: number = 0) {
    Text() {
      ForEach(this.textRunsForUnit(text, paragraphIndex, unitStartOffset), (run: TextRun, idx: number) => {
        Span(this.scriptText(run.text))
          .textBackgroundStyle({
            color: run.highlighted ? '#F8DCDC' : (run.selected ? '#F6E6E2' : '#00FFFFFF'),
            radius: 4,
          })
      }, (run: TextRun, idx: number) => `${key}-${idx}-${run.highlighted}-${run.selected}-${run.text.substring(0, 8)}`)
    }
      .fontColor(this.th().text)
      .fontFamily(this.appFont())
      .fontSize(this.fs())
      .lineHeight(this.fs() * this.ls())
      .textIndent(this.fs() * 2)
      .textAlign(TextAlign.Start)
      .width('100%')
      .padding({ left: 3, right: 3, top: 4, bottom: 4 })
      .backgroundColor(this.isMarked(paragraphIndex) ? '#F8DCDC' : 'transparent')
      .border({
        width: this.selectedParagraphIndex === paragraphIndex && this.showParagraphToolbar ? 0.8 : 0,
        color: '#D9827C',
      })
      .borderRadius(4)
      .onClick(() => { if (interactive) this.handleContentTap(); })
      .copyOption(interactive ? CopyOptions.InApp : CopyOptions.None)
      .onTextSelectionChange((start: number, end: number) => {
        if (interactive) {
          this.selectTextRange(paragraphIndex, text, unitStartOffset, start, end);
        }
      })
  }

  @Builder
  ChapterFooter() {
    this.ChapterEndPage(this.content)
  }

  @Builder
  ChapterEndPage(content: ReadingContent | null) {
    if (content && !this.busyText) {
      Column({ space: 14 }) {
        Divider().color(this.th().divider).strokeWidth(0.5)
        Text('本章结束')
          .fontColor(this.th().secondary).fontSize(13)
          .width('100%').textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ top: 20, bottom: 28 })
      .hitTestBehavior(HitTestMode.Block)
      .onVisibleAreaChange([0.35], (isExpanding: boolean, currentRatio: number) => {
        if (isExpanding && currentRatio >= 0.35) {
          void this.syncChapterEndProgress(content);
        }
      })
      .onClick(() => {
        this.activateScrollChapter(content);
        this.handleContentTap();
      })
    }
  }

  @Builder
  ToolbarDismissLayer() {
    Column()
      .width('100%')
      .height(this.toolbarDismissHeight())
      .backgroundColor('#01000000')
      .hitTestBehavior(HitTestMode.Block)
      .position({ x: 0, y: this.toolbarDismissTop() })
      .zIndex(4)
      .onClick(() => this.hideBarsFromOverlay())
  }

  @Builder
  ToolbarHitLayer() {
    Stack() {
      Column()
        .width(this.toolbarActionWidth())
        .height(48)
        .backgroundColor('#01000000')
        .hitTestBehavior(HitTestMode.Block)
        .position({ x: this.toolbarContentLeft(), y: this.toolbarTopActionTop() })
        .onClick(() => this.runToolbarAction(() => {
          this.stopAutoRead();
          this.saveProgress();
          goBack();
        }))

      Column()
        .width(this.toolbarActionWidth())
        .height(48)
        .backgroundColor('#01000000')
        .hitTestBehavior(HitTestMode.Block)
        .position({
          x: this.toolbarContentLeft() + this.toolbarContentMaxWidth() - this.toolbarActionWidth(),
          y: this.toolbarTopActionTop(),
        })
        .onClick(() => this.runToolbarAction(() => this.openReaderCatalog()))

      Column()
        .width(this.toolbarBottomSegmentWidth())
        .height(this.bottomBarHeight())
        .backgroundColor('#01000000')
        .hitTestBehavior(HitTestMode.Block)
        .position({ x: this.toolbarContentLeft(), y: this.bottomBarTop() })
        .onClick(() => this.runToolbarAction(() => this.openReaderCatalog()))

      Column()
        .width(this.toolbarBottomSegmentWidth())
        .height(this.bottomBarHeight())
        .backgroundColor('#01000000')
        .hitTestBehavior(HitTestMode.Block)
        .position({ x: this.toolbarContentLeft() + this.toolbarBottomSegmentWidth(), y: this.bottomBarTop() })
        .onClick(() => this.runToolbarAction(() => {
          this.themeKey = this.themeKey === 'dark' ? 'parchment' : 'dark';
        }))

      Column()
        .width(this.toolbarBottomSegmentWidth())
        .height(this.bottomBarHeight())
        .backgroundColor('#01000000')
        .hitTestBehavior(HitTestMode.Block)
        .position({ x: this.toolbarContentLeft() + this.toolbarBottomSegmentWidth() * 2, y: this.bottomBarTop() })
        .onClick(() => this.runToolbarAction(() => this.openReaderSettings()))

      Column()
        .width(this.toolbarBottomSegmentWidth())
        .height(this.bottomBarHeight())
        .backgroundColor('#01000000')
        .hitTestBehavior(HitTestMode.Block)
        .position({ x: this.toolbarContentLeft() + this.toolbarBottomSegmentWidth() * 3, y: this.bottomBarTop() })
        .onClick(() => this.runToolbarAction(() => this.openAiSheet()))
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
    .position({ x: 0, y: 0 })
    .zIndex(7)
  }

  @Builder
  TopBar() {
    Column() {
      Row({ space: 10 }) {
        Button('<')
          .fontColor(this.th().barText).fontSize(24)
          .width(44).height(44)
          .backgroundColor('#01000000')
          .borderRadius(0)
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => this.runToolbarAction(() => {
            this.stopAutoRead();
            this.saveProgress();
            goBack();
          }))

        Column({ space: 1 }) {
          Text(this.bundle.book.title || '阅读')
            .fontColor(this.th().barText).fontSize(15).fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.content) {
            Text(this.content.chapterTitle)
              .fontColor(this.th().secondary).fontSize(12)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)

        Text(this.pageMode === 'page' ? this.pageIndicatorText() : `${this.progress}%`)
          .fontColor(this.th().secondary).fontSize(12)

        Button('≡')
          .fontColor(this.th().barText).fontSize(22)
          .width(44).height(44)
          .backgroundColor('#01000000')
          .borderRadius(0)
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => this.runToolbarAction(() => this.openReaderCatalog()))
      }
      .width('100%')
      .constraintSize({ maxWidth: this.toolbarContentMaxWidth() })
      .height(48)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(this.topBarHeight())
    .padding({ top: this.safeTop(), left: 0, right: 0 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.th().barBg)
    .border({ width: { bottom: 0.5 }, color: this.th().divider })
    .hitTestBehavior(HitTestMode.Transparent)
    .opacity(Math.max(0.01, this.toolbarProgress))
    .translate({ x: 0, y: Math.round((this.toolbarProgress - 1) * 28), z: 0 })
    .position({ x: 0, y: 0 })
    .zIndex(5)
  }

  @Builder
  BottomBar() {
    Column() {
      Row() {}
        .width('100%')
        .height(0.5)
        .backgroundColor(this.th().divider)

      Row({ space: 0 }) {
        this.BottomAction('≡', '目录', () => this.openReaderCatalog())
        this.BottomAction(this.themeKey === 'dark' ? '☀' : '☾', '夜间', () => {
          this.toggleNightTheme();
        })
        this.BottomAction('A', '设置', () => this.openReaderSettings())
        this.BottomAction('AI', 'AI导读', () => this.openAiSheet())
      }
      .width('100%')
      .constraintSize({ maxWidth: this.toolbarContentMaxWidth() })
      .height(60)
    }
    .width('100%')
    .height(this.bottomBarHeight())
    .padding({ bottom: this.safeBottom(), left: 0, right: 0 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.th().barBg)
    .hitTestBehavior(HitTestMode.Block)
    .opacity(Math.max(0.01, this.toolbarProgress))
    .translate({ x: 0, y: Math.round((1 - this.toolbarProgress) * 34), z: 0 })
    .position({ x: 0, y: this.bottomBarTop() })
    .zIndex(5)
  }

  @Builder
  BottomAction(icon: string, label: string, action: () => void) {
    Button(icon === 'AI' ? label : `${icon} ${label}`)
      .fontColor(this.th().barText)
      .fontSize(13)
      .fontWeight(icon === 'AI' ? FontWeight.Bold : FontWeight.Regular)
      .backgroundColor('#01000000')
      .borderRadius(0)
      .layoutWeight(1)
      .height(58)
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => this.runToolbarAction(action))
  }

  @Builder
  ParagraphToolbar() {
    Row({ space: 0 }) {
      this.ParagraphTool('标记', () => { this.markSelected(); })
      this.ParagraphTool('分享', () => {
        this.shareHint = '';
        this.showParagraphToolbar = false;
        setTimeout(() => {
          this.showShareSheet = true;
        }, 80);
      })
      this.ParagraphTool('评论', () => {
        this.showParagraphToolbar = false;
        setTimeout(() => {
          this.openCommentSheet();
        }, 80);
      })
    }
    .height(58)
    .padding({ left: 12, right: 12 })
    .backgroundColor('#E6000000')
    .borderRadius(18)
    .shadow({ radius: 16, color: '#33000000', offsetX: 0, offsetY: 6 })
    .position({
      x: Math.max(18, Math.floor((this.pageW - Math.min(300, this.pageW - 36)) / 2)),
      y: Math.max(this.safeTop() + 62, Math.floor(this.pageH * 0.42)),
    })
    .width(Math.min(300, this.pageW - 36))
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  ParagraphTool(label: string, action: () => void) {
    Column({ space: 4 }) {
      Text(label === '问AI' ? 'AI' : label.substring(0, 1))
        .fontColor('#FFFFFF')
        .fontSize(label === '问AI' ? 13 : 16)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontColor('#E8E8E8')
        .fontSize(11)
    }
    .layoutWeight(1)
    .height(54)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.Block)
    .onClick(() => this.runToolbarAction(action))
  }

  @Builder
  CatalogSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .opacity(this.catalogSheetProgress)
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => this.closeReaderCatalog())
        .zIndex(1)

      Column({ space: 0 }) {
        Row({ space: 12 }) {
          Text('目录')
            .fontColor(this.th().text).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
          Button('×')
            .fontColor(this.th().barText).fontSize(18)
            .width(34).height(34)
            .borderRadius(17).backgroundColor('#15000000')
            .onClick(() => this.closeReaderCatalog())
        }
        .width('100%').padding({ left: 20, right: 16, top: 16, bottom: 12 })
        Divider().color(this.th().divider).strokeWidth(0.5)
        if (this.chapters.length === 0) {
          Column() {
            Text('暂无章节目录')
              .fontColor(this.th().secondary).fontSize(14).padding({ top: 60 })
          }
          .width('100%').layoutWeight(1)
        } else {
          List({ scroller: this.catalogScroller }) {
            ForEach(this.chapters, (ch: ReadingChapter, idx: number) => {
              ListItem() {
                Column({ space: 0 }) {
                  Row({ space: 12 }) {
                    Text(`${idx + 1}`)
                      .fontColor(this.chKey(ch) === this.chapterId ? '#FFFFFF' : this.th().secondary)
                      .fontSize(12).fontWeight(FontWeight.Medium)
                      .width(28).height(28).textAlign(TextAlign.Center)
                      .borderRadius(14)
                      .backgroundColor(this.chKey(ch) === this.chapterId ? this.th().accent : this.th().divider)
                    Column({ space: 2 }) {
                      Text(ch.title)
                        .fontColor(this.chKey(ch) === this.chapterId ? this.th().accent : this.th().text)
                        .fontSize(15)
                        .fontWeight(this.chKey(ch) === this.chapterId ? FontWeight.Bold : FontWeight.Regular)
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      if (ch.summary) {
                        Text(ch.summary)
                          .fontColor(this.th().secondary).fontSize(12)
                          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                    }
                    .layoutWeight(1).alignItems(HorizontalAlign.Start)
                    if (this.chKey(ch) === this.chapterId) {
                      Text('<').fontColor(this.th().accent).fontSize(12)
                    }
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                  .backgroundColor('#01000000')
                  if (idx < this.chapters.length - 1) {
                    Divider().color(this.th().divider).strokeWidth(0.3).margin({ left: 56 })
                  }
                }
                .width('100%')
              }
              .width('100%')
              .onClick(() => { this.markToolbarTap(); this.loadChapter(ch); })
            }, (ch: ReadingChapter) => this.chKey(ch))
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .hitTestBehavior(HitTestMode.Default)
          .gesture(
            PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 2 })
              .onActionStart(() => this.beginCatalogDrag())
              .onActionUpdate((event: GestureEvent) => this.updateCatalogDrag(event))
          )
        }
      }
      .width('100%')
      .height('70%')
      .constraintSize({ maxWidth: this.pageW >= 900 ? 760 : this.pageW })
      .backgroundColor(this.th().bg)
      .borderRadius({ topLeft: 18, topRight: 18 })
      .shadow({ radius: 20, color: '#30000000', offsetX: 0, offsetY: -8 })
      .opacity(Math.max(0.01, this.catalogSheetProgress))
      .scale({ x: 0.98 + this.catalogSheetProgress * 0.02, y: 0.98 + this.catalogSheetProgress * 0.02, centerX: '50%', centerY: '100%' })
      .translate({ x: 0, y: Math.round((1 - this.catalogSheetProgress) * 60), z: 0 })
      .hitTestBehavior(HitTestMode.Default)
      .zIndex(2)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(5)
  }

  @Builder
  SettingsSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .opacity(this.settingsSheetProgress)
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => this.closeReaderSettings())

      Column({ space: 0 }) {
        Row({ space: 12 }) {
          Text('阅读设置')
            .fontColor(this.th().text).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
          Button('×')
            .fontColor(this.th().barText).fontSize(18)
            .width(34).height(34)
            .borderRadius(17).backgroundColor('#15000000')
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => this.closeReaderSettings())
        }
        .width('100%').padding({ left: 20, right: 16, top: 16, bottom: 12 })
        Divider().color(this.th().divider).strokeWidth(0.5)
        Scroll() {
          Column({ space: 22 }) {
            this.ModeSetting()
            this.BrightnessSetting()
            this.AutoReadSetting()
            this.FontSetting()
            this.LineSetting()
            this.ThemeSetting()
            this.PlanSetting()
          }
          .width('100%').padding({ left: 20, right: 20, top: 18, bottom: 36 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .hitTestBehavior(HitTestMode.Default)
      }
      .width('100%')
      .height('64%')
      .constraintSize({ maxWidth: this.pageW >= 900 ? 760 : this.pageW })
      .backgroundColor(this.th().bg)
      .borderRadius({ topLeft: 18, topRight: 18 })
      .shadow({ radius: 20, color: '#30000000', offsetX: 0, offsetY: -8 })
      .opacity(Math.max(0.01, this.settingsSheetProgress))
      .scale({ x: 0.98 + this.settingsSheetProgress * 0.02, y: 0.98 + this.settingsSheetProgress * 0.02, centerX: '50%', centerY: '100%' })
      .translate({ x: 0, y: Math.round((1 - this.settingsSheetProgress) * 60), z: 0 })
      .hitTestBehavior(HitTestMode.Default)
      .zIndex(2)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(12)
  }

  @Builder
  ModeSetting() {
    Column({ space: 10 }) {
      Row() {
        Text('阅读模式').fontColor(this.th().text).fontSize(15)
        Blank()
        Text(this.pageMode === 'scroll' ? '上下滚动' : '左右翻页')
          .fontColor(this.th().secondary).fontSize(13)
      }
      .width('100%')
      Row({ space: 8 }) {
        this.ModeCard('scroll', '滚动', '纵向连续阅读')
        this.ModeCard('page', '翻页', '点击左右区域翻页')
      }
      .width('100%')
    }
  }

  @Builder
  ModeCard(mode: string, title: string, sub: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontColor(this.pageMode === mode ? '#FFFFFF' : this.th().text)
        .fontSize(14).fontWeight(FontWeight.Bold)
      Text(sub)
        .fontColor(this.pageMode === mode ? '#F8F3E8' : this.th().secondary)
        .fontSize(11)
    }
    .height(58).layoutWeight(1)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(this.pageMode === mode ? this.th().accent : this.th().barBg)
    .border({ width: this.pageMode === mode ? 0 : 1, color: this.th().divider })
    .borderRadius(14)
    .hitTestBehavior(HitTestMode.Block)
    .onClick(() => { this.markToolbarTap(); this.setReaderMode(mode); })
  }

  @Builder
  BrightnessSetting() {
    Column({ space: 10 }) {
      Row() {
        Text('亮度').fontColor(this.th().text).fontSize(15)
        Blank()
        Text(this.brightnessPercent()).fontColor(this.th().secondary).fontSize(13)
      }
      .width('100%')
      Slider({ value: this.brightValue(), min: 0.2, max: 1.0, step: 0.05, style: SliderStyle.InSet })
        .blockColor(this.th().accent)
        .trackColor(this.th().divider)
        .selectedColor(this.th().accent)
        .trackThickness(4)
        .onChange((v: number) => {
          for (let i = 0; i < BRIGHTNESS_STEPS.length; i++) {
            if (v <= BRIGHTNESS_STEPS[i] + 0.025) { this.brightnessIdx = i; return; }
          }
          this.brightnessIdx = BRIGHTNESS_STEPS.length - 1;
        })
    }
  }

  @Builder
  AutoReadSetting() {
    Column({ space: 10 }) {
      Row() {
        Text('自动阅读').fontColor(this.th().text).fontSize(15)
        Blank()
        Text(this.autoReadActive ? `${this.autoReadSpeedLabel()} · ${this.autoReadSeconds()} 秒/页` : '已关闭')
          .fontColor(this.autoReadActive ? this.th().accent : this.th().secondary).fontSize(13)
      }
      .width('100%')
      Button(this.autoReadActive ? '停止自动阅读' : '开启自动阅读')
        .width('100%').height(40).fontSize(14)
        .fontColor(this.autoReadActive ? '#FFFFFF' : this.th().barText)
        .backgroundColor(this.autoReadActive ? this.th().accent : this.th().barBg)
        .borderRadius(20).border({ width: this.autoReadActive ? 0 : 1, color: this.th().divider })
        .onClick(() => { this.markToolbarTap(); this.toggleAutoRead(); })
      Row({ space: 6 }) {
        ForEach(AUTO_READ_SPEEDS, (s: AutoReadSpeedDef, idx: number) => {
          Text(`${s.label} ${s.seconds}s`)
            .fontSize(12)
            .fontColor(idx === this.autoReadSpeedIdx ? '#FFFFFF' : this.th().text)
            .width(72).height(30).borderRadius(15)
            .backgroundColor(idx === this.autoReadSpeedIdx ? this.th().accent : this.th().barBg)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.markToolbarTap();
              this.autoReadSpeedIdx = idx;
              if (this.autoReadActive) {
                this.stopAutoRead();
                this.startAutoRead();
              }
            })
        }, (s: AutoReadSpeedDef) => `${s.label}-${s.seconds}`)
      }
      .width('100%')
    }
  }

  @Builder
  FontSetting() {
    Column({ space: 10 }) {
      Row() {
        Text('字号').fontColor(this.th().text).fontSize(15)
        Blank()
        Text(`${this.fs()}`).fontColor(this.th().secondary).fontSize(13)
      }
      .width('100%')
      Row({ space: 14 }) {
        Button('A-')
          .width(64).height(38)
          .fontSize(14)
          .fontColor(this.canDecreaseFont() ? this.th().barText : this.th().secondary)
          .backgroundColor(this.th().barBg)
          .borderRadius(19)
          .border({ width: 1, color: this.th().divider })
          .enabled(this.canDecreaseFont())
          .onClick(() => { this.markToolbarTap(); this.changeFontSize(-1); })
        Text(`${this.fs()}`)
          .layoutWeight(1)
          .height(38)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.th().text)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.th().barBg)
          .borderRadius(19)
        Button('A+')
          .width(64).height(38)
          .fontSize(14)
          .fontColor(this.canIncreaseFont() ? this.th().barText : this.th().secondary)
          .backgroundColor(this.th().barBg)
          .borderRadius(19)
          .border({ width: 1, color: this.th().divider })
          .enabled(this.canIncreaseFont())
          .onClick(() => { this.markToolbarTap(); this.changeFontSize(1); })
      }
      .width('100%')
    }
  }

  @Builder
  LineSetting() {
    Column({ space: 10 }) {
      Row() {
        Text('行间距').fontColor(this.th().text).fontSize(15)
        Blank()
        Text(`${this.ls().toFixed(1)}`).fontColor(this.th().secondary).fontSize(13)
      }
      .width('100%')
      Row({ space: 8 }) {
        ForEach(LINE_SPACINGS, (s: number, idx: number) => {
          Text(`${s.toFixed(1)}`)
            .fontSize(13)
            .fontColor(idx === this.lineSpacingIdx ? '#FFFFFF' : this.th().text)
            .fontWeight(idx === this.lineSpacingIdx ? FontWeight.Bold : FontWeight.Regular)
            .width(46).height(34).borderRadius(17)
            .backgroundColor(idx === this.lineSpacingIdx ? this.th().accent : this.th().barBg)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.markToolbarTap(); this.lineSpacingIdx = idx; this.resetPaging(); })
        }, (s: number) => `${s}`)
      }
      .width('100%')
    }
  }

  @Builder
  ThemeSetting() {
    Column({ space: 10 }) {
      Text('主题').fontColor(this.th().text).fontSize(15)
      Row({ space: 10 }) {
        ForEach(ALL_THEME_KEYS, (k: string) => {
          Column({ space: 6 }) {
            Column() {}
              .width(44).height(44).borderRadius(22)
              .backgroundColor(this.themeByKey(k).bg)
              .border({ width: this.themeKey === k ? 3 : 1, color: this.themeKey === k ? this.th().accent : this.th().divider })
            Text(this.themeByKey(k).name)
              .fontColor(this.themeKey === k ? this.th().accent : this.th().secondary)
              .fontSize(11)
          }
          .alignItems(HorizontalAlign.Center)
          .onClick(() => { this.markToolbarTap(); this.selectTheme(k); })
        }, (k: string) => k)
      }
      .width('100%').justifyContent(FlexAlign.Start)
    }
  }

  @Builder
  PlanSetting() {
    if (!this.bundle.plan) {
      Button('创建阅读计划，记录进度')
        .width('100%').height(44).fontSize(15).fontColor('#FFFFFF')
        .backgroundColor(this.th().accent).borderRadius(22)
        .onClick(() => { this.markToolbarTap(); this.createPlan(); })
    } else {
      Row({ space: 12 }) {
        Text('当前计划')
          .fontColor(this.th().secondary).fontSize(13)
        Text(`${this.progress}%`)
          .fontColor(this.th().accent).fontSize(22).fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%').padding({ top: 6 })
    }
  }

  @Builder
  AiSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .opacity(this.aiSheetProgress)
        .onClick(() => this.closeAiSheet())
      Column({ space: 14 }) {
        Row() {
          Column({ space: 4 }) {
            Text('AI 导读')
              .fontColor('#141414')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
            Text(this.content ? this.content.chapterTitle : this.bundle.book.title)
              .fontColor('#8A8A8A')
              .fontSize(12)
              .maxLines(1)
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start)
          Button('×')
            .fontColor('#777777')
            .fontSize(22)
            .width(36).height(36)
            .borderRadius(18)
            .backgroundColor('#15000000')
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => this.closeAiSheet())
        }
        .width('100%')

        TextInput({ placeholder: '想问点什么？', text: this.aiQuestion })
          .height(46)
          .fontColor('#222222')
          .placeholderColor('#6F7378')
          .backgroundColor('#EEF0F2')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => { this.aiQuestion = value; })

        Stack({ alignContent: Alignment.Center }) {
          Button(this.aiBusy ? '' : '提问')
            .width('100%')
            .height(42)
            .fontSize(15)
            .fontColor('#FFFFFF')
            .backgroundColor(this.aiBusy ? '#B7A172' : '#8F6B22')
            .borderRadius(21)
            .enabled(!this.aiBusy)
            .onClick(() => this.askAi())

          if (this.aiBusy) {
            Row({ space: 7 }) {
              LoadingProgress()
                .width(14)
                .height(14)
                .color('#FFFFFF')
              Text('思考中')
                .fontColor('#FFFFFF')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
            }
            .hitTestBehavior(HitTestMode.None)
          }
        }
        .width('100%')
        .height(42)

        if (this.aiError) {
          Text(this.aiError)
            .fontColor('#B30000')
            .fontSize(13)
            .lineHeight(19)
            .padding(10)
            .backgroundColor('#FFF0F0')
            .borderRadius(10)
            .width('100%')
        }
        Scroll() {
          AiResponseView({
            answer: this.aiAnswer,
            reasoning: this.aiReasoning,
            followUpSuggestion: this.aiFollowUp,
            sources: this.aiSources,
            toolTrace: this.aiToolTrace,
            busy: this.aiBusy,
            statusText: this.aiStatusText,
            emptyText: '',
            compact: true,
            maxAnswerLines: 0,
          })
        }
        .height(Math.min(320, Math.max(170, this.pageH * 0.36)))
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('66%')
      .constraintSize({ maxWidth: this.pageW >= 900 ? 760 : this.pageW })
      .padding({ left: 18, right: 18, top: 18, bottom: 18 })
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
      .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: -8 })
      .opacity(Math.max(0.01, this.aiSheetProgress))
      .scale({ x: 0.98 + this.aiSheetProgress * 0.02, y: 0.98 + this.aiSheetProgress * 0.02, centerX: '50%', centerY: '100%' })
      .translate({ x: 0, y: Math.round((1 - this.aiSheetProgress) * 60), z: 0 })
      .hitTestBehavior(HitTestMode.Default)
      .zIndex(2)
    }
    .width('100%')
    .height('100%')
    .zIndex(12)
  }

  @Builder
  CommentSheet() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#77000000')
        .onClick(() => { this.showCommentSheet = false; })

      Column({ space: 12 }) {
        Row() {
          Column({ space: 4 }) {
            Text('段落评论')
              .fontColor('#222222')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
            Text(this.selectedParagraphText())
              .fontColor('#777777')
              .fontSize(12)
              .lineHeight(18)
              .maxLines(2)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text('×')
            .fontColor('#777777')
            .fontSize(22)
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.showCommentSheet = false; })
        }
        .width('100%')

        if (this.commentError) {
          Text(this.commentError)
            .fontColor('#B30000')
            .fontSize(12)
            .lineHeight(18)
            .padding(10)
            .backgroundColor('#FFF0F0')
            .borderRadius(10)
            .width('100%')
        }

        TextArea({ placeholder: '写下你的评论', text: this.commentInput })
          .height(78)
          .fontColor('#222222')
          .placeholderColor('#999999')
          .backgroundColor('#F5F6F7')
          .borderRadius(14)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onChange((value: string) => { this.commentInput = value; })

        Button(this.commentBusy ? '发送中' : '发送评论')
          .width('100%')
          .height(42)
          .fontSize(15)
          .fontColor('#FFFFFF')
          .backgroundColor(this.commentBusy ? '#B7A172' : '#8F6B22')
          .borderRadius(21)
          .enabled(!this.commentBusy)
          .onClick(() => this.submitReaderComment())

        Scroll() {
          Column({ space: 8 }) {
            if (this.readerComments.length === 0 && !this.commentBusy) {
              Text('还没有评论')
                .fontColor('#777777')
                .fontSize(13)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 18, bottom: 18 })
            } else {
              ForEach(this.readerComments, (comment: ReaderComment) => {
                Column({ space: 5 }) {
                  Row() {
                    Text(comment.userName || '同学')
                      .fontColor('#333333')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                    Blank()
                    Text(comment.createdAt || '')
                      .fontColor('#A0A0A0')
                      .fontSize(11)
                  }
                  .width('100%')

                  Text(comment.content || '')
                    .fontColor('#555555')
                    .fontSize(13)
                    .lineHeight(19)
                }
                .width('100%')
                .padding(10)
                .backgroundColor('#F7F2E8')
                .borderRadius(10)
              }, (comment: ReaderComment) => `${comment.id}`)
            }
          }
          .width('100%')
        }
        .height(Math.min(220, Math.max(130, this.pageH * 0.24)))
        .scrollBar(BarState.Off)
      }
      .width(this.pageW >= 720 ? 520 : Math.max(300, this.pageW - 32))
      .padding({ left: 18, right: 18, top: 18, bottom: 18 })
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .shadow({ radius: 28, color: '#33000000', offsetX: 0, offsetY: 12 })
      .position({
        x: this.pageW >= 720 ? Math.floor((this.pageW - 520) / 2) : 16,
        y: Math.max(this.safeTop() + 24, Math.floor(this.pageH * 0.12)),
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ShareSheet() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#77000000')
        .onClick(() => { this.showShareSheet = false; })
      Column({ space: 16 }) {
        Column({ space: 14 }) {
          Row({ space: 10 }) {
            if (this.shareAvatarUrl()) {
              Image(ApiClient.resourceUrl(this.shareAvatarUrl()))
                .width(34)
                .height(34)
                .borderRadius(17)
                .objectFit(ImageFit.Cover)
            } else {
              Text(this.shareUserName().substring(0, 1))
                .width(34)
                .height(34)
                .fontSize(14)
                .fontColor('#5C6F5D')
                .fontWeight(FontWeight.Bold)
                .textAlign(TextAlign.Center)
                .backgroundColor('#E6EDE0')
                .borderRadius(17)
            }
            Column({ space: 4 }) {
              Text(this.shareUserName())
                .fontColor('#303030')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
              Text(`标记于 ${this.shareTimeText()}`)
                .fontColor('#9A9A9A')
                .fontSize(12)
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          Text(this.selectedParagraphText())
            .fontColor('#333333')
            .fontSize(20)
            .lineHeight(30)
            .fontWeight(FontWeight.Regular)
          Column({ space: 4 }) {
            Text(`/ 引自《${this.bundle.book.title || '未知图书'}》`)
              .fontColor('#8E8E8E')
              .fontSize(13)
            Text(this.chapterTitleForId(this.selectedChapterId || this.chapterId))
              .fontColor('#AAAAAA')
              .fontSize(12)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 24, bottom: 26 })
        .backgroundColor('#FFFFFF')
        .borderRadius(22)

        Column({ space: 16 }) {
          Row({ space: 14 }) {
            this.ShareAction('微信')
            this.ShareAction('朋友圈')
            this.ShareAction('QQ')
            this.ShareAction('微博')
            this.ShareAction('动态')
          }
          .width('100%')
          Row({ space: 14 }) {
            this.ShareAiGuideAction()
            this.ShareAction('复制链接')
            this.ShareAction('保存图片')
            Blank().layoutWeight(1)
            Blank().layoutWeight(1)
          }
          .width('100%')
        }
        .padding({ left: 4, right: 4, top: 2, bottom: 2 })
        .width('100%')
        if (this.shareHint) {
          Text(this.shareHint)
            .width('100%')
            .fontSize(12)
            .fontColor('#777777')
            .textAlign(TextAlign.Center)
        }
        Button('取消')
          .width('100%')
          .height(46)
          .fontColor('#777777')
          .backgroundColor('#FFFFFF')
          .borderRadius(18)
          .onClick(() => { this.showShareSheet = false; this.shareHint = ''; })
      }
      .width(this.pageW >= 720 ? 520 : Math.max(300, this.pageW - 32))
      .position({
        x: this.pageW >= 720 ? Math.floor((this.pageW - 520) / 2) : 16,
        y: Math.max(this.safeTop() + 22, Math.floor(this.pageH * 0.12)),
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ShareAction(label: string) {
    Column({ space: 8 }) {
      Text(label.substring(0, 1))
        .fontColor('#333333')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width(52)
        .height(52)
        .textAlign(TextAlign.Center)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
      Text(label)
        .fontColor('#555555')
        .fontSize(12)
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.markToolbarTap();
      this.shareHint = `${label}暂未开放`;
    })
  }

  @Builder
  ShareAiGuideAction() {
    Column({ space: 8 }) {
      Text('AI')
        .fontColor('#8F6B22')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width(52)
        .height(52)
        .textAlign(TextAlign.Center)
        .backgroundColor('#FFF6E7')
        .borderRadius(16)
      Text('AI导读')
        .fontColor('#555555')
        .fontSize(12)
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.markToolbarTap();
      this.showShareSheet = false;
      this.openAiSheet();
    })
  }
}
