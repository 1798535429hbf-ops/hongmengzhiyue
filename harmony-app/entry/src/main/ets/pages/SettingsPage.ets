import { ApiClient } from '../common/ApiClient';
import { APP_DARK_MODE_KEY, APP_FONT_FAMILY_KEY, AppSettings } from '../common/AppSettings';
import { UserProfile, emptyProfile } from '../common/Models';
import { goBack, openAccountSecurity, openGeneralSettings, openLogin, openPreferenceSettings } from '../common/Navigation';
import { UserSession } from '../common/UserSession';
import { common } from '@kit.AbilityKit';

interface SettingItem {
  title: string;
  value: string;
  action: string;
}

@Entry
@Component
struct SettingsPage {
  @State pageWidth: number = 390;
  @State profile: UserProfile = emptyProfile();
  @State loadingProfile: boolean = false;
  @State toastText: string = '';
  @State showToast: boolean = false;
  @State showSwitchConfirm: boolean = false;
  @StorageLink('smartread_session_user_id') sessionUserId: number = 0;
  @StorageLink('smartread_session_profile_json') sessionProfileJson: string = '';
  @StorageLink(APP_DARK_MODE_KEY) darkMode: boolean = false;
  @StorageLink(APP_FONT_FAMILY_KEY) fontFamily: string = 'system';

  aboutToAppear(): void {
    this.loadProfile();
  }

  onPageShow(): void {
    this.loadProfile();
  }

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  bg(): string {
    return this.darkMode ? '#0F1218' : '#F5F5F7';
  }

  surface(): string {
    return this.darkMode ? '#191D25' : '#FFFFFF';
  }

  secondarySurface(): string {
    return this.darkMode ? '#111722' : '#F2F3F7';
  }

  text(): string {
    return this.darkMode ? '#EEF2F8' : '#1D1D1F';
  }

  subtext(): string {
    return this.darkMode ? '#9BA3B4' : '#6E7380';
  }

  line(): string {
    return this.darkMode ? '#293040' : '#E8E9EE';
  }

  accent(): string {
    return '#0A84FF';
  }

  appFont(): string {
    return AppSettings.fontFamilyValue(this.fontFamily);
  }

  isSessionProfile(profile: UserProfile | null, userId: number): boolean {
    return !!profile && Number.isFinite(profile.id) && profile.id === userId;
  }

  visibleProfile(): UserProfile | null {
    const stateProfile = this.isSessionProfile(this.profile, this.sessionUserId) ? this.profile : null;
    let cachedProfile: UserProfile | null = null;
    try {
      const profile = JSON.parse(this.sessionProfileJson) as UserProfile;
      cachedProfile = this.isSessionProfile(profile, this.sessionUserId) ? profile : null;
    } catch (_) {
    }
    if (cachedProfile && (cachedProfile.phone || cachedProfile.account || cachedProfile.email)) {
      return cachedProfile;
    }
    return stateProfile || cachedProfile;
  }

  groupOne(): SettingItem[] {
    return [
      { title: '账号安全', value: '头像、昵称、邮箱与密码', action: 'account' },
      { title: '偏好设置', value: '学习与通识标签', action: 'preference' },
      { title: '通用设置', value: '外观、字体、翻页与语言', action: 'general' },
    ];
  }

  displayName(): string {
    if (this.sessionUserId <= 0) {
      return '未登录';
    }
    const profile = this.visibleProfile();
    return profile?.nickname || profile?.name || `智阅同学 ${this.sessionUserId}`;
  }

  profileId(): string {
    return this.sessionUserId > 0 ? `${this.sessionUserId}` : '未登录';
  }

  boundPhone(): string {
    const profile = this.visibleProfile();
    const phone = (profile?.phone || '').replace(/\D/g, '');
    if (/^1\d{10}$/.test(phone)) {
      return phone;
    }
    const account = (profile?.account || '').replace(/\D/g, '');
    return /^1\d{10}$/.test(account) ? account : '';
  }

  displayPhone(): string {
    const phone = this.boundPhone();
    if (!phone) {
      return '未绑定';
    }
    if (phone.length >= 11) {
      return `${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}`;
    }
    return phone;
  }

  displayEmail(): string {
    const profile = this.visibleProfile();
    return profile?.email || '未绑定';
  }

  avatarSource(): string {
    const profile = this.visibleProfile();
    return profile?.avatarUrl ? ApiClient.resourceUrl(profile.avatarUrl) : '';
  }

  async loadProfile(): Promise<void> {
    if (this.sessionUserId <= 0) {
      this.profile = emptyProfile();
      return;
    }
    this.loadingProfile = true;
    try {
      const bundle = await ApiClient.profile(this.sessionUserId);
      if (this.isSessionProfile(bundle.profile, this.sessionUserId)) {
        this.profile = bundle.profile;
        const context = this.hostContext();
        if (context) {
          await UserSession.persist(context, bundle.profile);
        }
      } else {
        const cached = UserSession.currentProfile();
        this.profile = this.isSessionProfile(cached, this.sessionUserId) ? cached as UserProfile : emptyProfile();
      }
    } catch (_) {
      const cached = UserSession.currentProfile();
      this.profile = this.isSessionProfile(cached, this.sessionUserId) ? cached as UserProfile : emptyProfile();
    } finally {
      this.loadingProfile = false;
    }
  }

