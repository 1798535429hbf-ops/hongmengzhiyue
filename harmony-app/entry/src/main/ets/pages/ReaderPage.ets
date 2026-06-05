import { ApiClient, ChatResult } from '../common/ApiClient';
import {
  BookmarkItem,
  Book,
  PlanItem,
  ReaderBundle,
  ReadingChapter,
  ReadingContent,
  SourceRef,
  emptyReaderBundle,
} from '../common/Models';
import { currentBookId, currentChapterId, goBack } from '../common/Navigation';
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
}

function makeTheme(name: string, bg: string, text: string, secondary: string, barBg: string, barText: string, divider: string, accent: string): ReadingThemeDef {
  const t = new ReadingThemeDef();
  t.name = name; t.bg = bg; t.text = text; t.secondary = secondary;
  t.barBg = barBg; t.barText = barText; t.divider = divider; t.accent = accent;
  return t;
}

function makeParagraphUnit(paragraphIndex: number, text: string): ParagraphUnit {
  const unit = new ParagraphUnit();
  unit.paragraphIndex = paragraphIndex;
  unit.text = text;
  return unit;
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
const AUTO_READ_SPEEDS: number[] = [8, 15, 30, 60, 90];

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
  @State barsVisible: boolean = false;
  @State themeKey: string = 'parchment';
  @State fontSizeIdx: number = 1;
  @State lineSpacingIdx: number = 1;
  @State brightnessIdx: number = 3;
  @State pageMode: string = 'scroll';
  @State autoReadActive: boolean = false;
  @State autoReadSpeedIdx: number = 1;

  @State pageW: number = 390;
  @State pageH: number = 780;
  @State pageIndex: number = 0;
  @State selectedParagraphIndex: number = -1;
  @State markedParagraphIndexes: number[] = [];
  @State showParagraphToolbar: boolean = false;
  @State showShareSheet: boolean = false;
  @State showAiSheet: boolean = false;
  @State aiQuestion: string = '';
  @State aiAnswer: string = '';
  @State aiFollowUp: string = '';
  @State aiSources: SourceRef[] = [];
  @State aiBusy: boolean = false;
  @State aiError: string = '';

  private readerScroller: Scroller = new Scroller();
  private readingDurationFlushed: boolean = false;
  private autoReadTimer: number = -1;
  private ignoreNextContentTap: boolean = false;

  aboutToAppear(): void {
    this.readingDurationFlushed = false;
    this.bookId = currentBookId();
    this.chapterId = currentChapterId();
    this.loadReader();
  }

  onPageHide(): void { this.flushReadingDuration(); this.stopAutoRead(); }
  aboutToDisappear(): void { this.flushReadingDuration(); this.stopAutoRead(); }

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  async flushReadingDuration(): Promise<void> {
    if (this.readingDurationFlushed) return;
    const ctx = this.hostContext();
    const range = finishReadingSession();
    this.readingDurationFlushed = true;
    if (!range) return;
    if (ctx) {
      try { await ShelfStore.addTodayReadingDuration(ctx, range.startedAtMs, range.endedAtMs); } catch (_) {}
    }
    const durationSeconds: number = Math.max(0, Math.floor((range.endedAtMs - range.startedAtMs) / 1000));
    const userId: number = UserSession.currentUserId();
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

  async loadReader(): Promise<void> {
    if (this.bookId <= 0) { this.errorText = '缺少 bookId，无法进入阅读器。'; return; }
    this.busyText = '正在加载正文和阅读进度';
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
      const targetChId = this.pickChId(chs);
      let nextContent: ReadingContent | null = null;
      if (targetChId) {
        try { nextContent = await ApiClient.getReadingContent(this.bookId, targetChId); }
        catch (e) { this.errorText = `正文加载失败：${e}`; }
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
      this.progress = plan ? plan.progress : this.estimateProgress(this.chapterId);
      this.resetReaderInteraction();
      setReadingSession(this.bookId, this.chapterId, this.progress);
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
    } catch (e) {
      this.errorText = `阅读器加载失败：${e}`;
    } finally { this.busyText = ''; }
  }

  async loadChapter(ch: ReadingChapter): Promise<void> {
    this.busyText = '正在切换章节';
    this.errorText = '';
    try {
      const tid = this.chKey(ch);
      this.chapterId = tid;
      this.content = await ApiClient.getReadingContent(this.bookId, tid);
      this.showCatalog = false;
      this.showSettings = false;
      this.barsVisible = false;
      this.progress = this.estimateProgress(tid);
      this.resetReaderInteraction();
      setReadingSession(this.bookId, this.chapterId, this.progress);
      await this.syncShelfTrace(this.bundle.book, this.chapterId, this.content.chapterTitle, this.progress);
    } catch (e) {
      this.errorText = `章节加载失败：${e}`;
    } finally { this.busyText = ''; }
  }

  async saveProgress(): Promise<void> {
    if (!this.bundle.plan) return;
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先登录后再保存阅读进度。';
      return;
    }
    this.busyText = '正在保存进度';
    this.errorText = '';
    try {
      await ApiClient.updatePlanProgress(userId, this.bundle.plan.id, this.bookId,
        this.chapterId, this.progress, this.pageMode === 'page' ? this.pageIndex : 0,
        this.progress >= 100 ? 'finished' : 'reading');
      try {
        await ApiClient.trackEvent({
          user_id: userId,
          event_type: 'SAVE_PROGRESS',
          book_id: this.bookId,
          chapter_id: this.chapterId,
          progress: this.progress,
        });
      } catch (_) {}
      setReadingSession(this.bookId, this.chapterId, this.progress, this.pageMode === 'page' ? this.pageIndex : 0);
      await this.syncShelfTrace(this.bundle.book, this.chapterId,
        this.content ? this.content.chapterTitle : '', this.progress);
      this.busyText = '';
    } catch (e) { this.errorText = `保存失败：${e}`; this.busyText = ''; }
  }

  async createPlan(): Promise<void> {
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先登录后再创建阅读计划。';
      return;
    }
    this.busyText = '正在创建阅读计划';
    this.errorText = '';
    try {
      await ApiClient.createPlan(userId, this.bookId, 14, { dailyMinutesTarget: 30, weeklyMinutesTarget: 210 });
      await this.loadReader();
      this.busyText = '计划已创建';
    } catch (e) { this.errorText = `创建计划失败：${e}`; this.busyText = ''; }
  }

  findPlan(plans: PlanItem[]): PlanItem | null {
    for (let i = 0; i < plans.length; i++) { if (plans[i].bookId === this.bookId) return plans[i]; }
    return null;
  }

  pickChId(chs: ReadingChapter[]): string {
    if (this.chapterId) return this.chapterId;
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
      if (this.chKey(this.chapters[i]) === cid) return Math.floor(((i + 1) / this.chapters.length) * 100);
    }
    return this.progress;
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
  ls(): number { return LINE_SPACINGS[this.lineSpacingIdx]; }
  brightValue(): number { return BRIGHTNESS_STEPS[this.brightnessIdx]; }
  autoReadInterval(): number { return AUTO_READ_SPEEDS[this.autoReadSpeedIdx] * 1000; }

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
    return Math.min(108, Math.max(64, Math.floor(this.pageW * 0.18)));
  }

  readingPageHeight(): number {
    const chrome = (this.barsVisible ? this.topBarHeight() + this.bottomBarHeight() : 36) + 70;
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
    if (this.content.paragraphs && this.content.paragraphs.length > 0) {
      return this.content.paragraphs;
    }
    if (!this.content.content) return [];
    const parts = this.content.content.split(/\n+/);
    const values: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const p = parts[i].trim();
      if (p) values.push(p);
    }
    return values.length > 0 ? values : [this.content.content];
  }

  pageCharLimit(): number {
    const lineHeight = this.fs() * this.ls();
    const lines = Math.max(7, Math.floor(this.readingPageHeight() / lineHeight) - 3);
    const charsPerLine = Math.max(12, Math.floor(this.readingContentWidth() / (this.fs() * 0.58)));
    return Math.max(120, lines * charsPerLine);
  }

  allUnits(): ParagraphUnit[] {
    const paragraphs = this.readingParagraphs();
    const units: ParagraphUnit[] = [];
    const unitLimit = Math.max(120, Math.floor(this.pageCharLimit() * 0.72));
    for (let i = 0; i < paragraphs.length; i++) {
      const text = paragraphs[i] || '';
      if (text.length <= unitLimit) {
        units.push(makeParagraphUnit(i, text));
      } else {
        let start = 0;
        while (start < text.length) {
          units.push(makeParagraphUnit(i, text.substring(start, Math.min(text.length, start + unitLimit))));
          start += unitLimit;
        }
      }
    }
    return units;
  }

  totalPages(): number {
    const units = this.allUnits();
    if (units.length <= 0) return 1;
    const limit = this.pageCharLimit();
    let count = 1;
    let used = 0;
    for (let i = 0; i < units.length; i++) {
      const next = units[i].text.length + 18;
      if (used > 0 && used + next > limit) {
        count++;
        used = 0;
      }
      used += next;
    }
    return Math.max(1, count);
  }

  currentPageUnits(): ParagraphUnit[] {
    const units = this.allUnits();
    const limit = this.pageCharLimit();
    const target = Math.min(Math.max(0, this.pageIndex), this.totalPages() - 1);
    let page = 0;
    let used = 0;
    const values: ParagraphUnit[] = [];
    for (let i = 0; i < units.length; i++) {
      const next = units[i].text.length + 18;
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

  resetReaderInteraction(): void {
    this.pageIndex = 0;
    this.selectedParagraphIndex = -1;
    this.showParagraphToolbar = false;
    this.showShareSheet = false;
  }

  resetPaging(): void {
    this.pageIndex = 0;
    this.showParagraphToolbar = false;
  }

  handleContentTap(): void {
    if (this.ignoreNextContentTap) {
      this.ignoreNextContentTap = false;
      return;
    }
    if (this.showCatalog || this.showSettings || this.showShareSheet || this.showAiSheet) {
      this.showCatalog = false;
      this.showSettings = false;
      return;
    }
    if (this.showParagraphToolbar) {
      this.showParagraphToolbar = false;
      return;
    }
    this.barsVisible = !this.barsVisible;
  }

  markToolbarTap(): void {
    this.ignoreNextContentTap = true;
    setTimeout(() => {
      this.ignoreNextContentTap = false;
    }, 80);
  }

  startAutoRead(): void {
    if (this.autoReadActive) return;
    this.autoReadActive = true;
    this.scheduleAutoRead();
  }

  stopAutoRead(): void {
    this.autoReadActive = false;
    clearTimeout(this.autoReadTimer);
    this.autoReadTimer = -1;
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
    this.autoReadTimer = setTimeout(() => {
      if (this.pageMode === 'page') {
        this.turnNextPage();
      } else {
        const y = this.readerScroller.currentOffset().yOffset;
        const step = Math.max(180, this.readingPageHeight() * 0.72);
        this.readerScroller.scrollTo({ xOffset: 0, yOffset: y + step, animation: { duration: 360, curve: Curve.Linear } });
      }
      if (this.autoReadActive) this.scheduleAutoRead();
    }, this.autoReadInterval());
  }

  turnPrevPage(): void {
    this.stopAutoRead();
    this.showParagraphToolbar = false;
    if (this.pageIndex > 0) {
      this.pageIndex--;
    } else {
      this.prevChapter();
    }
  }

  turnNextPage(): void {
    this.showParagraphToolbar = false;
    const total = this.totalPages();
    if (this.pageIndex < total - 1) {
      this.pageIndex++;
    } else {
      this.nextChapter();
    }
  }

  brightnessPercent(): string { return `${Math.round(this.brightValue() * 100)}%`; }

  isMarked(idx: number): boolean {
    for (let i = 0; i < this.markedParagraphIndexes.length; i++) {
      if (this.markedParagraphIndexes[i] === idx) return true;
    }
    return false;
  }

  selectParagraph(idx: number): void {
    this.selectedParagraphIndex = idx;
    this.showParagraphToolbar = true;
    this.barsVisible = false;
    this.markToolbarTap();
  }

  selectedParagraphText(): string {
    const paragraphs = this.readingParagraphs();
    if (this.selectedParagraphIndex >= 0 && this.selectedParagraphIndex < paragraphs.length) {
      return paragraphs[this.selectedParagraphIndex];
    }
    return '';
  }

  toggleMarkSelected(): void {
    if (this.selectedParagraphIndex < 0) return;
    const next: number[] = [];
    let found = false;
    for (let i = 0; i < this.markedParagraphIndexes.length; i++) {
      if (this.markedParagraphIndexes[i] === this.selectedParagraphIndex) {
        found = true;
      } else {
        next.push(this.markedParagraphIndexes[i]);
      }
    }
    if (!found) next.push(this.selectedParagraphIndex);
    this.markedParagraphIndexes = next;
  }

  openAiForParagraph(): void {
    const text = this.selectedParagraphText();
    this.aiQuestion = text ? `帮我解释这段：${text}` : '这段是什么意思？';
    this.showAiSheet = true;
    this.showParagraphToolbar = false;
    this.aiError = '';
  }

  openAiSheet(): void {
    this.aiQuestion = this.aiQuestion || '这章我应该抓住哪些重点？';
    this.showAiSheet = true;
    this.showCatalog = false;
    this.showSettings = false;
    this.showParagraphToolbar = false;
  }

  async askAi(): Promise<void> {
    const userId = UserSession.currentUserId();
    if (userId <= 0) {
      this.aiError = '请先登录后再使用 AI 伴读。';
      return;
    }
    const question = this.aiQuestion.trim();
    if (!question) {
      this.aiError = '先写一个想问的问题。';
      return;
    }
    this.aiBusy = true;
    this.aiError = '';
    this.aiAnswer = '';
    this.aiFollowUp = '';
    this.aiSources = [];
    try {
      const result: ChatResult = await ApiClient.chat(userId, this.bookId, question, {
        chapterId: this.chapterId,
        paragraph: this.selectedParagraphText(),
        allowExternalSearch: true,
        tone: 'warm_companion',
      });
      this.aiAnswer = result.answer || '';
      this.aiFollowUp = result.follow_up_suggestion || '';
      this.aiSources = result.sources || [];
    } catch (err) {
      this.aiError = `伴读失败：${err}`;
    } finally {
      this.aiBusy = false;
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

  pageIndicatorText(): string {
    if (this.pageMode === 'page') {
      return `${Math.min(this.pageIndex + 1, this.totalPages())}/${this.totalPages()}`;
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
        .onClick(() => this.handleContentTap())

      if (this.pageMode === 'page') {
        this.PagedReader()
      } else {
        this.ScrollReader()
      }

      if (this.barsVisible) {
        Stack({ alignContent: Alignment.Top }) {
          this.TopBar()
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)

        Stack({ alignContent: Alignment.Bottom }) {
          this.BottomBar()
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.showParagraphToolbar) { this.ParagraphToolbar() }
      if (this.showCatalog) { this.CatalogSheet() }
      if (this.showSettings) { this.SettingsSheet() }
      if (this.showAiSheet) { this.AiSheet() }
      if (this.showShareSheet) { this.ShareSheet() }

      if (this.autoReadActive) {
        Row({ space: 6 }) {
          Text('AUTO').fontColor('#FFFFFF').fontSize(10).fontWeight(FontWeight.Bold)
          Text(`${AUTO_READ_SPEEDS[this.autoReadSpeedIdx]} 秒/页`).fontColor('#FFFFFF').fontSize(11)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('#B0000000').borderRadius(14)
        .position({ x: Math.max(12, Math.floor((this.pageW - 102) / 2)), y: this.safeTop() + 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.th().bg)
    .onAreaChange((_, area) => {
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
        this.ReaderHeader()
        this.StatusBlocks()
        this.ScrollParagraphs()
        this.ChapterFooter()
      }
      .width('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth() })
      .padding({
        left: this.contentPad(),
        right: this.contentPad(),
        top: this.barsVisible ? this.topBarHeight() + 8 : 24,
        bottom: this.barsVisible ? this.bottomBarHeight() + 18 : 28,
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onClick(() => this.handleContentTap())
    .onTouch(() => {
      if (this.autoReadActive) { this.stopAutoRead(); }
    })
  }

  @Builder
  PagedReader() {
    Stack() {
      Column({ space: 12 }) {
        this.ReaderHeader()
        this.StatusBlocks()
        if (this.readingParagraphs().length > 0) {
          Column({ space: Math.max(10, this.fs() * 0.8) }) {
            ForEach(this.currentPageUnits(), (unit: ParagraphUnit, idx: number) => {
              this.ReaderParagraph(unit.text, unit.paragraphIndex, `${this.pageIndex}-${idx}-${unit.text.substring(0, 8)}`)
            }, (unit: ParagraphUnit, idx: number) => `${this.pageIndex}-${idx}-${unit.paragraphIndex}-${unit.text.substring(0, 8)}`)
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          Text(!this.busyText && !this.errorText ? '后端尚未返回正文内容。请确认接口已提供章节正文。' : '')
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
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth() })
      .padding({
        left: this.contentPad(),
        right: this.contentPad(),
        top: this.barsVisible ? this.topBarHeight() + 10 : this.safeTop() + 18,
        bottom: this.barsVisible ? this.bottomBarHeight() + 10 : this.safeBottom() + 16,
      })
      .onClick(() => this.handleContentTap())
      .onTouch(() => {
        if (this.autoReadActive) { this.stopAutoRead(); }
      })

      Stack() {
        Column()
          .height('100%')
          .width(this.pageTurnZoneWidth())
          .position({ x: 0, y: 0 })
          .onClick(() => { this.stopAutoRead(); this.turnPrevPage(); })
        Column()
          .height('100%')
          .width(this.pageTurnZoneWidth())
          .position({ x: Math.max(0, this.pageW - this.pageTurnZoneWidth()), y: 0 })
          .onClick(() => { this.stopAutoRead(); this.turnNextPage(); })
      }
      .width('100%')
      .height('100%')
      .opacity(0.01)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ReaderHeader() {
    if (this.content) {
      Column({ space: 10 }) {
        Text(this.content.chapterTitle)
          .fontColor(this.th().text)
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
  ScrollParagraphs() {
    if (this.readingParagraphs().length > 0) {
      ForEach(this.readingParagraphs(), (p: string, idx: number) => {
        this.ReaderParagraph(p, idx, `${idx}-${p.substring(0, 8)}`)
      }, (p: string, idx: number) => `${idx}-${p.substring(0, 8)}`)
    } else if (!this.busyText && !this.errorText) {
      Text('后端尚未返回正文内容。请确认接口已提供章节正文。')
        .fontColor(this.th().secondary).fontSize(14).lineHeight(24)
        .width('100%').textAlign(TextAlign.Center).padding({ top: 60 })
    }
  }

  @Builder
  ReaderParagraph(text: string, paragraphIndex: number, key: string) {
    Text(text)
      .fontColor(this.th().text)
      .fontSize(this.fs())
      .lineHeight(this.fs() * this.ls())
      .textIndent(this.fs() * 2)
      .textAlign(TextAlign.Start)
      .width('100%')
      .padding({ left: 3, right: 3, top: 4, bottom: 4 })
      .backgroundColor(this.isMarked(paragraphIndex) ? '#F8DCDC' : (this.selectedParagraphIndex === paragraphIndex && this.showParagraphToolbar ? '#F6E6E2' : 'transparent'))
      .borderRadius(4)
      .gesture(LongPressGesture({ repeat: false }).onAction(() => this.selectParagraph(paragraphIndex)))
  }

  @Builder
  ChapterFooter() {
    if (this.content && !this.busyText) {
      Column({ space: 16 }) {
        Divider().color(this.th().divider).strokeWidth(0.5)
        Text('本章完')
          .fontColor(this.th().secondary).fontSize(13)
          .width('100%').textAlign(TextAlign.Center)
        Row({ space: 12 }) {
          Button('上一章')
            .fontSize(14).fontColor(this.th().barText)
            .backgroundColor(this.th().barBg)
            .borderRadius(22).height(40).layoutWeight(1)
            .onClick(() => this.prevChapter())
          Button('下一章')
            .fontSize(14).fontColor('#FFFFFF')
            .backgroundColor(this.th().accent)
            .borderRadius(22).height(40).layoutWeight(1)
            .onClick(() => this.nextChapter())
        }
        .width('100%')
      }
      .width('100%')
      .padding({ top: 20, bottom: 60 })
    }
  }

  @Builder
  TopBar() {
    Column() {
      Row({ space: 10 }) {
        Text('<')
          .fontColor(this.th().barText).fontSize(24)
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { this.markToolbarTap(); this.stopAutoRead(); this.saveProgress(); goBack(); })

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

        Text('≡')
          .fontColor(this.th().barText).fontSize(22)
          .width(44).height(44).textAlign(TextAlign.Center)
          .onClick(() => { this.markToolbarTap(); this.showCatalog = true; this.showSettings = false; })
      }
      .width('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth() + this.contentPad() * 2 })
      .height(48)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(this.topBarHeight())
    .padding({ top: this.safeTop(), left: this.pageW >= 900 ? this.contentPad() : 0, right: this.pageW >= 900 ? this.contentPad() : 0 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.th().barBg)
    .border({ width: { bottom: 0.5 }, color: this.th().divider })
  }

  @Builder
  BottomBar() {
    Column() {
      Row() {}
        .width('100%')
        .height(0.5)
        .backgroundColor(this.th().divider)

      Row({ space: 0 }) {
        this.BottomAction('≡', '目录', () => { this.markToolbarTap(); this.showCatalog = true; this.showSettings = false; })
        this.BottomAction(this.themeKey === 'dark' ? '☀' : '☾', '夜间', () => {
          this.markToolbarTap();
          this.themeKey = this.themeKey === 'dark' ? 'parchment' : 'dark';
        })
        this.BottomAction('A', '设置', () => { this.markToolbarTap(); this.showSettings = true; this.showCatalog = false; })
        this.BottomAction('AI', '伴读', () => { this.markToolbarTap(); this.openAiSheet(); })
      }
      .width('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth() + this.contentPad() * 2 })
      .height(60)
    }
    .width('100%')
    .height(this.bottomBarHeight())
    .padding({ bottom: this.safeBottom(), left: this.pageW >= 900 ? this.contentPad() : 0, right: this.pageW >= 900 ? this.contentPad() : 0 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.th().barBg)
  }

  @Builder
  BottomAction(icon: string, label: string, action: () => void) {
    Column({ space: 3 }) {
      Text(icon).fontColor(this.th().barText).fontSize(icon === 'AI' ? 13 : 18).fontWeight(icon === 'AI' ? FontWeight.Bold : FontWeight.Regular)
      Text(label).fontColor(this.th().secondary).fontSize(10)
    }
    .layoutWeight(1).height(58)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .onClick(() => action())
  }

  @Builder
  ParagraphToolbar() {
    Row({ space: 0 }) {
      this.ParagraphTool('标记', () => { this.markToolbarTap(); this.toggleMarkSelected(); })
      this.ParagraphTool('分享', () => { this.markToolbarTap(); this.showShareSheet = true; this.showParagraphToolbar = false; })
      this.ParagraphTool('问AI', () => { this.markToolbarTap(); this.openAiForParagraph(); })
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
    .onClick(() => action())
  }

  @Builder
  CatalogSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text('目录')
          .fontColor(this.th().text).fontSize(18).fontWeight(FontWeight.Bold)
        Blank()
        Text('×')
          .fontColor(this.th().barText).fontSize(18)
          .width(34).height(34).textAlign(TextAlign.Center)
          .borderRadius(17).backgroundColor('#15000000')
          .onClick(() => { this.showCatalog = false; })
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
        Scroll() {
          Column() {
            ForEach(this.chapters, (ch: ReadingChapter, idx: number) => {
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
                .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .onClick(() => this.loadChapter(ch))
              }
              .width('100%')
              if (idx < this.chapters.length - 1) {
                Divider().color(this.th().divider).strokeWidth(0.3).margin({ left: 56 })
              }
            }, (ch: ReadingChapter) => this.chKey(ch))
          }
          .width('100%')
        }
        .layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('70%')
    .constraintSize({ maxWidth: this.pageW >= 900 ? 760 : this.pageW })
    .backgroundColor(this.th().bg)
    .borderRadius({ topLeft: 18, topRight: 18 })
    .shadow({ radius: 20, color: '#30000000', offsetX: 0, offsetY: -8 })
    .position({ x: this.pageW >= 900 ? Math.floor((this.pageW - 760) / 2) : 0, y: '30%' })
  }

  @Builder
  SettingsSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text('阅读设置')
          .fontColor(this.th().text).fontSize(18).fontWeight(FontWeight.Bold)
        Blank()
        Text('×')
          .fontColor(this.th().barText).fontSize(18)
          .width(34).height(34).textAlign(TextAlign.Center)
          .borderRadius(17).backgroundColor('#15000000')
          .onClick(() => { this.showSettings = false; })
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
          this.SourceSetting()
        }
        .width('100%').padding({ left: 20, right: 20, top: 18, bottom: 36 })
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%')
    .height('64%')
    .constraintSize({ maxWidth: this.pageW >= 900 ? 760 : this.pageW })
    .backgroundColor(this.th().bg)
    .borderRadius({ topLeft: 18, topRight: 18 })
    .shadow({ radius: 20, color: '#30000000', offsetX: 0, offsetY: -8 })
    .position({ x: this.pageW >= 900 ? Math.floor((this.pageW - 760) / 2) : 0, y: '36%' })
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
    .onClick(() => { this.pageMode = mode; this.resetPaging(); })
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
        Text(this.autoReadActive ? `${AUTO_READ_SPEEDS[this.autoReadSpeedIdx]} 秒/页` : '已关闭')
          .fontColor(this.autoReadActive ? this.th().accent : this.th().secondary).fontSize(13)
      }
      .width('100%')
      Button(this.autoReadActive ? '停止自动阅读' : '开启自动阅读')
        .width('100%').height(40).fontSize(14)
        .fontColor(this.autoReadActive ? '#FFFFFF' : this.th().barText)
        .backgroundColor(this.autoReadActive ? this.th().accent : this.th().barBg)
        .borderRadius(20).border({ width: this.autoReadActive ? 0 : 1, color: this.th().divider })
        .onClick(() => this.toggleAutoRead())
      Row({ space: 6 }) {
        ForEach(AUTO_READ_SPEEDS, (s: number, idx: number) => {
          Text(`${s}s`)
            .fontSize(12)
            .fontColor(idx === this.autoReadSpeedIdx ? '#FFFFFF' : this.th().text)
            .width(44).height(30).borderRadius(15)
            .backgroundColor(idx === this.autoReadSpeedIdx ? this.th().accent : this.th().barBg)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.autoReadSpeedIdx = idx;
              if (this.autoReadActive) {
                this.stopAutoRead();
                this.startAutoRead();
              }
            })
        }, (s: number) => `${s}`)
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
      Row({ space: 8 }) {
        ForEach(FONT_SIZES, (s: number, idx: number) => {
          Text(`${s}`)
            .fontSize(14)
            .fontColor(idx === this.fontSizeIdx ? '#FFFFFF' : this.th().text)
            .fontWeight(idx === this.fontSizeIdx ? FontWeight.Bold : FontWeight.Regular)
            .width(42).height(36).borderRadius(18)
            .backgroundColor(idx === this.fontSizeIdx ? this.th().accent : this.th().barBg)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.fontSizeIdx = idx; this.resetPaging(); })
        }, (s: number) => `${s}`)
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
            .onClick(() => { this.lineSpacingIdx = idx; this.resetPaging(); })
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
          .onClick(() => { this.themeKey = k; })
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
        .onClick(() => this.createPlan())
    } else {
      Row({ space: 12 }) {
        Text('当前计划')
          .fontColor(this.th().secondary).fontSize(13)
        Text(`${this.progress}%`)
          .fontColor(this.th().accent).fontSize(22).fontWeight(FontWeight.Bold)
        Blank()
        Button('保存进度')
          .height(36).fontSize(13).fontColor('#FFFFFF')
          .backgroundColor(this.th().accent).borderRadius(18)
          .padding({ left: 18, right: 18 })
          .onClick(() => this.saveProgress())
      }
      .width('100%').padding({ top: 6 })
    }
  }

  @Builder
  SourceSetting() {
    if (this.contentSources().length > 0) {
      Column({ space: 8 }) {
        Text('参考来源').fontColor(this.th().text).fontSize(14).fontWeight(FontWeight.Medium)
        ForEach(this.contentSources().slice(0, 3), (s: SourceRef) => {
          Column({ space: 4 }) {
            Text(s.title || '来源').fontColor(this.th().text).fontSize(13).fontWeight(FontWeight.Medium)
            Text(s.text).fontColor(this.th().secondary).fontSize(12).lineHeight(18).maxLines(2)
            Text(s.source || '').fontColor(this.th().accent).fontSize(11)
          }
          .width('100%').padding(12)
          .backgroundColor(this.th().barBg).borderRadius(10)
        }, (s: SourceRef) => `${s.chunk_id}`)
      }
      .width('100%')
    }
  }

  @Builder
  AiSheet() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => { this.showAiSheet = false; })
      Column({ space: 14 }) {
        Row() {
          Column({ space: 4 }) {
            Text('AI 伴读')
              .fontColor('#141414')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
            Text(this.content ? this.content.chapterTitle : this.bundle.book.title)
              .fontColor('#8A8A8A')
              .fontSize(12)
              .maxLines(1)
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text('×')
            .fontColor('#777777')
            .fontSize(22)
            .width(36).height(36).textAlign(TextAlign.Center)
            .onClick(() => { this.showAiSheet = false; })
        }
        .width('100%')

        TextInput({ placeholder: '围绕当前章节或选中段落提问', text: this.aiQuestion })
          .height(46)
          .fontColor('#222222')
          .placeholderColor('#A0A0A0')
          .backgroundColor('#F5F6F7')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => { this.aiQuestion = value; })

        Button(this.aiBusy ? '正在检索来源' : '提问')
          .width('100%')
          .height(42)
          .fontSize(15)
          .fontColor('#FFFFFF')
          .backgroundColor(this.aiBusy ? '#B7A172' : '#8F6B22')
          .borderRadius(21)
          .enabled(!this.aiBusy)
          .onClick(() => this.askAi())

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
        if (this.aiAnswer) {
          Scroll() {
            Column({ space: 12 }) {
              Text(this.aiAnswer)
                .fontColor('#2C2C2C')
                .fontSize(15)
                .lineHeight(24)
              if (this.aiFollowUp) {
                Text(`下一步：${this.aiFollowUp}`)
                  .fontColor('#8F6B22')
                  .fontSize(13)
                  .lineHeight(20)
              }
              if (this.aiSources.length > 0) {
                Column({ space: 8 }) {
                  Text('参考依据')
                    .fontColor('#2C2C2C')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                  ForEach(this.aiSources.slice(0, 3), (source: SourceRef) => {
                    Text(`${source.title || '来源'} · ${source.source || ''}\n${source.text || ''}`)
                      .fontColor('#6E6E6E')
                      .fontSize(12)
                      .lineHeight(18)
                      .padding(10)
                      .backgroundColor('#F7F2E8')
                      .borderRadius(10)
                  }, (source: SourceRef) => `${source.chunk_id}-${source.source}`)
                }
                .width('100%')
              }
            }
            .width('100%')
          }
          .height(Math.min(280, Math.max(160, this.pageH * 0.34)))
          .scrollBar(BarState.Off)
        } else if (!this.aiBusy) {
          Text('我会先看当前书籍、章节和来源片段；资料不够时才补充外部检索，并把依据留给你核对。')
            .fontColor('#777777')
            .fontSize(13)
            .lineHeight(20)
        }
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
            Circle().width(32).height(32).fill('#E6EDE0')
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
            Text(`/ 引自《${this.bundle.book.title || '未命名图书'}》`)
              .fontColor('#8E8E8E')
              .fontSize(13)
            Text(this.content ? this.content.chapterTitle : '')
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

        Row({ space: 12 }) {
          this.ShareAction('复制链接')
          this.ShareAction('保存图片')
        }
        .width('100%')
        Button('取消')
          .width('100%')
          .height(46)
          .fontColor('#777777')
          .backgroundColor('#FFFFFF')
          .borderRadius(18)
          .onClick(() => { this.showShareSheet = false; })
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
        .width(48)
        .height(48)
        .textAlign(TextAlign.Center)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
      Text(label)
        .fontColor('#EDEDED')
        .fontSize(12)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}
