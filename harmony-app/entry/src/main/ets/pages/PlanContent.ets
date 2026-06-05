import { ApiClient } from '../common/ApiClient';
import { Book, PlanItem, ReadingDayStat, ReadingStats } from '../common/Models';
import { openReader } from '../common/Navigation';
import { Theme } from '../common/Theme';
import { UserSession } from '../common/UserSession';

interface PlanDay {
  id: number;
  week: string;
  day: string;
  state: string;
}

const PLAN_GREEN: string = '#4DB879';
const PLAN_GREEN_DARK: string = '#268957';
const PLAN_BG: string = '#F6F8F7';
const PLAN_TEXT: string = '#161A22';
const PLAN_MUTED: string = '#8B92A0';

@Component
export struct PlanContent {
  @Prop @Watch('onRefreshSeedChange') refreshSeed: number = 0;
  @Prop pageWidth: number = 390;
  @State plans: PlanItem[] = [];
  @State loading: boolean = false;
  @State errorText: string = '';
  @State selectedPlanId: number = 0;
  @State todayReadingSeconds: number = 0;
  @State weekReadingSeconds: number = 0;
  @State showCreatePlan: boolean = false;
  @State planCandidates: Book[] = [];
  @State loadingCandidates: boolean = false;
  @State selectedBookId: number = 0;
  @State selectedTargetDays: number = 14;
  @State creatingPlan: boolean = false;
  @State createPlanError: string = '';
  @State showPlanSettings: boolean = false;
  @State editingPlanId: number = 0;
  @State editingDailyMinutes: number = 30;
  @State editingWeeklyMinutes: number = 210;
  @State savingPlanSettings: boolean = false;
  @State planSettingsError: string = '';

  aboutToAppear(): void {
    this.loadPlans();
  }

  onRefreshSeedChange(): void {
    this.loadPlans();
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  cardRadius(): number {
    return this.isCompact() ? 18 : 22;
  }

  currentPlan(): PlanItem | null {
    if (this.plans.length === 0) {
      return null;
    }
    if (this.selectedPlanId > 0) {
      for (let i = 0; i < this.plans.length; i++) {
        if (this.plans[i].id === this.selectedPlanId) {
          return this.plans[i];
        }
      }
    }
    for (let i = 0; i < this.plans.length; i++) {
      const item = this.plans[i];
      if (item.status !== 'finished' && this.planProgress(item) < 100) {
        return item;
      }
    }
    return this.plans[0];
  }

  heroDays(): number {
    const plan = this.currentPlan();
    return plan ? Math.max(1, plan.targetDays) : 21;
  }

  planProgress(plan: PlanItem | null): number {
    if (!plan) {
      return 0;
    }
    return Math.max(0, Math.min(100, Math.round(plan.progress || 0)));
  }

  completedDays(): number {
    const plan = this.currentPlan();
    if (!plan) {
      return 0;
    }
    return Math.min(plan.targetDays, Math.round(plan.targetDays * this.planProgress(plan) / 100));
  }

  remainingDays(): number {
    const plan = this.currentPlan();
    if (!plan) {
      return 0;
    }
    return Math.max(0, plan.targetDays - this.completedDays());
  }

  finishedBookCount(): number {
    let count = 0;
    for (let i = 0; i < this.plans.length; i++) {
      if (this.plans[i].status === 'finished' || this.planProgress(this.plans[i]) >= 100) {
        count++;
      }
    }
    return count;
  }

  activePlanCount(): number {
    let count = 0;
    for (let i = 0; i < this.plans.length; i++) {
      if (this.plans[i].status !== 'finished' && this.planProgress(this.plans[i]) < 100) {
        count++;
      }
    }
    return count;
  }

  statusText(plan: PlanItem | null): string {
    if (!plan) {
      return '等待创建';
    }
    if (plan.status === 'finished' || this.planProgress(plan) >= 100) {
      return '今日已完成';
    }
    return '继续阅读';
  }

  statusColor(plan: PlanItem | null): string {
    if (plan && (plan.status === 'finished' || this.planProgress(plan) >= 100)) {
      return PLAN_GREEN;
    }
    return '#E6A23C';
  }

  progressWidth(plan: PlanItem | null, maxWidth: number): number {
    return Math.max(8, Math.round(maxWidth * this.planProgress(plan) / 100));
  }

  progressTrackWidth(): number {
    return this.pageWidth >= 600 ? 520 : Math.max(230, this.pageWidth - 92);
  }

  miniTrackWidth(): number {
    return this.pageWidth >= 600 ? 360 : Math.max(150, this.pageWidth - 200);
  }

  planDailyTarget(plan: PlanItem | null): number {
    return Math.max(1, Math.round(plan?.dailyMinutesTarget || 30));
  }

  planWeeklyTarget(plan: PlanItem | null): number {
    return Math.max(1, Math.round(plan?.weeklyMinutesTarget || this.planDailyTarget(plan) * 7));
  }

  editingPlan(): PlanItem | null {
    for (let i = 0; i < this.plans.length; i++) {
      if (this.plans[i].id === this.editingPlanId) {
        return this.plans[i];
      }
    }
    return null;
  }

  calendarDays(): PlanDay[] {
    const labels: string[] = ['一', '二', '三', '四', '五', '六', '日'];
    const today = new Date();
    const day = today.getDay() === 0 ? 7 : today.getDay();
    const start = new Date(today.getFullYear(), today.getMonth(), today.getDate() - day + 1);
    const completed = this.completedDays();
    const days: PlanDay[] = [];
    for (let i = 0; i < 7; i++) {
      const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
      let state = 'future';
      if (i < day - 1 && i < completed) {
        state = 'done';
      } else if (i === day - 1) {
        state = 'today';
      }
      days.push({ id: i, week: labels[i], day: `${date.getDate()}`, state });
    }
    return days;
  }

  async loadPlans(): Promise<void> {
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.plans = [];
      this.errorText = '请先在“我的”页面登录后查看阅读计划。';
      return;
    }

    this.loading = true;
    this.errorText = '';
    try {
      const items: PlanItem[] = await ApiClient.listPlans(userId);
      this.plans = items || [];
      try {
        const stats: ReadingStats = await ApiClient.readingStats(userId);
        this.todayReadingSeconds = Math.max(0, Math.round(stats.todaySeconds || 0));
        this.weekReadingSeconds = this.sumWeekSeconds(stats.dailySeconds || []);
      } catch (_) {
        this.todayReadingSeconds = 0;
        this.weekReadingSeconds = 0;
      }
      if (this.plans.length > 0 && this.selectedPlanId <= 0) {
        const first = this.currentPlan();
        this.selectedPlanId = first ? first.id : this.plans[0].id;
      }
    } catch (err) {
      this.plans = [];
      this.errorText = `阅读计划加载失败：${err}`;
    } finally {
      this.loading = false;
    }
  }

