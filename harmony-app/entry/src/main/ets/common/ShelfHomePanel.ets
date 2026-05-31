import { ApiClient } from './ApiClient';
import { PlanItem } from './Models';
import { openBookDetail, openReader, openSearch, openShelfManage } from './Navigation';
import { buildContinueItems, buildHistoryItems, formatReadingDuration, ShelfCardItem, ShelfTabMode } from './ShelfPresentation';
import { ShelfStore, ShelfStoreState } from './ShelfStore';
import { Theme } from './Theme';
import { common } from '@kit.AbilityKit';
import cameraPicker from '@ohos.multimedia.cameraPicker';
import { picker } from '@kit.CoreFileKit';
import camera from '@ohos.multimedia.camera';

const USER_ID: number = 10086;

@Component
export struct ShelfHomePanel {
  @Prop pageWidth: number = 390;
  @Prop @Watch('onRefreshSeedChange') refreshSeed: number = 0;
  private lastRefreshSeed: number = 0;
  @StorageProp('shelf_manage_dirty_timestamp') @Watch('onRefreshSeedChange') shelfDirtyTs: number = 0;
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

  visibleShelfItems(): ShelfCardItem[] {
    return this.shelfMode === 'continue' ? this.shelfContinueItems : this.shelfHistoryItems;
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
      const storeState: ShelfStoreState = await ShelfStore.load(context);
      let plans: PlanItem[] = [];
      try {
        plans = await ApiClient.listPlans(USER_ID);
      } catch (apiErr) {
        this.shelfErrorText = `同步阅读计划失败：${apiErr}`;
      }
      this.shelfContinueItems = buildContinueItems(storeState, plans);
      this.shelfHistoryItems = buildHistoryItems(storeState, plans);
      this.shelfVersion++;
      this.todayReadingLabel = formatReadingDuration(storeState.todayReading.seconds);
    } catch (err) {
      this.shelfErrorText = `书架加载失败：${err}`;
      this.shelfContinueItems = [];
      this.shelfHistoryItems = [];
      this.todayReadingLabel = '00:00:00';
    } finally {
      this.shelfBusyText = '';
    }
  }

  openCardDetail(item: ShelfCardItem): void {
    if (item.sourceType === 'remote' && item.remoteBookId) {
      if (this.shelfMode === 'continue') {
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

  openCardAction(item: ShelfCardItem): void {
    if (item.sourceType === 'remote' && item.remoteBookId) {
      if (this.shelfMode === 'continue') {
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
      await ShelfStore.openLocalBook(context, bookKey);
      await this.loadShelfData(false);
      this.shelfBusyText = '本地书籍已打开';
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
      options.fileSuffixFilters = ['书籍|.pdf,.epub,.txt,.md,.markdown,.doc,.docx'];
      const selectedUris: Array<string> = await documentPicker.select(options);
      if (!selectedUris || selectedUris.length === 0) {
        this.shelfBusyText = '';
        return;
      }
      this.shelfBusyText = '正在导入本地书籍';
      const result = await ShelfStore.importLocalBooks(context, selectedUris);
      await this.loadShelfData(false);
      if (result.imported.length > 0) {
        this.shelfBusyText = `已导入 ${result.imported.length} 本本地书`;
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

          if (this.showShelfMenu) {
            Column() {
              this.ShelfOverflowMenu()
            }
            .margin({ top: 50, right: 0 })
            .zIndex(10)
          }
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

      if (this.visibleShelfItems().length > 0) {
        ForEach(this.visibleShelfItems(), (item: ShelfCardItem) => {
          this.ShelfCard(item)
        }, (item: ShelfCardItem) => `${item.key}_v${this.shelfVersion}`)
      } else {
        this.EmptyShelfCard()
      }

      this.ImportCard()
    }
    .width('100%')
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
    .backgroundColor('#FFF9F4')
    .borderRadius(18)
    .shadow({ radius: 20, color: '#18000000', offsetX: 0, offsetY: 12 })
  }

  @Builder
  ShelfCard(item: ShelfCardItem) {
    if (this.shelfMode === 'continue') {
      this.ContinueCard(item)
    } else {
      this.HistoryCard(item)
    }
  }

  @Builder
  ContinueCard(item: ShelfCardItem) {
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
        this.openCardDetail(item);
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
              this.openCardAction(item);
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
        this.openCardDetail(item);
      })
    }
    .width('100%')
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
        Text('支持 PDF / EPUB / TXT / DOC 等格式')
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
  EmptyShelfCard() {
    Column({ space: 10 }) {
      Text(this.shelfMode === 'continue' ? '书架里还没有继续阅读内容' : '还没有浏览记录')
        .fontColor(Theme.mobileText)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
      Text(this.shelfMode === 'continue' ? '从搜索页找书，或者导入本地 PDF 到书架。' : '打开图书详情页、阅读器或本地书籍后，痕迹会出现在这里。')
        .fontColor(Theme.mobileSubtext)
        .fontSize(14)
        .lineHeight(22)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
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
