import { ApiClient } from '../common/ApiClient';
import { PlanItem } from '../common/Models';
import { openBookDetail, openReader, openSearch, openShelfManage } from '../common/Navigation';
import { buildContinueItems as createContinueItems, buildHistoryItems as createHistoryItems, formatReadingDuration } from '../common/ShelfPresentation';
import { ShelfHomePanel } from '../common/ShelfHomePanel';
import { LocalShelfBook, RemoteShelfSession, ShelfStore, ShelfStoreState } from '../common/ShelfStore';
import { Theme } from '../common/Theme';
import { common } from '@kit.AbilityKit';
import cameraPicker from '@ohos.multimedia.cameraPicker';
import { picker } from '@kit.CoreFileKit';
import camera from '@ohos.multimedia.camera';

const USER_ID: number = 10086;

interface ShelfBook {
  id: number;
  title: string;
  author: string;
  tag: string;
  progress: number;
  accent: string;
  lastRead: string;
  coverTone: string;
}

interface StoreBook {
  id: number;
  title: string;
  author: string;
  score: string;
  quote: string;
  tags?: string[];
  coverTone: string;
}

interface CategorySubject {
  title: string;
  coverTone: string;
}

interface QuickAction {
  id: number;
  label: string;
  icon: Resource;
}

interface DiscoverList {
  id: number;
  title: string;
  count: string;
  saved: string;
  coverTone: string;
}

interface ProfileService {
  title: string;
  subtitle: string;
  icon: Resource;
}

interface ProfileTool {
  title: string;
  icon: Resource;
}

type ShelfTabMode = 'continue' | 'history';

interface ShelfCardItem {
  key: string;
  sourceType: 'remote' | 'local';
  title: string;
  author: string;
  tag: string;
  progress: number;
  progressText: string;
  accent: string;
  lastRead: string;
  coverTone: string;
  updatedAt: string;
  actionLabel: string;
  manageLabel: string;
  remoteBookId?: number;
  chapterId?: string;
  localBookKey?: string;
  openCount?: number;
  inShelf?: boolean;
  downloaded?: boolean;
  pinned?: boolean;
}

const SHELF_BOOKS: ShelfBook[] = [
  {
    id: 1,
    title: '三体全集（全3册）',
    author: '刘慈欣',
    tag: '科幻',
    progress: 62,
    accent: '#3B6CFF',
    lastRead: '上次阅读：第三部 死神永生 第十二章',
    coverTone: '#E8EEFF',
  },
  {
    id: 2,
    title: '活着',
    author: '余华',
    tag: '文学',
    progress: 35,
    accent: '#8B63FF',
    lastRead: '上次阅读：第一部 福贵 第五章',
    coverTone: '#F0F4FF',
  },
  {
    id: 3,
    title: '云边有个小卖部',
    author: '张嘉佳',
    tag: '小说',
    progress: 18,
    accent: '#FF8C2A',
    lastRead: '上次阅读：第二章 云边镇',
    coverTone: '#FFF2E8',
  },
  {
    id: 4,
    title: '追风筝的人',
    author: '卡勒德·胡赛尼',
    tag: '文学',
    progress: 9,
    accent: '#3F72FF',
    lastRead: '上次阅读：第一部 第三章',
    coverTone: '#EAF0FF',
  },
  {
    id: 5,
    title: '明朝那些事儿（全集）',
    author: '当年明月',
    tag: '历史',
    progress: 12,
    accent: '#FF8425',
    lastRead: '上次阅读：第一卷 第六章',
    coverTone: '#FFF1DE',
  },
  {
    id: 6,
    title: '人类简史：从动物到上帝',
    author: '尤瓦尔·赫拉利',
    tag: '历史',
    progress: 8,
    accent: '#FF5B58',
    lastRead: '上次阅读：第二章 认知革命',
    coverTone: '#F5F0E8',
  },
];

const STORE_BOOKS: StoreBook[] = [
  {
    id: 1,
    title: '余华作品集',
    author: '余华',
    score: '9.6分',
    quote: '“我写这本书，不是为了控诉黑暗，而是为了，看见光明”',
    coverTone: '#F7EFE3',
  },
  {
    id: 2,
    title: '活着',
    author: '余华',
    score: '9.8分',
    quote: '人是为了活着本身而活着的，而不是为了活着之外的任何事物。',
    coverTone: '#EEF2FF',
  },
  {
    id: 3,
    title: '三体全集（全3册）',
    author: '刘慈欣',
    score: '9.1分',
    quote: '宇宙辽阔而生命短暂。',
    tags: ['科幻', '宇宙', '文明'],
    coverTone: '#E7EEFF',
  },
];

const CATEGORY_SIDE_MENU: string[] = [
  '全部分类',
  '人气榜',
  '畅销榜',
  '新书榜',
  '完结榜',
  '收藏榜',
  '推荐榜',
];

const CATEGORY_TOP_FILTERS: string[] = ['男生', '女生', '出版', '漫画'];

const CATEGORY_SUBJECT_ROWS: CategorySubject[][] = [
  [
    { title: '玄幻', coverTone: '#E9F0FF' },
    { title: '奇幻', coverTone: '#EEF4FF' },
  ],
  [
    { title: '武侠', coverTone: '#F8F0E6' },
    { title: '仙侠', coverTone: '#EEF6FF' },
  ],
  [
    { title: '都市', coverTone: '#EDF3FF' },
    { title: '现实', coverTone: '#FFF3EC' },
  ],
  [
    { title: '历史', coverTone: '#FFF4E8' },
    { title: '军事', coverTone: '#F2F6FF' },
  ],
  [
    { title: '游戏', coverTone: '#E9F9EF' },
    { title: '体育', coverTone: '#FFF2E6' },
  ],
  [
    { title: '科幻', coverTone: '#EAF0FF' },
    { title: '悬疑', coverTone: '#EEF3FF' },
  ],
  [
    { title: '轻小说', coverTone: '#FFF4F0' },
    { title: '短篇', coverTone: '#F3F6FF' },
  ],
  [
    { title: '二次元', coverTone: '#EEF8FF' },
    { title: '其他', coverTone: '#F6F7FB' },
  ],
];

const CATEGORY_STYLE_TAGS: string[] = [
  '热血',
  '爽文',
  '脑洞',
  '无敌流',
  '扮猪吃虎',
  '升级流',
  '穿越',
  '重生',
  '系统',
  '搞笑',
  '职场',
  '末世',
];

const CATEGORY_PLOT_TAGS: string[] = [
  '东方玄幻',
  '异世大陆',
  '王朝争霸',
  '架空历史',
  '高武世界',
  '都市异能',
  '娱乐明星',
  '商战职场',
  '悬疑推理',
  '未来世界',
  '星际文明',
  '灵异神怪',
];

const DISCOVER_QUICK_ACTIONS: QuickAction[] = [
  { id: 1, label: '书单', icon: $r('app.media.discover_quick_books') },
  { id: 2, label: '榜单', icon: $r('app.media.discover_quick_rank') },
  { id: 3, label: '主题', icon: $r('app.media.discover_quick_theme') },
  { id: 4, label: '活动', icon: $r('app.media.discover_quick_activity') },
  { id: 5, label: '听书', icon: $r('app.media.discover_quick_audio') },
];

