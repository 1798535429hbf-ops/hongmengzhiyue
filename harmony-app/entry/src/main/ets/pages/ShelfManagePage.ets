import { ApiClient } from '../common/ApiClient';
import { PlanItem } from '../common/Models';
import { goBack } from '../common/Navigation';
import { buildContinueItems, ShelfCardItem } from '../common/ShelfPresentation';
import { ShelfStore } from '../common/ShelfStore';
import { common } from '@kit.AbilityKit';

const USER_ID: number = 10086;

const KEY_SHELF_DIRTY: string = 'shelf_manage_dirty_timestamp';

@Entry
@Component
struct ShelfManagePage {
  @State pageWidth: number = 390;
  @State items: ShelfCardItem[] = [];
  @State selectedKeys: string[] = [];
  @State selectAll: boolean = false;
  @State sortByName: boolean = false;
  @State dataVersion: number = 0;

  @State toastText: string = '';
  @State showToast: boolean = false;
  @State showDeleteDialog: boolean = false;

  aboutToAppear(): void {
    this.loadData(true);
  }

  onPageShow(): void {
    this.loadData(false);
  }

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  gridColumns(): number {
    if (this.pageWidth >= 600) {
      return 4;
    }
    return 3;
  }

  gridSpacing(): number {
    if (this.pageWidth >= 600) {
      return 14;
    }
    return this.isCompact() ? 8 : 10;
  }

  pagePadding(): number {
    if (this.pageWidth >= 900) {
      return 28;
    }
    if (this.pageWidth >= 600) {
      return 22;
    }
    return this.isCompact() ? 12 : 16;
  }

  sortedItems(): ShelfCardItem[] {
    const list: ShelfCardItem[] = this.items.slice();
    if (this.sortByName) {
      list.sort((a: ShelfCardItem, b: ShelfCardItem) => {
        return a.title.localeCompare(b.title, 'zh-Hans-CN');
      });
    }
    return list;
  }

  toggleSortByName(): void {
    this.sortByName = !this.sortByName;
  }

