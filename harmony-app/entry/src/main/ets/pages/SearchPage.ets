import { ApiClient } from '../common/ApiClient';
import { Book } from '../common/Models';
import { BookCover } from '../common/BookCover';
import { currentKeyword, goBack, openBookDetail, openReader } from '../common/Navigation';
import { ShelfStore } from '../common/ShelfStore';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const USER_ID: number = 10086;
const MAX_SEARCH_HISTORY_COUNT: number = 8;
const MAX_SUGGESTION_COUNT: number = 10;
const SEARCH_PREFERENCES_NAME: string = 'smartread_search_store';
const SEARCH_HISTORY_KEY: string = 'search_history_json';

type SearchMode = 'history' | 'suggestions' | 'results';

interface SearchHistoryItem {
  keyword: string;
  updatedAt: string;
}

@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State results: Book[] = [];
  @State suggestions: Book[] = [];
  @State busyText: string = '';
  @State errorText: string = '';
  @State hasSearched: boolean = false;
  @State pageWidth: number = 390;
  @State searchHistory: SearchHistoryItem[] = [];
  @State showClearHistoryConfirm: boolean = false;
  @State mode: SearchMode = 'history';

  aboutToAppear(): void {
    this.keyword = currentKeyword();
    this.loadSearchHistory();
    if (this.keyword) {
      this.loadSuggestions();
    }
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  pagePadding(): number {
    if (this.pageWidth >= 900) {
      return 24;
    }
    if (this.pageWidth >= 600) {
      return 18;
    }
    return this.isCompact() ? 14 : 16;
  }

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  nowText(): string {
    return new Date().toISOString();
  }

  async searchPreferences(): Promise<preferences.Preferences | null> {
    const context = this.hostContext();
    if (!context) {
      return null;
    }
    return await preferences.getPreferences(context, SEARCH_PREFERENCES_NAME);
  }

  async loadSearchHistory(): Promise<void> {
    try {
      const prefs = await this.searchPreferences();
      if (!prefs) {
        return;
      }
      const raw: string = await prefs.get(SEARCH_HISTORY_KEY, '') as string;
      if (!raw) {
        return;
      }
      const parsed = JSON.parse(raw) as SearchHistoryItem[];
      this.searchHistory = Array.isArray(parsed) ? parsed.slice(0, MAX_SEARCH_HISTORY_COUNT) : [];
    } catch (_) {
      this.searchHistory = [];
    }
  }

  async saveSearchHistory(): Promise<void> {
    try {
      const prefs = await this.searchPreferences();
      if (!prefs) {
        return;
      }
      await prefs.put(SEARCH_HISTORY_KEY, JSON.stringify(this.searchHistory));
      await prefs.flush();
    } catch (_) {
    }
  }

  highlightPrefix(title: string): string {
    const query: string = this.keyword.trim();
    if (!query || title.indexOf(query) < 0) {
      return '';
    }
    return title.substring(0, title.indexOf(query));
  }

  highlightKeyword(title: string): string {
    const query: string = this.keyword.trim();
    if (!query || title.indexOf(query) < 0) {
      return '';
    }
    return query;
  }

  highlightSuffix(title: string): string {
    const query: string = this.keyword.trim();
    if (!query) {
      return title;
    }
    const index: number = title.indexOf(query);
    if (index < 0) {
      return title;
    }
    return title.substring(index + query.length);
  }

  recordSearchHistory(query: string): void {
    const text: string = query.trim();
    if (!text) {
      return;
    }
    const nextHistory: SearchHistoryItem[] = [{ keyword: text, updatedAt: this.nowText() }];
    for (let i = 0; i < this.searchHistory.length; i++) {
      if (this.searchHistory[i].keyword !== text && nextHistory.length < MAX_SEARCH_HISTORY_COUNT) {
        nextHistory.push(this.searchHistory[i]);
      }
    }
    this.searchHistory = nextHistory;
    this.saveSearchHistory();
  }

  applyHistory(item: SearchHistoryItem): void {
    this.keyword = item.keyword;
    this.searchBooks();
  }

  clearSearchHistory(): void {
    this.searchHistory = [];
    this.showClearHistoryConfirm = false;
    this.saveSearchHistory();
  }

  async loadSuggestions(): Promise<void> {
    const query: string = this.keyword.trim();
    if (!query) {
      this.suggestions = [];
      this.mode = 'history';
      return;
    }
    this.errorText = '';
    this.mode = 'suggestions';
    try {
      const books: Book[] = await ApiClient.searchBooks(query);
      this.suggestions = books.slice(0, MAX_SUGGESTION_COUNT);
    } catch (err) {
      this.suggestions = [];
      this.errorText = `搜索失败：${err}`;
    }
  }

  async searchBooks(): Promise<void> {
    const query: string = this.keyword.trim();
    if (!query) {
      this.errorText = '请输入书名、作者或关键词后再搜索';
      this.results = [];
      this.hasSearched = false;
      this.mode = 'history';
      return;
    }
    this.busyText = '正在搜索图书';
    this.errorText = '';
    this.hasSearched = true;
    this.mode = 'results';
    try {
      this.results = await ApiClient.searchBooks(query);
      this.recordSearchHistory(query);
      if (this.results.length === 0) {
        this.errorText = '';
      }
    } catch (err) {
      this.errorText = `搜索失败：${err}`;
      this.results = [];
    } finally {
      this.busyText = '';
    }
  }

  async openDetail(book: Book): Promise<void> {
    const context = this.hostContext();
    if (context) {
      await ShelfStore.recordRemoteBrowse(context, {
        bookId: book.id,
        title: book.title,
        author: book.author,
        tags: book.tags,
        difficulty: book.difficulty,
        coverColor: book.coverColor,
        actionText: '从搜索页查看详情',
      });
    }
    openBookDetail(book.id);
  }

  async openRemoteReader(book: Book): Promise<void> {
    const context = this.hostContext();
    if (context) {
      await ShelfStore.recordRemoteBrowse(context, {
        bookId: book.id,
        title: book.title,
        author: book.author,
        tags: book.tags,
        difficulty: book.difficulty,
        coverColor: book.coverColor,
        actionText: '从搜索页开始阅读',
      });
    }
    openReader(book.id);
  }

  openSuggestion(book: Book): void {
    this.recordSearchHistory(this.keyword || book.title);
    this.openRemoteReader(book);
  }

  readableBadge(book: Book): string {
    const chapterCount = book.chapterCount || 0;
    if (book.readable === 1 || book.readable === true || chapterCount > 0) {
      return `可读 ${chapterCount} 章`;
    }
    if (book.importStatus === 'failed') {
      return '导入失败';
    }
    return '待入库';
  }

  isBookReadable(book: Book): boolean {
    return book.readable === 1 || book.readable === true || (book.chapterCount || 0) > 0;
  }

  build() {
    Stack() {
      Column() {
        this.TopBar()
        if (this.busyText) {
          this.StatusBanner(this.busyText, '#2D2D2D')
        }
        if (this.errorText) {
          this.StatusBanner(this.errorText, '#A6483F')
        }
        if (this.mode === 'results') {
          this.ResultTabs()
        }
        if (this.mode === 'suggestions') {
          Stack() {
            Scroll() {
              this.SuggestionList()
            }
            .width('100%')
            .height('100%')
            .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 4, bottom: 82 })
            this.SearchSubmitBar()
          }
          .layoutWeight(1)
        } else {
          Scroll() {
            Column({ space: 0 }) {
              if (this.mode === 'results') {
                this.ResultList()
              } else {
                this.SearchHistorySection()
              }
            }
            .width('100%')
            .padding({
              left: this.pagePadding(),
              right: this.pagePadding(),
              top: this.mode === 'results' ? 6 : 42,
              bottom: 32,
            })
          }
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#121212')
      .onAreaChange((_, area) => {
        const nextWidth: number = typeof area.width === 'number' ? area.width : Number(area.width);
        if (Number.isFinite(nextWidth) && nextWidth > 0) {
          this.pageWidth = nextWidth;
        }
      })

      if (this.showClearHistoryConfirm) {
        this.ClearHistoryDialog()
      }
    }
  }

  @Builder
  TopBar() {
    Row({ space: 8 }) {
      Row() {
        Text('⌕')
          .fontColor('#F0F0F0')
          .fontSize(28)
          .margin({ left: 12, right: 8 })
        TextInput({ placeholder: '搜索你感兴趣的内容', text: this.keyword })
          .layoutWeight(1)
          .height(42)
          .fontColor('#F0F0F0')
          .placeholderColor('#787878')
          .fontSize(15)
          .backgroundColor('transparent')
          .border({ width: 0 })
          .onChange((value: string) => {
            this.keyword = value;
            this.loadSuggestions();
          })
          .onSubmit(() => {
            this.searchBooks();
          })
        if (this.keyword.trim()) {
          Button('×')
            .width(28)
            .height(28)
            .fontColor('#202020')
            .fontSize(20)
            .backgroundColor('#777777')
            .borderRadius(14)
            .margin({ right: 8 })
            .onClick(() => {
              this.keyword = '';
              this.results = [];
              this.suggestions = [];
              this.hasSearched = false;
              this.mode = 'history';
            })
        }
      }
      .layoutWeight(1)
      .height(44)
      .backgroundColor('#2A2A2A')
      .borderRadius(22)

      Text('取消')
        .fontColor('#8E8E8E')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .onClick(() => goBack())
    }
    .width('100%')
    .padding({
      left: this.pagePadding(),
      right: this.pagePadding(),
      top: 12,
      bottom: 8,
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SearchHistorySection() {
    Column({ space: 18 }) {
      Row() {
        Text('搜索历史')
          .fontColor('#ECECEC')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
        Blank()
        this.TrashIcon()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.searchHistory.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.searchHistory, (item: SearchHistoryItem) => {
            Text(item.keyword)
              .fontColor('#CFCFCF')
              .fontSize(15)
              .maxLines(1)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor('#272727')
              .borderRadius(20)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => this.applyHistory(item))
          }, (item: SearchHistoryItem) => item.keyword)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  TrashIcon() {
    Column({ space: 2 }) {
      Row() {}
        .width(17)
        .height(3)
        .backgroundColor(this.searchHistory.length > 0 ? '#ECECEC' : '#555555')
        .borderRadius(2)
      Row() {}
        .width(15)
        .height(17)
        .border({ width: 2, color: this.searchHistory.length > 0 ? '#ECECEC' : '#555555' })
        .borderRadius(3)
    }
    .width(34)
    .height(34)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.searchHistory.length > 0) {
        this.showClearHistoryConfirm = true;
      }
    })
  }

  @Builder
  SuggestionList() {
    Column({ space: 0 }) {
      ForEach(this.suggestions, (book: Book, index: number) => {
        this.SuggestionRow(book, index)
      }, (book: Book) => `${book.id}`)
    }
    .width('100%')
  }

  @Builder
  SearchSubmitBar() {
    Column() {
      Blank()
      Button(`搜索“${this.keyword.trim()}”`)
        .width('100%')
        .height(50)
        .fontColor('#E65C73')
        .fontSize(16)
        .backgroundColor('#45191E')
        .borderRadius(25)
        .margin({ left: this.pagePadding(), right: this.pagePadding(), bottom: 18 })
        .onClick(() => this.searchBooks())
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SuggestionRow(book: Book, index: number) {
    Row({ space: 14 }) {
      Text(index === 0 ? '♙' : '▯')
        .fontColor('#E8E8E8')
        .fontSize(index === 0 ? 28 : 26)
        .width(34)
      Row() {
        if (this.highlightPrefix(book.title)) {
          Text(this.highlightPrefix(book.title))
            .fontColor('#E6E6E6')
            .fontSize(16)
            .maxLines(1)
        }
        if (this.highlightKeyword(book.title)) {
          Text(this.highlightKeyword(book.title))
            .fontColor('#D84B61')
            .fontSize(16)
            .maxLines(1)
        }
        Text(this.highlightSuffix(book.title))
          .fontColor('#E6E6E6')
          .fontSize(16)
          .maxLines(1)
          .layoutWeight(1)
      }
      .layoutWeight(1)
      if (index === 0) {
        Text('作者')
          .fontColor('#777777')
          .fontSize(14)
      }
    }
    .width('100%')
    .height(52)
    .border({ width: { bottom: 1 }, color: '#252525' })
    .onClick(() => this.openSuggestion(book))
  }

  @Builder
  ResultTabs() {
    Column() {
      Row() {
        this.ResultTab('作品', true)
        this.ResultTab('听书', false)
        this.ResultTab('漫画', false)
        this.ResultTab('书单', false)
      }
      .width('100%')
      .height(52)
      .padding({ left: this.pagePadding(), right: this.pagePadding() })
      .border({ width: { bottom: 1 }, color: '#262626' })

      Row({ space: 10 }) {
        Button('按推荐⌄')
          .layoutWeight(1)
          .height(34)
          .fontColor('#9B9B9B')
          .fontSize(14)
          .backgroundColor('#2A2A2A')
          .borderRadius(18)
        Button('筛选⌯')
          .layoutWeight(1)
          .height(34)
          .fontColor('#9B9B9B')
          .fontSize(14)
          .backgroundColor('#2A2A2A')
          .borderRadius(18)
      }
      .width('100%')
      .padding({ left: this.pagePadding(), right: this.pagePadding(), top: 10, bottom: 8 })
    }
    .width('100%')
    .backgroundColor('#171717')
  }

  @Builder
  ResultTab(title: string, selected: boolean) {
    Column({ space: 4 }) {
      Text(title)
        .fontColor(selected ? '#F0F0F0' : '#777777')
        .fontSize(18)
        .fontWeight(selected ? FontWeight.Bold : FontWeight.Medium)
      Row() {}
        .width(16)
        .height(3)
        .backgroundColor(selected ? '#E65C73' : 'transparent')
        .borderRadius(2)
    }
    .layoutWeight(1)
    .height(50)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ResultSummary() {
    if (this.hasSearched && this.results.length === 0 && !this.busyText && !this.errorText) {
      Text('没有找到想要的书？告诉我们 ›')
        .fontColor('#DCDCDC')
        .fontSize(14)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 18 })
    }
  }

  @Builder
  ResultList() {
    Column({ space: 0 }) {
      ForEach(this.results, (book: Book) => {
        this.ResultCard(book)
      }, (book: Book) => `${book.id}`)
      this.ResultSummary()
    }
    .width('100%')
  }

  @Builder
  ResultCard(book: Book) {
    Row({ space: 12 }) {
      BookCover({
        bookId: book.id,
        title: book.title,
        difficulty: book.difficulty,
        coverColor: book.coverColor || '#2A2A2A',
        widthValue: 56,
        heightValue: 74,
        titleSize: 9,
      })
      Column({ space: 5 }) {
        Row() {
          if (this.highlightPrefix(book.title)) {
            Text(this.highlightPrefix(book.title))
              .fontColor('#ECECEC')
              .fontSize(16)
              .maxLines(1)
          }
          if (this.highlightKeyword(book.title)) {
            Text(this.highlightKeyword(book.title))
              .fontColor('#D84B61')
              .fontSize(16)
              .maxLines(1)
          }
          Text(this.highlightSuffix(book.title))
            .fontColor('#ECECEC')
            .fontSize(16)
            .maxLines(1)
            .layoutWeight(1)
        }
        Text(`${book.author || '作者待补充'} · ${book.tags || book.difficulty || '云端图书'} · ${book.difficulty || '连载'}`)
          .fontColor('#8B8B8B')
          .fontSize(12)
          .maxLines(1)
        Text(book.summary || '暂无简介')
          .fontColor('#8B8B8B')
          .fontSize(13)
          .lineHeight(18)
          .maxLines(2)
        Text(this.readableBadge(book))
          .fontColor(this.isBookReadable(book) ? '#59B77A' : '#8B8B8B')
          .fontSize(11)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#252525')
          .borderRadius(12)
        if (book.targetReader) {
          Text('◉ 听真人讲书')
            .fontColor('#BEBEBE')
            .fontSize(12)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: '#252525' })
    .onClick(() => this.openDetail(book))
  }

  @Builder
  ClearHistoryDialog() {
    Column() {
      Blank()
      Column({ space: 16 }) {
        Text('删除搜索记录？')
          .fontColor('#ECECEC')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
        Text('删除后将清空当前搜索历史。是否继续？')
          .fontColor('#A0A0A0')
          .fontSize(14)
          .lineHeight(22)
        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontColor('#ECECEC')
            .backgroundColor('#2A2A2A')
            .borderRadius(16)
            .onClick(() => {
              this.showClearHistoryConfirm = false;
            })
          Button('确认删除')
            .layoutWeight(1)
            .height(42)
            .fontColor('#FFFFFF')
            .backgroundColor('#A6483F')
            .borderRadius(16)
            .onClick(() => this.clearSearchHistory())
        }
        .width('100%')
      }
      .width('84%')
      .padding(20)
      .backgroundColor('#1C1C1C')
      .borderRadius(24)
      .shadow({ radius: 24, color: '#55000000', offsetX: 0, offsetY: 12 })
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#88000000')
    .onClick(() => {
      this.showClearHistoryConfirm = false;
    })
  }

  @Builder
  StatusBanner(text: string, color: string) {
    Text(text)
      .fontColor('#FFFFFF')
      .fontSize(13)
      .lineHeight(18)
      .padding({
        left: this.pagePadding(),
        right: this.pagePadding(),
        top: 10,
        bottom: 10,
      })
      .backgroundColor(color)
      .width('100%')
  }
}
