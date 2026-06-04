import { ApiClient } from '../common/ApiClient';
import { PlanItem } from '../common/Models';
import { openReader, openStoreTab } from '../common/Navigation';
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

  build() {
    Column({ space: this.isCompact() ? 16 : 20 }) {
      this.TopBar()

      if (this.errorText) {
        this.ErrorBanner()
      }

      if (this.loading && this.plans.length === 0) {
        this.LoadingState()
      } else if (this.plans.length === 0) {
        this.EmptyState()
      } else {
        this.HeroCard()
        this.ProgressCard()
        this.TodayPlanCard()
        this.CalendarCard()
        this.AllPlansCard()
      }
    }
    .width('100%')
    .padding({ left: 0, right: 0, bottom: 8 })
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
          .onClick(() => openStoreTab())
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
  PlanListRow(item: PlanItem) {
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
        Text(`${item.author} · ${item.targetDays}天计划`)
          .fontColor(PLAN_MUTED)
          .fontSize(13)
          .maxLines(1)
        this.ProgressBar(item, Math.max(160, this.pageWidth - 150), 5)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .onClick(() => {
      this.selectedPlanId = item.id;
      openReader(item.bookId);
    })
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
      Button('去找一本书')
        .fontColor('#FFFFFF')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .height(42)
        .padding({ left: 24, right: 24 })
        .backgroundColor(PLAN_GREEN)
        .borderRadius(21)
        .onClick(() => openStoreTab())
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 42, bottom: 48 })
    .backgroundColor(Theme.mobileSurface)
    .borderRadius(this.cardRadius())
    .shadow({ radius: 20, color: '#10000000', offsetX: 0, offsetY: 9 })
    .alignItems(HorizontalAlign.Center)
  }
}
