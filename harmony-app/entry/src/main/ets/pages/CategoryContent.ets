import { Theme } from '../common/Theme';

const CATEGORY_SIDE_MENU: string[] = [
  '全部分类',
  '人气榜',
  '畅销榜',
  '新书榜',
  '完结榜',
  '收藏榜',
  '推荐榜',
];

const CATEGORY_TOP_FILTERS: string[] = ['男生', '女生', '出版', '漫画'];

interface CategorySubject {
  title: string;
  coverTone: string;
}

const CATEGORY_SUBJECT_ROWS: CategorySubject[][] = [
  [
    { title: '玄幻', coverTone: '#E9F0FF' },
    { title: '奇幻', coverTone: '#EEF4FF' },
  ],
  [
    { title: '武侠', coverTone: '#F8F0E6' },
    { title: '仙侠', coverTone: '#EEF6FF' },
  ],
  [
    { title: '都市', coverTone: '#EDF3FF' },
    { title: '现实', coverTone: '#FFF3EC' },
  ],
  [
    { title: '历史', coverTone: '#FFF4E8' },
    { title: '军事', coverTone: '#F2F6FF' },
  ],
  [
    { title: '游戏', coverTone: '#E9F9EF' },
    { title: '体育', coverTone: '#FFF2E6' },
  ],
  [
    { title: '科幻', coverTone: '#EAF0FF' },
    { title: '悬疑', coverTone: '#EEF3FF' },
  ],
  [
    { title: '轻小说', coverTone: '#FFF4F0' },
    { title: '短篇', coverTone: '#F3F6FF' },
  ],
  [
    { title: '二次元', coverTone: '#EEF8FF' },
    { title: '其他', coverTone: '#F6F7FB' },
  ],
];

const CATEGORY_STYLE_TAGS: string[] = [
  '热血',
  '爽文',
  '脑洞',
  '无敌流',
  '扮猪吃虎',
  '升级流',
  '穿越',
  '重生',
  '系统',
  '搞笑',
  '职场',
  '末世',
];

const CATEGORY_PLOT_TAGS: string[] = [
  '东方玄幻',
  '异世大陆',
  '王朝争霸',
  '架空历史',
  '高武世界',
  '都市异能',
  '娱乐明星',
  '商战职场',
  '悬疑推理',
  '未来世界',
  '星际文明',
  '灵异神怪',
];

@Component
export struct CategoryContent {
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

  sidebarWidth(): number {
    if (this.pageWidth >= 600) {
      return 92;
    }
    return this.isCompact() ? 72 : 82;
  }

  build() {
    Column({ space: this.sectionGap() }) {
      Row() {
        Text('分类')
          .fontColor(Theme.mobileText)
          .fontSize(this.titleSize())
          .fontWeight(FontWeight.Bold)
        Blank()
        this.CircleActionButton($r('app.media.discover_search'), false)
      }
      .alignItems(VerticalAlign.Center)

      Row({ space: this.isCompact() ? 20 : 24 }) {
        ForEach(CATEGORY_TOP_FILTERS, (item: string, index: number) => {
          this.TopTextTab(item, index === 0, Theme.mobileBlue)
        }, (item: string) => item)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Row({ space: 14 }) {
        Column({ space: 8 }) {
          ForEach(CATEGORY_SIDE_MENU, (item: string, index: number) => {
            Row() {
              if (index === 0) {
                Blank()
                  .width(4)
                  .height(24)
                  .borderRadius(2)
                  .backgroundColor(Theme.mobileBlue)
              } else {
                Blank()
                  .width(4)
                  .height(24)
              }
              Text(item)
                .fontColor(index === 0 ? Theme.mobileBlue : Theme.mobileSubtext)
                .fontSize(15)
                .fontWeight(index === 0 ? FontWeight.Medium : FontWeight.Regular)
                .margin({ left: 10 })
            }
            .width('100%')
            .height(46)
            .padding({ left: 12, right: 12 })
            .backgroundColor(index === 0 ? Theme.mobileSurface : Theme.mobileSidebar)
            .borderRadius(14)
          }, (item: string) => item)
        }
        .width(this.sidebarWidth())

        Column({ space: 18 }) {
          this.CategoryTitle('按题材')
          ForEach(CATEGORY_SUBJECT_ROWS, (rowItems: CategorySubject[], index: number) => {
            Row({ space: 10 }) {
              this.SubjectTile(rowItems[0])
              this.SubjectTile(rowItems[1])
            }
            .width('100%')
          }, (rowItems: CategorySubject[], index: number) => `subject-row-${index}`)

          this.CategoryTitle('按风格')
          this.TagCloud(CATEGORY_STYLE_TAGS)

          this.CategoryTitle('按情节')
          this.TagCloud(CATEGORY_PLOT_TAGS)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
  }

  @Builder
  TopTextTab(label: string, selected: boolean, accent: string) {
    Column({ space: 8 }) {
      Text(label)
        .fontColor(selected ? Theme.mobileText : Theme.mobileSubtext)
        .fontSize(this.isCompact() ? 15 : 16)
        .fontWeight(selected ? FontWeight.Bold : FontWeight.Medium)
      Blank()
        .width(selected ? 28 : 0)
        .height(4)
        .borderRadius(2)
        .backgroundColor(selected ? accent : Theme.mobileCanvas)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CategoryTitle(title: string) {
    Text(title)
      .fontColor(Theme.mobileText)
      .fontSize(20)
      .fontWeight(FontWeight.Bold)
  }

  @Builder
  SubjectTile(subject: CategorySubject) {
    Row({ space: 10 }) {
      this.BookPlaceholder(this.isCompact() ? 34 : 38, this.isCompact() ? 42 : 46, subject.coverTone)
      Text(subject.title)
        .fontColor(Theme.mobileText)
        .fontSize(this.isCompact() ? 14 : 15)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 10, bottom: 10 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(14)
  }

  @Builder
  TagCloud(tags: string[]) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(tags, (tag: string) => {
        Text(tag)
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(Theme.mobileSurface)
          .borderRadius(12)
          .margin({ right: 10, bottom: 10 })
      }, (tag: string) => tag)
    }
    .width('100%')
  }

  @Builder
  BookPlaceholder(widthValue: number, heightValue: number, tone: string) {
    Stack({ alignContent: Alignment.Center }) {
      Column() {}
        .width(widthValue)
        .height(heightValue)
        .backgroundColor(tone || '#EEF2FF')
        .borderRadius({ topLeft: 8, topRight: 8, bottomLeft: 8, bottomRight: 8 })
      Text('BOOK')
        .fontColor('#68708A')
        .fontSize(9)
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