const DISCOVER_LISTS: DiscoverList[] = [
  {
    id: 1,
    title: '豆瓣高分书单',
    count: '10本书',
    saved: '392.4万人收藏',
    coverTone: '#EEF3FF',
  },
  {
    id: 2,
    title: '一生必读的经典好书',
    count: '20本书',
    saved: '268.7万人收藏',
    coverTone: '#FFF2E6',
  },
  {
    id: 3,
    title: '科幻迷必看的神作',
    count: '15本书',
    saved: '186.8万人收藏',
    coverTone: '#E8EEFF',
  },
];

const PROFILE_SERVICE_ROWS: ProfileService[][] = [
  [
    {
      title: '画像中心',
      subtitle: '编辑兴趣与渠道偏好',
      icon: $r('app.media.profile_user'),
    },
    {
      title: '活动中心',
      subtitle: '校园阅读活动进行中',
      icon: $r('app.media.profile_gift'),
    },
  ],
  [
    {
      title: '阅读计划',
      subtitle: '管理伴读节奏与进度',
      icon: $r('app.media.profile_calendar'),
    },
    {
      title: '问答记录',
      subtitle: '查看 AI 伴读历史',
      icon: $r('app.media.profile_chat'),
    },
  ],
  [
    {
      title: '我的笔记',
      subtitle: '摘录与灵感随时回看',
      icon: $r('app.media.profile_note'),
    },
    {
      title: '浏览记录',
      subtitle: '保留最近访问轨迹',
      icon: $r('app.media.profile_clock'),
    },
  ],
];

const PROFILE_TOOLS: ProfileTool[] = [
  { title: '收藏夹', icon: $r('app.media.profile_star') },
  { title: '阅读计划', icon: $r('app.media.profile_calendar') },
  { title: '阅读画像', icon: $r('app.media.profile_user') },
  { title: '成长勋章', icon: $r('app.media.profile_document') },
  { title: '渠道偏好', icon: $r('app.media.profile_download') },
  { title: '浏览记录', icon: $r('app.media.profile_clock') },
  { title: '关注作者', icon: $r('app.media.profile_user_plus') },
  { title: '字体设置', icon: $r('app.media.profile_font') },
];

@Entry
@Component
struct Index {
  @State activeTab: number = 0;
  @State pageWidth: number = 390;
  @State shelfRefreshSeed: number = 0;
  @State shelfMode: ShelfTabMode = 'continue';
  @State shelfContinueItems: ShelfCardItem[] = [];
  @State shelfHistoryItems: ShelfCardItem[] = [];
  @State shelfBusyText: string = '';
  @State shelfErrorText: string = '';
  @State showShelfMenu: boolean = false;
  @State todayReadingLabel: string = '00:00:00';
  @State shelfManageMode: boolean = false;
  @State shelfEditMode: boolean = false;
  @State selectedShelfKeys: string[] = [];

  aboutToAppear(): void {
    this.shelfRefreshSeed++;
  }

  onPageShow(): void {
    this.shelfRefreshSeed++;
  }

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  visibleShelfItems(): ShelfCardItem[] {
    return this.shelfMode === 'continue' ? this.shelfContinueItems : this.shelfHistoryItems;
  }

  isShelfSelected(itemKey: string): boolean {
    for (let i = 0; i < this.selectedShelfKeys.length; i++) {
      if (this.selectedShelfKeys[i] === itemKey) {
        return true;
      }
    }
    return false;
  }

  resetShelfModes(): void {
    this.shelfManageMode = false;
    this.shelfEditMode = false;
    this.selectedShelfKeys = [];
  }

  updateShelfMode(mode: ShelfTabMode): void {
    this.shelfMode = mode;
    this.showShelfMenu = false;
    this.resetShelfModes();
  }

  toggleManageMode(): void {
    this.shelfManageMode = !this.shelfManageMode;
    if (this.shelfManageMode) {
      this.shelfEditMode = false;
      this.selectedShelfKeys = [];
    }
  }

  toggleEditMode(): void {
    this.shelfEditMode = !this.shelfEditMode;
    if (this.shelfEditMode) {
      this.shelfManageMode = false;
      this.selectedShelfKeys = [];
    } else {
      this.selectedShelfKeys = [];
    }
  }

  toggleSelection(itemKey: string): void {
    const nextSelected: string[] = [];
    let existed: boolean = false;
    for (let i = 0; i < this.selectedShelfKeys.length; i++) {
      if (this.selectedShelfKeys[i] === itemKey) {
        existed = true;
      } else {
        nextSelected.push(this.selectedShelfKeys[i]);
      }
    }
    if (!existed) {
      nextSelected.push(itemKey);
    }
    this.selectedShelfKeys = nextSelected;
  }

  pickedTag(rawTags: string, fallback: string): string {
    const text = rawTags ? rawTags.trim() : '';
    if (!text) {
      return fallback;
    }
    const separators: string[] = [',', '，', '/', ' '];
    for (let i = 0; i < separators.length; i++) {
      const index: number = text.indexOf(separators[i]);
      if (index > 0) {
        return text.substring(0, index).trim();
      }
    }
    return text;
  }

  accentBySeed(seed: string): string {
    const palette: string[] = [Theme.mobileRed, Theme.mobileBlue, Theme.mobilePurple, Theme.mobileOrange];
    let score: number = 0;
    for (let i = 0; i < seed.length; i++) {
      score += seed.charCodeAt(i);
    }
    return palette[score % palette.length];
  }

  toneBySeed(seed: string): string {
    const tones: string[] = ['#EEF2FF', '#FFF3EC', '#F2F5FF', '#EEF8F4', '#FFF6E9'];
    let score: number = 0;
    for (let i = 0; i < seed.length; i++) {
      score += seed.charCodeAt(i);
    }
    return tones[score % tones.length];
  }

  formatDateLabel(isoText: string): string {
    if (!isoText) {
      return '刚刚';
    }
    const date: Date = new Date(isoText);
    if (Number.isNaN(date.getTime())) {
      return isoText;
    }
    const month: string = `${date.getMonth() + 1}`.padStart(2, '0');
    const day: string = `${date.getDate()}`.padStart(2, '0');
    const hour: string = `${date.getHours()}`.padStart(2, '0');
    const minute: string = `${date.getMinutes()}`.padStart(2, '0');
    return `${month}-${day} ${hour}:${minute}`;
  }

  findRemoteSession(sessions: RemoteShelfSession[], bookId: number): RemoteShelfSession | null {
    for (let i = 0; i < sessions.length; i++) {
      if (sessions[i].bookId === bookId) {
        return sessions[i];
      }
    }
    return null;
  }

