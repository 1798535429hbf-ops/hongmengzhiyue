import { ApiClient } from '../common/ApiClient';
import { Book, emptyBook, VolumeItem, CatalogVolume } from '../common/Models';
import { BookCover } from '../common/BookCover';
import { currentBookId, goBack, openCatalog, openReader } from '../common/Navigation';
import { ShelfStore } from '../common/ShelfStore';
import { Theme } from '../common/Theme';
import { common } from '@kit.AbilityKit';

const USER_ID: number = 10086;

@Entry
@Component
struct BookDetailPage {
  @State bookId: number = 0;
  @State book: Book = emptyBook();
  @State busyText: string = '';
  @State errorText: string = '';
  @State summaryExpanded: boolean = false;
  @State pageWidth: number = 390;

  aboutToAppear(): void {
    this.bookId = currentBookId();
    this.loadBook();
  }

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  isCompact(): boolean { return this.pageWidth < 360; }
  isWide(): boolean { return this.pageWidth >= 720; }

  cardHMargin(): number { return this.isWide() ? 24 : 12; }
  heroHeight(): number { if (this.isCompact()) return 380; if (this.isWide()) return 640; return 520; }

  coverWidth(): number { if (this.isCompact()) return 110; if (this.isWide()) return 180; return 138; }
  coverHeight(): number { if (this.isCompact()) return 156; if (this.isWide()) return 256; return 196; }

  titleSize(): number { if (this.isCompact()) return 20; if (this.isWide()) return 30; return 24; }
  cardPadding(): number { return this.isWide() ? 24 : 18; }
  watermarkSize(): number { if (this.isCompact()) return 60; if (this.isWide()) return 100; return 80; }
  sectionTitleSize(): number { return this.isWide() ? 22 : 18; }
  bodyFontSize(): number { return this.isWide() ? 16 : 14; }
  contentMaxWidth(): number { if (this.isWide()) return 680; return 640; }

  headerHeight(): number { return 56; }

  async loadBook(): Promise<void> {
    if (this.bookId <= 0) { this.errorText = '缺少 bookId'; return; }
    this.busyText = '正在读取图书详情'; this.errorText = '';
    try {
      this.book = await ApiClient.getBook(this.bookId);
      const ctx = this.hostContext();
      if (ctx) {
        await ShelfStore.recordRemoteBrowse(ctx, {
          bookId: this.book.id, title: this.book.title, author: this.book.author,
          tags: this.book.tags, difficulty: this.book.difficulty, coverColor: this.book.coverColor,
          actionText: '查看图书详情',
        });
      }
    } catch (err) { this.errorText = `详情加载失败：${err}`; } finally { this.busyText = ''; }
  }

  async addFavorite(): Promise<void> {
    this.busyText = '正在加入书架'; this.errorText = '';
    try { await ApiClient.favorite(USER_ID, this.book.id); this.busyText = '已加入书架'; }
    catch (err) { this.errorText = `加入书架失败：${err}`; this.busyText = ''; }
  }

  isReadable(): boolean { return this.book.readable === 1 || this.book.readable === true || (this.book.chapterCount || 0) > 0; }
  openReaderSafely(): void {
    if (!this.isReadable()) { this.errorText = this.book.sourceNote || '暂无章节'; return; }
    openReader(this.book.id);
  }

  heroGradientColors(): [string, string] {
    const base = this.book.coverColor || '#1A0E0A';
    if (base.startsWith('#') && base.length === 7) {
      const r = parseInt(base.substring(1, 3), 16);
      const g = parseInt(base.substring(3, 5), 16);
      const b = parseInt(base.substring(5, 7), 16);
      return [`rgb(${Math.max(0, r - 40)}, ${Math.max(0, g - 20)}, ${Math.max(0, b - 30)})`, `rgb(${Math.min(255, r + 60)}, ${Math.min(255, g + 30)}, ${Math.min(255, b + 20)})`];
    }
    return ['#2C1810', '#4A2C20'];
  }

  headerBgColor(): string {
    const base = this.book.coverColor || '#1A0E0A';
    if (base.startsWith('#') && base.length === 7) {
      const r = parseInt(base.substring(1, 3), 16);
      const g = parseInt(base.substring(3, 5), 16);
      const b = parseInt(base.substring(5, 7), 16);
      return `rgb(${Math.max(0, r - 30)}, ${Math.max(0, g - 15)}, ${Math.max(0, b - 25)})`;
    }
    return '#2C1810';
  }

