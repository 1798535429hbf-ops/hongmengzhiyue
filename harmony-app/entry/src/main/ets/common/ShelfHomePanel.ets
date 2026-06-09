import { ApiClient } from './ApiClient';
import { PlanItem, ReadingStats } from './Models';
import { openBookDetail, openReader, openSearch, openShelfManage } from './Navigation';
import { buildContinueItems, buildHistoryItems, formatReadingDuration, ShelfCardItem, ShelfTabMode } from './ShelfPresentation';
import { ShelfStore, ShelfStoreState } from './ShelfStore';
import { Theme } from './Theme';
import { UserSession } from './UserSession';
import { common } from '@kit.AbilityKit';
import cameraPicker from '@ohos.multimedia.cameraPicker';
import { picker } from '@kit.CoreFileKit';
import camera from '@ohos.multimedia.camera';

@Component
export struct ShelfHomePanel {
  @Prop pageWidth: number = 390;
  @Prop @Watch('onRefreshSeedChange') refreshSeed: number = 0;
  private lastRefreshSeed: number = 0;
  @StorageProp('shelf_manage_dirty_timestamp') @Watch('onRefreshSeedChange') shelfDirtyTs: number = 0;
  @StorageProp('smartread_session_user_id') @Watch('onSessionUserChange') sessionUserId: number = 0;
  @State shelfMode: ShelfTabMode = 'continue';
  @State shelfContinueItems: ShelfCardItem[] = [];
  @State shelfHistoryItems: ShelfCardItem[] = [];
  @State shelfVersion: number = 0;
  @State shelfBusyText: string = '';
  @State shelfErrorText: string = '';
  @State showShelfMenu: boolean = false;
  @State todayReadingLabel: string = '00:00:00';

  aboutToAppear(): void {
    this.lastRefreshSeed = this.refreshSeed;
    this.loadShelfData(true);
  }

  onPageShow(): void {
    this.loadShelfData(false);
  }

  onRefreshSeedChange(): void {
    this.loadShelfData(false);
  }

  onSessionUserChange(): void {
    this.loadShelfData(true);
  }

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  sectionGap(): number {
    return this.isCompact() ? 16 : 18;
  }

  shelfCoverWidth(): number {
    if (this.pageWidth >= 600) {
      return 98;
    }
    return this.isCompact() ? 80 : 90;
  }

  shelfCoverHeight(): number {
    return Math.floor(this.shelfCoverWidth() * 1.36);
  }

  continueCardHeight(): number {
    if (this.pageWidth >= 600) {
      return 224;
    }
    return this.isCompact() ? 208 : 216;
  }

  historyCardHeight(): number {
    if (this.pageWidth >= 600) {
      return 164;
    }
    return this.isCompact() ? 142 : 152;
  }

  emptyShelfHeight(): number {
    return this.isCompact() ? 132 : 140;
  }

  shelfPaneHeight(mode: ShelfTabMode): number {
    const itemCount: number = this.visibleShelfItems(mode).length;
    if (itemCount === 0) {
      return this.emptyShelfHeight();
    }
    const cardHeight: number = mode === 'continue' ? this.continueCardHeight() : this.historyCardHeight();
    return itemCount * cardHeight + (itemCount - 1) * this.sectionGap();
  }

  shelfModeIndex(): number {
    return this.shelfMode === 'continue' ? 0 : 1;
  }

  modeFromIndex(index: number): ShelfTabMode {
    return index === 1 ? 'history' : 'continue';
  }

  visibleShelfItems(mode: ShelfTabMode): ShelfCardItem[] {
    return mode === 'continue' ? this.shelfContinueItems : this.shelfHistoryItems;
  }

  updateShelfMode(mode: ShelfTabMode): void {
    this.shelfMode = mode;
    this.showShelfMenu = false;
  }

