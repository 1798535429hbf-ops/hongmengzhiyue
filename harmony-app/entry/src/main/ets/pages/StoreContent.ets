import { ApiClient, RecommendResult } from '../common/ApiClient';
import { Book, RecommendationBook } from '../common/Models';
import { BookCover } from '../common/BookCover';
import { openBookDetail, openSearch } from '../common/Navigation';
import { Theme } from '../common/Theme';
import { UserSession } from '../common/UserSession';

const STORE_TABS: string[] = ['精选', '男生', '女生', '出版', '听书', '漫画'];

@Component
export struct StoreContent {
  @Prop pageWidth: number = 390;
  @StorageProp('smartread_session_user_id') @Watch('onSessionUserChange') sessionUserId: number = 0;
  @State storeTabIndex: number = 0;
  @State storeRecommendBooks: RecommendationBook[] = [];
  @State storeRecommendReason: string = '';
  @State storeRecommendOffset: number = 0;
  @State storeRecommendLoading: boolean = false;
  @State storeSectionBooksData: Book[] = [];
  @State storeSectionLoading: boolean = false;
  @State storeSectionError: string = '';
  @State storeSectionPage: number = 0;

  aboutToAppear(): void {
    this.loadStoreRecommendations();
    this.loadStoreSection(true);
  }

  onSessionUserChange(): void {
    this.storeRecommendBooks = [];
    this.storeRecommendReason = '';
    this.storeRecommendOffset = 0;
    this.loadStoreRecommendations(true);
    this.loadStoreSection(true);
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  sectionGap(): number {
    return this.isCompact() ? 16 : 18;
  }

  storeSectionKey(): string {
    if (this.storeTabIndex === 1) {
      return 'male';
    }
    if (this.storeTabIndex === 2) {
      return 'female';
    }
    if (this.storeTabIndex === 3) {
      return 'publish';
    }
    if (this.storeTabIndex === 4) {
      return 'audio';
    }
    if (this.storeTabIndex === 5) {
      return 'comic';
    }
    return 'featured';
  }

  storeSectionTitle(): string {
    return STORE_TABS[this.storeTabIndex] || '精选';
  }

  async loadStoreSection(reset: boolean = false): Promise<void> {
    if (this.storeSectionLoading) {
      return;
    }
    const userId: number = UserSession.currentUserId();
    this.storeSectionLoading = true;
    this.storeSectionError = '';
    if (reset) {
      this.storeSectionPage = 0;
      this.storeSectionBooksData = [];
    }
    try {
      const books: Book[] = await ApiClient.storeBooks(this.storeSectionKey(), userId, this.storeSectionPage, 8);
      this.storeSectionBooksData = books || [];
      this.storeSectionPage += this.storeSectionBooksData.length > 0 ? 1 : 0;
    } catch (err) {
      this.storeSectionBooksData = [];
      this.storeSectionError = `分区加载失败：${err}`;
    } finally {
      this.storeSectionLoading = false;
    }
  }

  async loadStoreRecommendations(reset: boolean = false): Promise<void> {
    if (this.storeRecommendLoading) {
      return;
    }
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.storeRecommendBooks = [];
      this.storeRecommendReason = '登录后，我会直接从书库里挑几本更像你会喜欢的书。';
      return;
    }
    this.storeRecommendLoading = true;
    this.storeRecommendReason = '';
    if (reset) {
      this.storeRecommendOffset = 0;
    }
    try {
      const query: string = reset || this.storeRecommendOffset === 0 ? '' : `换一批 ${this.storeRecommendOffset}`;
      const result: RecommendResult = await ApiClient.recommendStream(userId, query, this.storeRecommendOffset);
      const normalized: RecommendationBook[] = result.book_list || [];
      this.storeRecommendBooks = normalized;
      this.storeRecommendReason = ApiClient.preferStreamText(this.storeRecommendReason, result.reason || '');
      this.storeRecommendReason = this.storeRecommendReason || (normalized.length > 0
        ? ''
        : '这批书刚好没命中，下次我换一组更贴近你当前阅读口味的。');
      this.storeRecommendOffset += normalized.length > 0 ? normalized.length : 1;
    } catch (_) {
      this.storeRecommendBooks = [];
      this.storeRecommendReason = '书库推荐暂时没拉到结果，稍后再试一次。';
    } finally {
      this.storeRecommendLoading = false;
    }
  }

