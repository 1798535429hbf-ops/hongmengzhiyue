import { ApiClient, RecommendResult } from '../common/ApiClient';
import { RecommendationBook } from '../common/Models';
import { openBookDetail, openSearch } from '../common/Navigation';
import { Theme } from '../common/Theme';

const USER_ID: number = 10086;

const STORE_TABS: string[] = ['精选', '男生', '女生', '出版', '听书', '漫画'];

interface StoreBook {
  id: number;
  title: string;
  author: string;
  score: string;
  quote: string;
  tags?: string[];
  coverTone: string;
}

const STORE_SECTION_BOOKS: Record<number, StoreBook[]> = {
  0: [
    {
      id: 1, title: '余华作品集', author: '余华', score: '9.6分',
      quote: '"我写这本书，不是为了控诉黑暗，而是为了，看见光明"', coverTone: '#F7EFE3',
    },
    {
      id: 2, title: '活着', author: '余华', score: '9.8分',
      quote: '人是为了活着本身而活着的，而不是为了活着之外的任何事物。', coverTone: '#EEF2FF',
    },
    {
      id: 3, title: '三体全集（全3册）', author: '刘慈欣', score: '9.1分',
      quote: '宇宙辽阔而生命短暂。', tags: ['科幻', '宇宙', '文明'], coverTone: '#E7EEFF',
    },
  ],
  1: [
    {
      id: 11, title: '斗破苍穹', author: '天蚕土豆', score: '8.5分',
      quote: '三十年河东，三十年河西，莫欺少年穷！', tags: ['玄幻', '热血'], coverTone: '#FFEFE8',
    },
    {
      id: 12, title: '凡人修仙传', author: '忘语', score: '9.0分',
      quote: '凡人亦可修仙，大道之行始于足下。', tags: ['仙侠', '升级流'], coverTone: '#EEF4FF',
    },
    {
      id: 13, title: '全职高手', author: '蝴蝶蓝', score: '9.3分',
      quote: '荣耀，从来都不是一个人的游戏。', tags: ['游戏', '热血'], coverTone: '#FFF2E6',
    },
    {
      id: 14, title: '诡秘之主', author: '爱潜水的乌贼', score: '9.4分',
      quote: '在漫长的黑暗中，总有一些光。', tags: ['奇幻', '悬疑'], coverTone: '#EEF0FF',
    },
  ],
  2: [
    {
      id: 21, title: '何以笙箫默', author: '顾漫', score: '8.8分',
      quote: '如果世界上曾经有那个人出现过，其他人都会变成将就。', coverTone: '#FFF0F0',
    },
    {
      id: 22, title: '微微一笑很倾城', author: '顾漫', score: '8.6分',
      quote: '如果我知道有一天我会这么爱你，我一定对你一见钟情。', coverTone: '#FFE8EE',
    },
    {
      id: 23, title: '三生三世十里桃花', author: '唐七公子', score: '8.3分',
      quote: '你有没有爱过一个人？你有没有恨过一个人？', tags: ['仙侠', '言情'], coverTone: '#FFF4F8',
    },
  ],
  3: [
    {
      id: 31, title: '百年孤独', author: '加西亚·马尔克斯', score: '9.7分',
      quote: '多年以后，面对行刑队，奥雷里亚诺·布恩迪亚上校...', tags: ['经典', '魔幻现实'], coverTone: '#F5F0E8',
    },
    {
      id: 32, title: '小王子', author: '安托万·德·圣-埃克苏佩里', score: '9.5分',
      quote: '真正重要的东西，用眼睛是看不见的。', tags: ['经典', '童话'], coverTone: '#FFEEDD',
    },
    {
      id: 33, title: '围城', author: '钱钟书', score: '9.2分',
      quote: '围在城里的人想逃出来，城外的人想冲进去。', tags: ['经典', '文学'], coverTone: '#EEF2FF',
    },
  ],
  4: [
    {
      id: 41, title: '红楼梦（有声版）', author: '曹雪芹', score: '9.9分',
      quote: '满纸荒唐言，一把辛酸泪。', tags: ['经典', '有声'], coverTone: '#EEE8F0',
    },
    {
      id: 42, title: '盗墓笔记（广播剧）', author: '南派三叔', score: '9.0分',
      quote: '比鬼神更可怕的，是人心。', tags: ['悬疑', '广播剧'], coverTone: '#EEF0F4',
    },
  ],
  5: [
    {
      id: 51, title: '镖人', author: '许先哲', score: '9.3分',
      quote: '大漠孤烟，刀客行走。', tags: ['漫画', '武侠'], coverTone: '#F5F0E0',
    },
    {
      id: 52, title: '一人之下', author: '米二', score: '9.1分',
      quote: '异人界的大门正向你打开。', tags: ['漫画', '奇幻'], coverTone: '#E8F0F8',
    },
    {
      id: 53, title: '狐妖小红娘', author: '小新', score: '8.8分',
      quote: '如果缘分有名字，一定是你的样子。', tags: ['漫画', '言情'], coverTone: '#FFF0F5',
    },
  ],
};

