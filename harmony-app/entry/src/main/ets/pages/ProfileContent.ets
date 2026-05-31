import { Theme } from '../common/Theme';

interface ProfileService {
  title: string;
  subtitle: string;
  icon: Resource;
}

interface ProfileTool {
  title: string;
  icon: Resource;
}

const PROFILE_SERVICE_ROWS: ProfileService[][] = [
  [
    {
      title: '画像中心',
      subtitle: '编辑兴趣与渠道偏好',
      icon: $r('app.media.profile_user'),
    },
    {
      title: '活动中心',
      subtitle: '校园阅读活动进行中',
      icon: $r('app.media.profile_gift'),
    },
  ],
  [
    {
      title: '阅读计划',
      subtitle: '管理伴读节奏与进度',
      icon: $r('app.media.profile_calendar'),
    },
    {
      title: '问答记录',
      subtitle: '查看 AI 伴读历史',
      icon: $r('app.media.profile_chat'),
    },
  ],
  [
    {
      title: '我的笔记',
      subtitle: '摘录与灵感随时回看',
      icon: $r('app.media.profile_note'),
    },
    {
      title: '浏览记录',
      subtitle: '保留最近访问轨迹',
      icon: $r('app.media.profile_clock'),
    },
  ],
];

const PROFILE_TOOLS: ProfileTool[] = [
  { title: '收藏夹', icon: $r('app.media.profile_star') },
  { title: '阅读计划', icon: $r('app.media.profile_calendar') },
  { title: '阅读画像', icon: $r('app.media.profile_user') },
  { title: '成长勋章', icon: $r('app.media.profile_document') },
  { title: '渠道偏好', icon: $r('app.media.profile_download') },
  { title: '浏览记录', icon: $r('app.media.profile_clock') },
  { title: '关注作者', icon: $r('app.media.profile_user_plus') },
  { title: '字体设置', icon: $r('app.media.profile_font') },
];

@Component
export struct ProfileContent {
  @Prop pageWidth: number = 390;

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  sectionGap(): number {
    return this.isCompact() ? 16 : 18;
  }