  build() {
    Column({ space: this.sectionGap() }) {
      Row({ space: 12 }) {
        Text('书城')
          .fontColor(Theme.mobileText)
          .fontSize(this.titleSize())
          .fontWeight(FontWeight.Bold)

        Row({ space: 10 }) {
          Image($r('app.media.discover_search'))
            .width(22)
            .height(22)
          Text('搜索书名 / 作者 / 关键词')
            .fontColor('#B0B4C1')
            .fontSize(this.isCompact() ? 15 : 16)
          Blank()
        }
        .layoutWeight(1)
        .height(this.isCompact() ? 48 : 52)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Theme.mobileSurface)
        .border({ width: 1, color: Theme.mobileLine })
        .borderRadius(26)
        .onClick(() => openSearch())

        this.CircleActionButton($r('app.media.mobile_cart'))
      }
      .alignItems(VerticalAlign.Center)

      Row({ space: this.isCompact() ? 20 : 24 }) {
        ForEach(STORE_TABS, (label: string, index: number) => {
          Column({ space: 8 }) {
            Text(label)
              .fontColor(this.storeTabIndex === index ? Theme.mobileText : Theme.mobileSubtext)
              .fontSize(this.isCompact() ? 15 : 16)
              .fontWeight(this.storeTabIndex === index ? FontWeight.Bold : FontWeight.Medium)
            if (this.storeTabIndex === index) {
              Row({}) {}
                .width(28)
                .height(4)
                .borderRadius(2)
                .backgroundColor(Theme.mobileBlue)
                .margin({ top: 6 })
            }
          }
          .alignItems(HorizontalAlign.Center)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(this.storeTabIndex === index ? Theme.mobileBlueSoft : 'transparent')
          .borderRadius(16)
          .onClick(() => {
            this.storeTabIndex = index;
            this.loadStoreSection(true);
          })
        }, (label: string) => label)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

      if (this.storeRecommendBooks.length > 0) {
        Column({ space: 14 }) {
          this.SectionTitle('猜你喜欢', this.storeRecommendLoading ? '换书中' : '换一批', 'recommend')
          if (this.storeRecommendReason) {
            Text(this.storeRecommendReason)
              .fontColor(Theme.mobileSubtext)
              .fontSize(13)
              .lineHeight(19)
          }
          ForEach(this.storeRecommendBooks, (rec: RecommendationBook) => {
            this.RecommendBookCard(rec)
          }, (rec: RecommendationBook, index: number) => `${rec.id}-${rec.title}-${index}`)
        }
      }

      if (this.storeSectionError) {
        Text(this.storeSectionError)
          .fontColor('#B45B47')
          .fontSize(12)
          .lineHeight(18)
      }

      this.SectionTitle(this.storeSectionTitle(), this.storeSectionLoading ? '加载中' : '换一批', 'section')

      if (this.storeSectionBooksData.length > 0) {
        ForEach(this.storeSectionBooksData, (book: Book) => {
          this.StoreBookCard(book)
        }, (book: Book) => `${book.id}`)
      } else {
        Text(this.storeSectionLoading ? '正在从后端书库加载...' : '这个分区暂时没有真实入库书籍。')
          .fontColor(Theme.mobileSubtext)
          .fontSize(14)
          .lineHeight(22)
          .padding(18)
          .backgroundColor(Theme.mobileSurface)
          .borderRadius(18)
      }
    }
    .width('100%')
  }

  canOpenRecommendation(rec: RecommendationBook): boolean {
    return !!rec && rec.id > 0 && !rec.titleOnly;
  }

  async changeRecommendBatch(): Promise<void> {
    await this.loadStoreRecommendations(false);
  }

  coverToneFor(rec: RecommendationBook): string {
    return rec.coverColor || '#F5F0E8';
  }

  splitBookTags(raw: string): string[] {
    if (!raw) {
      return [];
    }
    return raw.split(/[，,、\/\s]+/).filter((tag: string) => !!tag.trim());
  }

  bookMetaLine(book: Book): string {
    const chapterCount = book.chapterCount || 0;
    const readable = book.readable === 1 || book.readable === true || chapterCount > 0;
    const source = book.sourceType === 'local_txt' || book.sourceType === 'local_epub' ? '本地入库' : '云端书库';
    if (readable) {
      return `${source} · 可读 ${chapterCount} 章 · ${book.difficulty || '难度待定'}`;
    }
    return `${source} · ${book.importStatus || '待入库'} · ${book.difficulty || '难度待定'}`;
  }

  titleSize(): number {
    if (this.pageWidth >= 900) {
      return 34;
    }
    return this.isCompact() ? 26 : 30;
  }