  ratingDisplay(): string { const r = this.book.rating; return (r && r > 0) ? r.toFixed(1) : '-'; }
  ratingCountText(): string { const c = this.book.ratingCount || 0; return c > 0 ? `${c}人评分` : ''; }
  wordCountText(): string { const w = this.book.wordCount || 0; if (w >= 10000) return `${(w / 10000).toFixed(0)}万字`; if (w > 0) return `${w}字`; return '-'; }
  readerCountText(): string { const c = this.book.readerCount || 0; if (c >= 10000) return `${(c / 10000).toFixed(0)}万`; if (c > 0) return `${c}`; return '-'; }
  editionNoteText(): string { return this.book.editionNote || ''; }

  ratingStars(): number[] {
    const rating = this.book.rating || 0; const stars: number[] = [];
    for (let i = 1; i <= 5; i++) { stars.push(rating >= i ? 2 : (rating >= i - 0.5 ? 1 : 0)); }
    return stars;
  }

  volumeCount(): number {
    const vols = this.book.catalogVolumes; if (vols && vols.length > 0) return vols.length;
    const ch = this.book.chapterCount || 0; return ch > 0 ? Math.ceil(ch / 10) : 0;
  }

  volumeItems(): VolumeItem[] {
    const vols = this.book.catalogVolumes;
    if (vols && vols.length > 0) { const r: VolumeItem[] = []; for (let i = 0; i < vols.length; i++) r.push({ id: vols[i].id, title: vols[i].title }); return r; }
    const count = this.volumeCount(); if (count > 0) { const items: VolumeItem[] = []; for (let i = 0; i < count; i++) items.push({ id: `v${i + 1}`, title: `第${this.toCn(i + 1)}部分` }); return items; }
    return [];
  }

  toCn(n: number): string { const m = ['零','一','二','三','四','五','六','七','八','九','十']; if (n <= 10) return m[n]; if (n < 20) return `十${m[n - 10]}`; return `${m[Math.floor(n / 10)]}十${n % 10 > 0 ? m[n % 10] : ''}`; }

  translatorText(): string { return this.book.translator || '-'; }
  publisherText(): string { return this.book.sourceType || '-'; }
  isbnText(): string { return this.book.isbn || '-'; }