  buildContinueItems(storeState: ShelfStoreState, plans: PlanItem[]): ShelfCardItem[] {
    const nextItems: ShelfCardItem[] = [];
    for (let i = 0; i < storeState.localBooks.length; i++) {
      const item: LocalShelfBook = storeState.localBooks[i];
      const accent: string = this.accentBySeed(item.extension || item.title);
      const updatedAt: string = item.lastOpenedAt || item.importedAt;
      nextItems.push({
        key: item.key,
        sourceType: 'local',
        title: item.title,
        author: item.displayName,
        tag: item.extension ? item.extension.toUpperCase() : 'LOCAL',
        progress: 0,
        progressText: item.openCount > 0 ? `已打开 ${item.openCount} 次` : '未开始阅读',
        accent,
        lastRead: item.lastOpenedAt ? `上次打开：${this.formatDateLabel(item.lastOpenedAt)}` : `导入时间：${this.formatDateLabel(item.importedAt)}`,
        coverTone: this.toneBySeed(item.displayName),
        updatedAt,
        actionLabel: '打开文件',
        manageLabel: '移出书架',
        localBookKey: item.key,
        openCount: item.openCount,
      });
    }

    for (let i = 0; i < plans.length; i++) {
      const plan: PlanItem = plans[i];
      if (plan.status === 'finished' && plan.progress >= 100) {
        continue;
      }
      let hidden: boolean = false;
      for (let index = 0; index < storeState.hiddenRemoteBookIds.length; index++) {
        if (storeState.hiddenRemoteBookIds[index] === plan.bookId) {
          hidden = true;
          break;
        }
      }
      if (hidden) {
        continue;
      }
      const session = this.findRemoteSession(storeState.remoteSessions, plan.bookId);
      const seed: string = `${plan.title}-${plan.author}`;
      const accent: string = this.accentBySeed(seed);
      const updatedAt: string = session ? session.updatedAt : `1970-01-01T00:${`${plan.id % 60}`.padStart(2, '0')}:00.000Z`;
      nextItems.push({
        key: session ? session.key : `remote:${plan.bookId}`,
        sourceType: 'remote',
        title: plan.title,
        author: plan.author,
        tag: this.pickedTag(session ? session.tags : '', '在读'),
        progress: session ? session.progress : plan.progress,
        progressText: `${session ? session.progress : plan.progress}%`,
        accent,
        lastRead: session && session.chapterTitle ? `上次阅读：${session.chapterTitle}` : `当前进度：${plan.progress}%`,
        coverTone: this.toneBySeed(seed),
        updatedAt,
        actionLabel: '继续阅读',
        manageLabel: '移出书架',
        remoteBookId: plan.bookId,
        chapterId: session ? session.chapterId : '',
      });
    }

    for (let i = 0; i < storeState.remoteSessions.length; i++) {
      const session = storeState.remoteSessions[i];
      let existsInPlans: boolean = false;
      let hidden: boolean = false;
      for (let index = 0; index < plans.length; index++) {
        if (plans[index].bookId === session.bookId) {
          existsInPlans = true;
          break;
        }
      }
      for (let index = 0; index < storeState.hiddenRemoteBookIds.length; index++) {
        if (storeState.hiddenRemoteBookIds[index] === session.bookId) {
          hidden = true;
          break;
        }
      }
      if (existsInPlans || hidden) {
        continue;
      }
      const seed: string = `${session.title}-${session.author}`;
      nextItems.push({
        key: session.key,
        sourceType: 'remote',
        title: session.title,
        author: session.author,
        tag: this.pickedTag(session.tags, '在读'),
        progress: session.progress,
        progressText: `${session.progress}%`,
        accent: this.accentBySeed(seed),
        lastRead: session.chapterTitle ? `上次阅读：${session.chapterTitle}` : `最近阅读：${this.formatDateLabel(session.updatedAt)}`,
        coverTone: this.toneBySeed(seed),
        updatedAt: session.updatedAt,
        actionLabel: '继续阅读',
        manageLabel: '移出书架',
        remoteBookId: session.bookId,
        chapterId: session.chapterId,
      });
    }

    nextItems.sort((left: ShelfCardItem, right: ShelfCardItem) => {
      return right.updatedAt.localeCompare(left.updatedAt);
    });
    return nextItems;
  }

  buildHistoryItems(storeState: ShelfStoreState): ShelfCardItem[] {
    const nextItems: ShelfCardItem[] = [];
    for (let i = 0; i < storeState.browseHistory.length; i++) {
      const history = storeState.browseHistory[i];
      const session = history.remoteBookId ? this.findRemoteSession(storeState.remoteSessions, history.remoteBookId) : null;
      let localBook: LocalShelfBook | null = null;
      if (history.localBookKey) {
        for (let index = 0; index < storeState.localBooks.length; index++) {
          if (storeState.localBooks[index].key === history.localBookKey) {
            localBook = storeState.localBooks[index];
            break;
          }
        }
      }
      nextItems.push({
        key: history.key,
        sourceType: history.sourceType,
        title: history.title,
        author: history.subtitle,
        tag: history.sourceType === 'local' ? '浏览记录' : this.pickedTag(session ? session.tags : '', '浏览记录'),
        progress: session ? session.progress : 0,
        progressText: session ? `${session.progress}%` : (localBook ? `已打开 ${localBook.openCount} 次` : history.actionText),
        accent: history.sourceType === 'local' ? Theme.mobileBlue : Theme.mobileOrange,
        lastRead: `${history.actionText} · ${this.formatDateLabel(history.updatedAt)}`,
        coverTone: history.coverTone || this.toneBySeed(history.title),
        updatedAt: history.updatedAt,
        actionLabel: history.sourceType === 'local' ? '打开文件' : '打开书籍',
        manageLabel: '删除记录',
        remoteBookId: history.remoteBookId,
        chapterId: session ? session.chapterId : '',
        localBookKey: history.localBookKey,
        openCount: localBook ? localBook.openCount : 0,
      });
    }
    nextItems.sort((left: ShelfCardItem, right: ShelfCardItem) => {
      return right.updatedAt.localeCompare(left.updatedAt);
    });
    return nextItems;
  }

