import { ApiClient, RecommendResult } from '../common/ApiClient';
import { ChatRecord, RecommendationBook, SourceRef } from '../common/Models';
import { openBookDetail, openLogin } from '../common/Navigation';
import { UserSession } from '../common/UserSession';

interface AssistantPrompt {
  icon: string;
  color: string;
  tint: string;
  text: string;
}

@Component
export struct CategoryContent {
  @Prop pageWidth: number = 390;
  @StorageProp('smartread_session_user_id') @Watch('onSessionUserChange') sessionUserId: number = 0;
  @State query: string = '';
  @State answer: string = '';
  @State followUp: string = '';
  @State sources: SourceRef[] = [];
  @State recommendedBooks: RecommendationBook[] = [];
  @State statusText: string = '';
  @State busy: boolean = false;
  @State recentChats: ChatRecord[] = [];
  @State historyBusy: boolean = false;
  @State historyError: string = '';
  @State promptSetIndex: number = 0;

  aboutToAppear(): void {
    this.loadHistory();
  }

  onSessionUserChange(): void {
    this.answer = '';
    this.followUp = '';
    this.sources = [];
    this.recommendedBooks = [];
    this.statusText = '';
    this.loadHistory();
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  maxContentWidth(): number {
    return this.pageWidth >= 720 ? 620 : 520;
  }

  topButtonSize(): number {
    return this.isCompact() ? 44 : 50;
  }

  horizontalInset(): number {
    return this.isCompact() ? 2 : 4;
  }

  titleSize(): number {
    return this.isCompact() ? 44 : 50;
  }

  loggedIn(): boolean {
    return Number.isFinite(this.sessionUserId) && this.sessionUserId > 0;
  }

  promptGroups(): AssistantPrompt[][] {
    return [
      [
        { icon: '▤', color: '#6E78FF', tint: '#F1F2FF', text: '推荐几本适合入门的科幻小说' },
        { icon: '书', color: '#51C7AA', tint: '#EEFDF9', text: '《百年孤独》中的象征意义解析' },
        { icon: '灯', color: '#F0A13A', tint: '#FFF6E8', text: '如何培养高效的阅读习惯？' },
      ],
      [
        { icon: '策', color: '#6E78FF', tint: '#F1F2FF', text: '帮我制定一本专业书的阅读计划' },
        { icon: '问', color: '#51C7AA', tint: '#EEFDF9', text: '我想准备竞赛，先读哪些书？' },
        { icon: '摘', color: '#F0A13A', tint: '#FFF6E8', text: '怎么把读书笔记整理成复习材料？' },
      ],
    ];
  }

  currentPrompts(): AssistantPrompt[] {
    const groups = this.promptGroups();
    return groups[this.promptSetIndex % groups.length];
  }

  changePromptSet(): void {
    this.promptSetIndex = (this.promptSetIndex + 1) % this.promptGroups().length;
  }

  waitForThinkingFrame(): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, 500);
    });
  }

  async loadHistory(): Promise<void> {
    if (!this.loggedIn()) {
      this.recentChats = [];
      this.historyBusy = false;
      this.historyError = '';
      return;
    }
    this.historyBusy = true;
    this.historyError = '';
    try {
      const bundle = await ApiClient.profile(this.sessionUserId);
      this.recentChats = (bundle.chat_records || []).slice(0, 3);
    } catch (err) {
      this.recentChats = [];
      this.historyError = `历史对话加载失败：${err}`;
    } finally {
      this.historyBusy = false;
    }
  }

  async askAssistant(seed: string = ''): Promise<void> {
    const nextQuery: string = (seed || this.query || '').trim();
    if (!nextQuery) {
      this.statusText = '可以输入课程、主题、书名或阅读目标，我会基于书库和画像给出建议。';
      return;
    }
    if (!this.loggedIn()) {
      this.statusText = '先登录后，我才能结合你的画像和历史记录进行推荐。';
      openLogin();
      return;
    }
    if (this.busy) {
      return;
    }

    this.query = nextQuery;
    this.busy = true;
    this.answer = '';
    this.followUp = '';
    this.sources = [];
    this.recommendedBooks = [];
    this.statusText = '正在思考';
    let failed: boolean = false;

    try {
      await this.waitForThinkingFrame();
      const result: RecommendResult = await ApiClient.recommendStream(this.sessionUserId, nextQuery, 0, {
        onDelta: (text: string) => {
          this.answer += text;
        },
        onStatus: (text: string) => {
          this.statusText = text;
        },
        onResult: (value: RecommendResult) => {
          this.answer = ApiClient.preferStreamText(this.answer, value.reason || '');
          this.followUp = value.follow_up_suggestion || '';
          this.sources = value.sources || [];
          this.recommendedBooks = value.book_list || [];
        },
        onError: (message: string) => {
          this.statusText = message;
        },
      });
      this.answer = ApiClient.preferStreamText(this.answer, result.reason || '');
      this.followUp = result.follow_up_suggestion || '';
      this.sources = result.sources || [];
      this.recommendedBooks = result.book_list || [];
    } catch (err) {
      failed = true;
      this.statusText = `助手连接失败：${err}`;
      this.recommendedBooks = [];
      this.followUp = '';
      this.sources = [];
    } finally {
      this.busy = false;
      if (!failed) {
        this.statusText = '';
      }
      this.loadHistory();
    }
  }

  canOpenRecommendation(rec: RecommendationBook): boolean {
    return !!rec && rec.id > 0 && !rec.titleOnly;
  }

  historyTime(value: string): string {
    if (!value) {
      return '';
    }
    if (value.length >= 16) {
      return value.substring(5, 16).replace('T', ' ');
    }
    return value;
  }

  build() {
    Column() {
      Column() {
        Scroll() {
          Column() {
            this.TopActions()
            this.Hero()
            this.PromptCard()

            if (this.busy || this.answer || this.statusText || this.recommendedBooks.length > 0) {
              this.ResponsePanel()
            }

            this.HistoryBlock()
            Blank()
              .height(16)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)

        this.InputBar()
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: this.maxContentWidth() })
      .padding({ left: this.horizontalInset(), right: this.horizontalInset(), top: 12, bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#FFFCF8')
  }

  @Builder
  TopActions() {
    Row() {
      this.TopIconButton('☰')
      Blank()
      this.TopIconButton('◷')
    }
    .width('100%')
    .height(this.topButtonSize())
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  TopIconButton(label: string) {
    Stack() {
      Text(label)
        .fontColor('#493324')
        .fontSize(this.isCompact() ? 24 : 26)
        .fontWeight(FontWeight.Medium)
    }
    .width(this.topButtonSize())
    .height(this.topButtonSize())
    .backgroundColor('#FFFFFF')
    .borderRadius(this.topButtonSize() / 2)
    .shadow({ radius: 18, color: '#12000000', offsetX: 0, offsetY: 8 })
  }

  @Builder
  Hero() {
    Column({ space: 12 }) {
      this.AssistantOrb()
      Text('你好 ✦')
        .fontColor('#20283A')
        .fontSize(this.titleSize())
        .fontWeight(FontWeight.Medium)
        .letterSpacing(0)
      Text('我是智阅助手，有什么可以帮你？')
        .fontColor('#858078')
        .fontSize(this.isCompact() ? 17 : 19)
        .lineHeight(this.isCompact() ? 24 : 27)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: this.isCompact() ? 34 : 50, bottom: this.isCompact() ? 26 : 34 })
  }

  @Builder
  AssistantOrb() {
    Stack() {
      Circle()
        .width(74)
        .height(74)
        .fill('#FFFFFF')
        .shadow({ radius: 22, color: '#18000000', offsetX: 0, offsetY: 8 })
      Circle()
        .width(68)
        .height(68)
        .fill('#FFE1C9')
        .opacity(0.78)
        .translate({ x: -8, y: -9 })
      Circle()
        .width(62)
        .height(62)
        .fill('#8EA0FF')
        .opacity(0.66)
        .translate({ x: 8, y: 11 })
      Circle()
        .width(48)
        .height(48)
        .fill('#FFFFFF')
        .opacity(0.52)
        .translate({ x: -18, y: -18 })
      Text('✦')
        .fontColor('#F2D8A4')
        .fontSize(18)
        .translate({ x: 48, y: -30 })
      Text('✦')
        .fontColor('#F2D8A4')
        .fontSize(14)
        .translate({ x: 44, y: 36 })
    }
    .width(104)
    .height(96)
  }

  @Builder
  PromptCard() {
    Column({ space: 12 }) {
      Row() {
        Text('你可以这样问我')
          .fontColor('#211A16')
          .fontSize(this.isCompact() ? 19 : 21)
          .fontWeight(FontWeight.Medium)
        Blank()
        Row({ space: 6 }) {
          Text('⟳')
            .fontColor('#5F554C')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          Text('换一换')
            .fontColor('#5F554C')
            .fontSize(14)
        }
        .onClick(() => this.changePromptSet())
      }
      .width('100%')

      ForEach(this.currentPrompts(), (item: AssistantPrompt) => {
        this.PromptRow(item)
      }, (item: AssistantPrompt) => item.text)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 20, bottom: 20 })
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .shadow({ radius: 26, color: '#10000000', offsetX: 0, offsetY: 12 })
  }

  @Builder
  PromptRow(item: AssistantPrompt) {
    Row({ space: 14 }) {
      Stack() {
        Text(item.icon)
          .fontColor(item.color)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
      }
      .width(42)
      .height(42)
      .backgroundColor(item.tint)
      .borderRadius(21)
      .shadow({ radius: 14, color: '#10000000', offsetX: 0, offsetY: 5 })

      Text(item.text)
        .fontColor('#2D241E')
        .fontSize(this.isCompact() ? 16 : 18)
        .maxLines(1)
        .layoutWeight(1)

      Text('→')
        .fontColor('#80776D')
        .fontSize(24)
    }
    .width('100%')
    .height(this.isCompact() ? 58 : 64)
    .padding({ left: 10, right: 12 })
    .backgroundColor('#FFFDF9')
    .borderRadius(18)
    .onClick(() => this.askAssistant(item.text))
  }

  @Builder
  ResponsePanel() {
    Column({ space: 12 }) {
      Row() {
        Text(this.busy ? (this.statusText || '正在思考') : '助手回答')
          .fontColor('#211A16')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Blank()
        if (this.busy) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color('#E3B36A')
        }
      }
      .width('100%')

      if (this.statusText && !this.busy && !this.answer) {
        Text(this.statusText)
          .fontColor('#8A8177')
          .fontSize(14)
          .lineHeight(22)
      }

      if (this.answer) {
        Text(this.answer)
          .fontColor('#4F4842')
          .fontSize(14)
          .lineHeight(22)
          .maxLines(6)
      }

      if (this.recommendedBooks.length > 0) {
        Column({ space: 8 }) {
          ForEach(this.recommendedBooks.slice(0, 3), (rec: RecommendationBook, index: number) => {
            this.RecommendationRow(rec, index)
          }, (rec: RecommendationBook, index: number) => `${rec.id}-${rec.title}-${index}`)
        }
        .width('100%')
      }

      if (this.followUp) {
        Text(this.followUp)
          .fontColor('#B88A45')
          .fontSize(13)
          .lineHeight(20)
          .maxLines(2)
      }

      if (this.sources.length > 0) {
        Text(`参考依据 ${this.sources.length} 条`)
          .fontColor('#989187')
          .fontSize(12)
      }
    }
    .width('100%')
    .padding(18)
    .margin({ top: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .shadow({ radius: 20, color: '#0E000000', offsetX: 0, offsetY: 8 })
  }

  @Builder
  RecommendationRow(rec: RecommendationBook, index: number) {
    Row({ space: 10 }) {
      Text(`${index + 1}`)
        .fontColor('#FFFFFF')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .width(24)
        .height(24)
        .backgroundColor('#E1B86D')
        .borderRadius(12)

      Column({ space: 3 }) {
        Text(rec.title)
          .fontColor('#2D241E')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
        Text(rec.reason || rec.author || rec.difficulty || '来自后端智能推荐')
          .fontColor('#8A8177')
          .fontSize(12)
          .lineHeight(18)
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFDF8')
    .borderRadius(16)
    .onClick(() => {
      if (this.canOpenRecommendation(rec)) {
        openBookDetail(rec.id);
      }
    })
  }

  @Builder
  HistoryBlock() {
    Column({ space: 12 }) {
      Row() {
        Row({ space: 7 }) {
          Text('◷')
            .fontColor('#827B73')
            .fontSize(17)
          Text('历史对话')
            .fontColor('#716A63')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
        }
        Blank()
        Text('查看全部 ›')
          .fontColor('#827B73')
          .fontSize(15)
      }
      .width('100%')

      if (this.historyBusy) {
        this.HistoryPlaceholder('正在同步历史对话')
      } else if (this.historyError) {
        this.HistoryPlaceholder(this.historyError)
      } else if (this.recentChats.length === 0) {
        this.HistoryPlaceholder(this.loggedIn() ? '暂无历史对话' : '登录后显示真实问答历史')
      } else {
        ForEach(this.recentChats, (item: ChatRecord) => {
          this.HistoryRow(item)
        }, (item: ChatRecord) => `${item.id}-${item.createdAt}`)
      }
    }
    .width('100%')
    .margin({ top: 24 })
  }

  @Builder
  HistoryPlaceholder(text: string) {
    Text(text)
      .fontColor('#A79F96')
      .fontSize(14)
      .width('100%')
      .height(48)
      .padding({ left: 18, right: 18 })
      .backgroundColor('#FFFDF9')
      .borderRadius(18)
  }

  @Builder
  HistoryRow(item: ChatRecord) {
    Row() {
      Text(item.question || '未命名对话')
        .fontColor('#6A625B')
        .fontSize(this.isCompact() ? 15 : 16)
        .maxLines(1)
        .layoutWeight(1)
      Text(this.historyTime(item.createdAt))
        .fontColor('#B4ADA6')
        .fontSize(13)
        .margin({ left: 12 })
    }
    .width('100%')
    .height(this.isCompact() ? 50 : 56)
    .padding({ left: 18, right: 18 })
    .backgroundColor('#FFFDF9')
    .borderRadius(18)
    .onClick(() => {
      this.query = item.question || '';
    })
  }

  @Builder
  InputBar() {
    Row({ space: 12 }) {
      TextInput({ placeholder: '输入你的问题...', text: this.query })
        .layoutWeight(1)
        .height(56)
        .fontColor('#2D241E')
        .placeholderColor('#B7B1AA')
        .fontSize(this.isCompact() ? 16 : 18)
        .backgroundColor('transparent')
        .border({ width: 0 })
        .onChange((value: string) => {
          this.query = value;
        })
        .onSubmit(() => {
          this.askAssistant();
        })

      Stack() {
        Text('⋮')
          .fontColor('#5D554E')
          .fontSize(22)
          .rotate({ angle: 90 })
      }
      .width(40)
      .height(40)
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: '#D8D5D0' })
      .borderRadius(20)

      Stack() {
        if (this.busy) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color('#FFFFFF')
        } else {
          Text('↑')
            .fontColor('#FFFFFF')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
        }
      }
      .width(44)
      .height(44)
      .backgroundColor(this.busy ? '#D7C2A0' : '#E0B66F')
      .borderRadius(22)
      .onClick(() => {
        this.askAssistant();
      })
    }
    .width('100%')
    .height(this.isCompact() ? 72 : 78)
    .padding({ left: 18, right: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .shadow({ radius: 24, color: '#12000000', offsetX: 0, offsetY: 10 })
  }
}
