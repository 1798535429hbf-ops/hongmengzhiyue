import { ApiClient } from '../common/ApiClient';
import { Book } from '../common/Models';
import { BookCover } from '../common/BookCover';
import { goBack, openBookDetail } from '../common/Navigation';
import { Theme } from '../common/Theme';

type AudienceKey = 'male' | 'female';
type PanelMode = 'gender' | 'all' | 'tags';

interface AudienceOption {
  key: AudienceKey;
  label: string;
  keyword: string;
  accent: string;
  soft: string;
}

interface SubjectGroup {
  key: string;
  title: string;
  summary: string;
  tone: string;
  accent: string;
  aliases: string[];
}

interface CategoryCard {
  key: string;
  title: string;
  summary: string;
  tone: string;
  accent: string;
  count: number;
  books: Book[];
  sampleBook: Book | null;
}

interface TagCard {
  tag: string;
  count: number;
  tone: string;
  accent: string;
  books: Book[];
  sampleBook: Book | null;
}

const AUDIENCE_OPTIONS: AudienceOption[] = [
  {
    key: 'male',
    label: '男生',
    keyword: '男生向',
    accent: '#D84B45',
    soft: '#FCEBE9',
  },
  {
    key: 'female',
    label: '女生',
    keyword: '女生向',
    accent: '#5677FF',
    soft: '#EAF0FF',
  },
];

const SUBJECT_GROUPS: SubjectGroup[] = [
  {
    key: 'humanity',
    title: '人文',
    summary: '文学、写作、心理与通识阅读，适合先建立阅读感受。',
    tone: '#F7EFE7',
    accent: '#B27A58',
    aliases: ['人文', '文学', '写作', '心理学', '社会学', '通识', '英语', '设计'],
  },
  {
    key: 'geography',
    title: '地理',
    summary: '从地理和空间视角理解文明、国家与环境变化。',
    tone: '#EAF1FF',
    accent: '#5F7DFF',
    aliases: ['地理', '文明', '人类学', '世界', '空间', '区域', '环境'],
  },
  {
    key: 'history',
    title: '历史',
    summary: '人物、制度和时代背景，适合搭建时间线与大局观。',
    tone: '#FFF1E4',
    accent: '#D08A39',
    aliases: ['历史', '明史', '古典', '时代', '中国史', '世界史'],
  },
  {
    key: 'politics',
    title: '政治',
    summary: '经济、组织、商业与治理逻辑，偏现实问题的理解。',
    tone: '#EDF6ED',
    accent: '#4E8A5B',
    aliases: ['政治', '经济', '管理', '创业', '商业', '项目管理', '软件工程'],
  },
  {
    key: 'science',
    title: '科学',
    summary: '数理、计算、工程和方法论，适合做系统进阶。',
    tone: '#EEF4FF',
    accent: '#5A79FF',
    aliases: ['科学', '数学', '算法', 'AI', '人工智能', '机器学习', '深度学习', '物理', '电路', '信号', '数据结构', '数据库', '网络', '操作系统', '编译', 'Linux', 'Go', 'Python', '统计'],
  },
  {
    key: 'philosophy',
    title: '哲学',
    summary: '思考、认知、判断和方法，适合慢一点读。',
    tone: '#F4EEF9',
    accent: '#8B5EDB',
    aliases: ['哲学', '思考', '决策', '认知', '方法', '设计心理学', '快与慢', '判断'],
  },
];

const TAG_HIGHLIGHT_COLORS: string[] = ['#F7EFE7', '#EAF1FF', '#FFF1E4', '#EDF6ED', '#EEF4FF', '#F4EEF9'];

@Component
export struct CategoryContent {
  @Prop pageWidth: number = 390;
  @State panelMode: PanelMode = 'gender';
  @State selectedAudience: AudienceKey = 'male';
  @State selectedCategoryKey: string = 'all';
  @State selectedTagFilter: string = '';
  @State audienceBooks: Book[] = [];
  @State busyText: string = '';
  @State errorText: string = '';
  loadToken: number = 0;

