import { ApiClient, ResetPasswordResult } from '../common/ApiClient';
import { APP_DARK_MODE_KEY, APP_FONT_FAMILY_KEY, AppSettings } from '../common/AppSettings';
import { UserProfile, emptyProfile } from '../common/Models';
import { goBack, openLogin } from '../common/Navigation';
import { UserSession } from '../common/UserSession';
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';

@Entry
@Component
struct AccountSecurityPage {
  @State pageWidth: number = 390;
  @State profile: UserProfile = emptyProfile();
  @State nickname: string = '';
  @State intro: string = '';
  @State email: string = '';
  @State avatarUrl: string = '';
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State generatedPassword: string = '';
  @State busyText: string = '';
  @State errorText: string = '';
  @State toastText: string = '';
  @State showToast: boolean = false;
  @State showDeleteConfirm: boolean = false;
  @StorageLink(APP_DARK_MODE_KEY) darkMode: boolean = false;
  @StorageLink(APP_FONT_FAMILY_KEY) fontFamily: string = 'system';

  aboutToAppear(): void {
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

  fieldBg(): string {
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
    const userId = UserSession.currentUserId();
    return this.isSessionProfile(this.profile, userId) ? this.profile : null;
  }

  avatarSource(): string {
    const profile = this.visibleProfile();
    const avatar = this.avatarUrl || profile?.avatarUrl || '';
    return avatar ? ApiClient.resourceUrl(avatar) : '';
  }

  currentUserIdText(): string {
    const userId = UserSession.currentUserId();
    return userId > 0 ? `${userId}` : '未登录';
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

  maskedPhone(): string {
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
    return this.email || profile?.email || '未绑定';
  }

  async loadProfile(): Promise<void> {
    const userId = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先登录后再管理账号安全';
      this.profile = emptyProfile();
      this.nickname = '';
      this.intro = '';
      this.email = '';
      this.avatarUrl = '';
      return;
    }
    this.busyText = '正在加载账号资料';
    this.errorText = '';
    try {
      const bundle = await ApiClient.profile(userId);
      if (this.isSessionProfile(bundle.profile, userId)) {
        this.profile = bundle.profile;
        const context = this.hostContext();
        if (context) {
          await UserSession.persist(context, bundle.profile);
        }
      } else {
        const cached = UserSession.currentProfile();
        this.profile = this.isSessionProfile(cached, userId) ? cached as UserProfile : emptyProfile();
      }
      this.nickname = this.profile.nickname || this.profile.name || '';
      this.intro = this.profile.intro || '';
      this.email = this.profile.email || '';
      this.avatarUrl = this.profile.avatarUrl || '';
    } catch (err) {
      const cached = UserSession.currentProfile();
      this.profile = this.isSessionProfile(cached, userId) ? cached as UserProfile : emptyProfile();
      this.nickname = this.profile.nickname || this.profile.name || '';
      this.intro = this.profile.intro || '';
      this.email = this.profile.email || '';
      this.avatarUrl = this.profile.avatarUrl || '';
      this.errorText = `账号资料加载失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async saveProfile(): Promise<void> {
    const context = this.hostContext();
    const userId = UserSession.currentUserId();
    if (!context || userId <= 0) {
      this.flashToast('请先登录');
      return;
    }
    const nextName = this.nickname.trim();
    if (!nextName) {
      this.flashToast('昵称不能为空');
      return;
    }
    this.busyText = '正在保存账号资料';
    this.errorText = '';
    try {
      const draft: UserProfile = {
        id: userId,
        account: this.profile.account || String(userId),
        phone: this.profile.phone || '',
        email: this.email.trim(),
        name: nextName,
        nickname: nextName,
        major: this.profile.major || '',
        grade: this.profile.grade || '',
        interests: this.profile.interests || '',
        goal: this.profile.goal || '',
        intro: this.intro.trim(),
        avatarUrl: this.avatarUrl || this.profile.avatarUrl || '',
        channels: this.profile.channels || '',
      };
      const saved = await ApiClient.saveProfile(draft);
      this.profile = saved;
      this.nickname = saved.nickname || saved.name || '';
      this.intro = saved.intro || '';
      this.email = saved.email || '';
      this.avatarUrl = saved.avatarUrl || '';
      await UserSession.persist(context, saved);
      this.flashToast('资料已保存');
    } catch (err) {
      this.errorText = `保存失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async pickAvatar(): Promise<void> {
    const context = this.hostContext();
    const userId = UserSession.currentUserId();
    if (!context || userId <= 0) {
      this.flashToast('请先登录');
      return;
    }
    const photoPicker = new picker.PhotoViewPicker();
    const options = new picker.PhotoSelectOptions();
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    try {
      const result = await photoPicker.select(options);
      if (!result.photoUris || result.photoUris.length === 0) {
        return;
      }
      this.busyText = '正在上传头像';
      this.errorText = '';
      const uploadedUrl = await ApiClient.uploadAvatar(userId, result.photoUris[0]);
      if (!uploadedUrl) {
        this.flashToast('头像上传未返回地址');
        return;
      }
      this.avatarUrl = uploadedUrl;
      await this.saveProfile();
      this.flashToast('头像已更新');
    } catch (err) {
      this.errorText = `头像上传失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async bindEmail(): Promise<void> {
    const context = this.hostContext();
    const userId = UserSession.currentUserId();
    if (!context || userId <= 0) {
      this.flashToast('请先登录');
      return;
    }
    const nextEmail = this.email.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(nextEmail)) {
      this.flashToast('请输入有效邮箱');
      return;
    }
    this.busyText = '正在绑定邮箱';
    this.errorText = '';
    try {
      const saved = await ApiClient.bindEmail(userId, nextEmail);
      this.profile = saved;
      this.email = saved.email || nextEmail;
      await UserSession.persist(context, saved);
      this.flashToast('邮箱已绑定');
    } catch (err) {
      this.errorText = `绑定邮箱失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async changePassword(): Promise<void> {
    const userId = UserSession.currentUserId();
    if (userId <= 0) {
      this.flashToast('请先登录');
      return;
    }
    if (this.oldPassword.length < 6 || this.newPassword.length < 6) {
      this.flashToast('密码至少 6 位');
      return;
    }
    this.busyText = '正在修改密码';
    this.errorText = '';
    try {
      await ApiClient.changePassword(userId, this.oldPassword, this.newPassword);
      this.oldPassword = '';
      this.newPassword = '';
      this.flashToast('密码已修改');
    } catch (err) {
      this.errorText = `修改密码失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async resetPassword(): Promise<void> {
    const phone = this.boundPhone();
    if (!/^1\d{10}$/.test(phone)) {
      this.flashToast('当前账号未绑定可用手机号');
      return;
    }
    this.busyText = '正在重置密码';
    this.errorText = '';
    this.generatedPassword = '';
    try {
      const result: ResetPasswordResult = await ApiClient.resetPassword(phone);
      this.generatedPassword = result.generatedPassword || '';
      this.flashToast('系统密码已生成');
    } catch (err) {
      this.errorText = `重置密码失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async deleteAccount(): Promise<void> {
    const context = this.hostContext();
    const userId = UserSession.currentUserId();
    if (!context || userId <= 0) {
      this.flashToast('请先登录');
      return;
    }
    this.busyText = '正在注销账号';
    this.errorText = '';
    try {
      await ApiClient.deleteAccount(userId);
      await UserSession.logout(context);
      this.showDeleteConfirm = false;
      openLogin();
    } catch (err) {
      this.errorText = `注销账号失败：${err}`;
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

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.TopBar()
        Scroll() {
          Column({ space: 16 }) {
            if (this.errorText) { this.StatusBanner(this.errorText, '#D94242') }
            if (this.busyText) { this.StatusBanner(this.busyText, this.accent()) }
            this.ProfileCard()
            this.EmailCard()
            this.PasswordCard()
            this.ResetPasswordCard()
            this.DeleteAccountButton()
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

      if (this.showDeleteConfirm) {
        this.DeleteConfirmSheet()
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
      Text('账号与安全')
        .fontColor(this.text())
        .fontSize(this.isCompact() ? 21 : 24)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('保存')
        .fontColor(this.nickname.trim() ? this.accent() : this.subtext())
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .width(52)
        .textAlign(TextAlign.End)
        .onClick(() => this.saveProfile())
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
        .backgroundColor(this.fieldBg())
    } else {
      Image($r('app.media.profile_avatar'))
        .width(size)
        .height(size)
        .borderRadius(size / 2)
        .backgroundColor(this.fieldBg())
    }
  }

  @Builder
  ProfileCard() {
    Column() {
      Row({ space: 14 }) {
        this.AvatarImage(64)
        Column({ space: 4 }) {
          Text(this.nickname || this.profile.name || '智阅同学')
            .fontColor(this.text())
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`ID ${this.currentUserIdText()}`)
            .fontColor(this.subtext())
            .fontSize(14)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('更换')
          .fontColor(this.accent())
          .fontSize(15)
      }
      .width('100%')
      .height(88)
      .alignItems(VerticalAlign.Center)
      .border({ width: { bottom: 0.5 }, color: this.line() })
      .onClick(() => this.pickAvatar())

      this.InputRow('昵称', this.nickname, '请输入昵称', 'nickname')
      this.InputRow('简介', this.intro, '添加一句话简介', 'intro')
      this.StaticRow('ID', this.currentUserIdText())
      this.StaticRow('手机号', this.maskedPhone())
      this.StaticRow('邮箱', this.displayEmail(), false)
    }
    .width('100%')
    .padding({ left: 18, right: 16 })
    .backgroundColor(this.surface())
    .borderRadius(20)
  }

  @Builder
  StaticRow(label: string, value: string, showDivider: boolean = true) {
    Row({ space: 12 }) {
      Text(label)
        .fontColor(this.text())
        .fontSize(17)
        .width(78)
      Text(value)
        .fontColor(this.subtext())
        .fontSize(16)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(58)
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: showDivider ? 0.5 : 0 }, color: this.line() })
  }

  @Builder
  InputRow(label: string, value: string, placeholder: string, field: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontColor(this.text())
        .fontSize(17)
        .width(78)
      TextInput({ placeholder, text: value })
        .layoutWeight(1)
        .height(48)
        .fontColor(this.text())
        .fontSize(16)
        .textAlign(TextAlign.End)
        .placeholderColor(this.subtext())
        .backgroundColor('transparent')
        .padding({ left: 0, right: 0 })
        .onChange((text: string) => {
          if (field === 'nickname') {
            this.nickname = text;
          } else {
            this.intro = text;
          }
        })
    }
    .width('100%')
    .height(58)
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 0.5 }, color: this.line() })
  }

  @Builder
  EmailCard() {
    Column({ space: 12 }) {
      Text('绑定邮箱')
        .fontColor(this.text())
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      TextInput({ placeholder: 'name@example.com', text: this.email })
        .height(46)
        .fontColor(this.text())
        .fontSize(16)
        .placeholderColor(this.subtext())
        .backgroundColor(this.fieldBg())
        .borderRadius(12)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => { this.email = value; })
      Button('绑定邮箱')
        .width('100%')
        .height(42)
        .fontColor('#FFFFFF')
        .fontSize(15)
        .backgroundColor(this.accent())
        .borderRadius(21)
        .onClick(() => this.bindEmail())
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.surface())
    .borderRadius(20)
  }

  @Builder
  PasswordCard() {
    Column({ space: 12 }) {
      Text('修改密码')
        .fontColor(this.text())
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      this.PasswordInput('当前密码', this.oldPassword, 'old')
      this.PasswordInput('新密码', this.newPassword, 'new')
      Button('修改密码')
        .width('100%')
        .height(42)
        .fontColor('#FFFFFF')
        .fontSize(15)
        .backgroundColor(this.accent())
        .borderRadius(21)
        .onClick(() => this.changePassword())
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.surface())
    .borderRadius(20)
  }

  @Builder
  ResetPasswordCard() {
    Column({ space: 12 }) {
      Row() {
        Text('重置密码')
          .fontColor(this.text())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(this.maskedPhone())
          .fontColor(this.subtext())
          .fontSize(14)
      }
      .width('100%')
      Text('使用当前登录账号绑定的手机号向后端发起重置，不在页面展示完整号码。')
        .fontColor(this.subtext())
        .fontSize(13)
        .lineHeight(19)
        .width('100%')
      if (this.generatedPassword) {
        Text(`新密码：${this.generatedPassword}`)
          .fontColor('#167C4A')
          .fontSize(15)
          .lineHeight(22)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(this.darkMode ? '#143126' : '#EAF7EF')
          .borderRadius(12)
          .width('100%')
      }
      Button('生成系统密码')
        .width('100%')
        .height(42)
        .fontColor('#FFFFFF')
        .fontSize(15)
        .backgroundColor('#1D1D1F')
        .borderRadius(21)
        .onClick(() => this.resetPassword())
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.surface())
    .borderRadius(20)
  }

  @Builder
  PasswordInput(placeholder: string, value: string, field: string) {
    TextInput({ placeholder, text: value })
      .type(InputType.Password)
      .height(46)
      .fontColor(this.text())
      .fontSize(16)
      .placeholderColor(this.subtext())
      .backgroundColor(this.fieldBg())
      .borderRadius(12)
      .padding({ left: 14, right: 14 })
      .onChange((next: string) => {
        if (field === 'old') {
          this.oldPassword = next;
        } else {
          this.newPassword = next;
        }
      })
  }

  @Builder
  DeleteAccountButton() {
    Text('注销账号')
      .fontColor('#FF3B30')
      .fontSize(17)
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .height(54)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.surface())
      .borderRadius(18)
      .onClick(() => { this.showDeleteConfirm = true; })
  }

  @Builder
  DeleteConfirmSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.darkMode ? '#99000000' : '#66000000')
        .onClick(() => { this.showDeleteConfirm = false; })
      Column({ space: 12 }) {
        Text('确认注销账号？')
          .fontColor(this.text())
          .fontSize(21)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .textAlign(TextAlign.Center)
        Text('注销后当前账号将不能继续登录，计划、笔记、收藏仍保留在数据库中用于审计。')
          .fontColor(this.subtext())
          .fontSize(15)
          .lineHeight(22)
          .width('100%')
          .textAlign(TextAlign.Center)
        Button('确认注销')
          .width('100%')
          .height(46)
          .fontColor('#FFFFFF')
          .fontSize(16)
          .backgroundColor('#FF3B30')
          .borderRadius(23)
          .onClick(() => this.deleteAccount())
        Button('取消')
          .width('100%')
          .height(46)
          .fontColor(this.text())
          .fontSize(16)
          .backgroundColor(this.darkMode ? '#252B36' : '#F1F2F5')
          .borderRadius(23)
          .onClick(() => { this.showDeleteConfirm = false; })
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

  @Builder
  StatusBanner(text: string, color: string) {
    Text(text)
      .fontColor('#FFFFFF')
      .fontSize(13)
      .lineHeight(18)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(color)
      .borderRadius(12)
      .width('100%')
  }
}
