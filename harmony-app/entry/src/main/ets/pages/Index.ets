import {
  ApiClient,
  ChatResult,
  CommerceBundle,
  RecommendResult,
} from '../common/ApiClient';
import {
  Book,
  CommerceResult,
  NoteItem,
  PlanItem,
  ProfileBundle,
  RecommendationBook,
  SourceRef,
  UserProfile,
  emptyBook,
  emptyProfile,
} from '../common/Models';

const USER_ID: number = 10086;

@Entry
@Component
struct Index {
  @State activeTab: number = 0;
  @State query: string = '我想看适合零基础的人工智能入门书';
  @State keyword: string = '';
  @State tag: string = '';
  @State books: Book[] = [];
  @State recommendations: RecommendationBook[] = [];
  @State recommendReason: string = '';
  @State sources: SourceRef[] = [];
  @State plans: PlanItem[] = [];
  @State notes: NoteItem[] = [];
  @State favorites: Book[] = [];
  @State profile: UserProfile = emptyProfile();
  @State selectedBook: Book = emptyBook();
  @State showDetail: boolean = false;
  @State showChat: boolean = false;
  @State showCommerce: boolean = false;
  @State chatQuestion: string = '这本书适合我从哪一章开始读？';
  @State chatAnswer: string = '';
  @State commerceResults: CommerceResult[] = [];
  @State busyText: string = '';
  @State errorText: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.bootstrap();
  }

  async bootstrap(): Promise<void> {
    await this.loadBooks('');
    await this.loadProfile();
    await this.loadPlans();
  }

  async loadBooks(keyword: string): Promise<void> {
    this.errorText = '';
    try {
      this.books = await ApiClient.searchBooks(keyword, this.tag);
    } catch (err) {
      this.errorText = `后端连接失败：${err}`;
    }
  }

  async loadPlans(): Promise<void> {
    try {
      this.plans = await ApiClient.listPlans(USER_ID);
    } catch (err) {
      this.errorText = `计划加载失败：${err}`;
    }
  }

  async loadProfile(): Promise<void> {
    try {
      const data: ProfileBundle = await ApiClient.profile(USER_ID);
      this.profile = data.profile;
      this.favorites = data.favorites;
      this.notes = data.notes;
      this.plans = data.plans;
    } catch (err) {
      this.errorText = `画像加载失败：${err}`;
    }
  }

  async runRecommend(): Promise<void> {
    this.busyText = 'AI 正在检索图书资料';
    this.errorText = '';
    try {
      const result: RecommendResult = await ApiClient.recommend(USER_ID, this.query);
      this.recommendations = result.book_list || [];
      this.recommendReason = result.reason;
      this.sources = result.sources || [];
    } catch (err) {
      this.errorText = `推荐失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async openBook(book: Book): Promise<void> {
    this.selectedBook = book;
    this.showDetail = true;
    try {
      this.selectedBook = await ApiClient.getBook(book.id);
    } catch (err) {
      this.errorText = `详情加载失败：${err}`;
    }
  }

  async openBookById(bookId: number): Promise<void> {
    try {
      this.selectedBook = await ApiClient.getBook(bookId);
      this.showDetail = true;
    } catch (err) {
      this.errorText = `详情加载失败：${err}`;
    }
  }

  async addPlan(bookId: number): Promise<void> {
    this.busyText = '正在写入阅读计划';
    try {
      await ApiClient.createPlan(USER_ID, bookId, 14);
      await this.loadPlans();
    } catch (err) {
      this.errorText = `创建计划失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async addFavorite(bookId: number): Promise<void> {
    try {
      this.favorites = await ApiClient.favorite(USER_ID, bookId);
    } catch (err) {
      this.errorText = `收藏失败：${err}`;
    }
  }

  async askBook(): Promise<void> {
    this.busyText = 'AI 伴读正在查找来源片段';
    this.chatAnswer = '';
    try {
      const result: ChatResult = await ApiClient.chat(USER_ID, this.selectedBook.id, this.chatQuestion);
      this.chatAnswer = result.answer;
      this.sources = result.sources || [];
    } catch (err) {
      this.errorText = `伴读失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async saveChatNote(): Promise<void> {
    if (!this.chatAnswer) {
      return;
    }
    try {
      await ApiClient.saveNote(USER_ID, this.selectedBook.id, this.chatAnswer);
      await this.loadProfile();
    } catch (err) {
      this.errorText = `保存笔记失败：${err}`;
    }
  }

  async openCommerce(book: Book): Promise<void> {
    this.selectedBook = book;
    this.showCommerce = true;
    this.busyText = '正在聚合馆藏与电商结果';
    try {
      const data: CommerceBundle = await ApiClient.commerceSearch(USER_ID, book.id, book.isbn);
      this.commerceResults = data.results || [];
    } catch (err) {
      this.errorText = `聚合搜索失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async confirm(item: CommerceResult): Promise<void> {
    try {
      await ApiClient.confirmPurchase(USER_ID, this.selectedBook.id, item);
      await this.loadPlans();
      this.showCommerce = false;
      this.activeTab = 2;
    } catch (err) {
      this.errorText = `确认失败：${err}`;
    }
  }

  async saveProfile(): Promise<void> {
    try {
      this.profile = await ApiClient.saveProfile(this.profile);
      await this.loadProfile();
    } catch (err) {
      this.errorText = `保存画像失败：${err}`;
    }
  }

  build() {
    Stack() {
      Column() {
        this.TopBar()
        Scroll(this.scroller) {
          Column({ space: 16 }) {
            if (this.errorText) {
              this.StatusPill(this.errorText, '#432026')
            }
            if (this.busyText) {
              this.StatusPill(this.busyText, '#1D3541')
            }
            if (this.activeTab === 0) {
              this.HomeView()
            } else if (this.activeTab === 1) {
              this.SearchView()
            } else if (this.activeTab === 2) {
              this.PlanView()
            } else {
              this.ProfileView()
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 100 })
        }
        .layoutWeight(1)
        this.TabBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#090B10')

      if (this.showDetail) {
        this.DetailSheet()
      }
      if (this.showChat) {
        this.ChatSheet()
      }
      if (this.showCommerce) {
        this.CommerceSheet()
      }
    }
  }

  @Builder
  TopBar() {
    Row() {
      Column({ space: 4 }) {
        Text('鸿蒙智阅')
          .fontColor('#F5F7FA')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
        Text('AI 个性化图书推荐与伴读')
          .fontColor('#7D8794')
          .fontSize(13)
      }
      Blank()
      Column({ space: 4 }) {
        Text(this.profile.grade)
          .fontColor('#D9B46E')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
        Text('学习画像')
          .fontColor('#6F7784')
          .fontSize(11)
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#171512')
      .borderRadius(8)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 12 })
  }

  @Builder
  HomeView() {
    Column({ space: 16 }) {
      this.HeroPanel()
      this.SectionHeader('精选书架', `${this.books.length} 本图书已接入知识库`)
      Row({ space: 14 }) {
        ForEach(this.books.slice(0, 4), (book: Book) => {
          this.FeaturedBook(book)
        }, (book: Book) => `${book.id}`)
      }
      .width('100%')
      this.SectionHeader('AI 推荐解释', '围绕画像、目标和来源片段生成')
      if (this.recommendations.length > 0) {
        ForEach(this.recommendations, (item: RecommendationBook) => {
          this.RecommendCard(item)
        }, (item: RecommendationBook) => `${item.id}`)
        this.SourceList()
      } else {
        this.EmptyState('输入阅读目标后，推荐理由和来源片段会出现在这里')
      }
      this.SectionHeader('阅读路径', '从找书到伴读再到计划沉淀')
      Row({ space: 10 }) {
        this.MetricCard('画像', this.profile.major, '#88BFD8')
        this.MetricCard('预算', `¥${this.profile.budget}`, '#D9B46E')
        this.MetricCard('计划', `${this.plans.length} 个`, '#9DA8FF')
      }
    }
    .width('100%')
  }

  @Builder
  HeroPanel() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 6 }) {
          Text('今天想读什么？')
            .fontColor('#F5F7FA')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Text('输入方向，AI 会按你的画像、难度和来源片段解释推荐')
            .fontColor('#94A0AF')
            .fontSize(13)
            .lineHeight(20)
        }
        Blank()
        Text('RAG')
          .fontColor('#081019')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#88BFD8')
          .borderRadius(8)
      }
      TextInput({ placeholder: '例如：人工智能入门、考研英语、算法竞赛', text: this.query })
        .height(48)
        .fontColor('#F5F7FA')
        .placeholderColor('#657080')
        .backgroundColor('#0F141C')
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.query = value;
        })
      Row({ space: 10 }) {
        Button('AI 推荐')
          .layoutWeight(1)
          .height(46)
          .fontColor('#081019')
          .backgroundColor('#88BFD8')
          .borderRadius(8)
          .onClick(() => this.runRecommend())
        Button('去搜索')
          .width(116)
          .height(46)
          .fontColor('#F5F7FA')
          .backgroundColor('#1D2430')
          .borderRadius(8)
          .onClick(() => {
            this.activeTab = 1;
          })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#121821')
    .border({ width: 1, color: '#222B37' })
    .borderRadius(8)
  }

  @Builder
  SearchView() {
    Column({ space: 16 }) {
      this.SectionHeader('发现图书', '搜索关键词、作者、标签或阅读方向')
      Row({ space: 10 }) {
        TextInput({ placeholder: '关键词、作者、方向', text: this.keyword })
          .layoutWeight(1)
          .height(46)
          .fontColor('#F5F7FA')
          .placeholderColor('#657080')
          .backgroundColor('#111720')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.keyword = value;
          })
        Button('搜索')
          .height(46)
          .fontColor('#081019')
          .backgroundColor('#88BFD8')
          .borderRadius(8)
          .onClick(() => this.loadBooks(this.keyword))
      }
      Row({ space: 8 }) {
        ForEach(['人工智能', '算法', '考研', '通识', '设计'], (item: string) => {
          Text(item)
            .fontColor(this.tag === item ? '#081019' : '#AAB4C1')
            .fontSize(13)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(this.tag === item ? '#D9B46E' : '#171D27')
            .borderRadius(8)
            .onClick(() => {
              this.tag = this.tag === item ? '' : item;
              this.loadBooks(this.keyword);
            })
        })
      }
      ForEach(this.books, (book: Book) => {
        this.BookCard(book)
      }, (book: Book) => `${book.id}`)
    }
    .width('100%')
  }

  @Builder
  PlanView() {
    Column({ space: 16 }) {
      this.SectionHeader('阅读计划', '把推荐结果变成可推进的任务')
      if (this.plans.length === 0) {
        Column({ space: 10 }) {
          Text('还没有计划')
            .fontColor('#F5F7FA')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Text('先从首页推荐或图书详情里加入一本书，系统会沉淀到计划列表。')
            .fontColor('#8994A3')
            .fontSize(13)
            .lineHeight(20)
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#121821')
        .borderRadius(8)
      }
      ForEach(this.plans, (item: PlanItem) => {
        Row({ space: 14 }) {
          this.PlanCover(item)
          Column({ space: 10 }) {
            Row() {
              Column() {
                Text(item.title)
                  .fontColor('#F5F7FA')
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                Text(`${item.targetDays} 天计划 · ${item.status}`)
                  .fontColor('#7D8794')
                  .fontSize(12)
              }
              Blank()
              Text(`${item.progress}%`)
                .fontColor('#D9B46E')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
            }
            Progress({ value: item.progress, total: 100, type: ProgressType.Linear })
              .color('#88BFD8')
              .backgroundColor('#242B35')
            Text('继续阅读后，进度会作为下一次推荐上下文')
              .fontColor('#697382')
              .fontSize(12)
          }
          .layoutWeight(1)
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#121821')
        .borderRadius(8)
      }, (item: PlanItem) => `${item.id}`)
    }
    .width('100%')
  }

  @Builder
  ProfileView() {
    Column({ space: 16 }) {
      this.SectionHeader('我的画像', '推荐会读取专业、兴趣、目标和预算')
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          this.ProfileInput('姓名', this.profile.name, 0)
          this.ProfileInput('专业', this.profile.major, 1)
        }
        TextInput({ placeholder: '兴趣标签', text: this.profile.interests })
          .height(44)
          .fontColor('#F5F7FA')
          .backgroundColor('#0F141C')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.profile.interests = value;
          })
        TextInput({ placeholder: '阅读目标', text: this.profile.goal })
          .height(44)
          .fontColor('#F5F7FA')
          .backgroundColor('#0F141C')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.profile.goal = value;
          })
        Button('保存画像')
          .width('100%')
          .height(46)
          .fontColor('#081019')
          .backgroundColor('#D9B46E')
          .borderRadius(8)
          .onClick(() => this.saveProfile())
      }
      .padding(16)
      .backgroundColor('#121821')
      .borderRadius(8)

      this.SectionHeader('收藏', `${this.favorites.length} 本已收藏`)
      if (this.favorites.length === 0) {
        this.EmptyState('点击图书详情里的收藏，书籍会出现在这里')
      }
      ForEach(this.favorites.slice(0, 3), (book: Book) => {
        this.BookCard(book)
      }, (book: Book) => `${book.id}`)

      this.SectionHeader('笔记', `${this.notes.length} 条伴读沉淀`)
      if (this.notes.length === 0) {
        this.EmptyState('保存伴读回答后会出现在这里')
      }
      ForEach(this.notes.slice(0, 5), (note: NoteItem) => {
        Text(note.content)
          .fontColor('#B7C0CC')
          .fontSize(14)
          .lineHeight(21)
          .padding(14)
          .backgroundColor('#121821')
          .borderRadius(8)
      }, (note: NoteItem) => `${note.id}`)
    }
    .width('100%')
  }

  @Builder
  FeaturedBook(book: Book) {
    Column({ space: 8 }) {
      this.CoverArt(book, 112, 154, 12)
      Text(book.title)
        .fontColor('#F5F7FA')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
      Text(book.difficulty)
        .fontColor('#D9B46E')
        .fontSize(11)
    }
    .width(118)
    .onClick(() => this.openBook(book))
  }

  @Builder
  BookCard(book: Book) {
    Row({ space: 14 }) {
      this.CoverArt(book, 82, 116, 10)
      Column({ space: 8 }) {
        Row() {
          Text(book.title)
            .fontColor('#F5F7FA')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .layoutWeight(1)
          Text(book.difficulty)
            .fontColor('#D9B46E')
            .fontSize(12)
            .padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .backgroundColor('#211D14')
            .borderRadius(8)
        }
        Text(book.author)
          .fontColor('#7D8794')
          .fontSize(12)
          .maxLines(1)
        Text(book.summary)
          .fontColor('#B7C0CC')
          .fontSize(13)
          .lineHeight(19)
          .maxLines(2)
        Row({ space: 8 }) {
          Button('详情')
            .height(32)
            .fontSize(12)
            .fontColor('#F5F7FA')
            .backgroundColor('#202733')
            .borderRadius(8)
            .onClick(() => this.openBook(book))
          Button('计划')
            .height(32)
            .fontSize(12)
            .fontColor('#081019')
            .backgroundColor('#88BFD8')
            .borderRadius(8)
            .onClick(() => this.addPlan(book.id))
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#121821')
    .border({ width: 1, color: '#202A36' })
    .borderRadius(8)
    .onClick(() => this.openBook(book))
  }

  @Builder
  RecommendCard(item: RecommendationBook) {
    Row({ space: 14 }) {
      this.CoverById(item.id, 72, 102, item.title, item.difficulty, 9)
      Column({ space: 8 }) {
        Row() {
          Text(item.title)
            .fontColor('#F5F7FA')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .maxLines(1)
          Text(item.difficulty)
            .fontColor('#D9B46E')
            .fontSize(12)
        }
        Text(item.reason)
          .fontColor('#B7C0CC')
          .fontSize(13)
          .lineHeight(20)
          .maxLines(3)
        Row({ space: 8 }) {
          Button('进入图书')
            .height(34)
            .fontColor('#F5F7FA')
            .backgroundColor('#202733')
            .borderRadius(8)
            .onClick(() => this.openBookById(item.id))
          Button('加入计划')
            .height(34)
            .fontColor('#081019')
            .backgroundColor('#88BFD8')
            .borderRadius(8)
            .onClick(() => this.addPlan(item.id))
        }
      }
      .layoutWeight(1)
    }
    .padding(14)
    .backgroundColor('#121821')
    .borderRadius(8)
  }

  @Builder
  CoverArt(book: Book, widthValue: number, heightValue: number, titleSize: number) {
    this.CoverById(book.id, widthValue, heightValue, book.title, book.difficulty, titleSize)
  }

  @Builder
  CoverById(bookId: number, widthValue: number, heightValue: number, title: string, difficulty: string, titleSize: number) {
    Stack() {
      if (bookId === 1) {
        Image($r('app.media.cover_ai_modern')).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else if (bookId === 2) {
        Image($r('app.media.cover_machine_learning')).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else if (bookId === 3) {
        Image($r('app.media.cover_deep_learning')).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else if (bookId === 4) {
        Image($r('app.media.cover_algorithm')).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else if (bookId === 5) {
        Image($r('app.media.cover_english')).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else if (bookId === 6) {
        Image($r('app.media.cover_classic')).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else if (bookId === 7 || bookId === 9) {
        Image($r('app.media.cover_system')).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else {
        Image($r('app.media.cover_design')).width('100%').height('100%').objectFit(ImageFit.Cover)
      }
      Column() {
        Blank()
        Text(title)
          .fontColor('#F5F7FA')
          .fontSize(titleSize)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .lineHeight(titleSize + 3)
        Text(difficulty)
          .fontColor('#D9B46E')
          .fontSize(10)
          .margin({ top: 4 })
      }
      .width('100%')
      .height('100%')
      .padding(10)
      .backgroundColor('#33000000')
    }
    .width(widthValue)
    .height(heightValue)
    .borderRadius(8)
    .clip(true)
  }

  @Builder
  PlanCover(item: PlanItem) {
    Column() {
      Text(item.title.substring(0, 1))
        .fontColor('#F5F7FA')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
    }
    .width(62)
    .height(84)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(item.coverColor || '#182532')
    .borderRadius(8)
  }

  @Builder
  SourceList() {
    Column({ space: 8 }) {
      this.SectionHeader('参考依据', 'AI 回答引用的知识库片段')
      ForEach(this.sources.slice(0, 3), (source: SourceRef) => {
        Text(`${source.title} · ${source.source}\n${source.text}`)
          .fontColor('#9FAAB8')
          .fontSize(12)
          .lineHeight(18)
          .padding(12)
          .backgroundColor('#0F141C')
          .borderRadius(8)
      }, (source: SourceRef) => `${source.chunk_id}`)
    }
  }

  @Builder
  DetailSheet() {
    Column({ space: 16 }) {
      Row() {
        Text('图书详情')
          .fontColor('#F5F7FA')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('关闭')
          .height(34)
          .fontColor('#B7C0CC')
          .backgroundColor('#202733')
          .borderRadius(8)
          .onClick(() => {
            this.showDetail = false;
          })
      }
      Row({ space: 18 }) {
        this.CoverArt(this.selectedBook, 124, 174, 13)
        Column({ space: 8 }) {
          Text(this.selectedBook.title)
            .fontColor('#F5F7FA')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .maxLines(2)
          Text(this.selectedBook.author)
            .fontColor('#7D8794')
            .fontSize(13)
          Text(this.selectedBook.difficulty)
            .fontColor('#D9B46E')
            .fontSize(12)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#211D14')
            .borderRadius(8)
          Text(this.selectedBook.tags)
            .fontColor('#94A0AF')
            .fontSize(12)
            .lineHeight(18)
            .maxLines(2)
        }
        .layoutWeight(1)
      }
      Text(this.selectedBook.summary)
        .fontColor('#B7C0CC')
        .fontSize(14)
        .lineHeight(22)
      Text(`适合人群：${this.selectedBook.targetReader}`)
        .fontColor('#8994A3')
        .fontSize(13)
        .lineHeight(20)
      Row({ space: 10 }) {
        Button('收藏')
          .layoutWeight(1)
          .height(44)
          .fontColor('#F5F7FA')
          .backgroundColor('#202733')
          .borderRadius(8)
          .onClick(() => this.addFavorite(this.selectedBook.id))
        Button('AI 伴读')
          .layoutWeight(1)
          .height(44)
          .fontColor('#081019')
          .backgroundColor('#88BFD8')
          .borderRadius(8)
          .onClick(() => {
            this.showDetail = false;
            this.showChat = true;
          })
      }
      Row({ space: 10 }) {
        Button('加入计划')
          .layoutWeight(1)
          .height(44)
          .fontColor('#081019')
          .backgroundColor('#D9B46E')
          .borderRadius(8)
          .onClick(() => this.addPlan(this.selectedBook.id))
        Button('查馆藏')
          .layoutWeight(1)
          .height(44)
          .fontColor('#F5F7FA')
          .backgroundColor('#202733')
          .borderRadius(8)
          .onClick(() => {
            this.showDetail = false;
            this.openCommerce(this.selectedBook);
          })
      }
    }
    .width('100%')
    .height('84%')
    .padding(20)
    .backgroundColor('#101620')
    .borderRadius({ topLeft: 16, topRight: 16 })
    .position({ x: 0, y: '16%' })
  }

  @Builder
  ChatSheet() {
    Column({ space: 12 }) {
      Row() {
        Text('AI 伴读')
          .fontColor('#F5F7FA')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('关闭')
          .height(34)
          .fontColor('#B7C0CC')
          .backgroundColor('#202733')
          .borderRadius(8)
          .onClick(() => {
            this.showChat = false;
          })
      }
      Row({ space: 12 }) {
        this.CoverArt(this.selectedBook, 64, 90, 9)
        Column({ space: 6 }) {
          Text(this.selectedBook.title)
            .fontColor('#F5F7FA')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
          Text('问题会围绕本项目知识库片段回答')
            .fontColor('#7D8794')
            .fontSize(12)
        }
        .layoutWeight(1)
      }
      TextInput({ placeholder: '围绕这本书提问', text: this.chatQuestion })
        .height(46)
        .fontColor('#F5F7FA')
        .backgroundColor('#0F141C')
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.chatQuestion = value;
        })
      Button('提问')
        .width('100%')
        .height(44)
        .fontColor('#081019')
        .backgroundColor('#88BFD8')
        .borderRadius(8)
        .onClick(() => this.askBook())
      if (this.chatAnswer) {
        Text(this.chatAnswer)
          .fontColor('#F5F7FA')
          .fontSize(14)
          .lineHeight(22)
          .padding(14)
          .backgroundColor('#121821')
          .borderRadius(8)
        Button('保存为笔记')
          .height(42)
          .fontColor('#081019')
          .backgroundColor('#D9B46E')
          .borderRadius(8)
          .onClick(() => this.saveChatNote())
        this.SourceList()
      }
    }
    .width('100%')
    .height('78%')
    .padding(20)
    .backgroundColor('#101620')
    .borderRadius({ topLeft: 16, topRight: 16 })
    .position({ x: 0, y: '22%' })
  }

  @Builder
  CommerceSheet() {
    Column({ space: 12 }) {
      Row() {
        Text('购书 / 馆藏')
          .fontColor('#F5F7FA')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('关闭')
          .height(34)
          .fontColor('#B7C0CC')
          .backgroundColor('#202733')
          .borderRadius(8)
          .onClick(() => {
            this.showCommerce = false;
          })
      }
      ForEach(this.commerceResults, (item: CommerceResult) => {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(item.platform)
              .fontColor('#F5F7FA')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text(`${item.status} · ${item.delivery}`)
              .fontColor('#7D8794')
              .fontSize(12)
              .maxLines(2)
          }
          .layoutWeight(1)
          Text(`¥${item.price}`)
            .fontColor('#D9B46E')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
          Button(item.platform === 'library' ? '预约' : '确认')
            .height(34)
            .fontColor('#081019')
            .backgroundColor('#88BFD8')
            .borderRadius(8)
            .onClick(() => this.confirm(item))
        }
        .padding(14)
        .backgroundColor('#121821')
        .borderRadius(8)
      }, (item: CommerceResult) => `${item.platform}`)
    }
    .width('100%')
    .height('62%')
    .padding(20)
    .backgroundColor('#101620')
    .borderRadius({ topLeft: 16, topRight: 16 })
    .position({ x: 0, y: '38%' })
  }

  @Builder
  TabBar() {
    Row() {
      ForEach(['首页', '搜索', '计划', '我的'], (item: string, index: number) => {
        Column({ space: 3 }) {
          Text(item)
            .fontColor(this.activeTab === index ? '#88BFD8' : '#7D8794')
            .fontSize(13)
            .fontWeight(this.activeTab === index ? FontWeight.Bold : FontWeight.Regular)
          Blank()
            .width(this.activeTab === index ? 18 : 0)
            .height(3)
            .backgroundColor('#88BFD8')
            .borderRadius(2)
        }
        .layoutWeight(1)
        .height(58)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.activeTab = index;
          if (index === 2) {
            this.loadPlans();
          }
          if (index === 3) {
            this.loadProfile();
          }
        })
      })
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 10 })
    .backgroundColor('#0F131A')
  }

  @Builder
  SectionHeader(title: string, caption: string) {
    Row() {
      Column({ space: 3 }) {
        Text(title)
          .fontColor('#F5F7FA')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Text(caption)
          .fontColor('#707B8A')
          .fontSize(12)
      }
      Blank()
    }
    .width('100%')
  }

  @Builder
  MetricCard(label: string, value: string, color: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontColor('#7D8794')
        .fontSize(12)
      Text(value)
        .fontColor(color)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
    }
    .layoutWeight(1)
    .padding(14)
    .backgroundColor('#121821')
    .borderRadius(8)
  }

  @Builder
  ProfileInput(placeholder: string, value: string, type: number) {
    TextInput({ placeholder, text: value })
      .layoutWeight(1)
      .height(44)
      .fontColor('#F5F7FA')
      .backgroundColor('#0F141C')
      .borderRadius(8)
      .padding({ left: 12, right: 12 })
      .onChange((next: string) => {
        if (type === 0) {
          this.profile.name = next;
        } else {
          this.profile.major = next;
        }
      })
  }

  @Builder
  StatusPill(text: string, color: string) {
    Text(text)
      .fontColor('#F5F7FA')
      .fontSize(12)
      .lineHeight(18)
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(color)
      .borderRadius(8)
      .width('100%')
  }

  @Builder
  EmptyState(text: string) {
    Text(text)
      .fontColor('#7D8794')
      .fontSize(14)
      .padding(18)
      .backgroundColor('#121821')
      .borderRadius(8)
      .width('100%')
  }
}
