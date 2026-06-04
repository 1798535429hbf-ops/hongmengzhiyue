import { Theme } from '../common/Theme';

interface QuickAction {
  id: number;
  label: string;
  icon: Resource;
}

interface DiscoverList {
  id: number;
  title: string;
  count: string;
  saved: string;
  coverTone: string;
}

const DISCOVER_QUICK_ACTIONS: QuickAction[] = [
  { id: 1, label: '书单', icon: $r('app.media.discover_quick_books') },
  { id: 2, label: '榜单', icon: $r('app.media.discover_quick_rank') },
  { id: 3, label: '主题', icon: $r('app.media.discover_quick_theme') },
  { id: 4, label: '活动', icon: $r('app.media.discover_quick_activity') },
  { id: 5, label: '听书', icon: $r('app.media.discover_quick_audio') },
];

const DISCOVER_LISTS: DiscoverList[] = [
  {
    id: 1,
    title: '豆瓣高分书单',
    count: '10本书',
    saved: '392.4万人收藏',
    coverTone: '#EEF3FF',
  },
  {
    id: 2,
    title: '一生必读的经典好书',
    count: '20本书',
    saved: '268.7万人收藏',
    coverTone: '#FFF2E6',
  },
  {
    id: 3,
    title: '科幻迷必看的神作',
    count: '15本书',
    saved: '186.8万人收藏',
    coverTone: '#E8EEFF',
  },
];

@Component
export struct DiscoverContent {
  @Prop pageWidth: number = 390;

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  sectionGap(): number {
    return this.isCompact() ? 16 : 18;
  }

  titleSize(): number {
    if (this.pageWidth >= 900) {
      return 34;
    }
    return this.isCompact() ? 26 : 30;
  }

  build() {
    Column({ space: this.sectionGap() }) {
      Row() {
        Text('发现')
          .fontColor(Theme.mobileText)
          .fontSize(this.titleSize())
          .fontWeight(FontWeight.Bold)
        Blank()
        this.CircleActionButton($r('app.media.discover_search'), false)
      }
      .alignItems(VerticalAlign.Center)

      Column({ space: 14 }) {
        Text('今日推荐')
          .fontColor(Theme.mobileText)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)

        Row({ space: 16 }) {
          this.BookPlaceholder(78, 108, '#F1EADF')

          Column({ space: 8 }) {
            Text('人类简史：从动物到上帝')
              .fontColor(Theme.mobileText)
              .fontSize(this.isCompact() ? 20 : 22)
              .fontWeight(FontWeight.Bold)
              .maxLines(2)
            Text('[以色列] 尤瓦尔·赫拉利')
              .fontColor(Theme.mobileSubtext)
              .fontSize(13)
            Text('8.9分')
              .fontColor(Theme.mobileOrange)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text('从认知革命、农业革命到科学革命，探索人类如何一步步走到今天。')
              .fontColor(Theme.mobileSubtext)
              .fontSize(13)
              .lineHeight(20)
              .maxLines(3)

            Row() {
              Text('立即阅读')
                .fontColor('#A57B41')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
            }
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor('#F4E6C7')
            .borderRadius(12)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFF7EC')
      .borderRadius(20)
      .shadow({ radius: 16, color: '#16000000', offsetX: 0, offsetY: 8 })

      Row() {
        ForEach(DISCOVER_QUICK_ACTIONS, (item: QuickAction) => {
          this.QuickActionItem(item)
        }, (item: QuickAction) => `${item.id}`)
      }
      .width('100%')

      this.SectionTitle('热门书单', '查看更多')
      ForEach(DISCOVER_LISTS, (item: DiscoverList) => {
        this.DiscoverListCard(item)
      }, (item: DiscoverList) => `${item.id}`)

      this.SectionTitle('热门活动', '查看更多')
      Column({ space: 10 }) {
        Image($r('app.media.discover_activity_banner'))
          .width('100%')
          .height(this.isCompact() ? 128 : 148)
          .objectFit(ImageFit.Cover)
          .borderRadius(18)
        Row() {
          Text('万卷共读 · 春日计划')
            .fontColor(Theme.mobileText)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text('立即参与')
            .fontColor('#9A7B46')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(20)
      .shadow({ radius: 16, color: '#15000000', offsetX: 0, offsetY: 8 })

      this.SectionTitle('猜你喜欢')
      Row({ space: 12 }) {
        this.MiniGuessCard('通识阅读', '从经典书单继续探索', '#EEF3FF')
        this.MiniGuessCard('成长计划', '按阶段挑选适合你的书', '#FFF2EA')
      }
      .width('100%')
    }
    .width('100%')
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
          Image($r('app.media.icon_chevron_right'))
            .width(14)
            .height(14)
        }
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  QuickActionItem(item: QuickAction) {
    Column({ space: 10 }) {
      Image(item.icon)
        .width(this.isCompact() ? 46 : 50)
        .height(this.isCompact() ? 46 : 50)
      Text(item.label)
        .fontColor(Theme.mobileSubtext)
        .fontSize(14)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  DiscoverListCard(item: DiscoverList) {
    Row({ space: 14 }) {
      this.BookPlaceholder(68, 90, item.coverTone)

      Column({ space: 6 }) {
        Text(item.title)
          .fontColor(Theme.mobileText)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Text(item.count)
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
        Text(item.saved)
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text('收藏')
          .fontColor(Theme.mobileBlue)
          .fontSize(13)
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .border({ width: 1, color: '#DCE6FF' })
      .borderRadius(14)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(18)
    .shadow({ radius: 12, color: '#10000000', offsetX: 0, offsetY: 4 })
  }

  @Builder
  MiniGuessCard(title: string, subtitle: string, tone: string) {
    Column({ space: 12 }) {
      this.BookPlaceholder(90, 60, tone)
      Text(title)
        .fontColor(Theme.mobileText)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      Text(subtitle)
        .fontColor(Theme.mobileSubtext)
        .fontSize(13)
        .lineHeight(20)
        .maxLines(2)
    }
    .layoutWeight(1)
    .padding(14)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(18)
    .shadow({ radius: 12, color: '#10000000', offsetX: 0, offsetY: 4 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  BookPlaceholder(widthValue: number, heightValue: number, tone: string) {
    Stack({ alignContent: Alignment.Center }) {
      Column() {}
        .width(widthValue)
        .height(heightValue)
        .backgroundColor(tone || '#EEF2FF')
        .borderRadius({ topLeft: 12, topRight: 12, bottomLeft: 8, bottomRight: 12 })
      Text('BOOK')
        .fontColor('#68708A')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
    }
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
