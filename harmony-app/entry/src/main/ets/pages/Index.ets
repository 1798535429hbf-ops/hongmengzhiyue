import { ShelfHomePanel } from '../common/ShelfHomePanel';
import { Theme } from '../common/Theme';
import { StoreContent } from './StoreContent';
import { CategoryContent } from './CategoryContent';
import { DiscoverContent } from './DiscoverContent';
import { ProfileContent } from './ProfileContent';

@Entry
@Component
struct Index {
  @State activeTab: number = 0;
  @State pageWidth: number = 390;
  @State shelfRefreshSeed: number = 0;

  aboutToAppear(): void {
    this.shelfRefreshSeed++;
  }

  onPageShow(): void {
    this.shelfRefreshSeed++;
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
      return active ? $r('app.media.mobile_tab_discover_active') : $r('app.media.mobile_tab_discover');
    }
    return active ? $r('app.media.mobile_tab_me_active') : $r('app.media.mobile_tab_me');
  }

  build() {
    Column() {
      Scroll() {
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

      this.BottomTabs()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.mobileCanvas)
    .onAreaChange((_, area) => {
      const nextWidth: number = typeof area.width === 'number' ? area.width : Number(area.width);
      if (Number.isFinite(nextWidth) && nextWidth > 0) {
        this.pageWidth = nextWidth;
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
      DiscoverContent({ pageWidth: this.pageWidth })
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
      this.BottomTabItem(3, '发现')
      this.BottomTabItem(4, '我的')
    }
    .width('100%')
    .padding({
      left: this.isCompact() ? 10 : 12,
      right: this.isCompact() ? 10 : 12,
      top: 10,
      bottom: this.isCompact() ? 10 : 14,
    })
    .backgroundColor(Theme.mobileSurface)
    .border({ width: 1, color: '#EFF1F5' })
  }

  @Builder
  BottomTabItem(index: number, label: string) {
    Column({ space: 6 }) {
      Image(this.tabIcon(index))
        .width(26)
        .height(26)
      Text(label)
        .fontColor(this.activeTab === index ? this.tabAccent(index) : '#9197AA')
        .fontSize(12)
        .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Regular)
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.activeTab = index;
      if (index === 0) {
        this.shelfRefreshSeed++;
      }
    })
  }
}