const STORE_QUICK_QUESTIONS: string[] = [
  '推荐适合我的书',
  '最近有什么好书',
  '帮我制定阅读计划',
  '我要学人工智能',
];

@Component
export struct StoreContent {
  @Prop pageWidth: number = 390;
  @State storeTabIndex: number = 0;
  @State storeAiQuery: string = '';
  @State storeAiAnswer: string = '';
  @State storeAiBusy: boolean = false;
  @State storeAiBooks: RecommendationBook[] = [];
  @State storeRecommendBooks: RecommendationBook[] = [];
  @State storeRecommendReason: string = '';

  aboutToAppear(): void {
    this.loadStoreRecommendations();
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  sectionGap(): number {
    return this.isCompact() ? 16 : 18;
  }

  storeSectionBooks(): StoreBook[] {
    const books = STORE_SECTION_BOOKS[this.storeTabIndex];
    if (books && books.length > 0) {
      return books;
    }
    return STORE_SECTION_BOOKS[0];
  }

  async askStoreAi(): Promise<void> {
    const query = this.storeAiQuery.trim();
    if (!query) {
      this.storeAiAnswer = '请输入你想要了解的书籍类型或阅读问题。';
      return;
    }
    this.storeAiBusy = true;
    this.storeAiAnswer = '';
    try {
      const result: RecommendResult = await ApiClient.recommend(USER_ID, query);
      this.storeAiAnswer = result.reason || '为你找到以下推荐书籍';
      this.storeAiBooks = result.book_list || [];
    } catch (err) {
      this.storeAiAnswer = `推荐失败：${err}`;
      this.storeAiBooks = [];
    } finally {
      this.storeAiBusy = false;
    }
  }

  async quickAskStoreAi(question: string): Promise<void> {
    this.storeAiQuery = question;
    await this.askStoreAi();
  }

  async loadStoreRecommendations(): Promise<void> {
    if (this.storeRecommendBooks.length > 0) {
      return;
    }
    try {
      const result: RecommendResult = await ApiClient.recommend(USER_ID, '');
      this.storeRecommendBooks = result.book_list || [];
      this.storeRecommendReason = result.reason || '综合你的阅读历史和兴趣推荐';
    } catch (_) {
      this.storeRecommendBooks = [];
      this.storeRecommendReason = '开始阅读和搜索后，这里会出现更贴近你的推荐。';
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
              Text('AI 正在为你检索推荐结果...')
                .fontColor(Theme.mobileOrange)
                .fontSize(this.isCompact() ? 16 : 17)
                .fontWeight(FontWeight.Medium)
                .lineHeight(this.isCompact() ? 26 : 28)
            } else if (this.storeAiAnswer) {
              Text(this.storeAiAnswer)
                .fontColor(Theme.mobileText)
                .fontSize(this.isCompact() ? 16 : 17)
                .fontWeight(FontWeight.Medium)
                .lineHeight(this.isCompact() ? 24 : 26)
                .maxLines(4)
            } else {
              Text('你的专属 AI 阅读顾问\n告诉我你的阅读偏好，帮你精准找书')
                .fontColor(Theme.mobileText)
                .fontSize(this.isCompact() ? 16 : 17)
                .fontWeight(FontWeight.Medium)
                .lineHeight(this.isCompact() ? 26 : 28)
            }
          }
          .layoutWeight(1)
          .padding({ left: 18, right: 18, top: 16, bottom: 16 })
          .backgroundColor('#FDFAF5')
          .borderRadius(20)
          .border({ width: 1, color: '#F0E6D0' })
        }
        .alignItems(VerticalAlign.Center)

        Text('今天想读点什么？')
          .fontColor(Theme.mobileText)
          .fontSize(this.isCompact() ? 17 : 18)
          .fontWeight(FontWeight.Medium)

