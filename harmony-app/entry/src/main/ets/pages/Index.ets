import { ShelfHomePanel } from '../common/ShelfHomePanel';
import { APP_DARK_MODE_KEY, APP_FONT_FAMILY_KEY, AppSettings } from '../common/AppSettings';
import { Theme } from '../common/Theme';
import { StoreContent } from './StoreContent';
import { CategoryContent } from './CategoryContent';
import { PlanContent } from './PlanContent';
import { ProfileContent } from './ProfileContent';
import { UserSession } from '../common/UserSession';
import { PLAN_DATA_REFRESH_KEY } from '../common/Navigation';
import { common } from '@kit.AbilityKit';
import { SplashScreen } from '../common/SplashScreen';
import { setCurrentWindowSplashMode } from '../common/WindowMode';

@Entry
@Component
struct Index {
  @StorageLink('smartread_active_tab') activeTab: number = 0;
  @State pageWidth: number = 390;
  @State pageHeight: number = 780;
  @State showLaunchSplash: boolean = true;
  @State shelfRefreshSeed: number = 0;
  @State planRefreshSeed: number = 0;
  @State pageScrollOffset: number = 0;
  @StorageProp('smartread_session_user_id') @Watch('onSessionUserChange') sessionUserId: number = 0;
  @StorageLink(PLAN_DATA_REFRESH_KEY) @Watch('onPlanDataRefreshSignalChange') planDataRefreshSignal: number = 0;
  @StorageLink(APP_DARK_MODE_KEY) darkMode: boolean = false;
  @StorageLink(APP_FONT_FAMILY_KEY) fontFamily: string = 'system';
  private mainScroller: Scroller = new Scroller();
  private launchSplashTimer: number = -1;
  private launchSplashDuration: number = 1200;

  aboutToAppear(): void {
    AppSettings.ensureDefaults();
    this.enterLaunchSplashMode();
    this.scheduleLaunchSplashExit();
    this.bootstrapAppSettings();
    this.bootstrapSession();
    this.shelfRefreshSeed++;
    this.planRefreshSeed++;
  }

  aboutToDisappear(): void {
    this.clearLaunchSplashTimer();
    if (this.showLaunchSplash) {
      this.finishLaunchSplash();
    }
  }