  aboutToAppear(): void {
    this.reloadAudienceBooks();
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  sidebarWidth(): number {
    if (this.pageWidth >= 720) {
      return 104;
    }
    return this.isCompact() ? 76 : 86;
  }

  contentGap(): number {
    return this.isCompact() ? 12 : 16;
  }

  headerSize(): number {
    if (this.pageWidth >= 720) {
      return 34;
    }
    return this.isCompact() ? 26 : 30;
  }

  bodyWidth(): number {
    if (this.pageWidth >= 720) {
      return 680;
    }
    return Math.max(260, this.pageWidth - this.sidebarWidth() - 36);
  }

  currentAudienceOption(): AudienceOption {
    for (let i = 0; i < AUDIENCE_OPTIONS.length; i++) {
      if (AUDIENCE_OPTIONS[i].key === this.selectedAudience) {
        return AUDIENCE_OPTIONS[i];
      }
    }
    return AUDIENCE_OPTIONS[0];
  }

  currentAudienceLabel(): string {
    return `${this.currentAudienceOption().label}向`;
  }

  currentAudienceKeyword(): string {
    return this.currentAudienceOption().keyword;
  }

  audienceTitle(): string {
    return `${this.currentAudienceOption().label}向作品`;
  }

  categoryTabs(): SubjectGroup[] {
    return SUBJECT_GROUPS;
  }

  formatCount(count: number): string {
    if (count >= 10000) {
      return `${(count / 10000).toFixed(count >= 100000 ? 0 : 1)}万部`;
    }
    return `${count}部`;
  }

  splitTags(raw: string): string[] {
    if (!raw) {
      return [];
    }
    const parts: string[] = raw.split(/[，,、\/\s]+/);
    const tags: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const tag = parts[i].trim();
      if (tag) {
        tags.push(tag);
      }
    }
    return tags;
  }

  primaryTag(raw: string): string {
    const tags = this.splitTags(raw);
    for (let i = 0; i < tags.length; i++) {
      if (tags[i] !== '男生向' && tags[i] !== '女生向') {
        return tags[i];
      }
    }
    return '';
  }

  audienceBooksFiltered(): Book[] {
    const filtered: Book[] = [];
    for (let i = 0; i < this.audienceBooks.length; i++) {
      const book = this.audienceBooks[i];
      if (this.selectedCategoryKey !== 'all' && !this.matchesCategory(book, this.selectedCategoryKey)) {
        continue;
      }
      if (this.selectedTagFilter && !this.matchesTag(book, this.selectedTagFilter)) {
        continue;
      }
      filtered.push(book);
    }
    return filtered;
  }

  matchesTag(book: Book, tag: string): boolean {
    if (!tag) {
      return true;
    }
    const tags = this.splitTags(book.tags);
    for (let i = 0; i < tags.length; i++) {
      if (tags[i] === tag) {
        return true;
      }
    }
    const haystack = `${book.title} ${book.author} ${book.summary} ${book.tags}`;
    return haystack.indexOf(tag) >= 0;
  }

  matchesCategory(book: Book, categoryKey: string): boolean {
    for (let i = 0; i < SUBJECT_GROUPS.length; i++) {
      const group = SUBJECT_GROUPS[i];
      if (group.key !== categoryKey) {
        continue;
      }
      const haystack = `${book.title} ${book.author} ${book.summary} ${book.tags}`;
      for (let index = 0; index < group.aliases.length; index++) {
        if (haystack.indexOf(group.aliases[index]) >= 0) {
          return true;
        }
      }
      return false;
    }
    return true;
  }

  categoryCards(): CategoryCard[] {
    const cards: CategoryCard[] = [];
    for (let i = 0; i < SUBJECT_GROUPS.length; i++) {
      const group = SUBJECT_GROUPS[i];
      const books: Book[] = [];
      for (let index = 0; index < this.audienceBooks.length; index++) {
        const book = this.audienceBooks[index];
        if (this.matchesCategory(book, group.key)) {
          books.push(book);
        }
      }
      cards.push({
        key: group.key,
        title: group.title,
        summary: group.summary,
        tone: group.tone,
        accent: group.accent,
        count: books.length,
        books,
        sampleBook: books.length > 0 ? books[0] : null,
      });
    }
    return cards;
  }

  topCategoryCards(): CategoryCard[] {
    return this.categoryCards();
  }

  tagCardIndex(cards: TagCard[], tag: string): number {
    for (let i = 0; i < cards.length; i++) {
      if (cards[i].tag === tag) {
        return i;
      }
    }
    return -1;
  }

