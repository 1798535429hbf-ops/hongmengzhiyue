import { ApiClient } from '../common/ApiClient';
import { Book, emptyBook, VolumeItem, CatalogVolume } from '../common/Models';
import { currentBookId, goBack } from '../common/Navigation';
import { Theme } from '../common/Theme';

@Entry
@Component
struct CatalogPage {
  @State bookId: number = 0;
  @State book: Book = emptyBook();
  @State busyText: string = '';
  @State errorText: string = '';

  aboutToAppear(): void {
    this.bookId = currentBookId();
    this.loadBook();
  }

  async loadBook(): Promise<void> {
    if (this.bookId <= 0) {
      this.errorText = '缺少 bookId';
      return;
    }
    this.busyText = '正在加载目录';
    this.errorText = '';
    try {
      this.book = await ApiClient.getBook(this.bookId);
    } catch (err) {
      this.errorText = `加载失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  volumeItems(): VolumeItem[] {
    const vols = this.book.catalogVolumes;
    if (vols && vols.length > 0) {
      const result: VolumeItem[] = [];
      for (let vi = 0; vi < vols.length; vi++) {
        const item: VolumeItem = { id: vols[vi].id, title: vols[vi].title, chapterCount: vols[vi].chapterCount };
        result.push(item);
      }
      return result;
    }
    const count = this.book.chapterCount || 0;
    if (count > 0) {
      const items: VolumeItem[] = [];
      for (let i = 0; i < Math.ceil(count / 10); i++) {
        items.push({
          id: `vol-${i + 1}`,
          title: `第${this.toChineseNum(i + 1)}部分`,
          chapterCount: Math.min(10, count - i * 10),
        });
      }
      return items;
    }
    return [];
  }

  toChineseNum(n: number): string {
    const map = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    if (n <= 10) return map[n];
    if (n < 20) return `十${map[n - 10]}`;
    return `${map[Math.floor(n / 10)]}十${n % 10 > 0 ? map[n % 10] : ''}`;
  }

  build() {
    Column() {
      this.TopBar()
      Scroll() {
        Column({ space: 2 }) {
          if (this.errorText) {
            Text(this.errorText)
              .fontColor(Theme.mobileSurface)
              .fontSize(13)
              .padding(12)
              .backgroundColor(Theme.error)
              .borderRadius(12)
              .width('100%')
              .margin(12)
          }
          if (this.busyText) {
            Text(this.busyText)
              .fontColor(Theme.mobileSurface)
              .fontSize(13)
              .padding(12)
              .backgroundColor(Theme.mobileBlue)
              .borderRadius(12)
              .width('100%')
              .margin(12)
          }

          Column({ space: 6 }) {
            Text(this.book.title || '目录')
              .fontColor(Theme.mobileText)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
            if (this.volumeItems().length > 0) {
              Text(`共 ${this.volumeItems().length} 卷`)
                .fontColor(Theme.mobileSubtext)
                .fontSize(13)
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 16 })
          .alignItems(HorizontalAlign.Start)

          if (this.volumeItems().length > 0) {
            ForEach(this.volumeItems(), (item: VolumeItem, index: number) => {
              Column({ space: 8 }) {
                Row({ space: 14 }) {
                  Column() {
                    Image($r('app.media.icon_chevron_right'))
                      .width(22)
                      .height(22)
                      .fillColor('#8B7355')
                  }
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor('#F5F0E8')
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)

                  Column({ space: 4 }) {
                    Text(item.title)
                      .fontColor(Theme.mobileText)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                    if (item.chapterCount) {
                      Text(`${item.chapterCount} 章`)
                        .fontColor(Theme.mobileSubtext)
                        .fontSize(12)
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Image($r('app.media.icon_chevron_right'))
                    .width(16)
                    .height(16)
                    .fillColor('#C0C4CC')
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 16, bottom: 16 })

                if (index < this.volumeItems().length - 1) {
                  Divider()
                    .color('#F0F0F0')
                    .strokeWidth(0.5)
                    .margin({ left: 20, right: 20 })
                }
              }
            })
          } else {
            Column({ space: 12 }) {
              Text('暂无目录信息')
                .fontColor(Theme.mobileSubtext)
                .fontSize(14)
              Text('该书籍的章节目录尚未同步，请稍后再试或联系管理员导入。')
                .fontColor(Theme.mobileMuted)
                .fontSize(13)
                .lineHeight(22)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ top: 60 })
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F0')
  }

  @Builder
  TopBar() {
    Row() {
      Row({ space: 10 }) {
        Image($r('app.media.icon_chevron_right'))
          .width(24)
          .height(24)
          .fillColor(Theme.mobileText)
          .rotate({ angle: 180 })
          .onClick(() => goBack())
      }
      Blank()
      Text('目录')
        .fontColor(Theme.mobileText)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
      Blank()
      Row({}).width(24).height(24)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 14 })
    .backgroundColor('#F5F5F0')
  }
}