  openCurrentPlan(): void {
    const plan = this.currentPlan();
    if (plan && plan.bookId > 0) {
      openReader(plan.bookId);
    }
  }

  async openCreatePlan(): Promise<void> {
    this.showCreatePlan = true;
    this.createPlanError = '';
    if (this.planCandidates.length > 0) {
      return;
    }
    this.loadingCandidates = true;
    try {
      const books: Book[] = await ApiClient.searchBooks('', '', 0, 12);
      this.planCandidates = books || [];
      if (this.planCandidates.length > 0 && this.selectedBookId <= 0) {
        this.selectedBookId = this.planCandidates[0].id;
      }
    } catch (err) {
      this.createPlanError = `候选图书加载失败：${err}`;
      this.planCandidates = [];
    } finally {
      this.loadingCandidates = false;
    }
  }

  closeCreatePlan(): void {
    if (this.creatingPlan) {
      return;
    }
    this.showCreatePlan = false;
    this.createPlanError = '';
  }

  selectPlanBook(bookId: number): void {
    this.selectedBookId = bookId;
    this.createPlanError = '';
  }

  setTargetDays(days: number): void {
    this.selectedTargetDays = days;
  }

  async submitCreatePlan(): Promise<void> {
    if (this.creatingPlan) {
      return;
    }
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.createPlanError = '请先在“我的”页面登录后制定阅读计划。';
      return;
    }
    if (this.selectedBookId <= 0) {
      this.createPlanError = '请选择一本要加入计划的书。';
      return;
    }
    this.creatingPlan = true;
    this.createPlanError = '';
    try {
      await ApiClient.createPlan(userId, this.selectedBookId, this.selectedTargetDays);
      this.selectedPlanId = 0;
      this.showCreatePlan = false;
      await this.loadPlans();
    } catch (err) {
      this.createPlanError = `计划创建失败：${err}`;
    } finally {
      this.creatingPlan = false;
    }
  }

  clampMinutes(value: number): number {
    return Math.max(5, Math.min(1440, Math.round(value)));
  }

  openPlanSettings(plan: PlanItem): void {
    this.editingPlanId = plan.id;
    this.editingDailyMinutes = this.planDailyTarget(plan);
    this.editingWeeklyMinutes = this.planWeeklyTarget(plan);
    this.planSettingsError = '';
    this.showPlanSettings = true;
  }

  closePlanSettings(): void {
    if (this.savingPlanSettings) {
      return;
    }
    this.showPlanSettings = false;
    this.planSettingsError = '';
  }

  adjustDailyMinutes(delta: number): void {
    this.editingDailyMinutes = this.clampMinutes(this.editingDailyMinutes + delta);
    if (this.editingWeeklyMinutes < this.editingDailyMinutes) {
      this.editingWeeklyMinutes = this.editingDailyMinutes;
    }
    this.planSettingsError = '';
  }

  adjustWeeklyMinutes(delta: number): void {
    this.editingWeeklyMinutes = this.clampMinutes(this.editingWeeklyMinutes + delta);
    if (this.editingWeeklyMinutes < this.editingDailyMinutes) {
      this.editingWeeklyMinutes = this.editingDailyMinutes;
    }
    this.planSettingsError = '';
  }

  syncWeeklyFromDaily(): void {
    this.editingWeeklyMinutes = this.clampMinutes(this.editingDailyMinutes * 7);
  }

  async savePlanSettings(): Promise<void> {
    if (this.savingPlanSettings) {
      return;
    }
    const plan = this.editingPlan();
    if (!plan) {
      this.planSettingsError = '没有找到要设置的计划，请刷新后再试。';
      return;
    }
    const userId: number = UserSession.currentUserId();
    if (userId <= 0) {
      this.planSettingsError = '请先登录后再保存计划设置。';
      return;
    }
    this.savingPlanSettings = true;
    this.planSettingsError = '';
    try {
      await ApiClient.updatePlanTargets(
        userId,
        plan,
        this.clampMinutes(this.editingDailyMinutes),
        this.clampMinutes(this.editingWeeklyMinutes)
      );
      this.showPlanSettings = false;
      await this.loadPlans();
    } catch (err) {
      this.planSettingsError = `计划设置保存失败：${err}`;
    } finally {
      this.savingPlanSettings = false;
    }
  }

  sumWeekSeconds(days: ReadingDayStat[]): number {
    let total = 0;
    for (let i = 0; i < days.length; i++) {
      total += Math.max(0, Math.round(days[i].seconds || 0));
    }
    return total;
  }

  durationText(seconds: number): string {
    const safe = Math.max(0, Math.round(seconds || 0));
    const minutes = Math.floor(safe / 60);
    if (minutes < 60) {
      return `${minutes} 分钟`;
    }
    const hours = Math.floor(minutes / 60);
    const remain = minutes % 60;
    return remain > 0 ? `${hours} 小时 ${remain} 分钟` : `${hours} 小时`;
  }

  build() {
    Stack() {
      Column({ space: this.isCompact() ? 16 : 20 }) {
        this.TopBar()

        if (this.errorText) {
          this.ErrorBanner()
        }

        if (this.loading && this.plans.length === 0) {
          this.LoadingState()
        } else if (this.plans.length === 0) {
          this.ReadingTimeCard()
          if (this.showCreatePlan) {
            this.CreatePlanPanel()
          } else {
            this.EmptyState()
          }
        } else {
          this.HeroCard()
          this.ReadingTimeCard()
          if (this.showCreatePlan) {
            this.CreatePlanPanel()
          }
          this.ProgressCard()
          this.TodayPlanCard()
          this.CalendarCard()
          this.AllPlansCard()
        }
      }
      .width('100%')
      .padding({ left: 0, right: 0, bottom: 8 })
      .backgroundColor(PLAN_BG)

      if (this.showPlanSettings) {
        this.PlanSettingsSheet()
      }
    }
    .width('100%')
    .backgroundColor(PLAN_BG)
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontColor(PLAN_TEXT)
        .fontSize(36)
        .fontWeight(FontWeight.Medium)
        .opacity(0.75)
      Blank()
      Text('阅读计划')
        .fontColor(PLAN_TEXT)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Blank()
      Text('•••')
        .fontColor(PLAN_TEXT)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .onClick(() => this.loadPlans())
    }
    .width('100%')
    .height(56)
    .padding({ left: this.isCompact() ? 14 : 16, right: this.isCompact() ? 14 : 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ReadingTimeCard() {
    Row({ space: 12 }) {
      this.TimeStatItem('今日阅读', this.durationText(this.todayReadingSeconds), PLAN_GREEN)
      this.TimeStatItem('近 7 日', this.durationText(this.weekReadingSeconds), '#5C9CE6')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(this.cardRadius())
    .shadow({ radius: 16, color: '#0F000000', offsetX: 0, offsetY: 7 })
  }

  @Builder
  TimeStatItem(label: string, value: string, color: string) {
    Column({ space: 8 }) {
      Text(label)
        .fontColor(PLAN_MUTED)
        .fontSize(13)
      Text(value)
        .fontColor(color)
        .fontSize(this.isCompact() ? 18 : 20)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(70)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F7F9FB')
    .borderRadius(14)
  }

  @Builder
  HeroCard() {
    Stack({ alignContent: Alignment.End }) {
      Row() {
        Column({ space: 16 }) {
          Text(`${this.heroDays()}天阅读计划`)
            .fontColor(PLAN_TEXT)
            .fontSize(this.isCompact() ? 26 : 30)
            .fontWeight(FontWeight.Bold)
          Text('养成每日阅读的好习惯')
            .fontColor(PLAN_MUTED)
            .fontSize(18)
          Text(this.currentPlan() ? `当前书籍：${this.currentPlan()?.title}` : '从书籍详情创建计划后开始')
            .fontColor('#7A8190')
            .fontSize(15)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 30, bottom: 30 })

      this.HeroIllustration()
    }
    .width('100%')
    .height(this.isCompact() ? 190 : 210)
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(this.cardRadius())
    .shadow({ radius: 22, color: '#12000000', offsetX: 0, offsetY: 10 })
    .clip(true)
  }

  @Builder
  HeroIllustration() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(138)
        .height(138)
        .fill('#ECF8F1')
        .opacity(0.8)
      Column() {}
        .width(86)
        .height(116)
        .backgroundColor('#DFF4E8')
        .borderRadius({ topLeft: 12, topRight: 12, bottomLeft: 10, bottomRight: 10 })
        .rotate({ angle: 6 })
      Column({ space: 4 }) {
        Row({ space: 7 }) {
          ForEach([0, 1, 2, 3, 4], (dot: number) => {
            Circle().width(7).height(7).fill('#8FCBA8')
          }, (dot: number) => `${dot}`)
        }
        Text(`${this.heroDays()}`)
          .fontColor('#657976')
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 14 })
        Text('DAYS')
          .fontColor('#73827E')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
      }
      .width(78)
      .height(104)
      .padding({ top: 10 })
      .backgroundColor('#FFFFFF')
      .borderRadius(10)
      .shadow({ radius: 10, color: '#16000000', offsetX: 0, offsetY: 4 })

      Column() {}
        .width(62)
        .height(12)
        .backgroundColor('#F4DFB4')
        .borderRadius(6)
        .position({ x: 78, y: 118 })
      Column() {}
        .width(66)
        .height(12)
        .backgroundColor('#7AC998')
        .borderRadius(6)
        .position({ x: 72, y: 104 })
      Text('✓')
        .fontColor(PLAN_GREEN)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .position({ x: 18, y: 116 })
    }
    .width(156)
    .height(150)
    .margin({ right: this.isCompact() ? -18 : -4 })
  }

  @Builder
  ProgressCard() {
    Column({ space: 22 }) {
      Row() {
        Column({ space: 8 }) {
          Text('总体进度')
            .fontColor(PLAN_TEXT)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Text(`已完成 ${this.completedDays()} / ${this.heroDays()} 天`)
            .fontColor(PLAN_MUTED)
            .fontSize(15)
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text(`${this.planProgress(this.currentPlan())}%`)
          .fontColor(PLAN_GREEN)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')

      this.ProgressBar(this.currentPlan(), this.progressTrackWidth(), 9)

      Row() {
        this.StatItem('✓', `${this.completedDays()} 天`, '已完成', PLAN_GREEN)
        this.StatItem('⌛', `${this.remainingDays()} 天`, '剩余天数', '#5C9CE6')
        this.StatItem('◫', `${this.activePlanCount()} 个`, '进行中', '#E6A23C')
        this.StatItem('▣', `${this.finishedBookCount()} 本`, '已读书籍', '#8576DE')
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 24, bottom: 24 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(this.cardRadius())
    .shadow({ radius: 20, color: '#10000000', offsetX: 0, offsetY: 9 })
  }

  @Builder
  TodayPlanCard() {
    Column({ space: 18 }) {
      Row() {
        Text('今日计划')
          .fontColor(PLAN_TEXT)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        Blank()
        Row({ space: 6 }) {
          Text(this.statusText(this.currentPlan()))
            .fontColor(this.statusColor(this.currentPlan()))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
          Text(this.currentPlan() && (this.currentPlan()?.status === 'finished' || this.planProgress(this.currentPlan()) >= 100) ? '✓' : '›')
            .fontColor(this.statusColor(this.currentPlan()))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
        }
      }
      .width('100%')

      Row({ space: 16 }) {
        this.BookCover(this.currentPlan())
        Column({ space: 10 }) {
          Text(this.currentPlan()?.title || '暂无计划')
            .fontColor(PLAN_TEXT)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.currentPlan() ? `${this.currentPlan()?.author} · ${this.planProgress(this.currentPlan())}%` : '从书籍详情页加入阅读计划')
            .fontColor(PLAN_MUTED)
            .fontSize(15)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          this.ProgressBar(this.currentPlan(), this.miniTrackWidth(), 7)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('›')
          .fontColor('#9BA1AE')
          .fontSize(32)
      }
      .width('100%')
      .onClick(() => this.openCurrentPlan())

      Row({ space: 10 }) {
        Text('“')
          .fontColor('#D2D8DF')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
        Text(this.currentPlan() ? '继续从阅读器进入正文，保存进度后会自动同步到今天的计划。' : '先搜索一本书，在详情或阅读器中创建计划。')
          .fontColor('#8B92A0')
          .fontSize(15)
          .lineHeight(24)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .backgroundColor('#F7F9FB')
      .borderRadius(14)
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 24, bottom: 24 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(this.cardRadius())
    .shadow({ radius: 20, color: '#10000000', offsetX: 0, offsetY: 9 })
  }

  @Builder
  CalendarCard() {
    Column({ space: 18 }) {
      Row() {
        Text('计划日历')
          .fontColor(PLAN_TEXT)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('本周')
          .fontColor(PLAN_MUTED)
          .fontSize(15)
      }
      .width('100%')

      Row() {
        ForEach(this.calendarDays(), (item: PlanDay) => {
          this.CalendarDayCell(item)
        }, (item: PlanDay) => `${item.id}-${item.state}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 24, bottom: 24 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(this.cardRadius())
    .shadow({ radius: 20, color: '#10000000', offsetX: 0, offsetY: 9 })
  }

  @Builder
  AllPlansCard() {
    Column({ space: 14 }) {
      Row() {
        Text('全部计划')
          .fontColor(PLAN_TEXT)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('添加')
          .fontColor(PLAN_GREEN_DARK)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .onClick(() => this.openCreatePlan())
      }
      .width('100%')

      ForEach(this.plans, (item: PlanItem) => {
        this.PlanListRow(item)
      }, (item: PlanItem) => `${item.id}-${item.progress}`)
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 24, bottom: 24 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(this.cardRadius())
    .shadow({ radius: 20, color: '#10000000', offsetX: 0, offsetY: 9 })
  }

  @Builder
  CreatePlanPanel() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 6 }) {
          Text('制定阅读计划')
            .fontColor(PLAN_TEXT)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Text('选择一本后端书库里的书，计划会立即同步到个人计划。')
            .fontColor(PLAN_MUTED)
            .fontSize(14)
            .lineHeight(20)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('关闭')
          .fontColor(PLAN_MUTED)
          .fontSize(14)
          .onClick(() => this.closeCreatePlan())
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.createPlanError) {
        Text(this.createPlanError)
          .fontColor('#A94A4A')
          .fontSize(13)
          .lineHeight(19)
          .width('100%')
          .padding({ left: 12, right: 12, top: 9, bottom: 9 })
          .backgroundColor('#FFF1F1')
          .borderRadius(12)
      }

      if (this.loadingCandidates) {
        Text('正在读取可加入计划的图书')
          .fontColor(PLAN_MUTED)
          .fontSize(14)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 })
      } else if (this.planCandidates.length === 0 && !this.createPlanError) {
        Text('暂无可加入计划的图书')
          .fontColor(PLAN_MUTED)
          .fontSize(14)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 })
      } else {
        Scroll() {
          Column({ space: 0 }) {
            ForEach(this.planCandidates, (book: Book) => {
              this.PlanCandidateRow(book)
            }, (book: Book) => `${book.id}-${book.title}`)
          }
          .width('100%')
        }
        .height(this.isCompact() ? 220 : 260)
        .scrollBar(BarState.Off)
      }

      Column({ space: 10 }) {
        Row() {
          Text('计划周期')
            .fontColor(PLAN_TEXT)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
          Blank()
          Text(`${this.selectedTargetDays} 天`)
            .fontColor(PLAN_GREEN_DARK)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')

        Row({ space: 8 }) {
          ForEach([7, 14, 21, 30], (days: number) => {
            Text(`${days}天`)
              .fontColor(this.selectedTargetDays === days ? '#FFFFFF' : PLAN_TEXT)
              .fontSize(13)
              .fontWeight(this.selectedTargetDays === days ? FontWeight.Bold : FontWeight.Regular)
              .height(34)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.selectedTargetDays === days ? PLAN_GREEN : '#F1F4F3')
              .borderRadius(17)
              .onClick(() => this.setTargetDays(days))
          }, (days: number) => `${days}`)
        }
        .width('100%')
      }
      .width('100%')

      Button(this.creatingPlan ? '正在同步' : '创建计划')
        .width('100%')
        .height(44)
        .fontColor('#FFFFFF')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.creatingPlan ? '#A8DEC0' : PLAN_GREEN)
        .borderRadius(22)
        .enabled(!this.creatingPlan)
        .onClick(() => this.submitCreatePlan())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 22 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(this.cardRadius())
    .shadow({ radius: 20, color: '#12000000', offsetX: 0, offsetY: 9 })
  }

  @Builder
  PlanCandidateRow(book: Book) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {}
          .width(42)
          .height(56)
          .backgroundColor(book.coverColor || '#DDE8E3')
          .borderRadius({ topLeft: 6, topRight: 6, bottomLeft: 4, bottomRight: 6 })
        Text((book.title || '书').substring(0, Math.min(2, (book.title || '书').length)))
          .fontColor('#FFFFFF')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
      }
      .width(46)
      .height(60)

      Column({ space: 6 }) {
        Text(book.title || '未命名图书')
          .fontColor(PLAN_TEXT)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${book.author || '作者待补充'} · ${book.tags || book.category || '后端书库'}`)
          .fontColor(PLAN_MUTED)
          .fontSize(12)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.selectedBookId === book.id ? '已选' : '选择')
        .fontColor(this.selectedBookId === book.id ? '#FFFFFF' : PLAN_GREEN_DARK)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor(this.selectedBookId === book.id ? PLAN_GREEN : '#EDF8F1')
        .borderRadius(15)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: '#EEF1F5' })
    .onClick(() => this.selectPlanBook(book.id))
  }

  @Builder
  PlanListRow(item: PlanItem) {
    Row({ space: 12 }) {
      Row({ space: 12 }) {
        this.MiniCover(item)
        Column({ space: 6 }) {
          Row() {
            Text(item.title)
              .fontColor(PLAN_TEXT)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(`${this.planProgress(item)}%`)
              .fontColor(PLAN_GREEN)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
          }
          .width('100%')
          Text(`${item.author} · ${item.targetDays}天计划 · 每天 ${this.planDailyTarget(item)} 分钟 · 每周 ${this.planWeeklyTarget(item)} 分钟`)
            .fontColor(PLAN_MUTED)
            .fontSize(13)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          this.ProgressBar(item, Math.max(120, this.pageWidth - 224), 5)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .onClick(() => {
        this.selectedPlanId = item.id;
        openReader(item.bookId);
      })

      Text('设置')
        .fontColor(PLAN_GREEN_DARK)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .width(56)
        .height(34)
        .textAlign(TextAlign.Center)
        .backgroundColor('#EDF8F1')
        .borderRadius(17)
        .onClick(() => this.openPlanSettings(item))
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  PlanSettingsSheet() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => this.closePlanSettings())

      Column({ space: 16 }) {
        Row() {
          Column({ space: 4 }) {
            Text('阅读设置')
              .fontColor(PLAN_TEXT)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
            Text(this.editingPlan()?.title || '当前计划')
              .fontColor(PLAN_MUTED)
              .fontSize(13)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text('×')
            .fontColor(PLAN_MUTED)
            .fontSize(22)
            .width(38)
            .height(38)
            .textAlign(TextAlign.Center)
            .backgroundColor('#F2F4F6')
            .borderRadius(19)
            .onClick(() => this.closePlanSettings())
        }
        .width('100%')

        this.MinuteSettingRow('每天阅读', this.editingDailyMinutes, '分钟/天', 5, () => this.adjustDailyMinutes(-5), () => this.adjustDailyMinutes(5))
        this.MinuteSettingRow('每周阅读', this.editingWeeklyMinutes, '分钟/周', 15, () => this.adjustWeeklyMinutes(-15), () => this.adjustWeeklyMinutes(15))

        Text('按每日目标生成每周时长')
          .fontColor(PLAN_GREEN_DARK)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .height(38)
          .textAlign(TextAlign.Center)
          .backgroundColor('#EDF8F1')
          .borderRadius(19)
          .onClick(() => this.syncWeeklyFromDaily())

        if (this.planSettingsError) {
          Text(this.planSettingsError)
            .fontColor('#A94A4A')
            .fontSize(13)
            .lineHeight(19)
            .width('100%')
            .padding({ left: 12, right: 12, top: 9, bottom: 9 })
            .backgroundColor('#FFF1F1')
            .borderRadius(12)
        }

        Row({ space: 10 }) {
          Button('取消')
            .height(44)
            .layoutWeight(1)
            .fontColor(PLAN_MUTED)
            .fontSize(15)
            .backgroundColor('#F2F4F6')
            .borderRadius(22)
            .enabled(!this.savingPlanSettings)
            .onClick(() => this.closePlanSettings())
          Button(this.savingPlanSettings ? '正在保存' : '保存设置')
            .height(44)
            .layoutWeight(1)
            .fontColor('#FFFFFF')
            .fontSize(15)
            .backgroundColor(this.savingPlanSettings ? '#A8DEC0' : PLAN_GREEN)
            .borderRadius(22)
            .enabled(!this.savingPlanSettings)
            .onClick(() => this.savePlanSettings())
        }
        .width('100%')
      }
      .width(this.pageWidth >= 720 ? 520 : Math.max(300, this.pageWidth - 32))
      .padding({ left: 20, right: 20, top: 22, bottom: 20 })
      .backgroundColor(Theme.mobileSurface)
      .borderRadius(22)
      .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: 12 })
      .position({ x: this.pageWidth >= 720 ? Math.floor((this.pageWidth - 520) / 2) : 16, y: 86 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  MinuteSettingRow(label: string, value: number, unit: string, step: number, minusAction: () => void, plusAction: () => void) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(label)
          .fontColor(PLAN_TEXT)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Text(`每次调整 ${step} 分钟`)
          .fontColor(PLAN_MUTED)
          .fontSize(12)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 8 }) {
        Text('-')
          .fontColor(PLAN_TEXT)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#F2F4F6')
          .borderRadius(18)
          .onClick(() => minusAction())
        Column({ space: 1 }) {
          Text(`${value}`)
            .fontColor(PLAN_GREEN_DARK)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Text(unit)
            .fontColor(PLAN_MUTED)
            .fontSize(11)
        }
        .width(76)
        .height(44)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F7F9FB')
        .borderRadius(14)
        Text('+')
          .fontColor(PLAN_TEXT)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#F2F4F6')
          .borderRadius(18)
          .onClick(() => plusAction())
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor('#F7F9FB')
    .borderRadius(16)
  }

  @Builder
  StatItem(icon: string, value: string, label: string, color: string) {
    Column({ space: 8 }) {
      Text(icon)
        .fontColor(color)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(value)
        .fontColor(PLAN_TEXT)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontColor(PLAN_MUTED)
        .fontSize(13)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  CalendarDayCell(item: PlanDay) {
    Column({ space: 8 }) {
      Text(item.week)
        .fontColor(PLAN_MUTED)
        .fontSize(14)
      Stack({ alignContent: Alignment.Center }) {
        if (item.state === 'done') {
          Circle().width(42).height(42).fill(PLAN_GREEN)
          Text('✓')
            .fontColor('#FFFFFF')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
        } else if (item.state === 'today') {
          Circle().width(46).height(46).fill('#FFFFFF')
            .stroke('#A8DEC0')
            .strokeWidth(2)
          Text('今')
            .fontColor(PLAN_GREEN_DARK)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
        } else {
          Circle().width(42).height(42).fill('#F2F4F6')
          Text(item.day)
            .fontColor(PLAN_TEXT)
            .fontSize(16)
        }
      }
      .width(48)
      .height(48)
      Text(item.day)
        .fontColor(PLAN_TEXT)
        .fontSize(16)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ProgressBar(plan: PlanItem | null, widthValue: number, heightValue: number) {
    Stack({ alignContent: Alignment.Start }) {
      Column() {}
        .width(widthValue)
        .height(heightValue)
        .backgroundColor('#EEF0F3')
        .borderRadius(heightValue)
      Column() {}
        .width(this.progressWidth(plan, widthValue))
        .height(heightValue)
        .backgroundColor(PLAN_GREEN)
        .borderRadius(heightValue)
    }
    .width(widthValue)
    .height(heightValue)
  }

  @Builder
  BookCover(plan: PlanItem | null) {
    Stack({ alignContent: Alignment.Center }) {
      Column() {}
        .width(78)
        .height(104)
        .backgroundColor(plan?.coverColor || '#DDE8E3')
        .borderRadius({ topLeft: 8, topRight: 8, bottomLeft: 6, bottomRight: 8 })
      Text(plan ? plan.title.substring(0, Math.min(4, plan.title.length)) : 'PLAN')
        .fontColor('#FFFFFF')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .width(58)
        .maxLines(3)
    }
    .width(86)
    .height(112)
  }

  @Builder
  MiniCover(plan: PlanItem) {
    Stack({ alignContent: Alignment.Center }) {
      Column() {}
        .width(42)
        .height(56)
        .backgroundColor(plan.coverColor || '#DDE8E3')
        .borderRadius({ topLeft: 6, topRight: 6, bottomLeft: 4, bottomRight: 6 })
      Text(plan.title.substring(0, Math.min(2, plan.title.length)))
        .fontColor('#FFFFFF')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
    }
    .width(46)
    .height(60)
  }

  @Builder
  ErrorBanner() {
    Row({ space: 8 }) {
      Text('!')
        .fontColor('#FFFFFF')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .width(20)
        .height(20)
        .textAlign(TextAlign.Center)
        .backgroundColor('#D95B5B')
        .borderRadius(10)
      Text(this.errorText)
        .fontColor('#8C3D3D')
        .fontSize(13)
        .lineHeight(19)
        .layoutWeight(1)
      Text('重试')
        .fontColor('#8C3D3D')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .onClick(() => this.loadPlans())
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 11, bottom: 11 })
    .backgroundColor('#FFF0F0')
    .borderRadius(14)
  }

  @Builder
  LoadingState() {
    Column({ space: 16 }) {
      Text('正在同步阅读计划')
        .fontColor(PLAN_TEXT)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
      Text('计划、进度和今日阅读项都将从后端接口读取。')
        .fontColor(PLAN_MUTED)
        .fontSize(14)
    }
    .width('100%')
    .padding({ top: 72, bottom: 72 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(this.cardRadius())
  }

  @Builder
  EmptyState() {
    Column({ space: 16 }) {
      this.HeroIllustration()
      Text('还没有阅读计划')
        .fontColor(PLAN_TEXT)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text('从搜索或图书详情选择一本书，创建计划后这里会展示进度、今日任务和本周日历。')
        .fontColor(PLAN_MUTED)
        .fontSize(15)
        .lineHeight(23)
        .textAlign(TextAlign.Center)
      Button('制定阅读计划')
        .fontColor('#FFFFFF')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .height(42)
        .padding({ left: 24, right: 24 })
        .backgroundColor(PLAN_GREEN)
        .borderRadius(21)
        .onClick(() => this.openCreatePlan())
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 42, bottom: 48 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(this.cardRadius())
    .shadow({ radius: 20, color: '#10000000', offsetX: 0, offsetY: 9 })
    .alignItems(HorizontalAlign.Center)
  }
}