  async loadShelfData(showBusy: boolean = false): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法同步书架';
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
        this.shelfErrorText = `云端计划同步失败：${apiErr}`;
      }
      this.shelfContinueItems = createContinueItems(storeState, plans) as ShelfCardItem[];
      this.shelfHistoryItems = createHistoryItems(storeState, plans) as ShelfCardItem[];
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

  async openShelfItem(item: ShelfCardItem): Promise<void> {
    if (this.shelfEditMode) {
      this.toggleSelection(item.key);
      return;
    }
    if (item.sourceType === 'remote' && item.remoteBookId) {
      if (this.shelfMode === 'history') {
        openBookDetail(item.remoteBookId);
      } else {
        openReader(item.remoteBookId, item.chapterId || '');
      }
      return;
    }
    if (item.sourceType === 'local' && item.localBookKey) {
      const context = this.hostContext();
      if (!context) {
        this.shelfErrorText = '当前页面上下文不可用，无法打开本地书籍';
        return;
      }
      this.shelfBusyText = '正在打开本地书籍';
      this.shelfErrorText = '';
      try {
        await ShelfStore.openLocalBook(context, item.localBookKey);
        await this.loadShelfData(false);
        this.shelfBusyText = '本地书籍已打开';
      } catch (err) {
        this.shelfErrorText = `打开本地书籍失败：${err}`;
        this.shelfBusyText = '';
      }
    }
  }

  async importLocalBooks(): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法导入本地书籍';
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
        this.shelfBusyText = `已导入 ${result.imported.length} 本本地书籍`;
      } else {
        this.shelfBusyText = '所选书籍已在书架中';
      }
    } catch (err) {
      this.shelfErrorText = `导入本地书籍失败：${err}`;
      this.shelfBusyText = '';
    }
  }

  async manageShelfItem(item: ShelfCardItem): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法更新书架';
      return;
    }
    this.shelfBusyText = this.shelfMode === 'history' ? '正在删除阅读记录' : '正在从书架移除';
    this.shelfErrorText = '';
    try {
      if (this.shelfMode === 'history') {
        await ShelfStore.deleteHistoryRecords(context, [item.key]);
      } else {
        await ShelfStore.removeFromShelf(context, [item.key]);
      }
      await this.loadShelfData(false);
      this.shelfBusyText = this.shelfMode === 'history' ? '阅读记录已删除' : '已从书架移除';
      this.resetShelfModes();
    } catch (err) {
      this.shelfErrorText = `操作失败：${err}`;
      this.shelfBusyText = '';
    }
  }

  async commitSelectedShelfItems(): Promise<void> {
    if (this.selectedShelfKeys.length === 0) {
      this.shelfErrorText = this.shelfMode === 'history' ? '请先选择要删除的阅读记录' : '请先选择要移出的书籍';
      return;
    }
    const context = this.hostContext();
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法更新书架';
      return;
    }
    this.shelfBusyText = this.shelfMode === 'history' ? '正在批量删除阅读记录' : '正在批量移出书架';
    this.shelfErrorText = '';
    try {
      if (this.shelfMode === 'history') {
        await ShelfStore.deleteHistoryRecords(context, this.selectedShelfKeys);
      } else {
        await ShelfStore.removeFromShelf(context, this.selectedShelfKeys);
      }
      await this.loadShelfData(false);
      this.shelfBusyText = this.shelfMode === 'history' ? '批量删除完成' : '批量移出完成';
      this.resetShelfModes();
    } catch (err) {
      this.shelfErrorText = `批量操作失败：${err}`;
      this.shelfBusyText = '';
    }
  }

  toggleShelfMenu(): void {
    this.showShelfMenu = !this.showShelfMenu;
  }

  async addHistoryItemToShelf(item: ShelfCardItem): Promise<void> {
    if (item.sourceType !== 'remote' || !item.remoteBookId || item.inShelf) {
      return;
    }
    const context = this.hostContext();
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法加入书架';
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

  async startScan(): Promise<void> {
    const context = this.hostContext();
    this.showShelfMenu = false;
    if (!context) {
      this.shelfErrorText = '当前页面上下文不可用，无法启动扫一扫';
      return;
    }
    this.shelfBusyText = '正在打开扫一扫';
    this.shelfErrorText = '';
    try {
      const keyword: string = await this.pickScanKeyword(context);
      if (!keyword) {
        this.shelfBusyText = '';
        this.shelfErrorText = '未识别到可用于搜索的条码或文本';
        return;
      }
      this.shelfBusyText = '扫码成功，正在搜索图书';
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
      return this.uriToKeyword(result.resultUri);
    } catch (_) {
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
    Column() {
      Scroll() {
        Column() {
          Column({ space: this.sectionGap() }) {
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

  sectionGap(): number {
    return this.isCompact() ? 16 : 18;
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

  shelfCoverWidth(): number {
    if (this.isTabletLike()) {
      return 98;
    }
    if (this.isCompact()) {
      return 80;
    }
    return 90;
  }

  shelfCoverHeight(): number {
    return Math.floor(this.shelfCoverWidth() * 1.36);
  }

  titleSize(): number {
    if (this.pageWidth >= 900) {
      return 34;
    }
    if (this.isCompact()) {
      return 26;
    }
    return 30;
  }

  sidebarWidth(): number {
    if (this.isTabletLike()) {
      return 92;
    }
    return this.isCompact() ? 72 : 82;
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

  @Builder
  ActivePage() {
    if (this.activeTab === 0) {
      this.FunctionalShelfPage()
    } else if (this.activeTab === 1) {
      this.StorePage()
    } else if (this.activeTab === 2) {
      this.CategoryPage()
    } else if (this.activeTab === 3) {
      this.DiscoverPage()
    } else {
      this.ProfilePage()
    }
  }

  @Builder
  FunctionalShelfPage() {
    ShelfHomePanel({
      pageWidth: this.pageWidth,
      refreshSeed: this.shelfRefreshSeed,
    })
  }

  @Builder
  LegacyFunctionalShelfPage() {
    Column({ space: this.sectionGap() }) {
      Row({ space: 12 }) {
        Text('书架')
          .fontColor(Theme.mobileText)
          .fontSize(this.titleSize())
          .fontWeight(FontWeight.Bold)

        Row({ space: 10 }) {
          Image($r('app.media.discover_search'))
            .width(22)
            .height(22)
          Text('搜索书名 / 作者 / 关键词')
            .fontColor('#8C92A5')
            .fontSize(this.isCompact() ? 15 : 16)
          Blank()
        }
        .layoutWeight(1)
        .height(this.isCompact() ? 48 : 52)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Theme.mobileSurface)
        .borderRadius(26)
        .shadow({ radius: 16, color: '#18000000', offsetX: 0, offsetY: 8 })
        .onClick(() => {
          openSearch();
        })

        Stack() {
          this.CircleActionButton($r('app.media.mobile_more_circle'))
        }
        .onClick(() => {
          this.loadShelfData(true);
        })
      }
      .alignItems(VerticalAlign.Center)

      Row() {
        Row() {
          this.TopTextTab('继续阅读', this.shelfMode === 'continue', Theme.mobileRed)
        }
        .onClick(() => {
          this.updateShelfMode('continue');
        })
        Row() {
          this.TopTextTab('浏览记录', this.shelfMode === 'history', Theme.mobileBlue)
        }
        .onClick(() => {
          this.updateShelfMode('history');
        })
        Blank()
        Text(this.shelfManageMode ? '完成' : '管理')
          .fontColor(this.shelfManageMode ? Theme.mobileRed : Theme.mobileSubtext)
          .fontSize(16)
          .fontWeight(this.shelfManageMode ? FontWeight.Medium : FontWeight.Regular)
          .onClick(() => {
            this.toggleManageMode();
          })
        this.HeaderDivider()
        Text(this.shelfEditMode ? `删除(${this.selectedShelfKeys.length})` : '编辑')
          .fontColor(this.shelfEditMode ? Theme.mobileBlue : Theme.mobileSubtext)
          .fontSize(16)
          .fontWeight(this.shelfEditMode ? FontWeight.Medium : FontWeight.Regular)
          .onClick(() => {
            if (this.shelfEditMode && this.selectedShelfKeys.length > 0) {
              this.commitSelectedShelfItems();
            } else {
              this.toggleEditMode();
            }
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      if (this.shelfBusyText) {
        this.ShelfStatusBanner(this.shelfBusyText, Theme.mobileBlue)
      }
      if (this.shelfErrorText) {
        this.ShelfStatusBanner(this.shelfErrorText, Theme.mobileRed)
      }

      if (this.visibleShelfItems().length > 0) {
        ForEach(this.visibleShelfItems(), (item: ShelfCardItem) => {
          this.DynamicShelfBookCard(item)
        }, (item: ShelfCardItem) => item.key)
      } else {
        this.EmptyShelfCard()
      }

      if (this.shelfEditMode) {
        this.ShelfSelectionCard()
      }

      this.DynamicImportCard()
    }
    .width('100%')
  }

  @Builder
  DynamicShelfBookCard(item: ShelfCardItem) {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        this.BookPlaceholder(this.shelfCoverWidth(), this.shelfCoverHeight(), item.coverTone, item.sourceType === 'remote', true)
        if (this.shelfEditMode) {
          Stack() {
            this.ShelfSelectionBadge(this.isShelfSelected(item.key))
          }
          .margin({ left: 10, top: 10 })
        }
      }
      .onClick(() => {
        this.openShelfItem(item);
      })

      Column({ space: 10 }) {
        Row({ space: 12 }) {
          Column({ space: 8 }) {
            Text(item.title)
              .fontColor(Theme.mobileText)
              .fontSize(this.isCompact() ? 18 : 20)
              .fontWeight(FontWeight.Bold)
              .maxLines(2)
            Row({ space: 10 }) {
              Text(item.author)
                .fontColor(Theme.mobileSubtext)
                .fontSize(14)
                .maxLines(1)
              this.TagPill(item.tag, item.accent)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (!this.shelfManageMode && !this.shelfEditMode) {
            Row({ space: 6 }) {
              Text(item.actionLabel)
                .fontColor(item.sourceType === 'local' ? Theme.mobileBlue : Theme.mobileRed)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
              Image($r('app.media.icon_chevron_right'))
                .width(14)
                .height(14)
            }
            .margin({ top: 4 })
            .onClick(() => {
              this.openShelfItem(item);
            })
          }
        }
        .width('100%')

        if (this.shelfMode === 'continue') {
          Row({ space: 8 }) {
            Text(item.progressText)
              .fontColor(item.accent)
              .fontSize(this.isCompact() ? 16 : 17)
              .fontWeight(FontWeight.Bold)
            this.ProgressBar(item.progress, item.accent)
            this.MoreDots()
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        } else {
          Row({ space: 8 }) {
            Text(item.progressText)
              .fontColor(item.accent)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor('#F4F6FB')
              .borderRadius(12)
            Blank()
            Text(item.actionLabel)
              .fontColor(Theme.mobileSubtext)
              .fontSize(13)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }

        Text(item.lastRead)
          .fontColor(Theme.mobileSubtext)
          .fontSize(14)
          .maxLines(2)

        if (this.shelfManageMode) {
          Button(item.manageLabel)
            .height(34)
            .fontColor(Theme.mobileSurface)
            .backgroundColor(this.shelfMode === 'history' ? Theme.mobileRed : Theme.mobileBlue)
            .borderRadius(14)
            .padding({ left: 14, right: 14 })
            .onClick(() => {
              this.manageShelfItem(item);
            })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.openShelfItem(item);
      })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(24)
    .shadow({ radius: 18, color: '#18000000', offsetX: 0, offsetY: 10 })
  }

  @Builder
  DynamicImportCard() {
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
  ShelfSelectionCard() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(`已选择 ${this.selectedShelfKeys.length} 项`)
          .fontColor(Theme.mobileText)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(this.shelfMode === 'history' ? '批量删除阅读记录' : '批量把书籍移出书架')
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button(this.shelfMode === 'history' ? '删除选中' : '移出选中')
        .height(38)
        .fontColor(Theme.mobileSurface)
        .backgroundColor(this.selectedShelfKeys.length > 0 ? Theme.mobileBlue : '#C6CBD9')
        .borderRadius(16)
        .padding({ left: 16, right: 16 })
        .enabled(this.selectedShelfKeys.length > 0)
        .onClick(() => {
          this.commitSelectedShelfItems();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(22)
    .shadow({ radius: 16, color: '#14000000', offsetX: 0, offsetY: 8 })
  }

  @Builder
  ShelfStatusBanner(text: string, color: string) {
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
  ShelfSelectionBadge(selected: boolean) {
    Stack() {
      Circle()
        .width(22)
        .height(22)
        .fill(selected ? Theme.mobileBlue : Theme.mobileSurface)
        .border({ width: 1, color: selected ? Theme.mobileBlue : '#C7CDD9' })
      if (selected) {
        Text('√')
          .fontColor(Theme.mobileSurface)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width(22)
    .height(22)
  }

  @Builder
  ShelfPage() {
    Column({ space: this.sectionGap() }) {
      Row({ space: 12 }) {
        Text('书架')
          .fontColor(Theme.mobileText)
          .fontSize(this.titleSize())
          .fontWeight(FontWeight.Bold)

        Row({ space: 10 }) {
          Image($r('app.media.discover_search'))
            .width(22)
            .height(22)
          Text('搜索书名 / 作者')
            .fontColor('#8C92A5')
            .fontSize(this.isCompact() ? 15 : 16)
          Blank()
        }
        .layoutWeight(1)
        .height(this.isCompact() ? 48 : 52)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Theme.mobileSurface)
        .borderRadius(26)
        .shadow({ radius: 16, color: '#18000000', offsetX: 0, offsetY: 8 })

        this.CircleActionButton($r('app.media.mobile_more_circle'))
      }
      .alignItems(VerticalAlign.Center)

      Row() {
        this.TopTextTab('继续阅读', true, Theme.mobileRed)
        this.TopTextTab('浏览记录', false, Theme.mobileBlue)
        Blank()
        Text('管理')
          .fontColor(Theme.mobileSubtext)
          .fontSize(16)
        this.HeaderDivider()
        Text('编辑')
          .fontColor(Theme.mobileSubtext)
          .fontSize(16)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      ForEach(SHELF_BOOKS, (book: ShelfBook) => {
        this.ShelfBookCard(book)
      }, (book: ShelfBook) => `${book.id}`)

      this.ImportCard()
    }
    .width('100%')
  }

  @Builder
  StorePage() {
    Column({ space: this.sectionGap() }) {
      Row({ space: 12 }) {
        Text('书城')
          .fontColor(Theme.mobileText)
          .fontSize(this.titleSize())
          .fontWeight(FontWeight.Bold)

        Row({ space: 10 }) {
          Image($r('app.media.discover_search'))
            .width(22)
            .height(22)
          Text('搜索书名 / 作者 / 关键词')
            .fontColor('#B0B4C1')
            .fontSize(this.isCompact() ? 15 : 16)
          Blank()
        }
        .layoutWeight(1)
        .height(this.isCompact() ? 48 : 52)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Theme.mobileSurface)
        .border({ width: 1, color: Theme.mobileLine })
        .borderRadius(26)

        this.CircleActionButton($r('app.media.mobile_cart'))
      }
      .alignItems(VerticalAlign.Center)

      Row({ space: this.isCompact() ? 20 : 24 }) {
        this.TopTextTab('精选', true, Theme.mobileBlue)
        this.TopTextTab('男生', false, Theme.mobileBlue)
        this.TopTextTab('女生', false, Theme.mobileBlue)
        this.TopTextTab('出版', false, Theme.mobileBlue)
        this.TopTextTab('听书', false, Theme.mobileBlue)
        this.TopTextTab('漫画', false, Theme.mobileBlue)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)

      Column({ space: 18 }) {
        Row({ space: 14 }) {
          Stack() {
            Circle()
              .width(44)
              .height(44)
              .fill(Theme.mobileSurface)
            Text('AI')
              .fontColor(Theme.mobileText)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
          }
          .shadow({ radius: 14, color: '#15000000', offsetX: 0, offsetY: 6 })

          Row() {
            Text('你好！我是你的阅读助手，\n有什么书籍推荐或阅读问题可以问我～')
              .fontColor(Theme.mobileText)
              .fontSize(this.isCompact() ? 17 : 18)
              .fontWeight(FontWeight.Medium)
              .lineHeight(this.isCompact() ? 26 : 28)
          }
          .layoutWeight(1)
          .padding({ left: 18, right: 18, top: 16, bottom: 16 })
          .backgroundColor(Theme.mobileSurface)
          .borderRadius(20)
          .shadow({ radius: 16, color: '#18000000', offsetX: 0, offsetY: 8 })
        }
        .alignItems(VerticalAlign.Center)

        Text('今天想读点什么？')
          .fontColor(Theme.mobileText)
          .fontSize(this.isCompact() ? 17 : 18)
          .fontWeight(FontWeight.Medium)

        Row({ space: 10 }) {
          Text('输入书名、作者或关键词...')
            .fontColor('#C0C4D0')
            .fontSize(this.isCompact() ? 16 : 17)
          Blank()
          Stack() {
            Circle()
              .width(32)
              .height(32)
              .fill('#D2D4DB')
            Text('↑')
              .fontColor(Theme.mobileSurface)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('100%')
        .height(this.isCompact() ? 78 : 84)
        .padding({ left: 18, right: 16 })
        .backgroundColor(Theme.mobileSurface)
        .border({ width: 1, color: Theme.mobileLine })
        .borderRadius(18)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(24)
      .shadow({ radius: 20, color: '#18000000', offsetX: 0, offsetY: 10 })

      this.SectionTitle('重磅推荐', '换一批')

      ForEach(STORE_BOOKS, (book: StoreBook) => {
        this.StoreBookCard(book)
      }, (book: StoreBook) => `${book.id}`)

      this.StoreOfferCard()
    }
    .width('100%')
  }

  @Builder
  CategoryPage() {
    Column({ space: this.sectionGap() }) {
      Row() {
        Text('分类')
          .fontColor(Theme.mobileText)
          .fontSize(this.titleSize())
          .fontWeight(FontWeight.Bold)
        Blank()
        this.CircleActionButton($r('app.media.discover_search'), false)
      }
      .alignItems(VerticalAlign.Center)

      Row({ space: this.isCompact() ? 20 : 24 }) {
        ForEach(CATEGORY_TOP_FILTERS, (item: string, index: number) => {
          this.TopTextTab(item, index === 0, Theme.mobileBlue)
        }, (item: string) => item)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Row({ space: 14 }) {
        Column({ space: 8 }) {
          ForEach(CATEGORY_SIDE_MENU, (item: string, index: number) => {
            Row() {
              if (index === 0) {
                Blank()
                  .width(4)
                  .height(24)
                  .borderRadius(2)
                  .backgroundColor(Theme.mobileBlue)
              } else {
                Blank()
                  .width(4)
                  .height(24)
              }
              Text(item)
                .fontColor(index === 0 ? Theme.mobileBlue : Theme.mobileSubtext)
                .fontSize(15)
                .fontWeight(index === 0 ? FontWeight.Medium : FontWeight.Regular)
                .margin({ left: 10 })
            }
            .width('100%')
            .height(46)
            .padding({ left: 12, right: 12 })
            .backgroundColor(index === 0 ? Theme.mobileSurface : Theme.mobileSidebar)
            .borderRadius(14)
          }, (item: string) => item)
        }
        .width(this.sidebarWidth())

        Column({ space: 18 }) {
          this.CategoryTitle('按题材')
          ForEach(CATEGORY_SUBJECT_ROWS, (rowItems: CategorySubject[], index: number) => {
            Row({ space: 10 }) {
              this.SubjectTile(rowItems[0])
              this.SubjectTile(rowItems[1])
            }
            .width('100%')
          }, (rowItems: CategorySubject[], index: number) => `subject-row-${index}`)

          this.CategoryTitle('按风格')
          this.TagCloud(CATEGORY_STYLE_TAGS)

          this.CategoryTitle('按情节')
          this.TagCloud(CATEGORY_PLOT_TAGS)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
  }

  @Builder
  DiscoverPage() {
    Column({ space: this.sectionGap() }) {
      Row() {
        Text('发现')
          .fontColor(Theme.mobileText)
          .fontSize(this.titleSize())
          .fontWeight(FontWeight.Bold)
        Blank()
        this.CircleActionButton($r('app.media.discover_search'), false)
      }
      .alignItems(VerticalAlign.Center)

      Column({ space: 14 }) {
        Text('今日推荐')
          .fontColor(Theme.mobileText)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)

        Row({ space: 16 }) {
          this.BookPlaceholder(78, 108, '#F1EADF', false, false)

          Column({ space: 8 }) {
            Text('人类简史：从动物到上帝')
              .fontColor(Theme.mobileText)
              .fontSize(this.isCompact() ? 20 : 22)
              .fontWeight(FontWeight.Bold)
              .maxLines(2)
            Text('[以色列] 尤瓦尔·赫拉利')
              .fontColor(Theme.mobileSubtext)
              .fontSize(13)
            Text('8.9分')
              .fontColor(Theme.mobileOrange)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text('从认知革命、农业革命到科学革命，探索人类如何一步步走到今天。')
              .fontColor(Theme.mobileSubtext)
              .fontSize(13)
              .lineHeight(20)
              .maxLines(3)

            Row() {
              Text('立即阅读')
                .fontColor('#A57B41')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
            }
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor('#F4E6C7')
            .borderRadius(12)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFF7EC')
      .borderRadius(20)
      .shadow({ radius: 16, color: '#16000000', offsetX: 0, offsetY: 8 })

      Row() {
        ForEach(DISCOVER_QUICK_ACTIONS, (item: QuickAction) => {
          this.QuickActionItem(item)
        }, (item: QuickAction) => `${item.id}`)
      }
      .width('100%')

      this.SectionTitle('热门书单', '查看更多')
      ForEach(DISCOVER_LISTS, (item: DiscoverList) => {
        this.DiscoverListCard(item)
      }, (item: DiscoverList) => `${item.id}`)

      this.SectionTitle('热门活动', '查看更多')
      Column({ space: 10 }) {
        Image($r('app.media.discover_activity_banner'))
          .width('100%')
          .height(this.isCompact() ? 128 : 148)
          .objectFit(ImageFit.Cover)
          .borderRadius(18)
        Row() {
          Text('万卷共读 · 春日计划')
            .fontColor(Theme.mobileText)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text('立即参与')
            .fontColor('#9A7B46')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(20)
      .shadow({ radius: 16, color: '#15000000', offsetX: 0, offsetY: 8 })

      this.SectionTitle('猜你喜欢')
      Row({ space: 12 }) {
        this.MiniGuessCard('通识阅读', '从经典书单继续探索', '#EEF3FF')
        this.MiniGuessCard('成长计划', '按阶段挑选适合你的书', '#FFF2EA')
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  ProfilePage() {
    Column({ space: this.sectionGap() }) {
      Row({ space: 10 }) {
        this.IconOnlyButton($r('app.media.mobile_filter'))
        Row({ space: 6 }) {
          Circle()
            .width(8)
            .height(8)
            .fill('#91A8FF')
          Text('校园福利专区')
            .fontColor(Theme.mobileSubtext)
            .fontSize(15)
        }
        .padding({ left: 12, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#F2F4FF')
        .borderRadius(18)
        Blank()
        this.IconOnlyButton($r('app.media.profile_moon'))
        this.NotificationButton()
      }
      .alignItems(VerticalAlign.Center)

      Row({ space: 16 }) {
        Image($r('app.media.profile_avatar'))
          .width(88)
          .height(88)
          .borderRadius(44)
        Column({ space: 8 }) {
          Text('鸿蒙智阅同学')
            .fontColor(Theme.mobileText)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
          Row({ space: 8 }) {
            this.LevelBadge('Lv.6')
            this.LevelBadge('阅读成长中')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('>')
          .fontColor('#CFD3DE')
          .fontSize(26)
      }
      .alignItems(VerticalAlign.Center)

      Column({ space: 18 }) {
        Row() {
          Text('我的账户')
            .fontColor(Theme.mobileText)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          Blank()
          Text('更多')
            .fontColor('#B6BAC6')
            .fontSize(15)
        }

        Row() {
          this.AccountStat('12', '阅读积分')
          this.AccountStat('4', '进行中计划')
          this.AccountStat('18', '笔记')
          this.AccountStat('9', '收藏')
          Column() {
            Blank()
            Row() {
              Text('查看画像')
                .fontColor(Theme.mobileSurface)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
            }
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .backgroundColor(Theme.mobileRed)
            .borderRadius(18)
          }
          .alignItems(HorizontalAlign.End)
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(24)
      .shadow({ radius: 18, color: '#18000000', offsetX: 0, offsetY: 10 })

      Row() {
        Column({ space: 8 }) {
          Text('阅读成长计划')
            .fontColor('#8A622A')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
          Text('开通享受校园伴读、计划提醒和专题推荐权益')
            .fontColor('#B38A58')
            .fontSize(13)
            .maxLines(2)
        }
        .layoutWeight(1)
        Text('立即查看 >')
          .fontColor('#A27337')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 16 })
      .backgroundColor('#FFF2D9')
      .borderRadius(22)

      Column({ space: 14 }) {
        ForEach(PROFILE_SERVICE_ROWS, (rowItems: ProfileService[], index: number) => {
          Row({ space: 14 }) {
            this.ProfileServiceCard(rowItems[0])
            this.ProfileServiceCard(rowItems[1])
          }
          .width('100%')
        }, (rowItems: ProfileService[], index: number) => `service-${index}`)
      }
      .width('100%')

      Column({ space: 18 }) {
        Row() {
          ForEach(PROFILE_TOOLS.slice(0, 4), (item: ProfileTool) => {
            this.ProfileToolItem(item)
          }, (item: ProfileTool) => item.title)
        }
        .width('100%')

        Row() {
          ForEach(PROFILE_TOOLS.slice(4, 8), (item: ProfileTool) => {
            this.ProfileToolItem(item)
          }, (item: ProfileTool) => item.title)
        }
        .width('100%')

        Row({ space: 8 }) {
          Circle()
            .width(8)
            .height(8)
            .fill(Theme.mobileRed)
          Circle()
            .width(8)
            .height(8)
            .fill('#D9DCE5')
        }
        .justifyContent(FlexAlign.Center)

        Row({ space: 12 }) {
          this.BookPlaceholder(52, 52, '#FFF0EC', false, false)
          Text('阅读计划打卡、笔记沉淀、收藏整理都能在这里继续推进。')
            .fontColor(Theme.mobileText)
            .fontSize(14)
            .lineHeight(22)
            .layoutWeight(1)
          Text('>')
            .fontColor('#CBD0DD')
            .fontSize(22)
        }
        .padding(14)
        .backgroundColor(Theme.mobileSurfaceSoft)
        .borderRadius(16)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(24)
      .shadow({ radius: 18, color: '#18000000', offsetX: 0, offsetY: 10 })

      Row({ space: 12 }) {
        this.IconOnlyButton($r('app.media.profile_help'))
        Text('帮助与反馈')
          .fontColor(Theme.mobileText)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('>')
          .fontColor('#CBD0DD')
          .fontSize(22)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 18 })
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(22)
      .shadow({ radius: 16, color: '#15000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%')
  }

  @Builder
  TopTextTab(label: string, selected: boolean, accent: string) {
    Column({ space: 8 }) {
      Text(label)
        .fontColor(selected ? Theme.mobileText : Theme.mobileSubtext)
        .fontSize(this.isCompact() ? 15 : 16)
        .fontWeight(selected ? FontWeight.Bold : FontWeight.Medium)
      Blank()
        .width(selected ? 28 : 0)
        .height(4)
        .borderRadius(2)
        .backgroundColor(selected ? accent : Theme.mobileCanvas)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  HeaderDivider() {
    Blank()
      .width(1)
      .height(16)
      .backgroundColor(Theme.mobileLine)
      .margin({ left: 14, right: 14 })
  }

  @Builder
  CircleActionButton(icon: Resource, withShadow: boolean = true) {
    Stack() {
      Circle()
        .width(46)
        .height(46)
        .fill(Theme.mobileSurface)
      Image(icon)
        .width(22)
        .height(22)
    }
    .width(46)
    .height(46)
    .shadow(withShadow ? { radius: 14, color: '#15000000', offsetX: 0, offsetY: 6 } : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })
  }

  @Builder
  IconOnlyButton(icon: Resource) {
    Stack() {
      Circle()
        .width(40)
        .height(40)
        .fill(Theme.mobileSurface)
      Image(icon)
        .width(20)
        .height(20)
    }
    .width(40)
    .height(40)
  }

  @Builder
  NotificationButton() {
    Stack({ alignContent: Alignment.TopEnd }) {
      this.IconOnlyButton($r('app.media.mobile_bell'))
      Circle()
        .width(8)
        .height(8)
        .fill(Theme.mobileRed)
        .margin({ top: 4, right: 4 })
    }
  }

  @Builder
  ShelfBookCard(book: ShelfBook) {
    Row({ space: 14 }) {
      this.BookPlaceholder(this.shelfCoverWidth(), this.shelfCoverHeight(), book.coverTone, true, true)

      Column({ space: 10 }) {
        Row({ space: 12 }) {
          Column({ space: 8 }) {
            Text(book.title)
              .fontColor(Theme.mobileText)
              .fontSize(this.isCompact() ? 18 : 20)
              .fontWeight(FontWeight.Bold)
              .maxLines(2)
            Row({ space: 10 }) {
              Text(book.author)
                .fontColor(Theme.mobileSubtext)
                .fontSize(14)
              this.TagPill(book.tag, book.accent)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Row({ space: 6 }) {
            Text('继续阅读')
              .fontColor(Theme.mobileRed)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            Image($r('app.media.icon_chevron_right'))
              .width(14)
              .height(14)
          }
          .margin({ top: 4 })
        }
        .width('100%')

        Row({ space: 8 }) {
          Text(`${book.progress}%`)
            .fontColor(book.accent)
            .fontSize(this.isCompact() ? 17 : 18)
            .fontWeight(FontWeight.Bold)
          this.ProgressBar(book.progress, book.accent)
          this.MoreDots()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(book.lastRead)
          .fontColor(Theme.mobileSubtext)
          .fontSize(14)
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(24)
    .shadow({ radius: 18, color: '#18000000', offsetX: 0, offsetY: 10 })
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
        Text('支持 TXT / EPUB / PDF 等格式')
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
  }

  @Builder
  BookPlaceholder(widthValue: number, heightValue: number, tone: string, showRibbon: boolean, strongGlow: boolean) {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column()
          .width(widthValue)
          .height(heightValue)
          .backgroundColor(tone)
          .borderRadius(16)
          .border({ width: 1, color: '#F0F1F5' })

        Circle()
          .width(widthValue * 0.72)
          .height(widthValue * 0.72)
          .fill(strongGlow ? '#FFFFFF' : '#F9FAFD')
          .opacity(0.75)
          .margin({ right: 10, bottom: 10 })

        Column({ space: 7 }) {
          Blank()
            .width(widthValue * 0.56)
            .height(5)
            .borderRadius(3)
            .backgroundColor('#FFFFFF')
            .opacity(0.82)
          Blank()
            .width(widthValue * 0.42)
            .height(5)
            .borderRadius(3)
            .backgroundColor('#FFFFFF')
            .opacity(0.65)
        }
        .width(widthValue)
        .height(heightValue)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 14 })
      }

      if (showRibbon) {
        Text('在读')
          .fontColor(Theme.mobileSurface)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(Theme.mobileRed)
          .borderRadius({ topLeft: 16, bottomRight: 12 })
      }
    }
    .width(widthValue)
    .height(heightValue)
  }

  @Builder
  TagPill(label: string, accent: string) {
    Text(label)
      .fontColor(accent)
      .fontSize(13)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('#F7F6FF')
      .borderRadius(12)
  }

  @Builder
  ProgressBar(progress: number, accent: string) {
    Stack({ alignContent: Alignment.Start }) {
      Row() {
      }
        .width('100%')
        .height(4)
        .borderRadius(2)
        .backgroundColor('#ECEFF6')
      Row() {
      }
        .width(`${progress}%`)
        .height(4)
        .borderRadius(2)
        .backgroundColor(accent)
    }
    .layoutWeight(1)
    .height(4)
  }

  @Builder
  MoreDots() {
    Row({ space: 4 }) {
      Circle()
        .width(4)
        .height(4)
        .fill('#B8BDCB')
      Circle()
        .width(4)
        .height(4)
        .fill('#B8BDCB')
      Circle()
        .width(4)
        .height(4)
        .fill('#B8BDCB')
    }
    .margin({ left: 8 })
  }

  @Builder
  SectionTitle(title: string, action: string = '') {
    Row() {
      Text(title)
        .fontColor(Theme.mobileText)
        .fontSize(this.isCompact() ? 26 : 28)
        .fontWeight(FontWeight.Bold)
      Blank()
      if (action) {
        Row({ space: 6 }) {
          Text(action)
            .fontColor(Theme.mobileSubtext)
            .fontSize(15)
          if (action === '换一批') {
            Text('C')
              .fontColor(Theme.mobileSubtext)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
          } else {
            Image($r('app.media.icon_chevron_right'))
              .width(14)
              .height(14)
          }
        }
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  StoreBookCard(book: StoreBook) {
    Row({ space: 16 }) {
      this.BookPlaceholder(82, 118, book.coverTone, false, false)

      Column({ space: 8 }) {
        Text(book.title)
          .fontColor(Theme.mobileText)
          .fontSize(this.isCompact() ? 18 : 20)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
        Text(book.author)
          .fontColor(Theme.mobileSubtext)
          .fontSize(15)
        Text(book.score)
          .fontColor(Theme.mobileOrange)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Text(book.quote)
          .fontColor(Theme.mobileSubtext)
          .fontSize(14)
          .lineHeight(22)
          .maxLines(book.tags ? 2 : 3)

        if (book.tags && book.tags.length > 0) {
          Row({ space: 8 }) {
            ForEach(book.tags, (tag: string) => {
              Text(tag)
                .fontColor(Theme.mobileSubtext)
                .fontSize(13)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor('#F4F5F8')
                .borderRadius(12)
            }, (tag: string) => tag)
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
  }

  @Builder
  StoreOfferCard() {
    Column({ space: 16 }) {
      Row() {
        Text('今日限时特惠')
          .fontColor('#7C4A1F')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank()
        Row({ space: 6 }) {
          Text('剩余')
            .fontColor('#B98A5A')
            .fontSize(14)
          this.TimerBox('08')
          Text(':')
            .fontColor('#A07346')
            .fontSize(16)
          this.TimerBox('36')
          Text(':')
            .fontColor('#A07346')
            .fontSize(16)
          this.TimerBox('45')
        }
      }

      Row({ space: 16 }) {
        this.BookPlaceholder(86, 110, '#FFE7D5', false, false)

        Column({ space: 10 }) {
          Text('时间的玫瑰（全集）')
            .fontColor(Theme.mobileText)
            .fontSize(this.isCompact() ? 20 : 22)
            .fontWeight(FontWeight.Bold)
          Text('但德')
            .fontColor(Theme.mobileSubtext)
            .fontSize(15)
          Row({ space: 10 }) {
            Text('¥19.99')
              .fontColor(Theme.mobileOrange)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
            Text('¥59.99')
              .fontColor('#C1B5B0')
              .fontSize(16)
              .decoration({ type: TextDecorationType.LineThrough, color: '#C1B5B0' })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFF4EC')
    .borderRadius(22)
  }

  @Builder
  TimerBox(text: string) {
    Text(text)
      .fontColor('#865325')
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(10)
  }

  @Builder
  CategoryTitle(title: string) {
    Text(title)
      .fontColor(Theme.mobileText)
      .fontSize(20)
      .fontWeight(FontWeight.Bold)
  }

  @Builder
  SubjectTile(subject: CategorySubject) {
    Row({ space: 10 }) {
      this.BookPlaceholder(this.isCompact() ? 34 : 38, this.isCompact() ? 42 : 46, subject.coverTone, false, false)
      Text(subject.title)
        .fontColor(Theme.mobileText)
        .fontSize(this.isCompact() ? 14 : 15)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
    }
    .layoutWeight(1)
    .padding({ left: 10, right: 10, top: 10, bottom: 10 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(14)
  }

  @Builder
  TagCloud(tags: string[]) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(tags, (tag: string) => {
        Text(tag)
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(Theme.mobileSurface)
          .borderRadius(12)
          .margin({ right: 10, bottom: 10 })
      }, (tag: string) => tag)
    }
    .width('100%')
  }

  @Builder
  QuickActionItem(item: QuickAction) {
    Column({ space: 10 }) {
      Image(item.icon)
        .width(this.isCompact() ? 46 : 50)
        .height(this.isCompact() ? 46 : 50)
      Text(item.label)
        .fontColor(Theme.mobileSubtext)
        .fontSize(14)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  DiscoverListCard(item: DiscoverList) {
    Row({ space: 14 }) {
      this.BookPlaceholder(68, 90, item.coverTone, false, false)

      Column({ space: 6 }) {
        Text(item.title)
          .fontColor(Theme.mobileText)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Text(item.count)
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
        Text(item.saved)
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text('收藏')
          .fontColor(Theme.mobileBlue)
          .fontSize(13)
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .border({ width: 1, color: '#DCE6FF' })
      .borderRadius(14)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(18)
    .shadow({ radius: 12, color: '#10000000', offsetX: 0, offsetY: 4 })
  }

  @Builder
  MiniGuessCard(title: string, subtitle: string, tone: string) {
    Column({ space: 12 }) {
      this.BookPlaceholder(90, 60, tone, false, false)
      Text(title)
        .fontColor(Theme.mobileText)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      Text(subtitle)
        .fontColor(Theme.mobileSubtext)
        .fontSize(13)
        .lineHeight(20)
        .maxLines(2)
    }
    .layoutWeight(1)
    .padding(14)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(18)
    .shadow({ radius: 12, color: '#10000000', offsetX: 0, offsetY: 4 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  LevelBadge(text: string) {
    Text(text)
      .fontColor('#7A7E8B')
      .fontSize(13)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor('#F2F3F7')
      .borderRadius(10)
  }

  @Builder
  AccountStat(value: string, label: string) {
    Column({ space: 8 }) {
      Text(value)
        .fontColor(Theme.mobileText)
        .fontSize(this.isCompact() ? 24 : 28)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontColor(Theme.mobileSubtext)
        .fontSize(14)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProfileServiceCard(item: ProfileService) {
    Row({ space: 12 }) {
      Image(item.icon)
        .width(42)
        .height(42)
      Column({ space: 5 }) {
        Text(item.title)
          .fontColor(Theme.mobileText)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Text(item.subtitle)
          .fontColor(Theme.mobileSubtext)
          .fontSize(13)
          .lineHeight(20)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .padding(16)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(22)
    .shadow({ radius: 14, color: '#12000000', offsetX: 0, offsetY: 6 })
  }

  @Builder
  ProfileToolItem(item: ProfileTool) {
    Column({ space: 10 }) {
      Image(item.icon)
        .width(28)
        .height(28)
      Text(item.title)
        .fontColor(Theme.mobileText)
        .fontSize(14)
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
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