  onPageShow(): void {
    this.shelfRefreshSeed++;
    this.planRefreshSeed++;
  }

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  async bootstrapSession(): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      return;
    }
    await UserSession.bootstrap(context);
    this.shelfRefreshSeed++;
    this.planRefreshSeed++;
  }

  async bootstrapAppSettings(): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      return;
    }
    await AppSettings.bootstrap(context);
  }

  async enterLaunchSplashMode(): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      return;
    }
    await setCurrentWindowSplashMode(context, true);
  }

  scheduleLaunchSplashExit(): void {
    this.clearLaunchSplashTimer();
    this.launchSplashTimer = setTimeout(() => {
      this.finishLaunchSplash();
    }, this.launchSplashDuration);
  }

  clearLaunchSplashTimer(): void {
    if (this.launchSplashTimer >= 0) {
      clearTimeout(this.launchSplashTimer);
      this.launchSplashTimer = -1;
    }
  }

  async finishLaunchSplash(): Promise<void> {
    if (!this.showLaunchSplash) {
      return;
    }
    this.clearLaunchSplashTimer();
    const context = this.hostContext();
    if (context) {
      await setCurrentWindowSplashMode(context, false);
    }
    this.showLaunchSplash = false;
  }

  onSessionUserChange(): void {
    this.shelfRefreshSeed++;
    this.planRefreshSeed++;
  }

  onPlanDataRefreshSignalChange(): void {
    this.shelfRefreshSeed++;
    this.planRefreshSeed++;
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  isTabletLike(): boolean {
    return this.pageWidth >= 600;
  }

  pagePadding(): number {
    if (this.pageWidth >= 900) {
      return 32;
    }
    if (this.isTabletLike()) {
      return 24;
    }
    if (this.isCompact()) {
      return 14;
    }
    return 16;
  }

  pageTopPadding(): number {
    if (this.activeTab === 0) {
      return this.isCompact() ? 6 : 8;
    }
    if (this.pageWidth >= 900) {
      return 22;
    }
    if (this.isTabletLike()) {
      return 18;
    }
    return 12;
  }

  pageBottomPadding(): number {
    return this.isCompact() ? 20 : 28;
  }

  contentMaxWidth(): number {
    if (this.activeTab === 4) {
      if (this.pageWidth >= 1100) {
        return 1160;
      }
      if (this.pageWidth >= 900) {
        return 1040;
      }
      if (this.isTabletLike()) {
        return 900;
      }
      return 640;
    }
    if (this.pageWidth >= 900) {
      return 760;
    }
    if (this.isTabletLike()) {
      return 660;
    }
    return 640;
  }

  tabAccent(index: number): string {
    if (index === 0 || index === 4) {
      return Theme.mobileRed;
    }
    if (index === 3) {
      return Theme.mobileGreen;
    }
    return Theme.mobileBlue;
  }

  tabIcon(index: number): Resource {
    const active: boolean = this.activeTab === index;
    if (index === 0) {
      return active ? $r('app.media.mobile_tab_shelf_active') : $r('app.media.mobile_tab_shelf');
    }
    if (index === 1) {
      return active ? $r('app.media.mobile_tab_store_active') : $r('app.media.mobile_tab_store');
    }
    if (index === 2) {
      return active ? $r('app.media.mobile_tab_category_active') : $r('app.media.mobile_tab_category');
    }
    if (index === 3) {
      return active ? $r('app.media.mobile_tab_plan_active') : $r('app.media.mobile_tab_plan');
    }
    return active ? $r('app.media.mobile_tab_me_active') : $r('app.media.mobile_tab_me');
  }

  pageBg(): string {
    return this.darkMode ? '#0F1218' : Theme.mobileCanvas;
  }

  tabBg(): string {
    return this.darkMode ? '#171B24' : Theme.mobileSurface;
  }

  tabBorder(): string {
    return this.darkMode ? '#293040' : '#EFF1F5';
  }

  tabInactiveColor(): string {
    return this.darkMode ? '#8E97AA' : '#9197AA';
  }

  appFont(): string {
    return AppSettings.fontFamilyValue(this.fontFamily);
  }

  resetMainScroll(): void {
    this.pageScrollOffset = 0;
    try {
      this.mainScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    } catch (_) {
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        if (this.activeTab === 3) {
          Column() {
            this.ActivePage()
          }
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .constraintSize({ maxWidth: this.contentMaxWidth() })
          .padding({
            left: this.pagePadding(),
            right: this.pagePadding(),
            top: this.pageTopPadding(),
            bottom: this.pageBottomPadding(),
          })
        } else {
          Scroll(this.mainScroller) {
            Column() {
              Column() {
                this.ActivePage()
              }
              .width('100%')
              .constraintSize({ maxWidth: this.contentMaxWidth() })
              .padding({
                left: this.pagePadding(),
                right: this.pagePadding(),
                top: this.pageTopPadding(),
                bottom: this.pageBottomPadding(),
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .layoutWeight(1)
          .onScroll((_xOffset: number, yOffset: number) => {
            this.pageScrollOffset = Math.max(0, Math.round(yOffset || 0));
          })
        }

        this.BottomTabs()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBg())
      .animation({ duration: 320, curve: Curve.EaseInOut })

      if (this.showLaunchSplash) {
        SplashScreen({ pageWidth: this.pageWidth, pageHeight: this.pageHeight })
          .zIndex(10)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBg())
    .onAreaChange((_: Area, area: Area) => {
      const nextWidth: number = typeof area.width === 'number' ? area.width : Number(area.width);
      if (Number.isFinite(nextWidth) && nextWidth > 0) {
        this.pageWidth = nextWidth;
      }
      const nextHeight: number = typeof area.height === 'number' ? area.height : Number(area.height);
      if (Number.isFinite(nextHeight) && nextHeight > 0) {
        this.pageHeight = nextHeight;
      }
    })
  }

  @Builder
  ActivePage() {
    if (this.activeTab === 0) {
      ShelfHomePanel({
        pageWidth: this.pageWidth,
        refreshSeed: this.shelfRefreshSeed,
      })
    } else if (this.activeTab === 1) {
      StoreContent({ pageWidth: this.pageWidth })
    } else if (this.activeTab === 2) {
      CategoryContent({ pageWidth: this.pageWidth })
    } else if (this.activeTab === 3) {
      PlanContent({
        pageWidth: this.pageWidth,
        refreshSeed: this.planRefreshSeed,
      })
    } else {
      ProfileContent({ pageWidth: this.pageWidth })
    }
  }

  @Builder
  BottomTabs() {
    Row() {
      this.BottomTabItem(0, '书架')
      this.BottomTabItem(1, '书城')
      this.BottomTabItem(2, '分类')
      this.BottomTabItem(3, '计划')
      this.BottomTabItem(4, '我的')
    }
    .width('100%')
    .padding({
      left: this.isCompact() ? 10 : 12,
      right: this.isCompact() ? 10 : 12,
      top: 10,
      bottom: this.isCompact() ? 10 : 14,
    })
    .backgroundColor(this.tabBg())
    .border({ width: 1, color: this.tabBorder() })
  }

  @Builder
  BottomTabItem(index: number, label: string) {
    Column({ space: 6 }) {
      Image(this.tabIcon(index))
        .width(26)
        .height(26)
      Text(label)
        .fontColor(this.activeTab === index ? this.tabAccent(index) : this.tabInactiveColor())
        .fontSize(12)
        .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Regular)
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (this.activeTab !== index) {
        this.resetMainScroll();
      }
      this.activeTab = index;
      if (index === 0) {
        this.shelfRefreshSeed++;
      }
      if (index === 3) {
        this.planRefreshSeed++;
      }
    })
  }
}
