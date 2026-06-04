import { ApiClient, ChatResult } from '../common/ApiClient';
import { AnalyticsEvent, AnalyticsEventExtra, Book, SourceRef, emptyBook } from '../common/Models';
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
  @State followUpSuggestion: string = '';
  @State sources: SourceRef[] = [];
  @State busyText: string = '';
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

  async askBook(): Promise<void> {
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先在“我的”页面登录后再使用 AI 伴读。';
      return;
    }
    this.busyText = 'AI 伴读正在检索来源片段';
    this.errorText = '';
    this.answer = '';
    try {
      const result: ChatResult = await ApiClient.chat(userId, this.bookId, this.question);
      this.answer = result.answer || '';
      this.sources = result.sources || [];
      this.followUpSuggestion = result.follow_up_suggestion || '';
      if (result.llm_status === 'recovered') {
        this.followUpSuggestion = this.followUpSuggestion || '可以继续追问某一章、某个概念，或让我把这段整理成笔记。';
      }
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
      this.busyText = '';
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
          this.AnswerPanel()
          this.SourcePanel()
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
        Text('回答必须来自当前图书、用户画像和检索来源片段。资料不足时要明确提示。')
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
      Button('提问')
        .width('100%')
        .height(44)
        .fontColor(Theme.primary)
        .backgroundColor(Theme.onDark)
        .borderRadius(Theme.radius.pill)
        .onClick(() => this.askBook())
    }
    .width('100%')
  }

  @Builder
  AnswerPanel() {
    if (this.answer) {
      Column({ space: 12 }) {
        Text(this.answer)
          .fontColor(Theme.onDark)
          .fontSize(15)
          .lineHeight(24)
        if (this.followUpSuggestion) {
          Text(`下一步：${this.followUpSuggestion}`)
            .fontColor(Theme.coralSoft)
            .fontSize(13)
            .lineHeight(20)
        }
        Button('保存为笔记')
          .height(42)
          .fontColor(Theme.primary)
          .backgroundColor(Theme.onDark)
          .borderRadius(Theme.radius.pill)
          .onClick(() => this.saveNote())
      }
      .width('100%')
      .padding(18)
      .backgroundColor('#0D2233')
      .borderRadius(Theme.radius.lg)
    } else {
      Text('提出问题后，AI 会返回回答与可追溯来源。资料不足时应提示补充关键词，而不是编造内容。')
        .fontColor(Theme.onDarkSoft)
        .fontSize(14)
        .lineHeight(22)
        .padding(18)
        .backgroundColor('#0D2233')
        .borderRadius(Theme.radius.lg)
        .width('100%')
    }
  }

  @Builder
  SourcePanel() {
    if (this.sources.length > 0) {
      Column({ space: 8 }) {
        Text('参考依据')
          .fontColor(Theme.onDark)
          .fontSize(18)
          .fontWeight(FontWeight.Regular)
        ForEach(this.sources.slice(0, 4), (source: SourceRef) => {
          Text(`${source.title} · ${source.source}\n${source.text}`)
            .fontColor(Theme.onDarkSoft)
            .fontSize(12)
            .lineHeight(18)
            .padding(12)
            .backgroundColor('#13283A')
            .borderRadius(Theme.radius.sm)
        }, (source: SourceRef) => `${source.chunk_id}`)
      }
      .width('100%')
      .padding(18)
      .backgroundColor('#0D2233')
      .borderRadius(Theme.radius.lg)
    }
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