  async loadData(showBusy: boolean = false): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      this.flashToast('页面上下文不可用');
      return;
    }
    try {
      const storeState = await ShelfStore.load(context);
      let plans: PlanItem[] = [];
      try {
        plans = await ApiClient.listPlans(USER_ID);
      } catch (_) {}
      this.items = buildContinueItems(storeState, plans);
      this.dataVersion++;
      this.syncSelection();
    } catch (_) {
      this.items = [];
    }
  }

  syncSelection(): void {
    const validKeys: string[] = [];
    for (let i = 0; i < this.selectedKeys.length; i++) {
      for (let index = 0; index < this.items.length; index++) {
        if (this.items[index].key === this.selectedKeys[i]) {
          validKeys.push(this.selectedKeys[i]);
          break;
        }
      }
    }
    this.selectedKeys = validKeys;
    this.selectAll = this.items.length > 0 && this.selectedKeys.length === this.items.length;
  }

  isSelected(itemKey: string): boolean {
    return this.selectedKeys.includes(itemKey);
  }

  toggleSelection(itemKey: string): void {
    if (this.isSelected(itemKey)) {
      this.selectedKeys = this.selectedKeys.filter((key: string) => key !== itemKey);
    } else {
      this.selectedKeys = this.selectedKeys.concat([itemKey]);
    }
    this.selectAll = this.items.length > 0 && this.selectedKeys.length === this.items.length;
  }

  toggleSelectAll(): void {
    if (this.selectAll) {
      this.selectedKeys = [];
      this.selectAll = false;
    } else {
      this.selectedKeys = [];
      for (let i = 0; i < this.items.length; i++) {
        this.selectedKeys.push(this.items[i].key);
      }
      this.selectAll = true;
    }
  }

  selectedItems(): ShelfCardItem[] {
    return this.items.filter((item: ShelfCardItem) => this.selectedKeys.includes(item.key));
  }

  selectedRemoteBookIds(): number[] {
    const nextIds: number[] = [];
    const list: ShelfCardItem[] = this.selectedItems();
    for (let i = 0; i < list.length; i++) {
      if (list[i].remoteBookId && !nextIds.includes(list[i].remoteBookId || 0)) {
        nextIds.push(list[i].remoteBookId || 0);
      }
    }
    return nextIds.filter((bookId: number) => bookId > 0);
  }

  allSelectedArePinned(): boolean {
    if (this.selectedKeys.length === 0) {
      return false;
    }
    const selected: ShelfCardItem[] = this.selectedItems();
    for (let i = 0; i < selected.length; i++) {
      if (!selected[i].pinned) {
        return false;
      }
    }
    return true;
  }

  flashToast(text: string): void {
    this.toastText = text;
    this.showToast = true;
    setTimeout(() => {
      this.showToast = false;
      this.toastText = '';
    }, 1200);
  }

  markDirty(): void {
    AppStorage.setOrCreate(KEY_SHELF_DIRTY, Date.now());
  }

  async downloadSelected(): Promise<void> {
    if (this.selectedKeys.length === 0) {
      this.flashToast('请先选择要下载的书籍');
      return;
    }
    const context = this.hostContext();
    if (!context) { this.flashToast('上下文不可用'); return; }
    const bookIds: number[] = this.selectedRemoteBookIds().filter((bookId: number) => {
      for (let i = 0; i < this.items.length; i++) {
        if (this.items[i].remoteBookId === bookId) { return !this.items[i].downloaded; }
      }
      return false;
    });
    if (bookIds.length === 0) { this.flashToast('所选书籍均已下载'); return; }
    try {
      await ShelfStore.markRemoteBooksDownloaded(context, bookIds);
      this.markDirty();
      this.selectedKeys = []; this.selectAll = false;
      await this.loadData(false);
      this.flashToast(`已标记 ${bookIds.length} 本书为离线下载`);
    } catch (err) { this.flashToast(`下载失败：${err}`); }
  }

  async pinSelected(): Promise<void> {
    if (this.selectedKeys.length === 0) { this.flashToast('请先选择要置顶的书籍'); return; }
    const context = this.hostContext();
    if (!context) { this.flashToast('上下文不可用'); return; }

    if (this.allSelectedArePinned()) {
      try {
        const storeState = await ShelfStore.load(context);
        const nextPinned: string[] = [];
        for (let i = 0; i < storeState.pinnedSourceKeys.length; i++) {
          if (!this.selectedKeys.includes(storeState.pinnedSourceKeys[i])) {
            nextPinned.push(storeState.pinnedSourceKeys[i]);
          }
        }
        await ShelfStore.pinShelfItems(context, nextPinned);
        this.markDirty();
        this.selectedKeys = []; this.selectAll = false;
        await this.loadData(false);
        this.flashToast('已取消置顶');
      } catch (err) { this.flashToast(`取消置顶失败：${err}`); }
      return;
    }

    try {
      const storeState = await ShelfStore.load(context);
      const nextPinned: string[] = storeState.pinnedSourceKeys.slice();
      for (let i = 0; i < this.selectedKeys.length; i++) {
        if (!nextPinned.includes(this.selectedKeys[i])) {
          nextPinned.push(this.selectedKeys[i]);
        }
      }
      await ShelfStore.pinShelfItems(context, nextPinned);
      this.markDirty();
      this.selectedKeys = []; this.selectAll = false;
      await this.loadData(false);
      this.flashToast('所选书籍已置顶');
    } catch (err) { this.flashToast(`置顶失败：${err}`); }
  }

  openDeleteDialog(): void {
    if (this.selectedKeys.length === 0) { this.flashToast('请先选择要移除的书籍'); return; }
    this.showDeleteDialog = true;
  }

  async confirmDeleteSelected(): Promise<void> {
    this.showDeleteDialog = false;
    if (this.selectedKeys.length === 0) { return; }
    const context = this.hostContext();
    if (!context) { this.flashToast('上下文不可用'); return; }
    try {
      await ShelfStore.removeFromShelf(context, this.selectedKeys);
      this.markDirty();
      const count: number = this.selectedKeys.length;
      this.selectedKeys = []; this.selectAll = false;
      await this.loadData(false);
      this.flashToast(`已删除 ${count} 本作品`);
    } catch (err) { this.flashToast(`删除失败：${err}`); }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          this.TopBar()
          Scroll() {
            Column({ space: 14 }) {
              if (this.sortedItems().length > 0) {
                this.BookGrid()
              } else {
                this.EmptyState()
              }
            }
            .width('100%')
            .padding({
              left: this.pagePadding(),
              right: this.pagePadding(),
              top: 6,
              bottom: 100,
            })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .height('100%')

        this.BottomActionBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
      .onAreaChange((_, area) => {
        const nextWidth: number = typeof area.width === 'number' ? area.width : Number(area.width);
        if (Number.isFinite(nextWidth) && nextWidth > 0) { this.pageWidth = nextWidth; }
      })

      if (this.showToast) {
        Stack({ alignContent: Alignment.Center }) {
          Text(this.toastText)
            .fontColor('#FFFFFF')
            .fontSize(14)
            .padding({ left: 20, right: 20, top: 12, bottom: 12 })
            .backgroundColor('rgba(0,0,0,0.75)')
            .borderRadius(8)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
      }

      if (this.showDeleteDialog) {
        Stack({ alignContent: Alignment.Center }) {
          Column() {}
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => { this.showDeleteDialog = false; })

          Column({ space: 0 }) {
            Text(`删除已选的${this.selectedKeys.length}本作品`)
              .fontColor('#222222')
              .fontSize(15)
              .textAlign(TextAlign.Center)
              .padding({ left: 20, right: 20, top: 24, bottom: 20 })

            Divider().color('#EEEEEE').height(0.5).width('100%')

            Row({ space: 0 }) {
              Button('取消')
                .layoutWeight(1).height(48)
                .fontColor('#FF6B7A').fontSize(15)
                .backgroundColor('#FFFFFF').borderRadius(0)
                .onClick(() => { this.showDeleteDialog = false; })

              Divider().color('#EEEEEE').width(0.5).height(48)

              Button('确认删除')
                .layoutWeight(1).height(48)
                .fontColor('#FFFFFF').fontSize(15)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#FF3B30').borderRadius(0)
                .onClick(() => { this.confirmDeleteSelected(); })
            }
          }
          .width(270)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .clip(true)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TopBar() {
    Row() {
      Text('✕')
        .fontColor('#333333')
        .fontSize(18)
        .width(36).height(36)
        .borderRadius(18)
        .backgroundColor('#EDEDED')
        .textAlign(TextAlign.Center)
        .onClick(() => goBack())

      Blank()
      Text('书架管理')
        .fontColor('#1A1A1A')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
      Blank()

      Row({ space: 4 }) {
        Text(this.sortByName ? '✓' : '○')
          .fontColor(this.sortByName ? '#FF3B30' : '#999999')
          .fontSize(14)
        Text('书名排序')
          .fontColor('#666666')
          .fontSize(13)
      }
      .onClick(() => this.toggleSortByName())
    }
    .width('100%')
    .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 8, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  BookGrid() {
    Grid() {
      ForEach(this.sortedItems(), (item: ShelfCardItem) => {
        GridItem() { this.GridBookCard(item, this.dataVersion) }
      }, (item: ShelfCardItem) => `${item.key}_${this.dataVersion}`)
    }
    .columnsTemplate(`repeat(${this.gridColumns()}, 1fr)`)
    .columnsGap(this.gridSpacing())
    .rowsGap(this.isCompact() ? 18 : 22)
    .width('100%')
  }

  @Builder
  GridBookCard(item: ShelfCardItem, _version: number) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        // 封面主体 — 选中时加黄色边框
        Stack() {
          Column() {}
            .width('100%').height('100%')
            .backgroundColor(item.coverTone || '#E8ECF4')
            .borderRadius(8)

          Column({ space: 4 }) {
            Text(item.title)
              .fontColor('#FFFFFF')
              .fontSize(12).fontWeight(FontWeight.Bold)
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
              .lineHeight(16)
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 14, bottom: 14 })
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .aspectRatio(0.72)
        .borderRadius(8)
        .border({ width: this.isSelected(item.key) ? 3 : 0, color: '#FFD700' })
        .onClick(() => this.toggleSelection(item.key))

        // 左上角 — 置顶标志
        if (item.pinned) {
          Text('↑')
            .fontColor('#FFFFFF').fontSize(11).fontWeight(FontWeight.Bold)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor('#FF3B30')
            .borderRadius({ topLeft: 8, bottomRight: 6 })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%')

      // 书名
      Column({ space: 2 }) {
        Text(item.title)
          .fontColor('#333333')
          .fontSize(11).maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(item.progressText)
          .fontColor('#999999').fontSize(10).maxLines(1)
      }
      .width('100%')
      .padding({ left: 1, right: 1 })
      .alignItems(HorizontalAlign.Start)
      .onClick(() => this.toggleSelection(item.key))
    }
    .width('100%')
  }

  @Builder
  EmptyState() {
    Column({ space: 12 }) {
      Text('书架里还没有可管理的书籍')
        .fontColor('#999999').fontSize(15).fontWeight(FontWeight.Medium)
      Text('先回到首页搜索图书、加入书架，或导入本地书籍后再来管理。')
        .fontColor('#BBBBBB').fontSize(12).lineHeight(18).textAlign(TextAlign.Center).width('80%')
    }
    .width('100%').padding({ left: 20, right: 20, top: 60, bottom: 60 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  BottomActionBar() {
    Column() {
      Divider().color('#E5E5E5').height(0.5).width('100%')

      Row() {
        Row({ space: 6 }) {
          Stack({ alignContent: Alignment.Center }) {
            Circle().width(18).height(18)
              .fill(this.selectAll ? '#FF3B30' : 'transparent')
              .stroke(this.selectAll ? '#FF3B30' : '#BBBBBB')
              .strokeWidth(1.5)
            if (this.selectAll) { Text('✓').fontColor('#FFFFFF').fontSize(10).fontWeight(FontWeight.Bold) }
          }
          .width(22).height(22)

          Text('全选').fontColor('#333333').fontSize(13)
        }
        .onClick(() => this.toggleSelectAll())

        Blank()

        Row({ space: 2 }) {
          Text('已选').fontColor('#999999').fontSize(13)
          Text(`${this.selectedKeys.length}`)
            .fontColor(this.selectedKeys.length > 0 ? '#FF3B30' : '#999999')
            .fontSize(13)
            .fontWeight(this.selectedKeys.length > 0 ? FontWeight.Bold : FontWeight.Regular)
          Text('本').fontColor('#999999').fontSize(13)
        }
      }
      .width('100%')
      .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 10, bottom: 6 })

      Row({ space: 0 }) {
        // 下载
        Column({ space: 3 }) {
          Text('下')
            .fontSize(20)
            .fontColor(this.selectedKeys.length > 0 ? '#333333' : '#CCCCCC')
            .fontWeight(FontWeight.Medium)
          Text('下载')
            .fontSize(10)
            .fontColor(this.selectedKeys.length > 0 ? '#1A1A1A' : '#CCCCCC')
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 4 })
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { if (this.selectedKeys.length > 0) { this.downloadSelected(); } })

        // 置顶 / 取消置顶
        Column({ space: 3 }) {
          Text('顶')
            .fontSize(20)
            .fontColor(this.selectedKeys.length > 0 ? '#333333' : '#CCCCCC')
            .fontWeight(FontWeight.Medium)
          Text(this.selectedKeys.length > 0 && this.allSelectedArePinned() ? '取消置顶' : '置顶')
            .fontSize(10)
            .fontColor(this.selectedKeys.length > 0 ? '#1A1A1A' : '#CCCCCC')
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 4 })
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { if (this.selectedKeys.length > 0) { this.pinSelected(); } })

        // 删除
        Column({ space: 3 }) {
          Text('删')
            .fontSize(20)
            .fontColor(this.selectedKeys.length > 0 ? '#FF3B30' : '#CCCCCC')
            .fontWeight(FontWeight.Medium)
          Text('删除')
            .fontSize(10)
            .fontColor(this.selectedKeys.length > 0 ? '#FF3B30' : '#CCCCCC')
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 4 })
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { if (this.selectedKeys.length > 0) { this.openDeleteDialog(); } })
      }
      .width('100%')
      .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 2, bottom: 14 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
  }

  pageTransition() {
    PageTransitionEnter({ type: RouteType.Push, duration: 260, curve: Curve.EaseOut })
      .translate({ x: '100%' }).opacity(0.96)
    PageTransitionExit({ type: RouteType.Pop, duration: 220, curve: Curve.EaseIn })
      .translate({ x: '100%' }).opacity(0.96)
  }
}
