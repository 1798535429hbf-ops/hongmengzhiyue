import { goBack } from '../common/Navigation';
import { Theme } from '../common/Theme';
import { UserSession } from '../common/UserSession';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct LoginPage {
  @State pageWidth: number = 390;
  @State pageHeight: number = 780;
  @State phone: string = '';
  @State password: string = '';
  @State authMode: string = 'phone';
  @State busyText: string = '';
  @State errorText: string = '';

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  isWide(): boolean {
    return this.pageWidth >= 720;
  }

  isCompact(): boolean {
    return this.pageWidth < 360 || this.pageHeight < 680;
  }

  pagePadding(): number {
    if (this.pageWidth >= 1000) {
      return 48;
    }
    if (this.pageWidth >= 720) {
      return 34;
    }
    return this.isCompact() ? 18 : 24;
  }

  formMaxWidth(): number {
    if (this.pageWidth >= 1000) {
      return 460;
    }
    if (this.pageWidth >= 720) {
      return 430;
    }
    return 640;
  }

  heroHeight(): number {
    if (this.isWide()) {
      return Math.max(500, this.pageHeight - 120);
    }
    const ratioHeight = Math.floor(this.pageHeight * (this.isCompact() ? 0.49 : 0.56));
    return Math.max(this.isCompact() ? 280 : 360, Math.min(ratioHeight, 520));
  }

  normalizedPhone(): string {
    return this.phone.replace(/\D/g, '');
  }

  validateInputs(): boolean {
    if (!/^1\d{10}$/.test(this.normalizedPhone())) {
      this.errorText = '请输入 11 位中国大陆手机号。';
      return false;
    }
    if (this.password.length < 6) {
      this.errorText = '请输入至少 6 位密码。';
      return false;
    }
    return true;
  }

  async phoneLogin(): Promise<void> {
    if (!this.validateInputs()) {
      return;
    }
    const context = this.hostContext();
    if (!context) {
      this.errorText = '当前页面上下文不可用，无法登录。';
      return;
    }
    this.busyText = '正在登录';
    this.errorText = '';
    try {
      await UserSession.loginWithPhone(context, this.normalizedPhone(), this.password);
      this.busyText = '登录成功';
      goBack();
    } catch (err) {
      this.errorText = `登录失败：${err}`;
      this.busyText = '';
    }
  }

  async registerWithPhone(): Promise<void> {
    if (!this.validateInputs()) {
      return;
    }
    const context = this.hostContext();
    if (!context) {
      this.errorText = '当前页面上下文不可用，无法注册。';
      return;
    }
    this.busyText = '正在注册并写入数据库';
    this.errorText = '';
    try {
      await UserSession.registerWithPhone(context, this.normalizedPhone(), this.password);
      this.busyText = '注册成功';
      goBack();
    } catch (err) {
      this.errorText = `注册失败：${err}`;
      this.busyText = '';
    }
  }

  async providerLogin(provider: string): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      this.errorText = '当前页面上下文不可用，无法登录。';
      return;
    }
    this.busyText = provider === 'wechat' ? '正在通过微信登录' : '正在通过 QQ 登录';
    this.errorText = '';
    try {
      await UserSession.loginWithProvider(context, provider);
      this.busyText = '登录成功';
      goBack();
    } catch (err) {
      this.errorText = `登录失败：${err}`;
      this.busyText = '';
    }
  }

  resetStatus(): void {
    this.errorText = '';
    this.busyText = '';
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.Background()

      Scroll() {
        Column() {
          this.TopBar()
          if (this.isWide()) {
            Row({ space: 34 }) {
              this.BrandStage()
              this.AuthPanel()
            }
            .width('100%')
            .layoutWeight(1)
            .alignItems(VerticalAlign.Center)
          } else {
            Column() {
              this.BrandStage()
              this.AuthPanel()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .constraintSize({ minHeight: this.pageHeight })
        .padding({
          left: this.pagePadding(),
          right: this.pagePadding(),
          top: this.isCompact() ? 20 : 28,
          bottom: this.isCompact() ? 24 : 34,
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#405A88')
    .onAreaChange((_, area) => {
      const nextWidth: number = typeof area.width === 'number' ? area.width : Number(area.width);
      const nextHeight: number = typeof area.height === 'number' ? area.height : Number(area.height);
      if (Number.isFinite(nextWidth) && nextWidth > 0) { this.pageWidth = nextWidth; }
      if (Number.isFinite(nextHeight) && nextHeight > 0) { this.pageHeight = nextHeight; }
    })
  }

  @Builder
  Background() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {}
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#FFF8CF', 0], ['#EECFC8', 0.36], ['#7380B4', 0.64], ['#3E5684', 1]],
        })
      Circle()
        .width(280)
        .height(280)
        .fill('rgba(255,255,255,0.24)')
        .position({ x: this.pageWidth * 0.68, y: 58 })
      Circle()
        .width(210)
        .height(210)
        .fill('rgba(255,255,255,0.14)')
        .position({ x: this.pageWidth * -0.12, y: 150 })
      Circle()
        .width(12)
        .height(12)
        .fill('#D54852')
        .position({ x: this.pageWidth * 0.79, y: 122 })
      Circle()
        .width(8)
        .height(8)
        .fill('#D54852')
        .position({ x: this.pageWidth * 0.62, y: 244 })
      Row()
        .width('100%')
        .height('45%')
        .linearGradient({ angle: 180, colors: [['rgba(255,255,255,0)', 0], ['rgba(52,75,118,0.76)', 1]] })
        .position({ x: 0, y: this.pageHeight * 0.47 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TopBar() {
    Row() {
      Text('×')
        .fontColor('#0E1420')
        .fontSize(42)
        .fontWeight(FontWeight.Regular)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .onClick(() => goBack())
      Blank()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  BrandStage() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(this.isWide() ? 520 : 330)
        .height(this.isWide() ? 520 : 330)
        .fill('rgba(255,255,255,0.12)')
        .translate({ x: this.isWide() ? -70 : -52, y: this.isWide() ? 0 : -6 })
      Circle()
        .width(this.isWide() ? 420 : 260)
        .height(this.isWide() ? 420 : 260)
        .fill('rgba(255,255,255,0.10)')
        .translate({ x: this.isWide() ? 170 : 118, y: this.isWide() ? -120 : -86 })

      Column()
        .width(this.isWide() ? 500 : 340)
        .height(this.isWide() ? 190 : 124)
        .backgroundColor('rgba(255,255,255,0.42)')
        .borderRadius(38)
        .translate({ x: this.isWide() ? -54 : -38, y: this.isWide() ? 52 : 28 })
        .rotate({ angle: -7 })

      Column()
        .width(this.isWide() ? 420 : 280)
        .height(this.isWide() ? 82 : 54)
        .backgroundColor('rgba(255,255,255,0.78)')
        .borderRadius(24)
        .translate({ x: this.isWide() ? -26 : -18, y: this.isWide() ? 42 : 26 })
        .rotate({ angle: -7 })

      Column()
        .width(this.isWide() ? 250 : 160)
        .height(this.isWide() ? 76 : 48)
        .backgroundColor('rgba(255,255,255,0.82)')
        .borderRadius(20)
        .translate({ x: this.isWide() ? 222 : 150, y: this.isWide() ? 14 : 8 })
        .rotate({ angle: -7 })

      Column()
        .width(this.isWide() ? 430 : 286)
        .height(this.isWide() ? 76 : 50)
        .backgroundColor('rgba(255,255,255,0.72)')
        .borderRadius(24)
        .translate({ x: this.isWide() ? 112 : 76, y: this.isWide() ? 114 : 80 })
        .rotate({ angle: -7 })

      Text('智')
        .fontColor('#B9474F')
        .fontSize(this.isWide() ? 26 : 18)
        .fontWeight(FontWeight.Bold)
        .width(this.isWide() ? 42 : 30)
        .height(this.isWide() ? 68 : 48)
        .textAlign(TextAlign.Center)
        .translate({ x: this.isWide() ? -40 : -28, y: this.isWide() ? 112 : 76 })
        .rotate({ angle: -12 })
      Text('阅')
        .fontColor('#2E3443')
        .fontSize(this.isWide() ? 20 : 14)
        .fontWeight(FontWeight.Medium)
        .width(this.isWide() ? 38 : 28)
        .height(this.isWide() ? 54 : 38)
        .textAlign(TextAlign.Center)
        .translate({ x: this.isWide() ? 120 : 82, y: this.isWide() ? -22 : -12 })
    }
    .width(this.isWide() ? '56%' : '100%')
    .height(this.heroHeight())
  }

  @Builder
  AuthPanel() {
    Column({ space: this.isCompact() ? 14 : 18 }) {
      if (this.errorText) { this.StatusBanner(this.errorText, Theme.mobileRed) }
      if (this.busyText) { this.StatusBanner(this.busyText, Theme.mobileBlue) }

      this.PhoneInput()
      this.PasswordInput()

      Button(this.authMode === 'register' ? '注册' : '登录')
        .width('100%')
        .height(this.isCompact() ? 58 : 66)
        .fontColor('#D0A9AF')
        .fontSize(this.isCompact() ? 20 : 22)
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#A20718')
        .borderRadius(this.isCompact() ? 29 : 33)
        .onClick(() => {
          if (this.authMode === 'register') {
            this.registerWithPhone();
          } else {
            this.phoneLogin();
          }
        })

      if (this.authMode === 'phone') {
        Button('注册')
          .width('100%')
          .height(this.isCompact() ? 48 : 54)
          .fontColor('#FFFFFF')
          .fontSize(17)
          .backgroundColor('rgba(255,255,255,0.12)')
          .border({ width: 1, color: 'rgba(255,255,255,0.38)' })
          .borderRadius(this.isCompact() ? 24 : 27)
          .onClick(() => {
            this.authMode = 'register';
            this.resetStatus();
          })
      } else {
        Row({ space: 8 }) {
          Text('已有账号')
            .fontColor('rgba(255,255,255,0.74)')
            .fontSize(15)
          Text('去登录')
            .fontColor('#FFFFFF')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .height(40)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.authMode = 'phone';
          this.resetStatus();
        })
      }

      this.SocialLoginRow()
      this.AgreementRow()
    }
    .width(this.isWide() ? this.formMaxWidth() : '100%')
    .constraintSize({ maxWidth: this.formMaxWidth() })
    .padding({
      left: this.isWide() ? 4 : 0,
      right: this.isWide() ? 4 : 0,
      top: this.isWide() ? 26 : 0,
      bottom: this.isWide() ? 22 : 0,
    })
  }

  @Builder
  PhoneInput() {
    Row({ space: this.isCompact() ? 10 : 14 }) {
      Text('▯')
        .fontColor('#C9C9C9')
        .fontSize(28)
        .width(34)
        .textAlign(TextAlign.Center)
      Text('+86')
        .fontColor('#121821')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text('⌄')
        .fontColor('#1C2230')
        .fontSize(18)
        .width(20)
        .textAlign(TextAlign.Center)
      TextInput({ placeholder: '请输入手机号', text: this.phone })
        .layoutWeight(1)
        .height(52)
        .fontColor('#222831')
        .fontSize(this.isCompact() ? 18 : 21)
        .placeholderColor('#B6BAC2')
        .backgroundColor('transparent')
        .padding({ left: 0, right: 0 })
        .onChange((value: string) => { this.phone = value; })
    }
    .width('100%')
    .height(this.isCompact() ? 62 : 72)
    .padding({ left: this.isCompact() ? 18 : 24, right: this.isCompact() ? 16 : 22 })
    .backgroundColor('#FFFFFF')
    .borderRadius(this.isCompact() ? 31 : 36)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  PasswordInput() {
    Row({ space: this.isCompact() ? 10 : 14 }) {
      Text('123')
        .fontColor('#D5D5D5')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .width(44)
        .textAlign(TextAlign.Center)
      TextInput({ placeholder: this.authMode === 'register' ? '请输入注册密码' : '请输入密码', text: this.password })
        .type(InputType.Password)
        .layoutWeight(1)
        .height(52)
        .fontColor('#222831')
        .fontSize(this.isCompact() ? 18 : 21)
        .placeholderColor('#B6BAC2')
        .backgroundColor('transparent')
        .padding({ left: 0, right: 0 })
        .onChange((value: string) => { this.password = value; })
    }
    .width('100%')
    .height(this.isCompact() ? 62 : 72)
    .padding({ left: this.isCompact() ? 18 : 24, right: this.isCompact() ? 16 : 22 })
    .backgroundColor('#FFFFFF')
    .borderRadius(this.isCompact() ? 31 : 36)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SocialLoginRow() {
    Row() {
      this.SocialCircle('微信', '微', 'wechat', false)
      this.SocialCircle('QQ', 'Q', 'qq', true)
      this.SocialCircle('更多', '...', 'more', false)
    }
    .width('100%')
    .padding({
      left: this.isCompact() ? 34 : 46,
      right: this.isCompact() ? 34 : 46,
      top: this.isCompact() ? 10 : 18,
      bottom: 6,
    })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SocialCircle(label: string, icon: string, action: string, lastUsed: boolean) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 8 }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(this.isCompact() ? 66 : 76)
            .height(this.isCompact() ? 66 : 76)
            .fill('rgba(255,255,255,0.06)')
            .stroke('rgba(255,255,255,0.74)')
            .strokeWidth(1)
          Text(icon)
            .fontColor('#FFFFFF')
            .fontSize(action === 'more' ? 24 : 26)
            .fontWeight(FontWeight.Bold)
        }
        Text(label)
          .fontColor('rgba(255,255,255,0.0)')
          .fontSize(1)
      }
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        if (action === 'more') {
          this.errorText = '';
          this.busyText = '更多登录方式待接入';
        } else {
          this.providerLogin(action);
        }
      })

      if (lastUsed) {
        Text('上次登录')
          .fontColor('#FFFFFF')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .backgroundColor('#F04B2F')
          .borderRadius(8)
          .translate({ x: 17, y: -8 })
      }
    }
    .width(this.isCompact() ? 76 : 88)
    .height(this.isCompact() ? 82 : 94)
  }

  @Builder
  AgreementRow() {
    Row({ space: 12 }) {
      Text('✓')
        .fontColor('#FFFFFF')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .width(22)
        .height(22)
        .textAlign(TextAlign.Center)
        .backgroundColor('#E02C3D')
        .borderRadius(11)
      Text('我已阅读并同意《用户服务协议》及《隐私协议》，注册后将写入数据库，书架、计划、笔记和问答记录按当前登录身份隔离')
        .fontColor('rgba(255,255,255,0.82)')
        .fontSize(this.isCompact() ? 13 : 15)
        .lineHeight(this.isCompact() ? 22 : 25)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 4, right: 4, top: this.isCompact() ? 2 : 8 })
  }

  @Builder
  StatusBanner(text: string, color: string) {
    Text(text)
      .fontColor('#FFFFFF')
      .fontSize(13)
      .lineHeight(18)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(color)
      .borderRadius(18)
      .width('100%')
  }
}