  pickedTag(raw: string, fallback: string): string { const t = (raw || '').trim(); if (!t) return fallback; const sep = [',','，','/',' ']; for (let i = 0; i < sep.length; i++) { const idx = t.indexOf(sep[i]); if (idx > 0) return t.substring(0, idx).trim(); } return t; }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Scroll() {
          Column() {
            this.HeroSection()

            if (this.errorText) { this.Banner(this.errorText, Theme.error) }
            if (this.busyText) { this.Banner(this.busyText, Theme.mobileBlue) }

            this.RatingCard()
            this.SummaryCard()
            this.CatalogCard()
            this.BookInfoCard()
            Blank().height(100)
          }
          .width('100%')
          .constraintSize({ maxWidth: this.contentMaxWidth() })
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F0')

      this.StickyHeader()
      this.BottomActionBar()
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_, area) => {
      const nextWidth: number = typeof area.width === 'number' ? area.width : Number(area.width);
      if (Number.isFinite(nextWidth) && nextWidth > 0) { this.pageWidth = nextWidth; }
    })
  }

  @Builder
  StickyHeader() {
    Row({ space: 12 }) {
      Text('‹')
        .fontColor('#FFFFFF')
        .fontSize(32)
        .fontWeight(FontWeight.Regular)
        .onClick(() => goBack())

      BookCover({
        bookId: this.book.id, title: this.book.title, difficulty: this.book.difficulty,
        coverColor: this.book.coverColor, widthValue: 34, heightValue: 46, titleSize: 7,
      })

      Column({ space: 2 }) {
        Text(this.book.title || '加载中...')
          .fontColor('#FFFFFF')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
        Text(this.pickedTag(this.book.tags, this.book.difficulty || '详情'))
          .fontColor('rgba(255,255,255,0.6)')
          .fontSize(12)
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('···')
        .fontColor('#FFFFFF')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .opacity(0.8)
    }
    .width('100%')
    .height(this.headerHeight())
    .padding({ left: 12, right: 14 })
    .backgroundColor(this.headerBgColor())
    .position({ x: 0, y: 0 })
  }

  @Builder
  HeroSection() {
    Column() {
      Column()
        .width('100%')
        .height(this.heroHeight())
        .linearGradient({ angle: 180, colors: [[this.heroGradientColors()[0], 0], [this.heroGradientColors()[1], 1]] })

      Text(this.book.title || '')
        .fontColor('#FFFFFF')
        .fontSize(this.watermarkSize())
        .fontWeight(FontWeight.Bold)
        .opacity(0.08)
        .position({ x: '60%', y: 80 })

      Column() {
        Row()
          .width('100%')
          .height(56)

        Row({ space: this.isWide() ? 24 : 16 }) {
          BookCover({
            bookId: this.book.id, title: this.book.title, difficulty: this.book.difficulty,
            coverColor: this.book.coverColor, widthValue: this.coverWidth(),
            heightValue: this.coverHeight(), titleSize: this.isWide() ? 16 : 14,
          })
          Column({ space: this.isCompact() ? 6 : 10 }) {
            Text(this.book.title || '加载中...')
              .fontColor('#FFFFFF').fontSize(this.titleSize()).fontWeight(FontWeight.Bold)
              .lineHeight(this.titleSize() + 8).maxLines(2)
            Text(this.book.author || '')
              .fontColor('rgba(255,255,255,0.85)').fontSize(this.isWide() ? 17 : 15)
            if (this.book.tags) {
              Text(this.book.tags).fontColor('rgba(255,255,255,0.65)').fontSize(this.isWide() ? 15 : 13).maxLines(1)
            }
            if (this.editionNoteText()) {
              Text(this.editionNoteText()).fontColor('rgba(255,255,255,0.65)').fontSize(this.isWide() ? 15 : 13).maxLines(1)
            }
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: this.isWide() ? 24 : 16, right: this.isWide() ? 24 : 16, bottom: 30 })
      }
      .position({ x: 0, y: 0 })
      .width('100%')
    }
    .width('100%')
    .height(this.heroHeight())
  }

  @Builder
  Banner(text: string, color: string) {
    Text(text).fontColor(Theme.mobileSurface).fontSize(13).lineHeight(18)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 }).backgroundColor(color)
      .borderRadius(16).width('100%').margin({ left: this.cardHMargin(), right: this.cardHMargin() })
  }

  @Builder
  RatingCard() {
    Row({ space: 0 }) {
      Column({ space: 6 }) {
        Text(this.ratingDisplay()).fontColor(Theme.mobileText).fontSize(this.isWide() ? 40 : 32).fontWeight(FontWeight.Bold)
        Row({ space: 2 }) {
          ForEach(this.ratingStars(), (star: number) => {
            Text(star === 2 ? '★' : (star === 1 ? '☆' : '☆')).fontColor(star >= 1 ? '#F5A623' : '#DDDDDD').fontSize(14)
          })
        }
        if (this.ratingCountText()) { Text(this.ratingCountText()).fontColor(Theme.mobileSubtext).fontSize(12) }
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      Column({ space: 6 }) {
        Text(this.wordCountText()).fontColor(Theme.mobileText).fontSize(this.isWide() ? 28 : 22).fontWeight(FontWeight.Bold)
        Text('完整').fontColor(Theme.mobileSubtext).fontSize(12)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)

      Column({ space: 6 }) {
        Text(this.readerCountText()).fontColor(Theme.mobileText).fontSize(this.isWide() ? 28 : 22).fontWeight(FontWeight.Bold)
        Text('在读人数').fontColor(Theme.mobileSubtext).fontSize(12)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ left: this.cardPadding(), right: this.cardPadding(), top: 22, bottom: 22 })
    .margin({ left: this.cardHMargin(), right: this.cardHMargin(), top: -20 })
    .backgroundColor(Theme.mobileSurface).borderRadius(18)
    .shadow({ radius: 14, color: '#14000000', offsetX: 0, offsetY: 6 })
  }

  @Builder
  SummaryCard() {
    Column({ space: 12 }) {
      Text('简介').fontColor(Theme.mobileText).fontSize(this.sectionTitleSize()).fontWeight(FontWeight.Bold)
      Text(this.book.summary || '暂无简介').fontColor('#616161').fontSize(this.bodyFontSize())
        .lineHeight(this.bodyFontSize() + 10).maxLines(this.summaryExpanded ? 100 : 4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.book.summary && this.book.summary.length > 120) {
        Text(this.summaryExpanded ? '收起' : '展开')
          .fontColor(Theme.mobileBlue).fontSize(13).fontWeight(FontWeight.Medium)
          .onClick(() => { this.summaryExpanded = !this.summaryExpanded; })
      }
    }
    .width('100%').padding(this.cardPadding())
    .margin({ left: this.cardHMargin(), right: this.cardHMargin(), top: 12 })
    .backgroundColor(Theme.mobileSurface).borderRadius(18)
    .shadow({ radius: 12, color: '#10000000', offsetX: 0, offsetY: 4 })
  }

  @Builder
  CatalogCard() {
    Column({ space: 14 }) {
      Row() {
        Text('目录').fontColor(Theme.mobileText).fontSize(this.sectionTitleSize()).fontWeight(FontWeight.Bold)
        Blank()
        if (this.volumeCount() > 0) {
          Row({ space: 4 }) {
            Text(`共${this.volumeCount()}卷`).fontColor(Theme.mobileSubtext).fontSize(13)
            Image($r('app.media.icon_chevron_right')).width(14).height(14)
          }
        }
      }
      if (this.volumeItems().length > 0) {
        ForEach(this.volumeItems().slice(0, 3), (item: VolumeItem, index: number) => {
          Row({ space: 12 }) {
            Image($r('app.media.icon_chevron_right')).width(18).height(18).fillColor('#8B7355')
            Text(item.title).fontColor(Theme.mobileText).fontSize(15).lineHeight(22).layoutWeight(1)
            Image($r('app.media.icon_chevron_right')).width(14).height(14).fillColor('#C0C4CC')
          }
          .width('100%').padding({ top: index === 0 ? 0 : 12 })
          if (index < this.volumeItems().length - 1) { Divider().color('#F0F0F0').strokeWidth(0.5).margin({ top: 12 }) }
        })
      } else {
        Text('暂无目录信息').fontColor(Theme.mobileSubtext).fontSize(13)
      }
    }
    .width('100%').padding(this.cardPadding())
    .margin({ left: this.cardHMargin(), right: this.cardHMargin(), top: 12 })
    .backgroundColor(Theme.mobileSurface).borderRadius(18)
    .shadow({ radius: 12, color: '#10000000', offsetX: 0, offsetY: 4 })
    .onClick(() => { if (this.volumeCount() > 0) openCatalog(this.book.id); })
  }

  @Builder
  BookInfoCard() {
    Column({ space: 14 }) {
      Text('书籍信息').fontColor(Theme.mobileText).fontSize(this.sectionTitleSize()).fontWeight(FontWeight.Bold)
      Column({ space: 12 }) {
        this.InfoRow('作者', this.book.author || '-')
        this.InfoRow('译者', this.translatorText())
        this.InfoRow('出版社', this.publisherText())
        this.InfoRow('出版时间', '-')
        this.InfoRow('ISBN', this.isbnText())
      }
    }
    .width('100%').padding(this.cardPadding())
    .margin({ left: this.cardHMargin(), right: this.cardHMargin(), top: 12 })
    .backgroundColor(Theme.mobileSurface).borderRadius(18)
    .shadow({ radius: 12, color: '#10000000', offsetX: 0, offsetY: 4 })
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontColor(Theme.mobileSubtext).fontSize(14).width(72)
      Text(value).fontColor(Theme.mobileText).fontSize(14).layoutWeight(1).maxLines(1)
    }
    .width('100%')
  }

  @Builder
  BottomActionBar() {
    Row({ space: this.isWide() ? 20 : 12 }) {
      Column({ space: 4 }) {
        Image($r('app.media.icon_chevron_right')).width(this.isWide() ? 24 : 20).height(this.isWide() ? 24 : 20)
          .fillColor('#666666').rotate({ angle: 90 })
        Text('加入书架').fontColor('#666666').fontSize(this.isWide() ? 13 : 11)
      }
      .alignItems(HorizontalAlign.Center).onClick(() => this.addFavorite())

      Button('听书').height(this.isCompact() ? 36 : 40).fontColor('#8B4513').fontSize(this.isWide() ? 17 : 15)
        .backgroundColor('#FFF0E6').borderRadius(20)
        .padding({ left: this.isWide() ? 32 : 24, right: this.isWide() ? 32 : 24 })

      Button('立即阅读').layoutWeight(1).height(this.isCompact() ? 38 : 44)
        .fontColor(Theme.mobileSurface).fontSize(this.isWide() ? 18 : 16).fontWeight(FontWeight.Medium)
        .backgroundColor(this.isReadable() ? Theme.mobileRed : '#CCCCCC').borderRadius(22)
        .onClick(() => this.openReaderSafely())
    }
    .width('100%').height(this.isCompact() ? 60 : 72)
    .padding({ left: this.isWide() ? 24 : 16, right: this.isWide() ? 24 : 16, top: 10, bottom: this.isCompact() ? 8 : 12 })
    .backgroundColor(Theme.mobileSurface).border({ width: 1, color: '#F0F0F0' })
  }
}
