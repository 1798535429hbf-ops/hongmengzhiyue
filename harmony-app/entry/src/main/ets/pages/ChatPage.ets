import { ApiClient, ChatResult, ToolTrace } from '../common/ApiClient';
import { AnalyticsEvent, AnalyticsEventExtra, Book, SourceRef, emptyBook } from '../common/Models';
import { AiResponseView } from '../common/AiResponseView';
import { BookCover } from '../common/BookCover';
import { currentBookId, goBack, openReader } from '../common/Navigation';
import { Theme } from '../common/Theme';
import { UserSession } from '../common/UserSession';

@Entry
@Component
struct ChatPage {
  @State bookId: number = 0;
  @State book: Book = emptyBook();
  @State question: string = '这本书适合我从哪一章开始读？';
  @State answer: string = '';
  @State reasoning: string = '';
  @State followUpSuggestion: string = '';
  @State sources: SourceRef[] = [];
  @State toolTrace: ToolTrace[] = [];
  @State statusText: string = '';
  @State busyText: string = '';
  @State askBusy: boolean = false;
  @State errorText: string = '';

  aboutToAppear(): void {
    this.bookId = currentBookId();
    this.loadBook();
  }

  async loadBook(): Promise<void> {
    if (this.bookId <= 0) {
      this.errorText = '缺少 bookId，无法进入 AI 伴读。';
      return;
    }
    try {
      this.book = await ApiClient.getBook(this.bookId);
    } catch (err) {
      this.errorText = `图书加载失败：${err}`;
    }
  }

