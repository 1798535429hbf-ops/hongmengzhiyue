import { ApiClient } from '../common/ApiClient';
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
import { currentBookId, currentChapterId, goBack, openChat } from '../common/Navigation';
import { finishReadingSession, setReadingSession } from '../common/ReaderSession';
import { ShelfStore } from '../common/ShelfStore';
import { common } from '@kit.AbilityKit';

const USER_ID: number = 10086;

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

function makeTheme(name: string, bg: string, text: string, secondary: string, barBg: string, barText: string, divider: string, accent: string): ReadingThemeDef {
  const t = new ReadingThemeDef();
  t.name = name; t.bg = bg; t.text = text; t.secondary = secondary;
  t.barBg = barBg; t.barText = barText; t.divider = divider; t.accent = accent;
  return t;
}

const THEME_PARCHMENT = makeTheme('羊皮纸', '#F5F0E8', '#3C3028', '#8B7D6B', '#EDE6D8', '#5C4A38', '#D4C8B0', '#B8860B');
const THEME_LIGHT = makeTheme('纯白', '#F8F8F8', '#222222', '#999999', '#EEEEEE', '#333333', '#E0E0E0', '#4A90D9');
const THEME_DARK = makeTheme('夜间', '#1A1A1E', '#C8C8C8', '#707070', '#252528', '#B0B0B0', '#333333', '#6B8EAD');
const THEME_GREEN = makeTheme('护眼', '#C8DABC', '#3A4A32', '#6B7D5E', '#B8CCAA', '#3A4A32', '#A0B896', '#5A7A4A');

const ALL_THEME_KEYS: string[] = ['parchment', 'light', 'dark', 'green'];