  handleItem(item: SettingItem): void {
    if (item.action === 'account') {
      openAccountSecurity();
      return;
    }
    if (item.action === 'preference') {
      openPreferenceSettings();
      return;
    }
    if (item.action === 'general') {
      openGeneralSettings();
      return;
    }
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
      this.profile = emptyProfile();
      this.flashToast('已退出登录');
    } catch (err) {
      this.flashToast(`退出失败：${err}`);
    }
  }

  openSwitchConfirm(): void {
    this.showSwitchConfirm = true;
  }

  switchAccount(): void {
    this.showSwitchConfirm = false;
    openLogin();
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
            this.ProfileHeader()
            this.SettingGroup(this.groupOne())
            this.SessionActions()
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 34 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bg())
      .animation({ duration: 260, curve: Curve.EaseInOut })

      if (this.showSwitchConfirm) {
        this.SwitchAccountSheet()
      }

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
    .backgroundColor(this.bg())
    .onAreaChange((_: Area, area: Area) => {
      const nextWidth: number = typeof area.width === 'number' ? area.width : Number(area.width);
      if (Number.isFinite(nextWidth) && nextWidth > 0) {
        this.pageWidth = nextWidth;
      }
    })
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontColor(this.text())
        .fontSize(36)
        .width(52)
        .height(58)
        .textAlign(TextAlign.Center)
        .onClick(() => goBack())
      Text('设置')
        .fontColor(this.text())
        .fontSize(this.isCompact() ? 22 : 25)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('')
        .width(52)
    }
    .width('100%')
    .height(92)
    .padding({ left: 12, right: 18, top: 24 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  AvatarImage(size: number) {
    if (this.avatarSource()) {
      Image(this.avatarSource())
        .width(size)
        .height(size)
        .borderRadius(size / 2)
        .backgroundColor(this.secondarySurface())
    } else {
      Image($r('app.media.profile_avatar'))
        .width(size)
        .height(size)
        .borderRadius(size / 2)
        .backgroundColor(this.secondarySurface())
    }
  }

  @Builder
  ProfileHeader() {
    Column({ space: 14 }) {
      Row({ space: 14 }) {
        this.AvatarImage(68)
        Column({ space: 5 }) {
          Text(this.displayName())
            .fontColor(this.text())
            .fontSize(23)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.loadingProfile ? '正在同步账号资料' : `ID ${this.profileId()}`)
            .fontColor(this.subtext())
            .fontSize(14)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('›')
          .fontColor(this.subtext())
          .fontSize(28)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (this.sessionUserId > 0) {
          openAccountSecurity();
        } else {
          openLogin();
        }
      })

      Divider().height(0.5).color(this.line())

      Row({ space: 8 }) {
        this.ContactChip('手机号', this.displayPhone())
        this.ContactChip('邮箱', this.displayEmail())
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.surface())
    .borderRadius(22)
    .shadow(this.darkMode ? { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 } : { radius: 20, color: '#0A000000', offsetX: 0, offsetY: 8 })
  }

  @Builder
  ContactChip(label: string, value: string) {
    Column({ space: 3 }) {
      Text(label)
        .fontColor(this.subtext())
        .fontSize(12)
        .width('100%')
      Text(value)
        .fontColor(this.text())
        .fontSize(14)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .layoutWeight(1)
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.secondarySurface())
    .borderRadius(14)
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
              .color(this.line())
          }
        }
        .width('100%')
      }, (item: SettingItem) => item.title)
    }
    .width('100%')
    .padding({ left: 18, right: 14 })
    .backgroundColor(this.surface())
    .borderRadius(18)
  }

  @Builder
  SettingRow(item: SettingItem) {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(item.title)
          .fontColor(this.text())
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.value)
          .fontColor(this.subtext())
          .fontSize(13)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontColor(this.subtext())
        .fontSize(26)
        .width(20)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(64)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.handleItem(item))
  }

  @Builder
  SessionActions() {
    Column({ space: 10 }) {
      Text(this.sessionUserId > 0 ? '退出登录' : '登录/注册')
        .fontColor(this.sessionUserId > 0 ? '#FF3B30' : this.accent())
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .height(54)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.surface())
        .borderRadius(18)
        .onClick(() => this.logout())
      if (this.sessionUserId > 0) {
        Text('切换账号')
          .fontColor(this.text())
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .height(54)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.surface())
          .borderRadius(18)
          .onClick(() => this.openSwitchConfirm())
      }
    }
    .width('100%')
  }

  @Builder
  SwitchAccountSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.darkMode ? '#99000000' : '#66000000')
        .onClick(() => { this.showSwitchConfirm = false; })
      Column({ space: 12 }) {
        Text('切换账号')
          .fontColor(this.text())
          .fontSize(21)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .textAlign(TextAlign.Center)
        Text('前往登录页不会退出当前账号，取消后会回到设置页。')
          .fontColor(this.subtext())
          .fontSize(15)
          .lineHeight(22)
          .width('100%')
          .textAlign(TextAlign.Center)
        Button('前往登录')
          .width('100%')
          .height(46)
          .fontColor('#FFFFFF')
          .fontSize(16)
          .backgroundColor(this.accent())
          .borderRadius(23)
          .onClick(() => this.switchAccount())
        Button('取消')
          .width('100%')
          .height(46)
          .fontColor(this.text())
          .fontSize(16)
          .backgroundColor(this.darkMode ? '#252B36' : '#F1F2F5')
          .borderRadius(23)
          .onClick(() => { this.showSwitchConfirm = false; })
      }
      .width('100%')
      .padding({ left: 26, right: 26, top: 22, bottom: 34 })
      .backgroundColor(this.surface())
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
    .zIndex(10)
  }
}
