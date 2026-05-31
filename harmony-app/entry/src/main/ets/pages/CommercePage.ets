import { ApiClient, CommerceBundle } from '../common/ApiClient';
import { Book, CommerceResult, emptyBook } from '../common/Models';
import { currentBookId, goBack } from '../common/Navigation';
import { Theme } from '../common/Theme';

const USER_ID: number = 10086;

@Entry
@Component
struct CommercePage {
  @State bookId: number = 0;
  @State book: Book = emptyBook();
  @State results: CommerceResult[] = [];
  @State message: string = '';
  @State busyText: string = '';
  @State errorText: string = '';

  aboutToAppear(): void {
    this.bookId = currentBookId();
    this.loadData();
  }

  async loadData(): Promise<void> {
    if (this.bookId <= 0) {
      this.errorText = '缺少 bookId，无法检索购书 / 馆藏渠道。';
      return;
    }
    this.busyText = '正在聚合馆藏、电商和二手渠道';
    this.errorText = '';
    try {
      this.book = await ApiClient.getBook(this.bookId);
      const data: CommerceBundle = await ApiClient.commerceSearch(USER_ID, this.book.id, this.book.isbn);
      this.results = data.results || [];
      this.message = data.message || '';
    } catch (err) {
      this.errorText = `渠道检索失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async confirm(item: CommerceResult): Promise<void> {
    this.busyText = '正在确认并回写选择';
    this.errorText = '';
    try {
      await ApiClient.confirmPurchase(USER_ID, this.book.id, item);
      this.busyText = item.platform === 'library' ? '已确认预约借阅' : '已确认购买 / 愿望单动作';
    } catch (err) {
      this.errorText = `确认失败：${err}`;
      this.busyText = '';
    }
  }

  build() {
    Column() {
      this.TopBar()
      Scroll() {
        Column({ space: 18 }) {
          if (this.errorText) {
            this.StatusBanner(this.errorText, Theme.error)
          }
          if (this.busyText) {
            this.StatusBanner(this.busyText, Theme.primary)
          }
          this.HeaderPanel()
          if (this.message) {
            Text(this.message)
              .fontColor(Theme.bodyMuted)
              .fontSize(13)
              .lineHeight(20)
              .padding(16)
              .backgroundColor(Theme.paleBlue)
              .borderRadius(Theme.radius.sm)
          }
          if (this.results.length === 0) {
            this.EmptyState('后端暂未返回渠道结果。请确认 /commerce/search 返回 library、jd、dangdang 或 second_hand 结果。')
          }
          ForEach(this.results, (item: CommerceResult) => {
            this.ResultCard(item)
          }, (item: CommerceResult) => `${item.platform}-${item.isbn}`)
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 32 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.canvas)
  }

  @Builder
  TopBar() {
    Row() {
      Button('返回')
        .height(36)
        .fontColor(Theme.primary)
        .backgroundColor(Theme.canvas)
        .border({ width: 1, color: Theme.line })
        .borderRadius(Theme.radius.pill)
        .onClick(() => goBack())
      Blank()
      Text('购书 / 馆藏')
        .fontColor(Theme.primary)
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
      Blank()
      Text('用户确认')
        .fontColor(Theme.coral)
        .fontSize(Theme.type.micro)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 14 })
  }

  @Builder
  HeaderPanel() {
    Column({ space: 10 }) {
      Text(this.book.title || '渠道检索')
        .fontColor(Theme.primary)
        .fontSize(30)
        .fontWeight(FontWeight.Regular)
        .lineHeight(36)
      Text(`ISBN：${this.book.isbn || '-'}`)
        .fontColor(Theme.slate)
        .fontSize(13)
      Text('AI 可以辅助聚合渠道，但购买、借阅和愿望单必须由用户点击确认。')
        .fontColor(Theme.bodyMuted)
        .fontSize(14)
        .lineHeight(22)
    }
    .width('100%')
    .padding(22)
    .backgroundColor(Theme.softStone)
    .borderRadius(Theme.radius.lg)
  }

  @Builder
  ResultCard(item: CommerceResult) {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Text(item.platform)
          .fontColor(Theme.primary)
          .fontSize(20)
          .fontWeight(FontWeight.Regular)
        Text(item.title || this.book.title)
          .fontColor(Theme.bodyMuted)
          .fontSize(13)
          .maxLines(1)
        Text(`${item.status} · 库存 ${item.stock} · ${item.delivery}`)
          .fontColor(Theme.slate)
          .fontSize(12)
          .maxLines(2)
      }
      .layoutWeight(1)
      Text(`¥${item.price}`)
        .fontColor(Theme.actionBlue)
        .fontSize(18)
        .fontWeight(FontWeight.Regular)
      Button(item.platform === 'library' ? '预约' : '确认')
        .height(36)
        .fontColor(Theme.onPrimary)
        .backgroundColor(Theme.primary)
        .borderRadius(Theme.radius.pill)
        .onClick(() => this.confirm(item))
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .border({ width: 1, color: Theme.line })
    .borderRadius(Theme.radius.sm)
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

  @Builder
  EmptyState(text: string) {
    Text(text)
      .fontColor(Theme.bodyMuted)
      .fontSize(14)
      .lineHeight(20)
      .padding(18)
      .backgroundColor(Theme.softStone)
      .borderRadius(Theme.radius.sm)
      .width('100%')
  }
}
