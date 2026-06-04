import { ApiClient } from '../common/ApiClient';
import { Book, ChatRecord, NoteItem, PlanItem, UserProfile, emptyProfile } from '../common/Models';
import { openLogin, openProfileEdit, openSettings } from '../common/Navigation';
import { Theme } from '../common/Theme';
import { UserSession } from '../common/UserSession';

interface ProfileMenuItem {
  title: string;
  count: number;
  action: string;
}

@Component
export struct ProfileContent {
  @Prop pageWidth: number = 390;
  @StorageLink('smartread_session_user_id') @Watch('onSessionUserChange') sessionUserId: number = 0;
  @StorageLink('smartread_session_user_name') sessionUserName: string = '';

  @State profile: UserProfile = emptyProfile();
  @State favorites: Book[] = [];
  @State notes: NoteItem[] = [];
  @State plans: PlanItem[] = [];
  @State chats: ChatRecord[] = [];
  @State busyText: string = '';
  @State errorText: string = '';
  @State toastText: string = '';
  @State showToast: boolean = false;

  aboutToAppear(): void {
    this.loadDashboard();
  }

  onPageShow(): void {
    this.loadDashboard();
  }

  onSessionUserChange(): void {
    this.loadDashboard();
  }

  loggedIn(): boolean {
    return Number.isFinite(this.sessionUserId) && this.sessionUserId > 0;
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  pageGap(): number {
    return this.isCompact() ? 14 : 18;
  }

  displayName(): string {
    if (!this.loggedIn()) {
      return '登录/注册';
    }
    return this.sessionUserName || this.profile.name || `智阅同学 ${this.sessionUserId}`;
  }

  displaySubtitle(): string {
    if (!this.loggedIn()) {
      return '登录后同步收藏与浏览记录';
    }
    const major = this.profile.major || '未填写专业';
    const grade = this.profile.grade || '未填写年级';
    return `${major} · ${grade}`;
  }

  menuItems(): ProfileMenuItem[] {
    return [
      { title: '我的收藏', count: this.favorites.length, action: 'favorite' },
      { title: '浏览记录', count: this.chats.length + this.plans.length + this.notes.length, action: 'history' },
    ];
  }

  async loadDashboard(): Promise<void> {
    const userId = this.sessionUserId;
    if (userId <= 0) {
      this.profile = emptyProfile();
      this.favorites = [];
      this.notes = [];
      this.plans = [];
      this.chats = [];
      this.errorText = '';
      this.busyText = '';
      return;
    }

    this.busyText = '正在同步账号数据';
    this.errorText = '';
    try {
      const bundle = await ApiClient.profile(userId);
      this.profile = bundle.profile || UserSession.currentProfile() || emptyProfile();
      this.favorites = bundle.favorites || [];
      this.notes = bundle.notes || [];
      this.plans = bundle.plans || [];
      this.chats = bundle.chat_records || [];
    } catch (err) {
      this.profile = UserSession.currentProfile() || emptyProfile();
      this.favorites = [];
      this.notes = [];
      this.plans = [];
      this.chats = [];
      this.errorText = `账号数据加载失败：${err}`;
    } finally {
      this.busyText = '';
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

  handleAccountTap(): void {
    if (this.loggedIn()) {
      openProfileEdit();
    } else {
      openLogin();
    }
  }

  handleMenu(action: string): void {
    if (!this.loggedIn()) {
      openLogin();
      return;
    }
    if (action === 'favorite') {
      this.flashToast(`当前账号已收藏 ${this.favorites.length} 本书`);
      return;
    }
    this.flashToast(`浏览记录包含 ${this.plans.length} 个阅读计划、${this.notes.length} 条笔记、${this.chats.length} 条问答`);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: this.pageGap() }) {
        this.TopTools()
        this.AccountHero()
        if (this.errorText) {
          this.StatusBanner(this.errorText, Theme.mobileRed)
        }
        if (this.busyText) {
          this.StatusBanner(this.busyText, Theme.mobileBlue)
        }
        this.MenuCard()
      }
      .width('100%')

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
  }

  @Builder
  TopTools() {
    Row() {
      Image($r('app.media.mobile_filter'))
        .width(34)
        .height(34)
        .padding(4)
        .onClick(() => openSettings())

      Blank()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  AccountHero() {
    Row({ space: 16 }) {
      Image($r('app.media.profile_avatar'))
        .width(this.isCompact() ? 58 : 66)
        .height(this.isCompact() ? 58 : 66)
        .borderRadius(this.isCompact() ? 29 : 33)
        .backgroundColor('#F3F5F8')

      Column({ space: 7 }) {
        Text(this.displayName())
          .fontColor('#1F2430')
          .fontSize(this.isCompact() ? 28 : 32)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.displaySubtitle())
          .fontColor('#9AA0AE')
          .fontSize(this.isCompact() ? 14 : 16)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontColor('#C7CAD1')
        .fontSize(42)
        .fontWeight(FontWeight.Medium)
        .width(34)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: this.isCompact() ? 22 : 30, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.handleAccountTap())
  }

  @Builder
  MenuCard() {
    Column() {
      ForEach(this.menuItems(), (item: ProfileMenuItem, index: number) => {
        Column() {
          this.MenuRow(item)
          if (index < this.menuItems().length - 1) {
            Divider()
              .height(0.5)
              .color('#EEF0F4')
              .margin({ left: 8 })
          }
        }
        .width('100%')
      }, (item: ProfileMenuItem) => item.title)
    }
    .width('100%')
    .padding({ left: 22, right: 18 })
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
  }

  @Builder
  MenuRow(item: ProfileMenuItem) {
    Row({ space: 12 }) {
      Text(item.title)
        .fontColor('#30333B')
        .fontSize(this.isCompact() ? 20 : 22)
        .layoutWeight(1)
      if (this.loggedIn()) {
        Text(`${item.count}`)
          .fontColor('#9AA0AE')
          .fontSize(15)
      }
      Text('›')
        .fontColor('#D0D3DA')
        .fontSize(28)
    }
    .width('100%')
    .height(this.isCompact() ? 68 : 76)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.handleMenu(item.action))
  }

  @Builder
  StatusBanner(text: string, color: string) {
    Text(text)
      .fontColor('#FFFFFF')
      .fontSize(13)
      .lineHeight(18)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(color)
      .borderRadius(8)
      .width('100%')
  }
}