  build() {
    Column({ space: this.sectionGap() }) {
      Row({ space: 10 }) {
        this.IconOnlyButton($r('app.media.mobile_filter'))
        Row({ space: 6 }) {
          Circle()
            .width(8)
            .height(8)
            .fill('#91A8FF')
          Text('校园福利专区')
            .fontColor(Theme.mobileSubtext)
            .fontSize(15)
        }
        .padding({ left: 12, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#F2F4FF')
        .borderRadius(18)
        Blank()
        this.IconOnlyButton($r('app.media.profile_moon'))
        this.NotificationButton()
      }
      .alignItems(VerticalAlign.Center)

      Row({ space: 16 }) {
        Image($r('app.media.profile_avatar'))
          .width(88)
          .height(88)
          .borderRadius(44)
        Column({ space: 8 }) {
          Text('鸿蒙智阅同学')
            .fontColor(Theme.mobileText)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
          Row({ space: 8 }) {
            this.LevelBadge('Lv.6')
            this.LevelBadge('阅读成长中')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('>')
          .fontColor('#CFD3DE')
          .fontSize(26)
      }
      .alignItems(VerticalAlign.Center)

      Column({ space: 18 }) {
        Row() {
          Text('我的账户')
            .fontColor(Theme.mobileText)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          Blank()
          Text('更多')
            .fontColor('#B6BAC6')
            .fontSize(15)
        }

        Row() {
          this.AccountStat('12', '阅读积分')
          this.AccountStat('4', '进行中计划')
          this.AccountStat('18', '笔记')
          this.AccountStat('9', '收藏')
          Column() {
            Blank()
            Row() {
              Text('查看画像')
                .fontColor(Theme.mobileSurface)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
            }
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .backgroundColor(Theme.mobileRed)
            .borderRadius(18)
          }
          .alignItems(HorizontalAlign.End)
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(24)
      .shadow({ radius: 18, color: '#18000000', offsetX: 0, offsetY: 10 })

      Row() {
        Column({ space: 8 }) {
          Text('阅读成长计划')
            .fontColor('#8A622A')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
          Text('开通享受校园伴读、计划提醒和专题推荐权益')
            .fontColor('#B38A58')
            .fontSize(13)
            .maxLines(2)
        }
        .layoutWeight(1)
        Text('立即查看 >')
          .fontColor('#A27337')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 16 })
      .backgroundColor('#FFF2D9')
      .borderRadius(22)

      Column({ space: 14 }) {
        ForEach(PROFILE_SERVICE_ROWS, (rowItems: ProfileService[], index: number) => {
          Row({ space: 14 }) {
            this.ProfileServiceCard(rowItems[0])
            this.ProfileServiceCard(rowItems[1])
          }
          .width('100%')
        }, (rowItems: ProfileService[], index: number) => `service-${index}`)
      }
      .width('100%')

      Column({ space: 18 }) {
        Row() {
          ForEach(PROFILE_TOOLS.slice(0, 4), (item: ProfileTool) => {
            this.ProfileToolItem(item)
          }, (item: ProfileTool) => item.title)
        }
        .width('100%')

        Row() {
          ForEach(PROFILE_TOOLS.slice(4, 8), (item: ProfileTool) => {
            this.ProfileToolItem(item)
          }, (item: ProfileTool) => item.title)
        }
        .width('100%')

        Row({ space: 8 }) {
          Circle()
            .width(8)
            .height(8)
            .fill(Theme.mobileRed)
          Circle()
            .width(8)
            .height(8)
            .fill('#D9DCE5')
        }
        .justifyContent(FlexAlign.Center)

        Row({ space: 12 }) {
          this.BookPlaceholder(52, 52, '#FFF0EC', false, false)
          Text('阅读计划打卡、笔记沉淀、收藏整理都能在这里继续推进。')
            .fontColor(Theme.mobileText)
            .fontSize(14)
            .lineHeight(22)
            .layoutWeight(1)
          Text('>')
            .fontColor('#CBD0DD')
            .fontSize(22)
        }
        .padding(14)
        .backgroundColor(Theme.mobileSurfaceSoft)
        .borderRadius(16)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(24)
      .shadow({ radius: 18, color: '#18000000', offsetX: 0, offsetY: 10 })

      Row({ space: 12 }) {
        this.IconOnlyButton($r('app.media.profile_help'))
        Text('帮助与反馈')
          .fontColor(Theme.mobileText)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('>')
          .fontColor('#CBD0DD')
          .fontSize(22)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 18 })
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(22)
      .shadow({ radius: 16, color: '#15000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%')
  }

  @Builder
  LevelBadge(text: string) {
    Text(text)
      .fontColor('#7A7E8B')
      .fontSize(13)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor('#F2F3F7')
      .borderRadius(10)
  }

  @Builder
  AccountStat(value: string, label: string) {
    Column({ space: 8 }) {
      Text(value)
        .fontColor(Theme.mobileText)
        .fontSize(this.isCompact() ? 24 : 28)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontColor(Theme.mobileSubtext)
        .fontSize(14)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProfileServiceCard(item: ProfileService) {
    Row({ space: 12 }) {
      Image(item.icon)
        .width(42)
        .height(42)
      Column({ space: 5 }) {
        Text(item.title)
          .fontColor(Theme.mobileText)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Text(item.subtitle)
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
          .lineHeight(20)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .padding(16)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(22)
    .shadow({ radius: 14, color: '#12000000', offsetX: 0, offsetY: 6 })
  }

  @Builder
  ProfileToolItem(item: ProfileTool) {
    Column({ space: 10 }) {
      Image(item.icon)
        .width(28)
        .height(28)
      Text(item.title)
        .fontColor(Theme.mobileText)
        .fontSize(14)
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
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
  IconOnlyButton(icon: Resource) {
    Stack() {
      Circle()
        .width(40)
        .height(40)
        .fill(Theme.mobileSurface)
      Image(icon)
        .width(20)
        .height(20)
    }
    .width(40)
    .height(40)
  }

  @Builder
  NotificationButton() {
    Stack({ alignContent: Alignment.TopEnd }) {
      this.IconOnlyButton($r('app.media.mobile_bell'))
      Circle()
        .width(8)
        .height(8)
        .fill(Theme.mobileRed)
        .margin({ top: 4, right: 4 })
    }
  }
}
