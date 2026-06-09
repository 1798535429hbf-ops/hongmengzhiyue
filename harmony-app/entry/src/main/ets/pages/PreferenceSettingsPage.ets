import { ApiClient } from '../common/ApiClient';
import { APP_DARK_MODE_KEY, APP_FONT_FAMILY_KEY, AppSettings } from '../common/AppSettings';
import { Book, BookTagsBundle, UserProfile, emptyProfile } from '../common/Models';
import { goBack } from '../common/Navigation';
import { UserSession } from '../common/UserSession';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct PreferenceSettingsPage {
  @State pageWidth: number = 390;
  @State activeTab: number = 0;
  @State profile: UserProfile = emptyProfile();
  @State selectedTags: string[] = [];
  @State studyTags: string[] = [];
  @State readingTags: string[] = [];
  @State tagKeyword: string = '';
  @State busyText: string = '';
  @State errorText: string = '';
  @State toastText: string = '';
  @State showToast: boolean = false;
  @StorageLink(APP_DARK_MODE_KEY) darkMode: boolean = false;
  @StorageLink(APP_FONT_FAMILY_KEY) fontFamily: string = 'system';

  aboutToAppear(): void {
    this.loadPreferencePage();
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

  appFont(): string {
    return AppSettings.fontFamilyValue(this.fontFamily);
  }

  currentTags(): string[] {
    return this.activeTab === 0 ? this.studyTags : this.readingTags;
  }

  tabTitle(): string {
    return this.activeTab === 0 ? '学习标签' : '通识标签';
  }

  filteredTags(): string[] {
    const tags = this.currentTags();
    const keyword = this.tagKeyword.trim();
    if (!keyword) {
      return tags;
    }
    const result: string[] = [];
    for (let i = 0; i < tags.length; i++) {
      if (tags[i].indexOf(keyword) >= 0) {
        result.push(tags[i]);
      }
    }
    return result;
  }

  hasTag(tag: string): boolean {
    return this.selectedTags.indexOf(tag) >= 0;
  }

  splitTags(value: string): string[] {
    const raw = value ? value.split(/[，,、\/\s]+/) : [];
    const next: string[] = [];
    for (let i = 0; i < raw.length; i++) {
      const tag = raw[i].trim();
      if (tag && next.indexOf(tag) < 0) {
        next.push(tag);
      }
    }
    return next;
  }

  normalizeTags(tags: string[]): string[] {
    const next: string[] = [];
    for (let i = 0; i < tags.length; i++) {
      const tag = (tags[i] || '').trim();
      if (tag && next.indexOf(tag) < 0) {
        next.push(tag);
      }
    }
    return next;
  }

  isStudyTag(tag: string): boolean {
    const keywords: string[] = [
      '计算机', '人工智能', 'AI', '算法', '机器学习', '深度学习', '智能体', '编程',
      '数据库', '系统', 'Linux', 'Java', 'Python', 'Go', '数学', '统计', '概率',
      '线性代数', '微积分', '英语', '考研', '备考', '六级', '课程', '专业', '竞赛',
      '科研', '方法', '经管', '经济管理', '管理', '设计', '学习', '教材', '入门',
      '进阶', '基础',
    ];
    for (let i = 0; i < keywords.length; i++) {
      if (tag.indexOf(keywords[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  addExtractedTag(tag: string, study: string[], general: string[], all: string[]): void {
    const clean = tag.trim();
    if (!clean || clean === '男生向' || clean === '女生向' || clean === '本地导入' || clean === '可读' || clean === 'AI伴读') {
      return;
    }
    if (all.indexOf(clean) < 0) {
      all.push(clean);
    }
    const target = this.isStudyTag(clean) ? study : general;
    if (target.indexOf(clean) < 0) {
      target.push(clean);
    }
  }

  extractTagsFromBooks(books: Book[]): BookTagsBundle {
    const study: string[] = [];
    const general: string[] = [];
    const all: string[] = [];
    for (let i = 0; i < books.length; i++) {
      if (books[i].category) {
        this.addExtractedTag(books[i].category || '', study, general, all);
      }
      const tags = this.splitTags(books[i].tags || '');
      for (let j = 0; j < tags.length; j++) {
        this.addExtractedTag(tags[j], study, general, all);
      }
    }
    return { study, general, all };
  }

  async loadDatabaseTags(): Promise<void> {
    try {
      const bundle: BookTagsBundle = await ApiClient.bookTags();
      this.studyTags = this.normalizeTags(bundle.study || []);
      this.readingTags = this.normalizeTags(bundle.general || []);
      if (this.studyTags.length > 0 || this.readingTags.length > 0) {
        return;
      }
    } catch (_) {
    }
    const firstPage = await ApiClient.searchBooks('', '', 0, 50);
    const secondPage = await ApiClient.searchBooks('', '', 1, 50);
    const bundle = this.extractTagsFromBooks(firstPage.concat(secondPage));
    this.studyTags = this.normalizeTags(bundle.study);
    this.readingTags = this.normalizeTags(bundle.general);
  }

  async loadPreferencePage(): Promise<void> {
    const userId = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先登录后再设置偏好';
      this.profile = emptyProfile();
      this.selectedTags = [];
      return;
    }
    this.busyText = '正在加载偏好';
    this.errorText = '';
    try {
      const bundle = await ApiClient.profile(userId);
      this.profile = bundle.profile || UserSession.currentProfile() || emptyProfile();
      this.selectedTags = this.splitTags(this.profile.interests || '');
      await this.loadDatabaseTags();
    } catch (err) {
      this.profile = UserSession.currentProfile() || emptyProfile();
      this.selectedTags = this.splitTags(this.profile.interests || '');
      this.errorText = `偏好加载失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  toggleTag(tag: string): void {
    const next = this.selectedTags.slice();
    const index = next.indexOf(tag);
    if (index >= 0) {
      next.splice(index, 1);
    } else {
      next.push(tag);
    }
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.selectedTags = next;
    });
  }

  clearTags(): void {
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.selectedTags = [];
    });
  }

  async savePreference(): Promise<void> {
    const context = this.hostContext();
    const userId = UserSession.currentUserId();
    if (!context || userId <= 0) {
      this.flashToast('请先登录');
      return;
    }
    this.busyText = '正在保存偏好';
    this.errorText = '';
    try {
      const draft: UserProfile = {
        id: userId,
        account: this.profile.account || String(userId),
        phone: this.profile.phone || '',
        email: this.profile.email || '',
        name: this.profile.name || this.profile.nickname || '智阅同学',
        nickname: this.profile.nickname || this.profile.name || '智阅同学',
        major: this.profile.major || '',
        grade: this.profile.grade || '',
        interests: this.selectedTags.join(','),
        goal: this.profile.goal || '',
        intro: this.profile.intro || '',
        avatarUrl: this.profile.avatarUrl || '',
        channels: this.profile.channels || 'library,jd,dangdang,second_hand',
      };
      const saved = await ApiClient.saveProfile(draft);
      this.profile = saved;
      this.selectedTags = this.splitTags(saved.interests || '');
      await UserSession.persist(context, saved);
      this.flashToast('偏好已保存');
    } catch (err) {
      this.errorText = `保存偏好失败：${err}`;
    } finally {
      this.busyText = '';
    }
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
            if (this.errorText) { this.StatusBanner(this.errorText, '#D94242') }
            if (this.busyText) { this.StatusBanner(this.busyText, this.accent()) }
            this.SegmentControl()
            this.SearchField()
            this.TagSection()
            this.SelectedSection()
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 36 })
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
      Text('偏好设置')
        .fontColor(this.text())
        .fontSize(this.isCompact() ? 21 : 24)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('保存')
        .fontColor(this.accent())
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .width(52)
        .textAlign(TextAlign.End)
        .onClick(() => this.savePreference())
    }
    .width('100%')
    .height(92)
    .padding({ left: 12, right: 18, top: 24 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SegmentControl() {
    Row({ space: 0 }) {
      this.SegmentItem('学习', 0)
      this.SegmentItem('通识', 1)
    }
    .width('100%')
    .height(42)
    .padding(3)
    .backgroundColor(this.darkMode ? '#111722' : '#E9EBF0')
    .borderRadius(13)
  }

  @Builder
  SegmentItem(label: string, index: number) {
    Text(label)
      .fontColor(this.activeTab === index ? this.text() : this.subtext())
      .fontSize(16)
      .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Regular)
      .layoutWeight(1)
      .height(36)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.activeTab === index ? this.surface() : 'transparent')
      .borderRadius(10)
      .shadow(this.activeTab === index ? { radius: 8, color: '#14000000', offsetX: 0, offsetY: 2 } : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })
      .onClick(() => {
        animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          this.activeTab = index;
        });
      })
  }

  @Builder
  SearchField() {
    Column({ space: 10 }) {
      Row() {
        Text(this.tabTitle())
          .fontColor(this.text())
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(`${this.filteredTags().length}`)
          .fontColor(this.subtext())
          .fontSize(14)
      }
      .width('100%')
      TextInput({ placeholder: '搜索数据库标签', text: this.tagKeyword })
        .height(42)
        .fontColor(this.text())
        .fontSize(15)
        .placeholderColor(this.subtext())
        .backgroundColor(this.fieldBg())
        .borderRadius(12)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => { this.tagKeyword = value; })
    }
    .width('100%')
    .padding({ top: 8 })
  }

  @Builder
  TagSection() {
    Column({ space: 12 }) {
      if (this.filteredTags().length === 0 && !this.busyText) {
        Text(this.tagKeyword ? '没有匹配的数据库标签' : '数据库暂无可选标签')
          .fontColor(this.subtext())
          .fontSize(15)
          .width('100%')
          .height(72)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.surface())
          .borderRadius(16)
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.filteredTags(), (tag: string) => {
            this.TagPill(tag)
          }, (tag: string) => tag)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  TagPill(tag: string) {
    Text(tag)
      .fontColor(this.hasTag(tag) ? '#FFFFFF' : this.text())
      .fontSize(15)
      .fontWeight(this.hasTag(tag) ? FontWeight.Medium : FontWeight.Regular)
      .height(38)
      .padding({ left: 15, right: 15 })
      .textAlign(TextAlign.Center)
      .backgroundColor(this.hasTag(tag) ? this.accent() : this.surface())
      .border({ width: this.hasTag(tag) ? 0 : 0.5, color: this.line() })
      .borderRadius(19)
      .margin({ right: 8, bottom: 10 })
      .scale({ x: this.hasTag(tag) ? 1.02 : 1, y: this.hasTag(tag) ? 1.02 : 1 })
      .onClick(() => this.toggleTag(tag))
  }

  @Builder
  SelectedSection() {
    Column({ space: 14 }) {
      Row() {
        Text('已选偏好')
          .fontColor(this.text())
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(this.selectedTags.length > 0 ? '清空' : '')
          .fontColor(this.accent())
          .fontSize(15)
          .onClick(() => this.clearTags())
      }
      .width('100%')
      if (this.selectedTags.length === 0) {
        Text('从上方数据库标签中添加兴趣')
          .fontColor(this.subtext())
          .fontSize(15)
          .width('100%')
          .height(58)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.surface())
          .borderRadius(16)
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.selectedTags, (tag: string) => {
            Text(`${tag} ×`)
              .fontColor(this.accent())
              .fontSize(15)
              .height(36)
              .padding({ left: 13, right: 13 })
              .textAlign(TextAlign.Center)
              .backgroundColor(this.darkMode ? '#123255' : '#E8F2FF')
              .borderRadius(18)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => this.toggleTag(tag))
          }, (tag: string) => tag)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.surface())
    .borderRadius(20)
  }

  @Builder
  StatusBanner(text: string, color: string) {
    Text(text)
      .fontColor('#FFFFFF')
      .fontSize(13)
      .lineHeight(18)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(color)
      .borderRadius(12)
      .width('100%')
  }
}