const FONT_SIZES: number[] = [15, 17, 19, 21, 24];
const LINE_SPACINGS: number[] = [1.5, 1.7, 1.9, 2.1, 2.4];
const BRIGHTNESS_STEPS: number[] = [0.3, 0.45, 0.6, 0.75, 0.9, 1.0];
const AUTO_READ_SPEEDS: number[] = [30, 60, 90, 120, 180];

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
  @State autoReadSpeedIdx: number = 2;
  @State pageW: number = 390;

  private readerScroller: Scroller = new Scroller();
  private readingDurationFlushed: boolean = false;
  private autoReadTimer: number = -1;

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

  applyBrightness(): void {
    const v = BRIGHTNESS_STEPS[this.brightnessIdx];
  }

  async flushReadingDuration(): Promise<void> {
    if (this.readingDurationFlushed) return;
    const ctx = this.hostContext();
    const range = finishReadingSession();
    this.readingDurationFlushed = true;
    if (!ctx || !range) return;
    try { await ShelfStore.addTodayReadingDuration(ctx, range.startedAtMs, range.endedAtMs); } catch (_) {}
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
      const plans: PlanItem[] = await ApiClient.listPlans(USER_ID);
      const plan: PlanItem | null = this.findPlan(plans);
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
          progress: plan.progress, scrollOffset: 0, status: plan.status,
        } : null,
        bookmarks: [],
      };
      this.bundle = nb;
      this.chapters = chs;
      this.bookmarks = nb.bookmarks;
      this.content = nextContent;
      this.chapterId = nextContent ? nextContent.chapterId : targetChId;
      this.progress = plan ? plan.progress : this.estimateProgress(this.chapterId);
      setReadingSession(this.bookId, this.chapterId, this.progress);
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
      setReadingSession(this.bookId, this.chapterId, this.progress);
      await this.syncShelfTrace(this.bundle.book, this.chapterId, this.content.chapterTitle, this.progress);
    } catch (e) {
      this.errorText = `章节加载失败：${e}`;
    } finally { this.busyText = ''; }
  }

  async saveProgress(): Promise<void> {
    if (!this.bundle.plan) return;
    this.busyText = '正在保存进度';
    this.errorText = '';
    try {
      await ApiClient.updatePlanProgress(USER_ID, this.bundle.plan.id, this.bookId,
        this.chapterId, this.progress, 0, this.progress >= 100 ? 'finished' : 'reading');
      setReadingSession(this.bookId, this.chapterId, this.progress);
      await this.syncShelfTrace(this.bundle.book, this.chapterId,
        this.content ? this.content.chapterTitle : '', this.progress);
      this.busyText = '';
    } catch (e) { this.errorText = `保存失败：${e}`; this.busyText = ''; }
  }

  async createPlan(): Promise<void> {
    this.busyText = '正在创建阅读计划';
    this.errorText = '';
    try {
      await ApiClient.createPlan(USER_ID, this.bookId, 14);
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

  contentPad(): number {
    if (this.pageW >= 720) return 56;
    if (this.pageW >= 500) return 40;
    return 24;
  }

  contentSources(): SourceRef[] {
    if (!this.content) return [];
    if (this.content.sourceRefs && this.content.sourceRefs.length > 0) return this.content.sourceRefs;
    if (this.content.sources && this.content.sources.length > 0) return this.content.sources;
    return [];
  }

  handleContentTap(): void {
    if (this.showCatalog || this.showSettings) {
      this.showCatalog = false;
      this.showSettings = false;
      return;
    }
    this.barsVisible = !this.barsVisible;
  }

  startAutoRead(): void {
    if (this.autoReadActive) return;
    this.autoReadActive = true;
    this.scheduleAutoScroll();
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

  scheduleAutoScroll(): void {
    if (!this.autoReadActive) return;
    this.autoReadTimer = setTimeout(() => {
      const y = this.readerScroller.currentOffset().yOffset;
      const step = this.fs() * this.ls() * 2;
      this.readerScroller.scrollTo({ xOffset: 0, yOffset: y + step, animation: { duration: 200, curve: Curve.Linear } });
      if (this.autoReadActive) {
        this.scheduleAutoScroll();
      }
    }, this.autoReadInterval());
  }

  brightnessPercent(): string { return `${Math.round(this.brightValue() * 100)}%`; }

  brightnessIcon(): string {
    const v = this.brightValue();
    if (v <= 0.3) return '◐';
    if (v <= 0.6) return '◑';
    return '◉';
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.th().bg)
        .brightness(this.brightValue())
        .onClick(() => this.handleContentTap())

      Scroll(this.readerScroller) {
        Column({ space: this.ls() * 10 }) {
          if (this.content) {
            Column({ space: 12 }) {
              Text(this.content.chapterTitle)
                .fontColor(this.th().text)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .lineHeight(34)
                .textAlign(TextAlign.Center)
              if (this.bundle.book.author) {
                Text(this.bundle.book.author)
                  .fontColor(this.th().secondary)
                  .fontSize(14)
              }
            }
            .width('100%')
            .padding({ top: 20, bottom: 8 })
          }

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

          if (this.content && this.content.paragraphs && this.content.paragraphs.length > 0) {
            ForEach(this.content.paragraphs, (p: string, idx: number) => {
              Text(p)
                .fontColor(this.th().text)
                .fontSize(this.fs())
                .lineHeight(this.fs() * this.ls())
                .textIndent(this.fs() * 2)
                .textAlign(TextAlign.JUSTIFY)
                .width('100%')
            }, (p: string, idx: number) => `${idx}-${p.substring(0, 8)}`)
          } else if (this.content && this.content.content) {
            Text(this.content.content)
              .fontColor(this.th().text)
              .fontSize(this.fs())
              .lineHeight(this.fs() * this.ls())
              .textIndent(this.fs() * 2)
              .textAlign(TextAlign.JUSTIFY)
              .width('100%')
          } else if (!this.busyText && !this.errorText) {
            Text('后端尚未返回正文内容。请确认接口已提供章节正文。')
              .fontColor(this.th().secondary).fontSize(14).lineHeight(24)
              .width('100%').textAlign(TextAlign.Center).padding({ top: 60 })
          }

          if (this.content && !this.busyText) {
            Column({ space: 16 }) {
              Divider().color(this.th().divider).strokeWidth(0.5)
              Text('— 本章完 —')
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
        .width('100%')
        .padding({
          left: this.contentPad(),
          right: this.contentPad(),
          top: this.barsVisible ? 52 : 20,
          bottom: this.barsVisible ? 76 : 20,
        })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onTouch(() => {
        if (this.autoReadActive) { this.stopAutoRead(); }
      })

      if (this.barsVisible) {
        Column() {
          this.TopBar()
          Blank()
          this.BottomBar()
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.showCatalog) { this.CatalogSheet() }
      if (this.showSettings) { this.SettingsSheet() }

      if (this.autoReadActive) {
        Row({ space: 6 }) {
          Text('▶').fontColor(this.th().barText).fontSize(10)
          Text('自动阅读中').fontColor(this.th().barText).fontSize(11)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('#B0000000').borderRadius(14)
        .position({ x: '50%', y: 40 })
        .translate({ x: '-50%' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.th().bg)
    .onAreaChange((_, area) => {
      const w: number = typeof area.width === 'number' ? area.width : Number(area.width);
      if (Number.isFinite(w) && w > 0) this.pageW = w;
    })
  }

  @Builder
  TopBar() {
    Row({ space: 10 }) {
      Text('‹')
        .fontColor(this.th().barText).fontSize(28)
        .width(36).textAlign(TextAlign.Center)
        .onClick(() => { this.stopAutoRead(); this.saveProgress(); goBack(); })

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

      Text(`${this.progress}%`)
        .fontColor(this.th().secondary).fontSize(12)

      Text('☰')
        .fontColor(this.th().barText).fontSize(20)
        .width(36).textAlign(TextAlign.Center)
        .onClick(() => { this.showCatalog = true; this.showSettings = false; })
    }
    .width('100%').height(46)
    .padding({ left: 12, right: 12 })
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
        Column({ space: 3 }) {
          Text('☰').fontColor(this.th().barText).fontSize(18)
          Text('目录').fontColor(this.th().secondary).fontSize(10)
        }
        .layoutWeight(1).height(56)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .onClick(() => { this.showCatalog = true; this.showSettings = false; })

        Column({ space: 3 }) {
          Text(this.themeKey === 'dark' ? '☀' : '☾')
            .fontColor(this.th().barText).fontSize(18)
          Text('夜间').fontColor(this.th().secondary).fontSize(10)
        }
        .layoutWeight(1).height(56)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.themeKey = this.themeKey === 'dark' ? 'parchment' : 'dark';
        })

        Column({ space: 3 }) {
          Text('A').fontColor(this.th().barText).fontSize(17).fontWeight(FontWeight.Bold)
          Text('设置').fontColor(this.th().secondary).fontSize(10)
        }
        .layoutWeight(1).height(56)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .onClick(() => { this.showSettings = true; this.showCatalog = false; })

        Column({ space: 3 }) {
          Text('◇').fontColor(this.th().barText).fontSize(16)
          Text('伴读').fontColor(this.th().secondary).fontSize(10)
        }
        .layoutWeight(1).height(56)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .onClick(() => openChat(this.bookId))
      }
      .width('100%').height(60)
    }
    .width('100%')
    .backgroundColor(this.th().barBg)
  }

  @Builder
  CatalogSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text('目录')
          .fontColor(this.th().text).fontSize(18).fontWeight(FontWeight.Bold)
        Blank()
        if (this.chapters.length > 0) {
          Text(`共 ${this.chapters.length} 章`)
            .fontColor(this.th().secondary).fontSize(13)
        }
        Text('✕')
          .fontColor(this.th().barText).fontSize(16)
          .width(30).height(30).textAlign(TextAlign.Center)
          .borderRadius(15).backgroundColor('#15000000')
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
                  Column() {
                    Text(`${idx + 1}`)
                      .fontColor(this.chKey(ch) === this.chapterId ? '#FFFFFF' : this.th().secondary)
                      .fontSize(12).fontWeight(FontWeight.Medium)
                  }
                  .width(28).height(28).borderRadius(14)
                  .backgroundColor(this.chKey(ch) === this.chapterId ? this.th().accent : this.th().divider)
                  .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

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
                    Text('◀').fontColor(this.th().accent).fontSize(12)
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
    .width('100%').height('70%')
    .backgroundColor(this.th().bg)
    .borderRadius({ topLeft: 16, topRight: 16 })
    .shadow({ radius: 20, color: '#30000000', offsetX: 0, offsetY: -8 })
    .position({ x: 0, y: '30%' })
  }

  @Builder
  SettingsSheet() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text('阅读设置')
          .fontColor(this.th().text).fontSize(18).fontWeight(FontWeight.Bold)
        Blank()
        Text('✕')
          .fontColor(this.th().barText).fontSize(16)
          .width(30).height(30).textAlign(TextAlign.Center)
          .borderRadius(15).backgroundColor('#15000000')
          .onClick(() => { this.showSettings = false; })
      }
      .width('100%').padding({ left: 20, right: 16, top: 16, bottom: 12 })

      Divider().color(this.th().divider).strokeWidth(0.5)

      Scroll() {
        Column({ space: 22 }) {
          Column({ space: 10 }) {
            Row() {
              Text('翻页模式').fontColor(this.th().text).fontSize(15)
              Blank()
              Text(this.pageMode === 'scroll' ? '上下滚动' : '左右翻页')
                .fontColor(this.th().secondary).fontSize(13)
            }
            .width('100%')

            Row({ space: 8 }) {
              Column({ space: 6 }) {
                Column() {}
                  .width('100%').height(48).borderRadius(12)
                  .backgroundColor(this.pageMode === 'scroll' ? this.th().accent : this.th().barBg)
                  .border({ width: this.pageMode === 'scroll' ? 0 : 1, color: this.th().divider })
                Text('滚动')
                  .fontColor(this.pageMode === 'scroll' ? this.th().accent : this.th().secondary)
                  .fontSize(12)
              }
              .layoutWeight(1).alignItems(HorizontalAlign.Center)
              .onClick(() => { this.pageMode = 'scroll'; })

              Column({ space: 6 }) {
                Column() {}
                  .width('100%').height(48).borderRadius(12)
                  .backgroundColor(this.pageMode === 'page' ? this.th().accent : this.th().barBg)
                  .border({ width: this.pageMode === 'page' ? 0 : 1, color: this.th().divider })
                Text('翻页')
                  .fontColor(this.pageMode === 'page' ? this.th().accent : this.th().secondary)
                  .fontSize(12)
              }
              .layoutWeight(1).alignItems(HorizontalAlign.Center)
              .onClick(() => { this.pageMode = 'page'; })
            }
            .width('100%')
          }

          Column({ space: 10 }) {
            Row() {
              Text('亮度').fontColor(this.th().text).fontSize(15)
              Blank()
              Text(this.brightnessPercent()).fontColor(this.th().secondary).fontSize(13)
            }
            .width('100%')

            Row({ space: 8 }) {
              Text('◐').fontColor(this.th().secondary).fontSize(16)
              Slider({
                value: this.brightValue(),
                min: 0.2,
                max: 1.0,
                step: 0.05,
                style: SliderStyle.InSet
              })
                .blockColor(this.th().accent)
                .trackColor(this.th().divider)
                .selectedColor(this.th().accent)
                .trackThickness(4)
                .layoutWeight(1)
                .onChange((v: number) => {
                  for (let i = 0; i < BRIGHTNESS_STEPS.length; i++) {
                    if (v <= BRIGHTNESS_STEPS[i] + 0.025) { this.brightnessIdx = i; return; }
                  }
                  this.brightnessIdx = BRIGHTNESS_STEPS.length - 1;
                })
              Text('◉').fontColor(this.th().text).fontSize(16)
            }
            .width('100%').alignItems(VerticalAlign.Center)
          }

          Column({ space: 10 }) {
            Row() {
              Text('自动阅读').fontColor(this.th().text).fontSize(15)
              Blank()
              if (this.autoReadActive) {
                Text(`${AUTO_READ_SPEEDS[this.autoReadSpeedIdx]}秒/页`)
                  .fontColor(this.th().accent).fontSize(13)
              } else {
                Text('已关闭').fontColor(this.th().secondary).fontSize(13)
              }
            }
            .width('100%')

            Button(this.autoReadActive ? '停止自动阅读' : '开启自动阅读')
              .width('100%').height(40).fontSize(14)
              .fontColor(this.autoReadActive ? '#FFFFFF' : this.th().barText)
              .backgroundColor(this.autoReadActive ? this.th().accent : this.th().barBg)
              .borderRadius(20).border({ width: this.autoReadActive ? 0 : 1, color: this.th().divider })
              .onClick(() => this.toggleAutoRead())

            if (this.autoReadActive) {
              Row({ space: 6 }) {
                Text('滚动速度').fontColor(this.th().secondary).fontSize(13)
                Blank()
              }
              .width('100%').padding({ top: 6 })

              Row({ space: 6 }) {
                ForEach(AUTO_READ_SPEEDS, (s: number, idx: number) => {
                  Text(`${s}s`)
                    .fontSize(12)
                    .fontColor(idx === this.autoReadSpeedIdx ? '#FFFFFF' : this.th().text)
                    .width(40).height(28).borderRadius(14)
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
                  .width(40).height(36).borderRadius(18)
                  .backgroundColor(idx === this.fontSizeIdx ? this.th().accent : this.th().barBg)
                  .textAlign(TextAlign.Center)
                  .onClick(() => { this.fontSizeIdx = idx; })
              }, (s: number) => `${s}`)
            }
            .width('100%')
          }

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
                  .width(44).height(34).borderRadius(17)
                  .backgroundColor(idx === this.lineSpacingIdx ? this.th().accent : this.th().barBg)
                  .textAlign(TextAlign.Center)
                  .onClick(() => { this.lineSpacingIdx = idx; })
              }, (s: number) => `${s}`)
            }
            .width('100%')
          }

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

          Column({ space: 6 }) {
            Text('预览效果').fontColor(this.th().secondary).fontSize(12)
            Column({ space: 4 }) {
              Text('天地玄黄，宇宙洪荒。日月盈昃，辰宿列张。')
                .fontColor(this.th().text).fontSize(this.fs()).lineHeight(this.fs() * this.ls())
                .textIndent(this.fs() * 2)
              Text('寒来暑往，秋收冬藏。闰余成岁，律吕调阳。')
                .fontColor(this.th().text).fontSize(this.fs()).lineHeight(this.fs() * this.ls())
                .textIndent(this.fs() * 2)
            }
            .width('100%').padding({ left: 14, right: 14, top: 14, bottom: 14 })
            .backgroundColor(this.th().bg)
            .borderRadius(10).border({ width: 1, color: this.th().divider })
          }

          if (!this.bundle.plan) {
            Button('创建阅读计划，记录进度')
              .width('100%').height(44).fontSize(15).fontColor('#FFFFFF')
              .backgroundColor(this.th().accent).borderRadius(22)
              .onClick(() => this.createPlan())
          } else {
            Row({ space: 12 }) {
              Text(`当前计划`)
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

          if (this.contentSources().length > 0) {
            Column({ space: 8 }) {
              Row({ space: 6 }) {
                Text('≡').fontColor(this.th().accent).fontSize(14)
                Text('参考来源').fontColor(this.th().text).fontSize(14).fontWeight(FontWeight.Medium)
              }
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
        .width('100%').padding({ left: 20, right: 20, top: 18, bottom: 36 })
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('62%')
    .backgroundColor(this.th().bg)
    .borderRadius({ topLeft: 16, topRight: 16 })
    .shadow({ radius: 20, color: '#30000000', offsetX: 0, offsetY: -8 })
    .position({ x: 0, y: '38%' })
  }
}
