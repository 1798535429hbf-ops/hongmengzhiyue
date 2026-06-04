import { goBack, openLogin } from '../common/Navigation';
import { UserSession } from '../common/UserSession';
import { common } from '@kit.AbilityKit';

interface SettingItem {
  title: string;
  value: string;
  dot: boolean;
  action: string;
}

@Entry
@Component
struct SettingsPage {
  @State pageWidth: number = 390;
  @State toastText: string = '';
  @State showToast: boolean = false;
  @StorageLink('smartread_session_user_id') sessionUserId: number = 0;

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  groupOne(): SettingItem[] {
    return [
      { title: '账号安全', value: '', dot: false, action: 'account' },
      { title: '偏好设置', value: '', dot: false, action: 'preference' },
      { title: '阅读设置', value: '', dot: false, action: 'reader' },
      { title: '书架设置', value: '订阅及加书架管理', dot: false, action: 'shelf' },
      { title: '免密支付管理', value: '', dot: true, action: 'pay' },
      { title: '地址管理', value: '', dot: true, action: 'address' },
    ];
  }

  groupTwo(): SettingItem[] {
    return [
      { title: '推送通知', value: '已开启', dot: false, action: 'push' },
      { title: '隐私设置', value: '', dot: false, action: 'privacy' },
      { title: '通用设置', value: '夜间模式、听书及网络设置等', dot: false, action: 'general' },
    ];
  }

  groupThree(): SettingItem[] {
    return [
      { title: '青少年模式', value: '未开启', dot: false, action: 'teen' },
      { title: '隐私政策', value: '', dot: false, action: 'privacy_policy' },
      { title: '儿童隐私政策', value: '', dot: false, action: 'child_policy' },
      { title: '用户服务协议', value: '', dot: false, action: 'agreement' },
      { title: '个人信息收集清单', value: '', dot: false, action: 'collection' },
      { title: '第三方信息共享清单', value: '', dot: false, action: 'third_party' },
    ];
  }

  groupFour(): SettingItem[] {
    return [
      { title: '关于起点读书', value: '', dot: false, action: 'about' },
    ];
  }

  handleItem(item: SettingItem): void {
    this.flashToast(`${item.title}已设置为可跳转入口`);
  }

  async logout(): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      this.flashToast('当前页面上下文不可用');
      return;
    }
    if (this.sessionUserId <= 0) {
      openLogin();
      return;
    }
    try {
      await UserSession.logout(context);
      this.flashToast('已退出登录');
    } catch (err) {
      this.flashToast(`退出失败：${err}`);
    }
  }

  flashToast(text: string): void {
    this.toastText = text;
    this.showToast = true;
    setTimeout(() => {
      this.showToast = false;
      this.toastText = '';
    }, 1400);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.TopBar()
        Scroll() {
          Column({ space: 16 }) {
            this.SettingGroup(this.groupOne())
            this.SettingGroup(this.groupTwo())
            this.SettingGroup(this.groupThree())
            this.SettingGroup(this.groupFour())
            this.LogoutButton()
          }
          .width('100%')
          .padding({ left: 28, right: 28, bottom: 34 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F6F6F6')

      if (this.showToast) {
        Stack({ alignContent: Alignment.Center }) {
          Text(this.toastText)
            .fontColor('#FFFFFF')
            .fontSize(14)
            .padding({ left: 18, right: 18, top: 11, bottom: 11 })
            .backgroundColor('rgba(25,25,25,0.78)')
            .borderRadius(18)
        }
        .width('100%')
        .height(260)
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_, area) => {
      const nextWidth = typeof area.width === 'number' ? area.width : Number(area.width);
      if (Number.isFinite(nextWidth) && nextWidth > 0) {
        this.pageWidth = nextWidth;
      }
    })
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontColor('#191A1F')
        .fontSize(48)
        .fontWeight(FontWeight.Regular)
        .width(54)
        .height(58)
        .textAlign(TextAlign.Center)
        .onClick(() => goBack())
      Text('设置')
        .fontColor('#202124')
        .fontSize(this.isCompact() ? 25 : 29)
        .fontWeight(FontWeight.Regular)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('')
        .width(54)
    }
    .width('100%')
    .height(102)
    .padding({ left: 18, right: 18, top: 24 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SettingGroup(items: SettingItem[]) {
    Column() {
      ForEach(items, (item: SettingItem, index: number) => {
        Column() {
          this.SettingRow(item)
          if (index < items.length - 1) {
            Divider()
              .height(0.5)
              .color('#ECEDEF')
              .margin({ left: 0 })
          }
        }
        .width('100%')
      }, (item: SettingItem) => item.title)
    }
    .width('100%')
    .padding({ left: 26, right: 22 })
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
  }

  @Builder
  SettingRow(item: SettingItem) {
    Row({ space: 10 }) {
      Text(item.title)
        .fontColor('#2C2D32')
        .fontSize(this.isCompact() ? 23 : 26)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (item.value) {
        Text(item.value)
          .fontColor('#8E929A')
          .fontSize(this.isCompact() ? 16 : 18)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: this.pageWidth < 420 ? 190 : 260 })
      }
      if (item.dot) {
        Circle()
          .width(10)
          .height(10)
          .fill('#FF2F55')
          .margin({ right: 4 })
      }
      Text('›')
        .fontColor('#CFD2D6')
        .fontSize(36)
        .width(22)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(72)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.handleItem(item))
  }

  @Builder
  LogoutButton() {
    Text(this.sessionUserId > 0 ? '退出登录' : '登录/注册')
      .fontColor(this.sessionUserId > 0 ? '#EF3340' : '#2C2D32')
      .fontSize(22)
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .height(58)
      .textAlign(TextAlign.Center)
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .onClick(() => this.logout())
  }
}