  waitForThinkingFrame(): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, 650);
    });
  }

  async askBook(): Promise<void> {
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先在“我的”页面登录后再使用 AI 伴读。';
      return;
    }
    if (this.askBusy) {
      return;
    }
    this.askBusy = true;
    this.busyText = '正在思考';
    this.errorText = '';
    this.answer = '';
    this.reasoning = '';
    this.followUpSuggestion = '';
    this.sources = [];
    this.toolTrace = [];
    this.statusText = '正在思考';
    try {
      await this.waitForThinkingFrame();
      const result: ChatResult = await ApiClient.chatStream(userId, this.bookId, this.question, {
        chapterId: '',
        paragraph: '',
        allowExternalSearch: true,
        tone: 'warm_companion',
      }, {
        onDelta: (text: string) => {
          this.answer += text;
        },
        onReasoning: (text: string) => {
          this.reasoning += text;
        },
        onStatus: (text: string) => {
          this.statusText = text;
        },
        onResult: (value: ChatResult) => {
          this.answer = ApiClient.preferStreamText(this.answer, value.answer || '');
          this.sources = value.sources || [];
          this.followUpSuggestion = value.follow_up_suggestion || '';
          this.toolTrace = value.tool_trace || [];
          this.reasoning = value.hidden_reasoning || value.reasoning_content || value.reasoning || this.reasoning;
        },
        onError: (message: string) => {
          this.statusText = message;
        },
      });
      this.answer = ApiClient.preferStreamText(this.answer, result.answer || '');
      this.sources = result.sources || [];
      this.followUpSuggestion = result.follow_up_suggestion || '';
      this.toolTrace = result.tool_trace || [];
      this.reasoning = result.hidden_reasoning || result.reasoning_content || result.reasoning || this.reasoning;
      try {
        const extra: AnalyticsEventExtra = { sourceCount: this.sources.length };
        const event: AnalyticsEvent = {
          user_id: userId,
          event_type: 'ASK_AI',
          book_id: this.bookId,
          keyword: this.question,
          extra,
        };
        await ApiClient.trackEvent(event);
      } catch (_) {}
    } catch (err) {
      this.errorText = `伴读失败：${err}`;
    } finally {
      this.askBusy = false;
      this.busyText = '';
      this.statusText = '';
    }
  }

  async saveNote(): Promise<void> {
    if (!this.answer) {
      return;
    }
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先登录后再保存笔记。';
      return;
    }
    this.busyText = '正在保存为笔记';
    this.errorText = '';
    try {
      await ApiClient.saveNote(userId, this.bookId, this.answer);
      this.busyText = '笔记已保存';
    } catch (err) {
      this.errorText = `保存笔记失败：${err}`;
      this.busyText = '';
    }
  }

  build() {
    Column() {
      this.TopBar()
      Scroll() {
        Column({ space: 16 }) {
          if (this.errorText) {
            this.StatusBanner(this.errorText, Theme.error)
          }
          if (this.busyText) {
            this.StatusBanner(this.busyText, Theme.primary)
          }
          this.BookPanel()
          this.QuestionPanel()
          AiResponseView({
            answer: this.answer,
            reasoning: this.reasoning,
            followUpSuggestion: this.followUpSuggestion,
            sources: this.sources,
            toolTrace: this.toolTrace,
            busy: this.askBusy,
            statusText: this.statusText,
            emptyText: '可以直接问“这章怎么读”“这个概念什么意思”，也可以把卡住的一句话贴过来。',
            dark: true,
            compact: false,
            maxAnswerLines: 0,
          })
          Button('保存为笔记')
            .height(42)
            .fontColor(Theme.primary)
            .backgroundColor(Theme.onDark)
            .borderRadius(Theme.radius.pill)
            .enabled(!!this.answer)
            .onClick(() => this.saveNote())
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 32 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.darkNavy)
  }

  @Builder
  TopBar() {
    Row() {
      Button('返回')
        .height(36)
        .fontColor(Theme.onDark)
        .backgroundColor('#13283A')
        .borderRadius(Theme.radius.pill)
        .onClick(() => goBack())
      Blank()
      Text('AI 伴读')
        .fontColor(Theme.onDark)
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
      Blank()
      Button('阅读')
        .height(36)
        .fontColor(Theme.onDark)
        .backgroundColor('#13283A')
        .borderRadius(Theme.radius.pill)
        .onClick(() => openReader(this.bookId))
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 12 })
  }

  @Builder
  BookPanel() {
    Row({ space: 14 }) {
      BookCover({
        bookId: this.book.id,
        title: this.book.title,
        difficulty: this.book.difficulty,
        coverColor: this.book.coverColor,
        widthValue: 72,
        heightValue: 102,
        titleSize: 9,
      })
      Column({ space: 7 }) {
        Text(this.book.title || '等待图书详情')
          .fontColor(Theme.onDark)
          .fontSize(22)
          .fontWeight(FontWeight.Regular)
          .maxLines(2)
        Text(this.book.author)
          .fontColor(Theme.onDarkSoft)
          .fontSize(13)
        Text('问章节、概念、读法都可以，我会尽量贴着这本书讲。')
          .fontColor(Theme.onDarkSoft)
          .fontSize(12)
          .lineHeight(18)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#0D2233')
    .borderRadius(Theme.radius.lg)
  }

  @Builder
  QuestionPanel() {
    Column({ space: 10 }) {
      TextInput({ placeholder: '围绕这本书提问', text: this.question })
        .height(48)
        .fontColor(Theme.onDark)
        .placeholderColor(Theme.onDarkSoft)
        .backgroundColor('#13283A')
        .border({ width: 1, color: '#294255' })
        .borderRadius(Theme.radius.xs)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.question = value;
        })
        .onSubmit(() => {
          if (!this.askBusy) {
            this.askBook();
          }
        })
      Stack({ alignContent: Alignment.Center }) {
        Button(this.askBusy ? '' : '提问')
          .width('100%')
          .height(44)
          .fontColor(Theme.primary)
          .backgroundColor(Theme.onDark)
          .borderRadius(Theme.radius.pill)
          .enabled(!this.askBusy)
          .onClick(() => this.askBook())

        if (this.askBusy) {
          Row({ space: 8 }) {
            LoadingProgress()
              .width(14)
              .height(14)
              .color(Theme.primary)
            Text('思考中')
              .fontColor(Theme.primary)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
          }
          .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%')
      .height(44)
    }
    .width('100%')
  }

  @Builder
  StatusBanner(text: string, color: string) {
    Text(text)
      .fontColor(Theme.onPrimary)
      .fontSize(12)
      .lineHeight(18)
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(color)
      .borderRadius(Theme.radius.sm)
      .width('100%')
  }
}