  tagCards(): TagCard[] {
    const values: TagCard[] = [];
    for (let i = 0; i < this.audienceBooks.length; i++) {
      const book = this.audienceBooks[i];
      const tags = this.splitTags(book.tags);
      for (let index = 0; index < tags.length; index++) {
        const tag = tags[index];
        if (!tag || tag === '男生向' || tag === '女生向' || tag === this.currentAudienceKeyword()) {
          continue;
        }
        let cardIndex = this.tagCardIndex(values, tag);
        if (cardIndex < 0) {
          const tone = TAG_HIGHLIGHT_COLORS[values.length % TAG_HIGHLIGHT_COLORS.length];
          values.push({
            tag,
            count: 0,
            tone,
            accent: this.currentAudienceOption().accent,
            books: [],
            sampleBook: null,
          });
          cardIndex = values.length - 1;
        }
        values[cardIndex].count++;
        if (values[cardIndex].books.length < 3) {
          values[cardIndex].books.push(book);
        }
        if (!values[cardIndex].sampleBook) {
          values[cardIndex].sampleBook = book;
        }
      }
    }

    values.sort((left: TagCard, right: TagCard) => {
      if (right.count !== left.count) {
        return right.count - left.count;
      }
      return left.tag.localeCompare(right.tag);
    });
    return values;
  }

  hotTags(): TagCard[] {
    return this.tagCards().slice(0, 4);
  }

  otherTags(): TagCard[] {
    return this.tagCards().slice(4);
  }

  async reloadAudienceBooks(): Promise<void> {
    const token = ++this.loadToken;
    this.busyText = '正在读取分类';
    this.errorText = '';
    try {
      const books = await ApiClient.searchBooks(this.currentAudienceKeyword(), '', 0, 50);
      if (token !== this.loadToken) {
        return;
      }
      this.audienceBooks = Array.isArray(books) ? books : [];
      if (this.panelMode === 'all' && this.selectedCategoryKey !== 'all' && !this.selectedTagFilter) {
        this.selectedCategoryKey = 'all';
      }
    } catch (err) {
      if (token !== this.loadToken) {
        return;
      }
      this.errorText = `分类加载失败：${err}`;
      this.audienceBooks = [];
    } finally {
      if (token === this.loadToken) {
        this.busyText = '';
      }
    }
  }

  switchAudience(audience: AudienceKey): void {
    const audienceChanged = this.selectedAudience !== audience;
    this.selectedAudience = audience;
    this.selectedCategoryKey = 'all';
    this.selectedTagFilter = '';
    this.panelMode = 'gender';
    if (audienceChanged) {
      this.reloadAudienceBooks();
    }
  }

  openAllWorks(categoryKey: string = 'all'): void {
    this.selectedCategoryKey = categoryKey;
    this.selectedTagFilter = '';
    this.panelMode = 'all';
  }

  openCategory(categoryKey: string): void {
    this.selectedCategoryKey = categoryKey;
    this.selectedTagFilter = '';
    this.panelMode = 'all';
  }

  openTagPanel(): void {
    this.selectedTagFilter = '';
    this.selectedCategoryKey = 'all';
    this.panelMode = 'tags';
  }

  backToOverview(): void {
    this.selectedTagFilter = '';
    this.selectedCategoryKey = 'all';
    this.panelMode = 'gender';
  }

  selectTag(tag: string): void {
    this.selectedTagFilter = tag;
    this.selectedCategoryKey = 'all';
    this.panelMode = 'all';
  }

  selectCategoryTab(categoryKey: string): void {
    this.selectedCategoryKey = categoryKey;
    this.selectedTagFilter = '';
  }

  openBook(book: Book): void {
    if (!book || !book.id) {
      return;
    }
    openBookDetail(book.id);
  }

