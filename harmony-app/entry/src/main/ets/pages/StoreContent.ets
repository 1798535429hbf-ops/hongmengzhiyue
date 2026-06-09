import { ApiClient, RecommendResult, ToolTrace } from '../common/ApiClient';
import { Book, RecommendationBook, SourceRef } from '../common/Models';
import { AiResponseView } from '../common/AiResponseView';
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
  @State storeAiQuery: string = '';
  @State storeAiAnswer: string = '';
  @State storeAiReasoning: string = '';
  @State storeAiFollowUp: string = '';
  @State storeAiSources: SourceRef[] = [];
  @State storeAiToolTrace: ToolTrace[] = [];
  @State storeAiStatusText: string = '';
  @State storeAiBusy: boolean = false;
  @State storeAiBooks: RecommendationBook[] = [];
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
    this.storeAiAnswer = '';
    this.storeAiReasoning = '';
    this.storeAiFollowUp = '';
    this.storeAiSources = [];
    this.storeAiToolTrace = [];
    this.storeAiStatusText = '';
    this.storeAiBooks = [];
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

  waitForThinkingFrame(): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, 650);
    });
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

  async askStoreAi(): Promise<void> {
    const query = this.storeAiQuery.trim();
    if (!query) {
      this.storeAiAnswer = '可以直接输入主题、课程、考试或心情关键词；线索少的时候，我会先从书库高评分和高热度书里挑。';
      this.storeAiReasoning = '';
      this.storeAiFollowUp = '';
      this.storeAiSources = [];
      this.storeAiToolTrace = [];
      return;
    }
    if (this.storeAiBusy) {
      return;
    }
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.storeAiAnswer = '先登录一下，我就能结合你的阅读偏好，直接替你挑出更顺手的书。';
      this.storeAiBooks = [];
      this.storeAiReasoning = '';
      this.storeAiFollowUp = '';
      this.storeAiSources = [];
      this.storeAiToolTrace = [];
      return;
    }
    this.storeAiBusy = true;
    this.storeAiAnswer = '';
    this.storeAiReasoning = '';
    this.storeAiFollowUp = '';
    this.storeAiSources = [];
    this.storeAiToolTrace = [];
    this.storeAiStatusText = '正在思考';
    let storeAiFailed: boolean = false;
    try {
      await this.waitForThinkingFrame();
      const result: RecommendResult = await ApiClient.recommendStream(userId, query, 0, {
        onDelta: (text: string) => {
          this.storeAiAnswer += text;
        },
        onReasoning: (text: string) => {
          this.storeAiReasoning += text;
        },
        onStatus: (text: string) => {
          this.storeAiStatusText = text;
        },
        onResult: (value: RecommendResult) => {
          this.storeAiAnswer = ApiClient.preferStreamText(this.storeAiAnswer, value.reason || '');
          this.storeAiBooks = value.book_list || [];
          this.storeAiFollowUp = value.follow_up_suggestion || '';
          this.storeAiSources = value.sources || [];
          this.storeAiToolTrace = value.tool_trace || [];
          this.storeAiReasoning = value.hidden_reasoning || value.reasoning_content || value.reasoning || this.storeAiReasoning;
        },
        onError: (message: string) => {
          this.storeAiStatusText = message;
        },
      });
      this.storeAiAnswer = ApiClient.preferStreamText(this.storeAiAnswer, result.reason || '');
      this.storeAiBooks = result.book_list || [];
      this.storeAiFollowUp = result.follow_up_suggestion || '';
      this.storeAiSources = result.sources || [];
      this.storeAiToolTrace = result.tool_trace || [];
      this.storeAiReasoning = result.hidden_reasoning || result.reasoning_content || result.reasoning || this.storeAiReasoning;
    } catch (err) {
      storeAiFailed = true;
      this.storeAiStatusText = `推荐失败：${err}`;
      this.storeAiBooks = [];
      this.storeAiFollowUp = '';
      this.storeAiSources = [];
      this.storeAiToolTrace = [];
    } finally {
      this.storeAiBusy = false;
      if (!storeAiFailed) {
        this.storeAiStatusText = '';
      }
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

      Column({ space: 18 }) {
        Row({ space: 14 }) {
          Stack() {
            Circle()
              .width(44)
              .height(44)
              .fill('#FDF8F0')
            Text('AI')
              .fontColor(Theme.mobileOrange)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
          }

          AiResponseView({
            answer: this.storeAiAnswer,
            reasoning: this.storeAiReasoning,
            followUpSuggestion: this.storeAiFollowUp,
            sources: this.storeAiSources,
            toolTrace: this.storeAiToolTrace,
            busy: this.storeAiBusy,
            statusText: this.storeAiStatusText,
            emptyText: '你的 AI 阅读顾问\n直接说想读什么，我会像朋友一样帮你挑书',
            compact: this.isCompact(),
            maxAnswerLines: 8,
          })
            .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)

        Text('今天想读点什么？')
          .fontColor(Theme.mobileText)
          .fontSize(this.isCompact() ? 17 : 18)
          .fontWeight(FontWeight.Medium)

        Row({ space: 10 }) {
          TextInput({ placeholder: '比如：想读人工智能入门、最近压力大想看轻松小说...', text: this.storeAiQuery })
            .layoutWeight(1)
            .height('100%')
            .fontColor(Theme.mobileText)
            .placeholderColor('#C0B7A6')
            .fontSize(this.isCompact() ? 16 : 17)
            .backgroundColor('transparent')
            .border({ width: 0 })
            .onChange((value: string) => {
              this.storeAiQuery = value;
            })
            .onSubmit(() => {
              if (!this.storeAiBusy) {
                this.askStoreAi();
              }
            })
          Stack() {
            Circle()
              .width(40)
              .height(40)
              .fill(this.storeAiBusy ? Theme.mobileOrange : (this.storeAiQuery.trim() ? Theme.mobileOrange : '#D2D4DB'))
            if (this.storeAiBusy) {
              LoadingProgress()
                .width(16)
                .height(16)
                .color(Theme.mobileSurface)
            } else {
              Text('↑')
                .fontColor(Theme.mobileSurface)
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
            }
          }
          .opacity(this.storeAiBusy ? 0.92 : 1)
          .onClick(() => {
            if (!this.storeAiBusy) {
              this.askStoreAi();
            }
          })
        }
        .width('100%')
        .height(this.isCompact() ? 104 : 116)
        .padding({ left: 18, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#FFFDF8')
        .border({ width: 1, color: '#EFE2D0' })
        .borderRadius(24)

        if (this.storeAiBooks.length > 0) {
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              Row({}) {}
                .width(3)
                .height(16)
                .borderRadius(2)
                .backgroundColor(Theme.mobileOrange)
              Text('AI 智能推荐')
                .fontColor(Theme.mobileText)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text(this.storeAiBusy ? '更新中' : '已就绪')
                .fontColor(Theme.mobileSubtext)
                .fontSize(12)
            }
            ForEach(this.storeAiBooks, (rec: RecommendationBook) => {
              Row({ space: 12 }) {
                Column({ space: 5 }) {
                  Text(rec.title)
                    .fontColor(Theme.mobileText)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                  if (!rec.titleOnly && rec.author) {
                    Text(rec.author)
                      .fontColor(Theme.mobileSubtext)
                      .fontSize(13)
                  }
                  if (!rec.titleOnly && rec.reason) {
                    Text(rec.reason)
                      .fontColor(Theme.mobileBlue)
                      .fontSize(12)
                      .lineHeight(18)
                      .maxLines(2)
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                if (this.canOpenRecommendation(rec)) {
                  Row() {
                    Text('详情 >')
                      .fontColor(Theme.mobileOrange)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                  }
                  .onClick(() => {
                    openBookDetail(rec.id);
                  })
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#FDFAF5')
              .borderRadius(16)
              .border({ width: 1, color: '#F0E6D0' })
            }, (rec: RecommendationBook, index: number) => `${rec.id}-${rec.title}-${index}`)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(24)
      .shadow({ radius: 20, color: '#18000000', offsetX: 0, offsetY: 10 })

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