        Row({ space: 10 }) {
          TextInput({ placeholder: '输入书名、作者或关键词...', text: this.storeAiQuery })
            .layoutWeight(1)
            .height('100%')
            .fontColor(Theme.mobileText)
            .placeholderColor('#C0C4D0')
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
              .width(32)
              .height(32)
              .fill(this.storeAiQuery.trim() ? Theme.mobileOrange : '#D2D4DB')
            Text('↑')
              .fontColor(Theme.mobileSurface)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
          }
          .onClick(() => {
            this.askStoreAi();
          })
        }
        .width('100%')
        .height(this.isCompact() ? 78 : 84)
        .padding({ left: 18, right: 16 })
        .backgroundColor(Theme.mobileSurface)
        .border({ width: 1, color: Theme.mobileLine })
        .borderRadius(18)

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
            Row({ space: 6 }) {
              Row({}) {}
                .width(3)
                .height(16)
                .borderRadius(2)
                .backgroundColor(Theme.mobileOrange)
              Text('AI 智能推荐')
                .fontColor(Theme.mobileText)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
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
                  Text(rec.reason || 'AI推荐')
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
          this.SectionTitle('猜你喜欢', '换一批')
          ForEach(this.storeRecommendBooks, (rec: RecommendationBook) => {
            this.RecommendBookCard(rec)
          }, (rec: RecommendationBook) => `${rec.id}`)
        }
      }

      this.SectionTitle('重磅推荐', '换一批')

      ForEach(this.storeSectionBooks(), (book: StoreBook) => {
        this.StoreBookCard(book)
      }, (book: StoreBook) => `${book.id}`)

      this.StoreOfferCard()
    }
    .width('100%')
  }

  titleSize(): number {
    if (this.pageWidth >= 900) {
      return 34;
    }
    return this.isCompact() ? 26 : 30;
  }

  @Builder
  StoreBookCard(book: StoreBook) {
    Row({ space: 16 }) {
      this.BookPlaceholder(82, 118, book.coverTone, false, false)

      Column({ space: 8 }) {
        Text(book.title)
          .fontColor(Theme.mobileText)
          .fontSize(this.isCompact() ? 18 : 20)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
        Text(book.author)
          .fontColor(Theme.mobileSubtext)
          .fontSize(15)
        Text(book.score)
          .fontColor(Theme.mobileOrange)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Text(book.quote)
          .fontColor(Theme.mobileSubtext)
          .fontSize(14)
          .lineHeight(22)
          .maxLines(book.tags ? 2 : 3)

        if (book.tags && book.tags.length > 0) {
          Row({ space: 8 }) {
            ForEach(book.tags, (tag: string) => {
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
  }

  @Builder
  StoreOfferCard() {
    Column({ space: 16 }) {
      Row() {
        Text('今日限时特惠')
          .fontColor('#7C4A1F')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank()
        Row({ space: 6 }) {
          Text('剩余')
            .fontColor('#B98A5A')
            .fontSize(14)
          this.TimerBox('08')
          Text(':')
            .fontColor('#A07346')
            .fontSize(16)
          this.TimerBox('36')
          Text(':')
            .fontColor('#A07346')
            .fontSize(16)
          this.TimerBox('45')
        }
      }

      Row({ space: 16 }) {
        this.BookPlaceholder(86, 110, '#FFE7D5', false, false)

        Column({ space: 10 }) {
          Text('时间的玫瑰（全集）')
            .fontColor(Theme.mobileText)
            .fontSize(this.isCompact() ? 20 : 22)
            .fontWeight(FontWeight.Bold)
          Text('但德')
            .fontColor(Theme.mobileSubtext)
            .fontSize(15)
          Row({ space: 10 }) {
            Text('¥19.99')
              .fontColor(Theme.mobileOrange)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
            Text('¥59.99')
              .fontColor('#C1B5B0')
              .fontSize(16)
              .decoration({ type: TextDecorationType.LineThrough, color: '#C1B5B0' })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFF4EC')
    .borderRadius(22)
  }

  @Builder
  TimerBox(text: string) {
    Text(text)
      .fontColor('#865325')
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(10)
  }

  @Builder
  RecommendBookCard(rec: RecommendationBook) {
    Row({ space: 16 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column()
          .width(68)
          .height(92)
          .backgroundColor('#F5F0E8')
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
          Text(rec.reason || (rec.difficulty ? `基于你的 ${rec.difficulty} 阅读偏好推荐` : '基于你的阅读记录为你推荐'))
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
  SectionTitle(title: string, action: string = '') {
    Row() {
      Text(title)
        .fontColor(Theme.mobileText)
        .fontSize(this.isCompact() ? 26 : 28)
        .fontWeight(FontWeight.Bold)
      Blank()
      if (action) {
        Row({ space: 6 }) {
          Text(action)
            .fontColor(Theme.mobileSubtext)
            .fontSize(15)
          if (action === '换一批') {
            Text('C')
              .fontColor(Theme.mobileSubtext)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
          } else {
            Image($r('app.media.icon_chevron_right'))
              .width(14)
              .height(14)
          }
        }
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  BookPlaceholder(widthValue: number, heightValue: number, tone: string, showRibbon: boolean, strongGlow: boolean) {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column()
          .width(widthValue)
          .height(heightValue)
          .backgroundColor(tone)
          .borderRadius(16)
          .border({ width: 1, color: '#F0F1F5' })

        Circle()
          .width(widthValue * 0.72)
          .height(widthValue * 0.72)
          .fill(strongGlow ? '#FFFFFF' : '#F9FAFD')
          .opacity(0.75)
          .margin({ right: 10, bottom: 10 })

        Column({ space: 7 }) {
          Blank()
            .width(widthValue * 0.56)
            .height(5)
            .borderRadius(3)
            .backgroundColor('#FFFFFF')
            .opacity(0.82)
          Blank()
            .width(widthValue * 0.42)
            .height(5)
            .borderRadius(3)
            .backgroundColor('#FFFFFF')
            .opacity(0.65)
        }
        .width(widthValue)
        .height(heightValue)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 14 })
      }

      if (showRibbon) {
        Text('在读')
          .fontColor(Theme.mobileSurface)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(Theme.mobileRed)
          .borderRadius({ topLeft: 16, bottomRight: 12 })
      }
    }
    .width(widthValue)
    .height(heightValue)
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