  @Builder
  StoreBookCard(book: Book) {
    Row({ space: 16 }) {
      BookCover({
        bookId: book.id,
        title: book.title,
        difficulty: book.difficulty,
        coverColor: book.coverColor || '#F5F0E8',
        widthValue: 82,
        heightValue: 118,
        titleSize: 11,
      })

      Column({ space: 8 }) {
        Text(book.title)
          .fontColor(Theme.mobileText)
          .fontSize(this.isCompact() ? 18 : 20)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
        Text(book.author)
          .fontColor(Theme.mobileSubtext)
          .fontSize(15)
        Text(this.bookMetaLine(book))
          .fontColor(Theme.mobileOrange)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
        Text(book.summary || '这本书来自真实书库，可以进入详情查看章节、来源和伴读能力。')
          .fontColor(Theme.mobileSubtext)
          .fontSize(14)
          .lineHeight(22)
          .maxLines(3)

        if (book.tags) {
          Row({ space: 8 }) {
            ForEach(this.splitBookTags(book.tags).slice(0, 3), (tag: string) => {
              Text(tag)
                .fontColor(Theme.mobileSubtext)
                .fontSize(13)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor('#F4F5F8')
                .borderRadius(12)
            }, (tag: string) => tag)
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .onClick(() => {
      openBookDetail(book.id);
    })
  }

  @Builder
  RecommendBookCard(rec: RecommendationBook) {
    Row({ space: 16 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column()
          .width(68)
          .height(92)
          .backgroundColor(this.coverToneFor(rec))
          .borderRadius(14)
          .border({ width: 1, color: '#E8DDCC' })
        Row({}) {}
          .width(32)
          .height(3)
          .borderRadius(2)
          .backgroundColor('#D4C8B0')
          .margin({ right: 12, bottom: 16 })
        Row({}) {}
          .width(22)
          .height(3)
          .borderRadius(2)
          .backgroundColor('#D4C8B0')
          .margin({ right: 12, bottom: 10 })
        Row({}) {}
          .width(28)
          .height(3)
          .borderRadius(2)
          .backgroundColor('#D4C8B0')
          .margin({ right: 12, bottom: 4 })
      }
      .width(68)
      .height(92)

      Column({ space: 8 }) {
        Text(rec.title)
          .fontColor(Theme.mobileText)
          .fontSize(this.isCompact() ? 17 : 19)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
        if (!rec.titleOnly && rec.author) {
          Text(rec.author)
            .fontColor(Theme.mobileSubtext)
            .fontSize(14)
            .maxLines(1)
        }
        if (!rec.titleOnly && rec.reason) {
          Row({ space: 6 }) {
            Row({}) {}
              .width(2)
              .height(14)
              .borderRadius(1)
              .backgroundColor(Theme.mobileOrange)
            Text(rec.reason)
              .fontColor(Theme.mobileSubtext)
              .fontSize(13)
              .lineHeight(18)
              .maxLines(2)
              .layoutWeight(1)
          }
        }
        if (this.canOpenRecommendation(rec)) {
          Row({ space: 6 }) {
            Text('查看详情')
              .fontColor(Theme.mobileOrange)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
            Image($r('app.media.icon_chevron_right'))
              .width(14)
              .height(14)
          }
          .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FDFAF5')
    .borderRadius(22)
    .border({ width: 1, color: '#F0E6D0' })
    .onClick(() => {
      if (this.canOpenRecommendation(rec)) {
        openBookDetail(rec.id);
      }
    })
  }

  @Builder
  SectionTitle(title: string, action: string = '', actionKind: string = '') {
    Row() {
      Text(title)
        .fontColor(Theme.mobileText)
        .fontSize(this.isCompact() ? 26 : 28)
        .fontWeight(FontWeight.Bold)
      Blank()
      if (action) {
        Row({ space: 6 }) {
          Text(action)
            .fontColor(action === '加载中' || action === '换书中' ? '#C0B7A6' : Theme.mobileSubtext)
            .fontSize(15)
          if (action === '换一批' || action === '换书中') {
            Text(action === '换书中' ? '…' : 'C')
              .fontColor(Theme.mobileSubtext)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
          } else {
            Image($r('app.media.icon_chevron_right'))
              .width(14)
              .height(14)
          }
        }
        .onClick(() => {
          if (action === '加载中' || action === '换书中') {
            return;
          }
          if (actionKind === 'recommend') {
            this.changeRecommendBatch();
          } else if (actionKind === 'section') {
            this.loadStoreSection(false);
          }
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  CircleActionButton(icon: Resource, withShadow: boolean = true) {
    Stack() {
      Circle()
        .width(46)
        .height(46)
        .fill(Theme.mobileSurface)
      Image(icon)
        .width(22)
        .height(22)
    }
    .width(46)
    .height(46)
    .shadow(withShadow ? { radius: 14, color: '#15000000', offsetX: 0, offsetY: 6 } : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })
  }
}