  async loadShelfData(showBusy: boolean = false): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法同步书架。';
      return;
    }
    if (showBusy) {
      this.shelfBusyText = '正在同步书架';
    }
    this.shelfErrorText = '';
    try {
      const userId: number = UserSession.currentUserId();
      const storeState: ShelfStoreState = await ShelfStore.load(context, userId);
      let plans: PlanItem[] = [];
      if (userId > 0) {
        try {
          plans = await ApiClient.listPlans(userId);
        } catch (apiErr) {
          this.shelfErrorText = `同步阅读计划失败：${apiErr}`;
        }
      }
      this.shelfContinueItems = buildContinueItems(storeState, plans);
      this.shelfHistoryItems = buildHistoryItems(storeState, plans);
      this.shelfVersion++;
      let todaySeconds: number = storeState.todayReading.seconds;
      if (userId > 0) {
        try {
          const stats: ReadingStats = await ApiClient.readingStats(userId);
          todaySeconds = Math.max(0, Math.round(stats.todaySeconds || 0));
          const weekSeconds: number = stats.dailySeconds.reduce((total: number, day) => {
            return total + Math.max(0, Math.round(day.seconds || 0));
          }, 0);
          AppStorage.setOrCreate('smartread_reading_stats_user_id', userId);
          AppStorage.setOrCreate('smartread_today_reading_seconds', todaySeconds);
          AppStorage.setOrCreate('smartread_week_reading_seconds', weekSeconds);
        } catch (_) {
        }
      }
      this.todayReadingLabel = formatReadingDuration(todaySeconds);
    } catch (err) {
      this.shelfErrorText = `书架加载失败：${err}`;
      this.shelfContinueItems = [];
      this.shelfHistoryItems = [];
      this.todayReadingLabel = '00:00:00';
    } finally {
      this.shelfBusyText = '';
    }
  }

  openCardDetail(item: ShelfCardItem, mode: ShelfTabMode): void {
    if (item.sourceType === 'remote' && item.remoteBookId) {
      if (mode === 'continue') {
        openReader(item.remoteBookId, item.chapterId || '');
      } else {
        openBookDetail(item.remoteBookId);
      }
      return;
    }
    if (item.sourceType === 'local' && item.localBookKey) {
      this.openLocalBook(item.localBookKey);
    }
  }

  openCardAction(item: ShelfCardItem, mode: ShelfTabMode): void {
    if (item.sourceType === 'remote' && item.remoteBookId) {
      if (mode === 'continue') {
        openReader(item.remoteBookId, item.chapterId || '');
      } else {
        openBookDetail(item.remoteBookId);
      }
      return;
    }
    if (item.sourceType === 'local' && item.localBookKey) {
      this.openLocalBook(item.localBookKey);
    }
  }

  async openLocalBook(bookKey: string): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法打开本地书籍。';
      return;
    }
    this.shelfBusyText = '正在打开本地书籍';
    this.shelfErrorText = '';
    try {
      const opened = await ShelfStore.openLocalBook(context, bookKey);
      await this.loadShelfData(false);
      if (opened.remoteBookId && opened.remoteBookId > 0) {
        this.shelfBusyText = '本地书籍已入库，正在进入阅读器';
        openReader(opened.remoteBookId);
      } else {
        this.shelfBusyText = '本地书籍已打开';
      }
    } catch (err) {
      this.shelfErrorText = `打开本地书籍失败：${err}`;
      this.shelfBusyText = '';
    }
  }

  async importLocalBooks(): Promise<void> {
    const context = this.hostContext();
    this.showShelfMenu = false;
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法导入本地书籍。';
      return;
    }
    this.shelfBusyText = '正在选择本地书籍';
    this.shelfErrorText = '';
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 10;
      options.fileSuffixFilters = ['可入库书籍|.epub,.txt,.md,.markdown'];
      const selectedUris: Array<string> = await documentPicker.select(options);
      if (!selectedUris || selectedUris.length === 0) {
        this.shelfBusyText = '';
        return;
      }
      this.shelfBusyText = '正在导入本地书籍';
      const result = await ShelfStore.importLocalBooks(context, selectedUris);
      await this.loadShelfData(false);
      if (result.imported.length > 0) {
        this.shelfBusyText = `已入库 ${result.imported.length} 本本地书，可搜索和 AI 推荐`;
      } else {
        this.shelfBusyText = '所选书籍已在书架中';
      }
    } catch (err) {
      this.shelfErrorText = `导入本地书籍失败：${err}`;
      this.shelfBusyText = '';
    }
  }

  async addHistoryItemToShelf(item: ShelfCardItem): Promise<void> {
    if (item.sourceType !== 'remote' || !item.remoteBookId || item.inShelf) {
      return;
    }
    const context = this.hostContext();
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法加入书架。';
      return;
    }
    this.shelfBusyText = '正在加入书架';
    this.shelfErrorText = '';
    try {
      await ShelfStore.restoreHistoryBookToShelf(context, item.key);
      await this.loadShelfData(false);
      this.shelfBusyText = '已加入书架';
    } catch (err) {
      this.shelfErrorText = `加入书架失败：${err}`;
      this.shelfBusyText = '';
    }
  }

  toggleShelfMenu(): void {
    this.showShelfMenu = !this.showShelfMenu;
  }

  async startScan(): Promise<void> {
    const context = this.hostContext();
    this.showShelfMenu = false;
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法启动扫一扫。';
      return;
    }
    this.shelfBusyText = '正在打开扫一扫';
    this.shelfErrorText = '';
    try {
      const keyword: string = await this.pickScanKeyword(context);
      if (!keyword) {
        this.shelfBusyText = '';
        this.shelfErrorText = '未识别到可用于搜索的 ISBN / 条码文本。';
        return;
      }
      this.shelfBusyText = '已获取扫码线索，正在搜索图书';
      openSearch(keyword);
    } catch (err) {
      this.shelfErrorText = `扫一扫失败：${err}`;
      this.shelfBusyText = '';
    }
  }

  async pickScanKeyword(context: common.UIAbilityContext): Promise<string> {
    try {
      const profile = new cameraPicker.PickerProfile();
      profile.cameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;
      const result = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], profile);
      const keyword: string = this.uriToKeyword(result.resultUri);
      if (keyword) {
        return keyword;
      }
    } catch (_) {
    }
    return await this.pickPhotoScanKeyword();
  }

  async startPhotoScan(): Promise<void> {
    const context = this.hostContext();
    this.showShelfMenu = false;
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法选择扫码图片。';
      return;
    }
    this.shelfBusyText = '正在选择扫码图片';
    this.shelfErrorText = '';
    try {
      const keyword: string = await this.pickPhotoScanKeyword();
      if (!keyword) {
        this.shelfBusyText = '';
        this.shelfErrorText = '未识别到可用于搜索的 ISBN / 条码文本。';
        return;
      }
      this.shelfBusyText = '已获取图片线索，正在搜索图书';
      openSearch(keyword);
    } catch (err) {
      this.shelfErrorText = `本地图片扫码失败：${err}`;
      this.shelfBusyText = '';
    }
  }

  async pickPhotoScanKeyword(): Promise<string> {
    const photoPicker = new picker.PhotoViewPicker();
    const options = new picker.PhotoSelectOptions();
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const result = await photoPicker.select(options);
    if (!result.photoUris || result.photoUris.length === 0) {
      return '';
    }
    return this.uriToKeyword(result.photoUris[0]);
  }
  uriToKeyword(uri: string): string {
    if (!uri) {
      return '';
    }
    const segments: string[] = uri.split('/');
    const fileName: string = segments.length > 0 ? segments[segments.length - 1] : uri;
    return fileName.replace(/\.[^.]+$/, '').replace(/[%_\-]+/g, ' ').trim();
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: this.sectionGap() }) {
        Column({ space: 14 }) {
          Stack({ alignContent: Alignment.TopEnd }) {
            Row({ space: 14 }) {
              Column({ space: 4 }) {
                Text('今日阅读时长')
                  .fontColor(Theme.mobileSubtext)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                Text(this.todayReadingLabel)
                  .fontColor(Theme.mobileText)
                  .fontSize(this.isCompact() ? 26 : 30)
                  .fontWeight(FontWeight.Bold)
                Text('书架')
                  .fontColor(Theme.mobileSubtext)
                  .fontSize(14)
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Row({ space: 8 }) {
                Stack() {
                  this.CircleActionButton($r('app.media.discover_search'))
                }
                .onClick(() => {
                  this.showShelfMenu = false;
                  openSearch();
                })

                Stack() {
                  this.CircleActionButton($r('app.media.mobile_more_circle'))
                }
                .onClick(() => this.toggleShelfMenu())
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }
          .width('100%')

          Row({ space: 24 }) {
            Column({ space: 6 }) {
              Text('继续阅读')
                .fontColor(this.shelfMode === 'continue' ? Theme.mobileText : Theme.mobileSubtext)
                .fontSize(16)
                .fontWeight(this.shelfMode === 'continue' ? FontWeight.Medium : FontWeight.Regular)
              if (this.shelfMode === 'continue') {
                Row()
                  .width(28).height(3).borderRadius(2).backgroundColor(Theme.mobileRed)
              }
            }
            .alignItems(HorizontalAlign.Center)
            .onClick(() => { this.updateShelfMode('continue'); })

            Column({ space: 6 }) {
              Text('浏览记录')
                .fontColor(this.shelfMode === 'history' ? Theme.mobileText : Theme.mobileSubtext)
                .fontSize(16)
                .fontWeight(this.shelfMode === 'history' ? FontWeight.Medium : FontWeight.Regular)
              if (this.shelfMode === 'history') {
                Row()
                  .width(28).height(3).borderRadius(2).backgroundColor(Theme.mobileRed)
              }
            }
            .alignItems(HorizontalAlign.Center)
            .onClick(() => { this.updateShelfMode('history'); })

            Blank()
            Button('管理')
              .height(38)
              .fontColor(Theme.mobileText)
              .backgroundColor(Theme.mobileSurface)
              .borderRadius(18)
              .padding({ left: 16, right: 16 })
              .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 6 })
              .onClick(() => {
                this.showShelfMenu = false;
                openShelfManage();
              })
          }
          .width('100%')
        }

        if (this.shelfBusyText) {
          this.StatusBanner(this.shelfBusyText, Theme.mobileBlue)
        }
        if (this.shelfErrorText) {
          this.StatusBanner(this.shelfErrorText, Theme.mobileRed)
        }

        this.ShelfSwipeContent()

        this.ImportCard()
      }
      .width('100%')

      if (this.showShelfMenu) {
        this.ShelfMenuOverlay()
      }
    }
    .width('100%')
  }

  @Builder
  ShelfMenuOverlay() {
    Column() {
      this.ShelfOverflowMenu()
    }
    .margin({ top: 50, right: 0 })
    .zIndex(20)
  }

  @Builder
  ShelfOverflowMenu() {
    Column({ space: 6 }) {
      Button('拍照扫码')
        .width(128)
        .height(40)
        .fontColor(Theme.mobileText)
        .backgroundColor(Theme.mobileSurface)
        .borderRadius(14)
        .onClick(() => {
          this.startScan();
        })
      Button('本地图片扫码')
        .width(128)
        .height(40)
        .fontColor(Theme.mobileText)
        .backgroundColor(Theme.mobileSurface)
        .borderRadius(14)
        .onClick(() => {
          this.startPhotoScan();
        })
      Button('导入本地书')
        .width(128)
        .height(40)
        .fontColor(Theme.mobileText)
        .backgroundColor(Theme.mobileSurface)
        .borderRadius(14)
        .onClick(() => {
          this.importLocalBooks();
        })
    }
    .padding(8)
    .backgroundColor(Theme.mobileSurface)
    .border({ width: 1, color: Theme.mobileLine })
    .borderRadius(18)
    .shadow({ radius: 20, color: '#18000000', offsetX: 0, offsetY: 12 })
  }

  @Builder
  ShelfSwipeContent() {
    Swiper() {
      this.ShelfPane('continue')
      this.ShelfPane('history')
    }
    .index(this.shelfModeIndex())
    .indicator(false)
    .loop(false)
    .duration(260)
    .width('100%')
    .height(this.shelfPaneHeight(this.shelfMode))
    .onChange((index: number) => {
      this.updateShelfMode(this.modeFromIndex(index));
    })
  }

  @Builder
  ShelfPane(mode: ShelfTabMode) {
    Column({ space: this.sectionGap() }) {
      if (this.visibleShelfItems(mode).length > 0) {
        ForEach(this.visibleShelfItems(mode), (item: ShelfCardItem) => {
          this.ShelfCard(item, mode)
        }, (item: ShelfCardItem) => `${mode}_${item.key}_v${this.shelfVersion}`)
      } else {
        this.EmptyShelfCard(mode)
      }
    }
    .width('100%')
  }

  @Builder
  ShelfCard(item: ShelfCardItem, mode: ShelfTabMode) {
    if (mode === 'continue') {
      this.ContinueCard(item, mode)
    } else {
      this.HistoryCard(item)
    }
  }

  @Builder
  ContinueCard(item: ShelfCardItem, mode: ShelfTabMode) {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        this.BookPlaceholder(this.shelfCoverWidth(), this.shelfCoverHeight(), item.coverTone)
        if (item.pinned) {
          Text('TOP')
            .fontColor(Theme.mobileSurface)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .backgroundColor(Theme.mobileRed)
            .borderRadius(12)
            .margin({ left: 8, top: 8 })
        }
      }
      .onClick(() => {
        this.openCardDetail(item, mode);
      })

      Column({ space: 10 }) {
        Row({ space: 12 }) {
          Column({ space: 8 }) {
            Text(item.title)
              .fontColor(Theme.mobileText)
              .fontSize(this.isCompact() ? 18 : 20)
              .fontWeight(FontWeight.Bold)
              .maxLines(2)
            Text(item.author)
              .fontColor(Theme.mobileSubtext)
              .fontSize(14)
              .maxLines(1)
            Row({ space: 8 }) {
              this.TagPill(item.tag, item.accent)
              Text(item.downloaded ? (item.sourceType === 'local' ? '已在本地' : '已下载') : '待下载')
                .fontColor(item.downloaded ? Theme.mobileGreen : Theme.mobileOrange)
                .fontSize(12)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor(item.downloaded ? '#ECFBF3' : '#FFF4E8')
                .borderRadius(12)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button(item.actionLabel)
            .height(34)
            .fontColor(Theme.mobileSurface)
            .backgroundColor(item.sourceType === 'local' ? Theme.mobileBlue : Theme.mobileRed)
            .borderRadius(14)
            .padding({ left: 14, right: 14 })
            .onClick(() => {
              this.openCardAction(item, mode);
            })
        }
        .width('100%')

        Row({ space: 8 }) {
          Text(item.progressText)
            .fontColor(item.accent)
            .fontSize(this.isCompact() ? 16 : 17)
            .fontWeight(FontWeight.Bold)
          this.ProgressBar(item.progress, item.accent)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(item.lastRead)
          .fontColor(Theme.mobileSubtext)
          .fontSize(14)
          .lineHeight(21)
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.openCardDetail(item, mode);
      })
    }
    .width('100%')
    .height(this.continueCardHeight())
    .padding(16)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(26)
    .shadow({ radius: 18, color: '#18000000', offsetX: 0, offsetY: 10 })
  }

  @Builder
  HistoryCard(item: ShelfCardItem) {
    Row({ space: 14 }) {
      this.BookPlaceholder(this.shelfCoverWidth(), this.shelfCoverHeight(), item.coverTone)

      Column({ space: 6 }) {
        Text(item.title)
          .fontColor(Theme.mobileText)
          .fontSize(this.isCompact() ? 17 : 19)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
        Text(item.lastRead)
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (item.inShelf) {
        Text('已在书架')
          .fontColor('#B0B0B0')
          .fontSize(13)
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor('#F5F5F5')
          .borderRadius(16)
      } else {
        Button('+ 书架')
          .height(34)
          .fontColor(Theme.mobileRed)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(Theme.mobileSurface)
          .border({ width: 1, color: Theme.mobileRed })
          .borderRadius(17)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.addHistoryItemToShelf(item);
          })
      }
    }
    .width('100%')
    .height(this.historyCardHeight())
    .padding(14)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(24)
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 4 })
    .onClick(() => {
      if (item.sourceType === 'remote' && item.remoteBookId) {
        openBookDetail(item.remoteBookId);
      }
    })
  }

  @Builder
  ImportCard() {
    Row({ space: 14 }) {
      Stack() {
        Circle()
          .width(48)
          .height(48)
          .fill('#FFF1F1')
        Image($r('app.media.mobile_import_book'))
          .width(24)
          .height(24)
      }
      Column({ space: 6 }) {
        Text('本地导入书籍')
          .fontColor(Theme.mobileText)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Text('支持 TXT / MD / EPUB 入库，搜索和 AI 都能使用')
          .fontColor(Theme.mobileSubtext)
          .fontSize(14)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Image($r('app.media.icon_chevron_right'))
        .width(16)
        .height(16)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(22)
    .shadow({ radius: 16, color: '#16000000', offsetX: 0, offsetY: 8 })
    .onClick(() => {
      this.importLocalBooks();
    })
  }

  @Builder
  EmptyShelfCard(mode: ShelfTabMode) {
    Column({ space: 10 }) {
      Text(mode === 'continue' ? '书架里还没有继续阅读内容' : '还没有浏览记录')
        .fontColor(Theme.mobileText)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
      Text(mode === 'continue' ? '从搜索页找书，或者导入本地 PDF 到书架。' : '打开图书详情页、阅读器或本地书籍后，痕迹会出现在这里。')
        .fontColor(Theme.mobileSubtext)
        .fontSize(14)
        .lineHeight(22)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(this.emptyShelfHeight())
    .padding({ left: 22, right: 22, top: 28, bottom: 28 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 18, color: '#14000000', offsetX: 0, offsetY: 8 })
  }

  @Builder
  StatusBanner(text: string, color: string) {
    Text(text)
      .fontColor(Theme.mobileSurface)
      .fontSize(13)
      .lineHeight(18)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(color)
      .borderRadius(16)
      .width('100%')
  }

  @Builder
  TagPill(text: string, color: string) {
    Text(text)
      .fontColor(color)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor('#F5F7FF')
      .borderRadius(12)
  }

  @Builder
  ProgressBar(progress: number, accent: string) {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width(88)
        .height(6)
        .backgroundColor('#EEF2FA')
        .borderRadius(Theme.radius.full)
      Row()
        .width(`${progress}%`)
        .height(6)
        .backgroundColor(accent)
        .borderRadius(Theme.radius.full)
    }
  }

  @Builder
  BookPlaceholder(widthValue: number, heightValue: number, tone: string) {
    Stack({ alignContent: Alignment.Center }) {
      Column() {}
        .width(widthValue)
        .height(heightValue)
        .backgroundColor(tone || '#EEF2FF')
        .borderRadius({ topLeft: 18, topRight: 18, bottomLeft: 12, bottomRight: 18 })
      Text('BOOK')
        .fontColor('#68708A')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
    }
  }

  @Builder
  CircleActionButton(icon: Resource) {
    Stack() {
      Circle()
        .width(42)
        .height(42)
        .fill(Theme.mobileSurface)
      Image(icon)
        .width(18)
        .height(18)
    }
    .width(42)
    .height(42)
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 6 })
  }
}
