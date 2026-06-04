import { ApiClient, RecommendResult } from '../common/ApiClient';
import { Book, RecommendationBook, UserProfile } from '../common/Models';
import { BookCover } from '../common/BookCover';
import { openBookDetail, openSearch } from '../common/Navigation';
import { Theme } from '../common/Theme';
import { UserSession } from '../common/UserSession';

const STORE_TABS: string[] = ['精选', '男生', '女生', '出版', '听书', '漫画'];

const STORE_QUICK_QUESTIONS: string[] = [
  '推荐适合我的书',
  '最近有什么好书',
  '根据我的画像制定阅读计划',
  '我要学人工智能',
];

@Component
export struct StoreContent {
  @Prop pageWidth: number = 390;
  @StorageProp('smartread_session_user_id') @Watch('onSessionUserChange') sessionUserId: number = 0;
  @State storeTabIndex: number = 0;
  @State storeAiQuery: string = '';
  @State storeAiAnswer: string = '';
  @State storeAiBusy: boolean = false;
  @State storeAiBooks: RecommendationBook[] = [];
  @State storeAiThoughts: string[] = [];
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
    this.storeAiBooks = [];
    this.storeAiThoughts = [];
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

  async askStoreAi(): Promise<void> {
    const query = this.storeAiQuery.trim();
    if (!query) {
      this.storeAiAnswer = '告诉我你最近想读的感觉、场景或者主题，我来帮你挑书。';
      return;
    }
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.storeAiAnswer = '先登录一下，我就能结合你的阅读偏好，直接替你挑出更顺手的书。';
      this.storeAiBooks = [];
      this.storeAiThoughts = [];
      return;
    }
    this.storeAiBusy = true;
    this.storeAiAnswer = '';
    this.storeAiThoughts = [];
    try {
      const result: RecommendResult = await ApiClient.recommend(userId, this.buildAiRequestQuery(query));
      this.storeAiAnswer = this.makeHumanRecommendation(result, query);
      this.storeAiBooks = result.book_list || [];
      this.storeAiThoughts = this.buildRecommendationEvidence(result);
    } catch (err) {
      this.storeAiAnswer = `我刚刚没把书找全，换个问法我再试一次。`;
      this.storeAiBooks = [];
      this.storeAiThoughts = [];
    } finally {
      this.storeAiBusy = false;
    }
  }

  async quickAskStoreAi(question: string): Promise<void> {
    this.storeAiQuery = question;
    await this.askStoreAi();
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
    if (reset) {
      this.storeRecommendOffset = 0;
    }
    try {
      const query: string = reset || this.storeRecommendOffset === 0 ? '' : `换一批 ${this.storeRecommendOffset}`;
      const result: RecommendResult = await ApiClient.recommend(userId, query, this.storeRecommendOffset);
      const normalized: RecommendationBook[] = result.book_list || [];
      this.storeRecommendBooks = normalized;
      this.storeRecommendReason = result.reason || (normalized.length > 0
        ? this.pickRecommendationLead(normalized)
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

          Row() {
            if (this.storeAiBusy) {
              Text('我正在翻书库、看资料片段，再给你挑几本顺手的...')
                .fontColor(Theme.mobileOrange)
                .fontSize(this.isCompact() ? 16 : 17)
                .fontWeight(FontWeight.Medium)
                .lineHeight(this.isCompact() ? 26 : 28)
            } else if (this.storeAiAnswer) {
              Text(this.storeAiAnswer)
                .fontColor(Theme.mobileText)
                .fontSize(this.isCompact() ? 16 : 17)
                .fontWeight(FontWeight.Medium)
                .lineHeight(this.isCompact() ? 25 : 27)
                .maxLines(6)
            } else {
              Text('你的 AI 阅读顾问\n直接说想读什么，我会像朋友一样帮你挑书')
                .fontColor(Theme.mobileText)
                .fontSize(this.isCompact() ? 16 : 17)
                .fontWeight(FontWeight.Medium)
                .lineHeight(this.isCompact() ? 26 : 28)
            }
          }
          .layoutWeight(1)
          .padding({ left: 18, right: 18, top: 18, bottom: 18 })
          .backgroundColor('#FDFAF5')
          .borderRadius(24)
          .border({ width: 1, color: '#F0E6D0' })
        }
        .alignItems(VerticalAlign.Top)

        if (this.storeAiThoughts.length > 0) {
          Column({ space: 8 }) {
            Row({ space: 6 }) {
              Text('推荐依据')
                .fontColor('#8A6A3F')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text(this.storeAiBusy ? '整理中' : '已整理')
                .fontColor(Theme.mobileOrange)
                .fontSize(12)
            }
            ForEach(this.storeAiThoughts, (thought: string, index: number) => {
              Row({ space: 8 }) {
                Text(`${index + 1}`)
                  .fontColor(Theme.mobileSurface)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .width(20)
                  .height(20)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(Theme.mobileOrange)
                  .borderRadius(10)
                Text(thought)
                  .fontColor('#7C6B56')
                  .fontSize(13)
                  .lineHeight(19)
                  .layoutWeight(1)
              }
            }, (thought: string) => thought)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .backgroundColor('#FFF8EE')
          .border({ width: 1, color: '#F0E1C8' })
          .borderRadius(18)
        }

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
              this.askStoreAi();
            })
          Stack() {
            Circle()
              .width(40)
              .height(40)
              .fill(this.storeAiQuery.trim() ? Theme.mobileOrange : '#D2D4DB')
            Text('↑')
              .fontColor(Theme.mobileSurface)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
          }
          .onClick(() => {
            this.askStoreAi();
          })
        }
        .width('100%')
        .height(this.isCompact() ? 104 : 116)
        .padding({ left: 18, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#FFFDF8')
        .border({ width: 1, color: '#EFE2D0' })
        .borderRadius(24)

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(STORE_QUICK_QUESTIONS, (question: string) => {
            Text(question)
              .fontColor(Theme.mobileOrange)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor('#FFF5EC')
              .border({ width: 1, color: '#F0DCC0' })
              .borderRadius(16)
              .margin({ right: 8, bottom: 4 })
              .onClick(() => {
                this.quickAskStoreAi(question);
              })
          }, (question: string) => question)
        }
        .width('100%')

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
                  Text(rec.author || '作者待补充')
                    .fontColor(Theme.mobileSubtext)
                    .fontSize(13)
                  Text(rec.reason || '这本和你刚才的想法很搭，可以先点进去看看简介。')
                    .fontColor(Theme.mobileBlue)
                    .fontSize(12)
                    .lineHeight(18)
                    .maxLines(2)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
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
              .width('100%')
              .padding(14)
              .backgroundColor('#FDFAF5')
              .borderRadius(16)
              .border({ width: 1, color: '#F0E6D0' })
            }, (rec: RecommendationBook) => `${rec.id}`)
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
          ForEach(this.storeRecommendBooks, (rec: RecommendationBook) => {
            this.RecommendBookCard(rec)
          }, (rec: RecommendationBook) => `${rec.id}`)
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

  pickRecommendationLead(books: RecommendationBook[]): string {
    if (books.length <= 0) {
      return '我先从书库里挑几本耐读的给你。';
    }
    return `这次先给你换成《${books[0].title}》这一组，想轻松读或深入读都能接上。`;
  }

  isPlanQuery(query: string): boolean {
    return query.indexOf('计划') >= 0 || query.indexOf('持续读') >= 0 || query.indexOf('怎么读') >= 0;
  }

  profileSummary(): string {
    const profile: UserProfile | null = UserSession.currentProfile();
    if (!profile) {
      return '';
    }
    const parts: string[] = [];
    if (profile.major) {
      parts.push(`专业：${profile.major}`);
    }
    if (profile.grade) {
      parts.push(`年级：${profile.grade}`);
    }
    if (profile.interests) {
      parts.push(`兴趣：${profile.interests}`);
    }
    if (profile.goal) {
      parts.push(`目标：${profile.goal}`);
    }
    return parts.join('；');
  }

  buildAiRequestQuery(query: string): string {
    const profileText: string = this.profileSummary();
    if (this.isPlanQuery(query)) {
      return `${query}。请结合用户画像给出可点击的阅读推荐，并在推荐理由或下一步建议中给出可执行的阅读计划安排；只基于后端书库和可追溯来源，不要编造书名或章节。${profileText ? `用户画像：${profileText}` : ''}`;
    }
    if (profileText) {
      return `${query}。请结合用户画像进行阅读推荐，用户画像：${profileText}`;
    }
    return query;
  }

  makeHumanRecommendation(result: RecommendResult, query: string = ''): string {
    const books = result.book_list || [];
    if (books.length > 0) {
      const second = books.length > 1 ? `，再把《${books[1].title}》作为对照读` : '';
      const sourceText = (result.sources || []).length > 0 ? '后面点进伴读还能继续看参考依据。' : '';
      const planText = this.isPlanQuery(query) && result.follow_up_suggestion ? ` 阅读计划：${result.follow_up_suggestion}` : '';
      return `我推荐先读《${books[0].title}》${second}。${result.reason || '这一组书和你刚才说的方向比较贴近，难度和主题都比较好接上。'}${planText}${sourceText}`;
    }
    return result.reason || '这次没有找到足够合适的书，我先不硬凑书单。你可以补充专业、难度或用途，我再帮你缩小范围。';
  }

  buildRecommendationEvidence(result: RecommendResult): string[] {
    const thoughts: string[] = [];
    if ((result.book_list || []).length > 0) {
      result.book_list.slice(0, 2).forEach((book: RecommendationBook) => {
        thoughts.push(`《${book.title}》：${book.reason || '和你刚才说的方向比较贴近，可以先点进详情看看。'}`);
      });
    }
    if ((result.sources || []).length > 0) {
      thoughts.push(`参考依据已保留 ${result.sources.length} 条，点进伴读可以继续查证。`);
    }
    if (result.follow_up_suggestion) {
      thoughts.push(`下一步：${result.follow_up_suggestion}`);
    }
    if (thoughts.length <= 0) {
      thoughts.push(result.reason || '暂时没有足够依据生成书单。');
    }
    return thoughts.slice(0, 3);
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
        Text(rec.author || '作者待补充')
          .fontColor(Theme.mobileSubtext)
          .fontSize(14)
          .maxLines(1)
        Row({ space: 6 }) {
          Row({}) {}
            .width(2)
            .height(14)
            .borderRadius(1)
            .backgroundColor(Theme.mobileOrange)
          Text(rec.reason || '这本和你刚才的想法很搭，可以先点进去看看简介。')
            .fontColor(Theme.mobileSubtext)
            .fontSize(13)
            .lineHeight(18)
            .maxLines(2)
            .layoutWeight(1)
        }
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
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FDFAF5')
    .borderRadius(22)
    .border({ width: 1, color: '#F0E6D0' })
    .onClick(() => {
      openBookDetail(rec.id);
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
