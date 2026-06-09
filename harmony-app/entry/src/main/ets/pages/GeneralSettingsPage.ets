import {
  APP_AUTO_APPEARANCE_KEY,
  APP_DARK_MODE_KEY,
  APP_FONT_FAMILY_KEY,
  APP_ONE_HAND_MODE_KEY,
  APP_SCRIPT_VARIANT_KEY,
  APP_VOLUME_PAGE_TURN_KEY,
  AppSettings,
} from '../common/AppSettings';
import { goBack } from '../common/Navigation';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct GeneralSettingsPage {
  @State pageWidth: number = 390;
  @State refreshRotation: number = 0;
  @State refreshScale: number = 1;
  @State previewSeed: number = 0;
  @State toastText: string = '';
  @State showToast: boolean = false;
  @StorageLink(APP_DARK_MODE_KEY) darkMode: boolean = false;
  @StorageLink(APP_AUTO_APPEARANCE_KEY) autoAppearance: boolean = false;
  @StorageLink(APP_FONT_FAMILY_KEY) fontFamily: string = 'system';
  @StorageLink(APP_ONE_HAND_MODE_KEY) oneHandMode: boolean = false;
  @StorageLink(APP_SCRIPT_VARIANT_KEY) scriptVariant: string = 'simplified';
  @StorageLink(APP_VOLUME_PAGE_TURN_KEY) volumePageTurn: boolean = false;

  private feedbackTimer: number = -1;

  aboutToAppear(): void {
    AppSettings.ensureDefaults();
  }

  aboutToDisappear(): void {
    clearTimeout(this.feedbackTimer);
    this.feedbackTimer = -1;
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

  selectedBg(selected: boolean): string {
    if (selected) {
      return this.darkMode ? '#123255' : '#E8F2FF';
    }
    return this.fieldBg();
  }

  appFont(): string {
    return AppSettings.fontFamilyValue(this.fontFamily);
  }

  ui(text: string): string {
    return AppSettings.scriptText(text, this.scriptVariant);
  }

  fontName(): string {
    if (this.fontFamily === 'rounded') {
      return this.ui('HarmonyOS 圆润字体');
    }
    if (this.fontFamily === 'serif') {
      return this.ui('宋体阅读字体');
    }
    return this.ui('跟随系统字体');
  }

  scriptName(): string {
    return this.scriptVariant === 'traditional' ? this.ui('繁体中文') : '简体中文';
  }

  playRefreshFeedback(): void {
    this.previewSeed++;
    clearTimeout(this.feedbackTimer);
    animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
      this.refreshScale = 0.9;
      this.refreshRotation += 180;
    });
    this.feedbackTimer = setTimeout(() => {
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.refreshScale = 1;
        this.refreshRotation += 180;
      });
      this.feedbackTimer = -1;
    }, 130);
  }

  async refreshNow(): Promise<void> {
    this.playRefreshFeedback();
    this.flashToast(this.ui('设置已刷新'));
  }

  async toggleAutoAppearance(): Promise<void> {
    const next = !this.autoAppearance;
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.autoAppearance = next;
      if (next) {
        this.darkMode = AppSettings.autoDarkMode();
      }
    });
    this.playRefreshFeedback();
    await AppSettings.setAutoAppearance(this.hostContext(), next);
    this.flashToast(next ? this.ui('已随系统时间切换外观') : this.ui('已关闭自动外观'));
  }

  async setFont(value: string): Promise<void> {
    animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.fontFamily = value;
    });
    this.playRefreshFeedback();
    await AppSettings.setFontFamily(this.hostContext(), value);
    this.flashToast(this.ui('字体已应用'));
  }

  async setScript(value: string): Promise<void> {
    animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.scriptVariant = value === 'traditional' ? 'traditional' : 'simplified';
    });
    this.playRefreshFeedback();
    await AppSettings.setScriptVariant(this.hostContext(), value);
    this.flashToast(value === 'traditional' ? this.ui('已切换为繁体中文') : '已切换为简体中文');
  }

  async toggleOneHandMode(): Promise<void> {
    const next = !this.oneHandMode;
    animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.oneHandMode = next;
    });
    this.playRefreshFeedback();
    await AppSettings.setOneHandMode(this.hostContext(), next);
    this.flashToast(next ? this.ui('单手模式已开启') : this.ui('单手模式已关闭'));
  }

  async toggleVolumePageTurn(): Promise<void> {
    const next = !this.volumePageTurn;
    animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.volumePageTurn = next;
    });
    this.playRefreshFeedback();
    await AppSettings.setVolumePageTurn(this.hostContext(), next);
    this.flashToast(next ? this.ui('音量键翻页已开启') : this.ui('音量键翻页已关闭'));
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
            this.PreviewCard()
            this.AppearanceGroup()
            this.FontGroup()
            this.ReaderGroup()
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
      Text(this.ui('通用设置'))
        .fontColor(this.text())
        .fontSize(this.isCompact() ? 21 : 24)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('↻')
        .fontColor(this.accent())
        .fontSize(24)
        .width(52)
        .height(42)
        .textAlign(TextAlign.End)
        .rotate({ z: 1, angle: this.refreshRotation })
        .scale({ x: this.refreshScale, y: this.refreshScale })
        .onClick(() => this.refreshNow())
    }
    .width('100%')
    .height(92)
    .padding({ left: 12, right: 18, top: 24 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  PreviewCard() {
    Row({ space: 14 }) {
      Text('Aa')
        .fontColor(this.accent())
        .fontSize(34)
        .fontWeight(FontWeight.Medium)
        .width(58)
        .height(58)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.selectedBg(true))
        .borderRadius(18)
        .fontFamily(this.appFont())
      Column({ space: 5 }) {
        Text(this.ui('即时预览'))
          .fontColor(this.text())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Text(`${this.fontName()} · ${this.scriptName()}`)
          .fontColor(this.subtext())
          .fontSize(13)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.surface())
    .borderRadius(22)
  }

  @Builder
  AppearanceGroup() {
    Column() {
      this.SwitchRow(
        this.ui('日夜间随系统时间变化'),
        this.autoAppearance ? this.ui('夜间自动使用护眼深色 UI') : this.ui('关闭后可在阅读器手动切换'),
        this.autoAppearance,
        () => { this.toggleAutoAppearance(); }
      )
    }
    .width('100%')
    .padding({ left: 18, right: 16 })
    .backgroundColor(this.surface())
    .borderRadius(20)
  }

  @Builder
  FontGroup() {
    Column() {
      this.GroupTitle(this.ui('App 字体'))
      this.OptionRow(this.ui('跟随系统字体'), 'system', this.fontFamily === 'system', () => { this.setFont('system'); })
      Divider().height(0.5).color(this.line())
      this.OptionRow(this.ui('HarmonyOS 圆润字体'), 'rounded', this.fontFamily === 'rounded', () => { this.setFont('rounded'); })
      Divider().height(0.5).color(this.line())
      this.OptionRow(this.ui('宋体阅读字体'), 'serif', this.fontFamily === 'serif', () => { this.setFont('serif'); })
    }
    .width('100%')
    .padding({ left: 18, right: 16, top: 8, bottom: 6 })
    .backgroundColor(this.surface())
    .borderRadius(20)
  }

  @Builder
  ReaderGroup() {
    Column() {
      this.SwitchRow(this.ui('单手模式'), this.ui('阅读器翻页模式下点击左侧也会进入下一页'), this.oneHandMode, () => { this.toggleOneHandMode(); })
      Divider().height(0.5).color(this.line())
      this.SwitchRow(this.ui('音量键翻页'), this.ui('阅读器翻页模式下用音量键前后翻页'), this.volumePageTurn, () => { this.toggleVolumePageTurn(); })
      Divider().height(0.5).color(this.line())
      this.GroupTitle(this.ui('简繁体切换'))
      this.OptionRow('简体中文', 'simplified', this.scriptVariant === 'simplified', () => { this.setScript('simplified'); })
      Divider().height(0.5).color(this.line())
      this.OptionRow(this.ui('繁体中文'), 'traditional', this.scriptVariant === 'traditional', () => { this.setScript('traditional'); })
    }
    .width('100%')
    .padding({ left: 18, right: 16, top: 6, bottom: 6 })
    .backgroundColor(this.surface())
    .borderRadius(20)
  }

  @Builder
  GroupTitle(title: string) {
    Text(title)
      .fontColor(this.subtext())
      .fontSize(13)
      .width('100%')
      .padding({ top: 8, bottom: 8 })
  }

  @Builder
  SwitchRow(title: string, subtitle: string, value: boolean, action: () => void) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .fontColor(this.text())
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Text(subtitle)
          .fontColor(this.subtext())
          .fontSize(13)
          .lineHeight(18)
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Stack({ alignContent: value ? Alignment.End : Alignment.Start }) {
        Circle()
          .width(27)
          .height(27)
          .fill('#FFFFFF')
          .shadow({ radius: 5, color: '#22000000', offsetX: 0, offsetY: 1 })
          .margin({ left: 3, right: 3 })
      }
      .width(56)
      .height(33)
      .backgroundColor(value ? '#34C759' : (this.darkMode ? '#303746' : '#D9DDE5'))
      .borderRadius(17)
      .animation({ duration: 180, curve: Curve.EaseOut })
      .onClick(action)
    }
    .width('100%')
    .height(74)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  OptionRow(label: string, value: string, selected: boolean, action: () => void) {
    Row({ space: 12 }) {
      Text(label)
        .fontColor(this.text())
        .fontSize(16)
        .layoutWeight(1)
      Text(selected ? this.ui('已选') : '')
        .fontColor(this.accent())
        .fontSize(13)
      Column()
        .width(22)
        .height(22)
        .backgroundColor(this.selectedBg(selected))
        .border({ width: selected ? 6 : 1, color: selected ? this.accent() : this.line() })
        .borderRadius(11)
        .animation({ duration: 160, curve: Curve.EaseOut })
    }
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }
}