  build() {
    Column() {
      this.TopBar()

      if (this.busyText) {
        this.StatusBanner(this.busyText, Theme.mobileBlue)
      }
      if (this.errorText) {
        this.StatusBanner(this.errorText, '#C85B52')
      }

      Row({ space: 0 }) {
        this.SideBar()
        Column({ space: this.contentGap() }) {
          if (this.panelMode === 'gender') {
            this.GenderPanel()
          } else if (this.panelMode === 'all') {
            this.AllWorksPanel()
          } else {
            this.TagPanel()
          }
          Blank().height(18)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 14, right: 14, top: 14, bottom: 24 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .backgroundColor(Theme.mobileCanvas)
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontColor(Theme.mobileText)
        .fontSize(this.isCompact() ? 32 : 36)
        .fontWeight(FontWeight.Medium)
        .width(40)
        .textAlign(TextAlign.Start)
        .onClick(() => goBack())

      Text('分类')
        .fontColor(Theme.mobileText)
        .fontSize(this.headerSize())
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text(this.panelMode === 'gender' ? '全部作品' : '返回分类')
        .fontColor(Theme.mobileBlue)
        .fontSize(this.isCompact() ? 15 : 16)
        .fontWeight(FontWeight.Medium)
        .width(72)
        .textAlign(TextAlign.End)
        .onClick(() => {
          if (this.panelMode === 'gender') {
            this.openAllWorks('all');
          } else {
            this.backToOverview();
          }
        })
    }
    .width('100%')
    .height(this.isCompact() ? 54 : 58)
    .padding({ left: 12, right: 12, top: 6 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SideBar() {
    Column({ space: 10 }) {
      this.SideItem('男生', this.selectedAudience === 'male' && this.panelMode !== 'tags', AUDIENCE_OPTIONS[0].accent, AUDIENCE_OPTIONS[0].soft, () => this.switchAudience('male'))
      this.SideItem('女生', this.selectedAudience === 'female' && this.panelMode !== 'tags', AUDIENCE_OPTIONS[1].accent, AUDIENCE_OPTIONS[1].soft, () => this.switchAudience('female'))
      this.SideItem('标签', this.panelMode === 'tags', Theme.mobilePurple, '#F4EEF9', () => this.openTagPanel())
    }
    .width(this.sidebarWidth())
    .height('100%')
    .padding({ left: 10, right: 10, top: 4, bottom: 16 })
    .border({ width: { right: 1 }, color: '#ECEEF4' })
    .backgroundColor('#F9FAFD')
  }

  @Builder
  SideItem(label: string, selected: boolean, accent: string, tone: string, action: () => void) {
    Row() {
      Column() {}
        .width(4)
        .height(26)
        .borderRadius(2)
        .backgroundColor(selected ? accent : 'transparent')

      Text(label)
        .fontColor(selected ? accent : Theme.mobileText)
        .fontSize(this.isCompact() ? 15 : 16)
        .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
        .margin({ left: 12 })
    }
    .width('100%')
    .height(this.isCompact() ? 46 : 50)
    .padding({ left: 10, right: 10 })
    .backgroundColor(selected ? tone : '#FFFFFF')
    .borderRadius(14)
    .onClick(() => action())
  }

  @Builder
  GenderPanel() {
    Column({ space: 14 }) {
      Row() {
        Text(`共 ${this.formatCount(this.audienceBooks.length)}`)
          .fontColor(Theme.mobileText)
          .fontSize(this.isCompact() ? 16 : 18)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Grid() {
        ForEach(this.topCategoryCards(), (card: CategoryCard) => {
          GridItem() {
            this.CategoryCard(card)
          }
        }, (card: CategoryCard) => card.key)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(12)
      .rowsGap(12)
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  CategoryCard(card: CategoryCard) {
    Row({ space: 12 }) {
      Stack() {
        Column() {}
          .width('100%')
          .height('100%')
          .backgroundColor(card.tone)
          .borderRadius(16)

        Column() {}
          .width('100%')
          .height('100%')
          .backgroundColor('#FFFFFF')
          .opacity(0.22)
          .translate({ x: 7, y: 7 })
          .borderRadius(16)

        Column() {}
          .width('100%')
          .height('100%')
          .backgroundColor(card.accent)
          .opacity(0.08)
          .translate({ x: 3, y: 3 })
          .borderRadius(16)

        Row({ space: 10 }) {
          if (card.sampleBook) {
            BookCover({
              bookId: card.sampleBook.id,
              title: card.sampleBook.title,
              difficulty: card.sampleBook.difficulty,
              coverColor: card.sampleBook.coverColor,
              widthValue: this.isCompact() ? 42 : 48,
              heightValue: this.isCompact() ? 58 : 66,
              titleSize: 8,
            })
          } else {
            Blank()
              .width(this.isCompact() ? 42 : 48)
              .height(this.isCompact() ? 58 : 66)
              .backgroundColor('#FFFFFF')
              .borderRadius(10)
          }

          Column({ space: 5 }) {
            Text(card.title)
              .fontColor(Theme.mobileText)
              .fontSize(this.isCompact() ? 16 : 18)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
            Text(this.formatCount(card.count))
              .fontColor(card.accent)
              .fontSize(this.isCompact() ? 13 : 14)
              .fontWeight(FontWeight.Medium)
            Text(card.summary)
              .fontColor(Theme.mobileSubtext)
              .fontSize(this.isCompact() ? 11 : 12)
              .lineHeight(this.isCompact() ? 16 : 17)
              .maxLines(2)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      }
      .width('100%')
      .height(this.isCompact() ? 148 : 158)
      .borderRadius(16)
      .shadow({ radius: 10, color: '#12000000', offsetX: 0, offsetY: 4 })
      .onClick(() => this.openCategory(card.key))
    }
    .width('100%')
  }

  @Builder
  AllWorksPanel() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.audienceTitle())
            .fontColor(Theme.mobileText)
            .fontSize(this.isCompact() ? 20 : 22)
            .fontWeight(FontWeight.Bold)
          Text(`共 ${this.formatCount(this.audienceBooksFiltered().length)}`)
            .fontColor(Theme.mobileSubtext)
            .fontSize(13)
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Row({ space: 8 }) {
        this.CategoryFilterTab('全部', this.selectedCategoryKey === 'all', () => this.selectCategoryTab('all'))
        ForEach(this.categoryTabs(), (group: SubjectGroup) => {
          this.CategoryFilterTab(group.title, this.selectedCategoryKey === group.key, () => this.selectCategoryTab(group.key))
        }, (group: SubjectGroup) => group.key)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Row({ space: 8 }) {
        Image($r('app.media.mobile_filter'))
          .width(16)
          .height(16)
        Text(this.selectedTagFilter ? `标签精筛 · ${this.selectedTagFilter}` : '标签精筛')
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
      }
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F3F4F8')
      .borderRadius(20)

      Column({ space: 0 }) {
        if (this.audienceBooksFiltered().length === 0) {
          this.EmptyState()
        } else {
          ForEach(this.audienceBooksFiltered(), (book: Book) => {
            this.BookListCard(book)
          }, (book: Book) => `${book.id}_${book.title}`)
        }
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  CategoryFilterTab(label: string, selected: boolean, action: () => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontColor(selected ? Theme.mobileText : Theme.mobileSubtext)
        .fontSize(this.isCompact() ? 13 : 14)
        .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
      Row() {}
        .width(selected ? 22 : 0)
        .height(3)
        .borderRadius(2)
        .backgroundColor(selected ? this.currentAudienceOption().accent : 'transparent')
    }
    .padding({ left: 2, right: 2, top: 6, bottom: 6 })
    .onClick(() => action())
  }

  @Builder
  EmptyState() {
    Column({ space: 8 }) {
      Text('这一组还没有书')
        .fontColor(Theme.mobileText)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      Text('可以先切换分类，或者换一个标签看看。')
        .fontColor(Theme.mobileSubtext)
        .fontSize(13)
        .lineHeight(18)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 32, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  BookListCard(book: Book) {
    Row({ space: 12 }) {
      BookCover({
        bookId: book.id,
        title: book.title,
        difficulty: book.difficulty,
        coverColor: book.coverColor || '#D9E1F5',
        widthValue: this.isCompact() ? 66 : 74,
        heightValue: this.isCompact() ? 92 : 104,
        titleSize: 11,
      })

      Column({ space: 6 }) {
        Text(book.title || '未命名图书')
          .fontColor(Theme.mobileText)
          .fontSize(this.isCompact() ? 16 : 18)
          .fontWeight(FontWeight.Medium)
          .lineHeight(this.isCompact() ? 22 : 24)
          .maxLines(2)

        Text(`${book.author || '作者待补充'} · ${this.primaryTag(book.tags) || book.difficulty || '云端图书'}`)
          .fontColor(Theme.mobileSubtext)
          .fontSize(12)
          .maxLines(1)

        Text(book.summary || '暂无简介')
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
          .lineHeight(18)
          .maxLines(2)

        Row({ space: 8 }) {
          Text(this.currentAudienceLabel())
            .fontColor(this.currentAudienceOption().accent)
            .fontSize(11)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.currentAudienceOption().soft)
            .borderRadius(10)
          if (book.difficulty) {
            Text(book.difficulty)
              .fontColor(Theme.mobileSubtext)
              .fontSize(11)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#F3F5F8')
              .borderRadius(10)
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#EEF1F5' })
    .onClick(() => this.openBook(book))
  }

  @Builder
  TagPanel() {
    Column({ space: 14 }) {
      Row({ space: 18 }) {
        this.TagAudienceTab('男生标签', this.selectedAudience === 'male', AUDIENCE_OPTIONS[0].accent, () => this.switchAudience('male'))
        this.TagAudienceTab('女生标签', this.selectedAudience === 'female', AUDIENCE_OPTIONS[1].accent, () => this.switchAudience('female'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Column({ space: 10 }) {
        Row() {
          Text('热门标签')
            .fontColor(Theme.mobileText)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          Blank()
        }
        .width('100%')

        Grid() {
          ForEach(this.hotTags(), (tag: TagCard) => {
            GridItem() {
              this.TagSquare(tag, true)
            }
          }, (tag: TagCard) => tag.tag)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .width('100%')
      }

      Column({ space: 10 }) {
        Row() {
          Text(`全部标签 ${this.tagCards().length}`)
            .fontColor(Theme.mobileText)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          Blank()
        }
        .width('100%')

        Grid() {
          ForEach(this.otherTags(), (tag: TagCard) => {
            GridItem() {
              this.TagSquare(tag, false)
            }
          }, (tag: TagCard) => tag.tag)
        }
        .columnsTemplate(this.pageWidth >= 720 ? '1fr 1fr 1fr 1fr' : '1fr 1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  TagAudienceTab(label: string, selected: boolean, accent: string, action: () => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontColor(selected ? Theme.mobileText : Theme.mobileSubtext)
        .fontSize(this.isCompact() ? 17 : 18)
        .fontWeight(selected ? FontWeight.Bold : FontWeight.Medium)
      Row() {}
        .width(selected ? 36 : 0)
        .height(4)
        .borderRadius(2)
        .backgroundColor(selected ? accent : 'transparent')
    }
    .padding({ top: 4, bottom: 4 })
    .onClick(() => action())
  }

  @Builder
  TagSquare(tag: TagCard, featured: boolean) {
    Stack() {
      Column() {}
        .width('100%')
        .height('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .opacity(0.55)
        .translate({ x: 8, y: 8 })

      Column() {}
        .width('100%')
        .height('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .opacity(0.72)
        .translate({ x: 4, y: 4 })

      Column({ space: 6 }) {
        Text(tag.tag)
          .fontColor(Theme.mobileText)
          .fontSize(featured ? 18 : 16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)

        Text(this.formatCount(tag.count))
          .fontColor(tag.accent)
          .fontSize(featured ? 13 : 12)
          .fontWeight(FontWeight.Medium)

        Text(tag.sampleBook ? tag.sampleBook.title : ' ')
          .fontColor(Theme.mobileSubtext)
          .fontSize(11)
          .lineHeight(16)
          .maxLines(2)

        Blank()

        Row() {
          Blank()
          if (tag.sampleBook) {
            BookCover({
              bookId: tag.sampleBook.id,
              title: tag.sampleBook.title,
              difficulty: tag.sampleBook.difficulty,
              coverColor: tag.sampleBook.coverColor || '#D9E1F5',
              widthValue: featured ? 54 : 46,
              heightValue: featured ? 72 : 62,
              titleSize: 8,
            })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .height('100%')
      .padding(14)
      .backgroundColor(tag.tone)
      .borderRadius(18)
      .shadow({ radius: 10, color: '#12000000', offsetX: 0, offsetY: 4 })
    }
    .width('100%')
    .aspectRatio(1)
    .onClick(() => this.selectTag(tag.tag))
  }

  @Builder
  StatusBanner(text: string, color: string) {
    Text(text)
      .fontColor('#FFFFFF')
      .fontSize(13)
      .lineHeight(18)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(color)
      .width('100%')
  }
}
