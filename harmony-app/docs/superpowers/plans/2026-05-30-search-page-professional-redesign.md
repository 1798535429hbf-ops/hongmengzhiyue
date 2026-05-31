# Search Page Professional Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `SearchPage.ets` into a professional reading-product search page with dynamic behavior-based recommendations, search history, and confirmed history deletion.

**Architecture:** Keep the implementation in `SearchPage.ets` because the existing page is self-contained and already owns search state and navigation. Add small page-local data models for recommendation cards and search history, derive recommendation intent from profile/favorites/plans/chat records plus local shelf reading history, and update the layout builders to render the approved restrained professional aesthetic.

**Tech Stack:** HarmonyOS ArkTS / ArkUI ETS, existing `ApiClient`, `ShelfStore`, `Theme`, `BookCover`, and page-local `@State` state.

---

## File structure

- Modify: `entry/src/main/ets/pages/SearchPage.ets`
  - Add imports for `ProfileBundle`, `RecommendationBook`, `ShelfHistoryRecord`, and `ShelfStoreState`.
  - Add page-local interfaces for search history and recommendation display state.
  - Add state for recommendation cards, recommendation reason, search history, and delete confirmation dialog.
  - Load user profile and local reading/search history in `aboutToAppear`.
  - Record successful searches into local search history state.
  - Render redesigned search panel, recommendation section, search history section, and confirmation dialog.

No new production files are needed.

### Task 1: Add page-local models and state

**Files:**
- Modify: `entry/src/main/ets/pages/SearchPage.ets:1-24`

- [ ] **Step 1: Update imports**

Replace the imports at the top of `SearchPage.ets` with:

```ts
import { ApiClient, RecommendResult } from '../common/ApiClient';
import { Book, ChatRecord, PlanItem, ProfileBundle, RecommendationBook } from '../common/Models';
import { BookCover } from '../common/BookCover';
import { currentKeyword, goBack, openBookDetail, openReader } from '../common/Navigation';
import { ShelfHistoryRecord, ShelfStore, ShelfStoreState } from '../common/ShelfStore';
import { Theme } from '../common/Theme';
import { common } from '@kit.AbilityKit';

const USER_ID: number = 10086;
const MAX_SEARCH_HISTORY_COUNT: number = 8;
const MAX_RECOMMENDATION_COUNT: number = 6;

interface SearchHistoryItem {
  keyword: string;
  updatedAt: string;
}

interface SearchRecommendationCard {
  bookId: number;
  title: string;
  author: string;
  difficulty: string;
  reason: string;
  coverColor: string;
}
```

- [ ] **Step 2: Add state fields**

Inside `struct SearchPage`, after `@State pageWidth: number = 390;`, add:

```ts
  @State recommendations: SearchRecommendationCard[] = [];
  @State recommendationIntent: string = '根据你的阅读和提问习惯推荐';
  @State recommendationReason: string = '';
  @State searchHistory: SearchHistoryItem[] = [];
  @State showClearHistoryConfirm: boolean = false;
```

- [ ] **Step 3: Run a compile check**

Run from project root:

```bash
hvigorw --mode module -p module=entry assembleHap
```

Expected: build may fail later if project environment is incomplete, but there should be no syntax error pointing to the added imports, constants, interfaces, or state fields.

### Task 2: Load dynamic profile and behavior signals

**Files:**
- Modify: `entry/src/main/ets/pages/SearchPage.ets:19-66`

- [ ] **Step 1: Replace `aboutToAppear`**

Replace the existing `aboutToAppear` method with:

```ts
  aboutToAppear(): void {
    this.keyword = currentKeyword();
    this.loadBehaviorContext();
    if (this.keyword) {
      this.searchBooks();
    }
  }
```

- [ ] **Step 2: Add behavior-loading helpers after `hostContext`**

Insert this code after `hostContext()`:

```ts
  async loadBehaviorContext(): Promise<void> {
    const context = this.hostContext();
    let shelfState: ShelfStoreState | null = null;
    let profileBundle: ProfileBundle | null = null;
    try {
      if (context) {
        shelfState = await ShelfStore.load(context);
      }
    } catch (_) {
      shelfState = null;
    }
    try {
      profileBundle = await ApiClient.profile(USER_ID);
    } catch (_) {
      profileBundle = null;
    }
    this.searchHistory = this.deriveSearchHistory(shelfState, profileBundle);
    await this.loadRecommendations(shelfState, profileBundle);
  }

  deriveSearchHistory(shelfState: ShelfStoreState | null, profileBundle: ProfileBundle | null): SearchHistoryItem[] {
    const items: SearchHistoryItem[] = [];
    const seen: string[] = [];
    this.appendHistoryKeyword(items, seen, currentKeyword(), new Date().toISOString());
    if (profileBundle) {
      for (let i = 0; i < profileBundle.chat_records.length; i++) {
        this.appendHistoryKeyword(items, seen, this.compactQuestion(profileBundle.chat_records[i].question), profileBundle.chat_records[i].createdAt);
      }
      for (let i = 0; i < profileBundle.plans.length; i++) {
        this.appendHistoryKeyword(items, seen, profileBundle.plans[i].title, new Date().toISOString());
      }
    }
    if (shelfState) {
      for (let i = 0; i < shelfState.browseHistory.length; i++) {
        const record: ShelfHistoryRecord = shelfState.browseHistory[i];
        this.appendHistoryKeyword(items, seen, record.tags || record.title, record.updatedAt);
      }
    }
    items.sort((left: SearchHistoryItem, right: SearchHistoryItem) => right.updatedAt.localeCompare(left.updatedAt));
    return items.slice(0, MAX_SEARCH_HISTORY_COUNT);
  }

  appendHistoryKeyword(items: SearchHistoryItem[], seen: string[], keyword: string, updatedAt: string): void {
    const normalized = keyword.trim();
    if (!normalized) {
      return;
    }
    for (let i = 0; i < seen.length; i++) {
      if (seen[i] === normalized) {
        return;
      }
    }
    seen.push(normalized);
    items.push({ keyword: normalized, updatedAt });
  }

  compactQuestion(question: string): string {
    const normalized = question.trim();
    if (normalized.length <= 18) {
      return normalized;
    }
    return normalized.substring(0, 18);
  }
```

- [ ] **Step 3: Run a compile check**

Run:

```bash
hvigorw --mode module -p module=entry assembleHap
```

Expected: no syntax errors in `loadBehaviorContext`, `deriveSearchHistory`, `appendHistoryKeyword`, or `compactQuestion`.

### Task 3: Add dynamic recommendations

**Files:**
- Modify: `entry/src/main/ets/pages/SearchPage.ets`

- [ ] **Step 1: Add recommendation methods after `compactQuestion`**

Insert:

```ts
  async loadRecommendations(shelfState: ShelfStoreState | null, profileBundle: ProfileBundle | null): Promise<void> {
    const query: string = this.buildRecommendationQuery(shelfState, profileBundle);
    if (!query) {
      this.recommendations = [];
      this.recommendationReason = '开始搜索或阅读后，这里会根据你的行为生成推荐。';
      return;
    }
    try {
      const result: RecommendResult = await ApiClient.recommend(USER_ID, query);
      this.recommendationIntent = result.intent || '根据你的阅读和提问习惯推荐';
      this.recommendationReason = result.reason || '综合最近阅读、搜索和伴读提问生成。';
      this.recommendations = this.toRecommendationCards(result.book_list);
    } catch (_) {
      this.recommendationIntent = '根据你的阅读和提问习惯推荐';
      this.recommendationReason = '综合最近阅读、搜索和伴读提问生成。';
      this.recommendations = this.fallbackRecommendations(profileBundle);
    }
  }

  buildRecommendationQuery(shelfState: ShelfStoreState | null, profileBundle: ProfileBundle | null): string {
    const signals: string[] = [];
    if (shelfState) {
      for (let i = 0; i < shelfState.remoteSessions.length && signals.length < 4; i++) {
        const session = shelfState.remoteSessions[i];
        signals.push(`${session.title} ${session.tags} ${session.difficulty} 进度${session.progress}%`);
      }
      for (let i = 0; i < shelfState.browseHistory.length && signals.length < 8; i++) {
        const record = shelfState.browseHistory[i];
        signals.push(`${record.title} ${record.tags || ''} ${record.actionText}`);
      }
    }
    if (profileBundle) {
      for (let i = 0; i < profileBundle.chat_records.length && signals.length < 12; i++) {
        const chat: ChatRecord = profileBundle.chat_records[i];
        signals.push(chat.question);
      }
      for (let i = 0; i < profileBundle.plans.length && signals.length < 16; i++) {
        const plan: PlanItem = profileBundle.plans[i];
        signals.push(`${plan.title} ${plan.author} ${plan.status} ${plan.progress}%`);
      }
      signals.push(`${profileBundle.profile.interests} ${profileBundle.profile.goal}`);
    }
    return signals.join('；');
  }

  toRecommendationCards(books: RecommendationBook[]): SearchRecommendationCard[] {
    const cards: SearchRecommendationCard[] = [];
    for (let i = 0; i < books.length && cards.length < MAX_RECOMMENDATION_COUNT; i++) {
      const book = books[i];
      cards.push({
        bookId: book.id,
        title: book.title,
        author: book.author || '作者待补充',
        difficulty: book.difficulty || '推荐阅读',
        reason: book.reason || '与你最近的阅读和提问主题相关。',
        coverColor: '#F2E7D6',
      });
    }
    return cards;
  }

  fallbackRecommendations(profileBundle: ProfileBundle | null): SearchRecommendationCard[] {
    const cards: SearchRecommendationCard[] = [];
    if (!profileBundle) {
      return cards;
    }
    for (let i = 0; i < profileBundle.favorites.length && cards.length < MAX_RECOMMENDATION_COUNT; i++) {
      const book: Book = profileBundle.favorites[i];
      cards.push({
        bookId: book.id,
        title: book.title,
        author: book.author || '作者待补充',
        difficulty: book.difficulty || '推荐阅读',
        reason: '基于你收藏和持续关注的阅读方向。',
        coverColor: book.coverColor || '#F2E7D6',
      });
    }
    return cards;
  }
```

- [ ] **Step 2: Run a compile check**

Run:

```bash
hvigorw --mode module -p module=entry assembleHap
```

Expected: no syntax errors in recommendation methods.

### Task 4: Record searches and add delete confirmation behavior

**Files:**
- Modify: `entry/src/main/ets/pages/SearchPage.ets:44-66`

- [ ] **Step 1: Update `searchBooks` success path**

In `searchBooks`, after `this.hasSearched = true;`, add:

```ts
    this.recordSearchKeyword(query);
```

- [ ] **Step 2: Add history mutation methods before `openDetail`**

Insert before `async openDetail(book: Book): Promise<void>`:

```ts
  recordSearchKeyword(query: string): void {
    const items: SearchHistoryItem[] = [];
    const seen: string[] = [];
    this.appendHistoryKeyword(items, seen, query, new Date().toISOString());
    for (let i = 0; i < this.searchHistory.length; i++) {
      this.appendHistoryKeyword(items, seen, this.searchHistory[i].keyword, this.searchHistory[i].updatedAt);
    }
    this.searchHistory = items.slice(0, MAX_SEARCH_HISTORY_COUNT);
  }

  applyHistoryKeyword(item: SearchHistoryItem): void {
    this.keyword = item.keyword;
    this.searchBooks();
  }

  requestClearHistory(): void {
    if (this.searchHistory.length === 0) {
      return;
    }
    this.showClearHistoryConfirm = true;
  }

  cancelClearHistory(): void {
    this.showClearHistoryConfirm = false;
  }

  confirmClearHistory(): void {
    this.searchHistory = [];
    this.showClearHistoryConfirm = false;
  }
```

- [ ] **Step 3: Run a compile check**

Run:

```bash
hvigorw --mode module -p module=entry assembleHap
```

Expected: no syntax errors in search history mutation methods.

### Task 5: Replace page layout with the approved professional structure

**Files:**
- Modify: `entry/src/main/ets/pages/SearchPage.ets:100-208`

- [ ] **Step 1: Replace `build` content**

Replace the existing `build()` method with:

```ts
  build() {
    Stack() {
      Column() {
        this.TopBar()
        if (this.busyText) {
          this.StatusBanner(this.busyText, '#6F583F')
        }
        if (this.errorText) {
          this.StatusBanner(this.errorText, Theme.mobileRed)
        }
        Scroll() {
          Column({ space: 20 }) {
            this.SearchPanel()
            this.RecommendationSection()
            this.SearchHistorySection()
            this.ResultSummary()
            this.ResultList()
          }
          .width('100%')
          .padding({
            left: this.pagePadding(),
            right: this.pagePadding(),
            top: 8,
            bottom: 32,
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F3EC')
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
```

- [ ] **Step 2: Replace `TopBar`**

Replace the existing `TopBar()` builder with:

```ts
  @Builder
  TopBar() {
    Row({ space: 12 }) {
      Button('返回')
        .height(38)
        .fontColor('#2C241C')
        .backgroundColor('#FFFDF8')
        .border({ width: 1, color: '#E4D8C8' })
        .borderRadius(Theme.radius.pill)
        .padding({ left: 16, right: 16 })
        .onClick(() => goBack())
      Column({ space: 2 }) {
        Text('发现下一本书')
          .fontColor('#241F19')
          .fontSize(this.isCompact() ? 22 : 26)
          .fontWeight(FontWeight.Bold)
        Text('从你的阅读和提问习惯里找线索')
          .fontColor('#8B7B68')
          .fontSize(12)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: this.pagePadding(),
      right: this.pagePadding(),
      top: 16,
      bottom: 10,
    })
    .alignItems(VerticalAlign.Center)
  }
```

- [ ] **Step 3: Replace `SearchPanel`**

Replace the existing `SearchPanel()` builder with:

```ts
  @Builder
  SearchPanel() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        TextInput({ placeholder: '搜索你感兴趣的内容', text: this.keyword })
          .layoutWeight(1)
          .height(this.isCompact() ? 50 : 54)
          .fontColor('#241F19')
          .placeholderColor('#9B8C79')
          .backgroundColor('#FFFDF8')
          .border({ width: 1, color: '#E1D4C3' })
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.keyword = value;
          })
          .onSubmit(() => {
            this.searchBooks();
          })

        Button('搜索')
          .height(this.isCompact() ? 50 : 54)
          .fontColor('#FFFDF8')
          .backgroundColor('#6F583F')
          .borderRadius(18)
          .padding({ left: 22, right: 22 })
          .onClick(() => this.searchBooks())
      }
      .width('100%')

      Text('输入书名、作者、主题或你最近想解决的问题。')
        .fontColor('#8B7B68')
        .fontSize(13)
        .lineHeight(20)
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFDF8')
    .border({ width: 1, color: '#E7DCCC' })
    .borderRadius(24)
    .shadow({ radius: 16, color: '#12000000', offsetX: 0, offsetY: 8 })
  }
```

- [ ] **Step 4: Run a compile check**

Run:

```bash
hvigorw --mode module -p module=entry assembleHap
```

Expected: no syntax errors in the replaced layout builders.

### Task 6: Add recommendation and history UI builders

**Files:**
- Modify: `entry/src/main/ets/pages/SearchPage.ets`

- [ ] **Step 1: Add recommendation builders after `SearchPanel`**

Insert after `SearchPanel()`:

```ts
  @Builder
  RecommendationSection() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.recommendationIntent)
            .fontColor('#241F19')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Text(this.recommendationReason || '综合最近阅读、搜索和伴读提问生成。')
            .fontColor('#8B7B68')
            .fontSize(12)
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      if (this.recommendations.length > 0) {
        ForEach(this.recommendations, (item: SearchRecommendationCard) => {
          this.RecommendationCard(item)
        }, (item: SearchRecommendationCard) => `${item.bookId}-${item.title}`)
      } else {
        Text('开始阅读、搜索或向伴读提问后，这里会出现更贴近你的推荐。')
          .fontColor('#8B7B68')
          .fontSize(13)
          .lineHeight(20)
          .padding(16)
          .backgroundColor('#FFFDF8')
          .border({ width: 1, color: '#E7DCCC' })
          .borderRadius(18)
      }
    }
    .width('100%')
  }

  @Builder
  RecommendationCard(item: SearchRecommendationCard) {
    Row({ space: 12 }) {
      BookCover({
        bookId: item.bookId,
        title: item.title,
        difficulty: item.difficulty,
        coverColor: item.coverColor || '#F2E7D6',
        widthValue: this.isCompact() ? 54 : 62,
        heightValue: this.isCompact() ? 76 : 86,
        titleSize: 10,
      })
      Column({ space: 7 }) {
        Text(item.title)
          .fontColor('#241F19')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
        Text(item.author)
          .fontColor('#8B7B68')
          .fontSize(12)
          .maxLines(1)
        Text(item.reason)
          .fontColor('#5E5143')
          .fontSize(13)
          .lineHeight(19)
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFDF8')
    .border({ width: 1, color: '#E7DCCC' })
    .borderRadius(20)
  }
```

- [ ] **Step 2: Add search history builders after recommendation builders**

Insert:

```ts
  @Builder
  SearchHistorySection() {
    Column({ space: 12 }) {
      Row() {
        Text('搜索历史')
          .fontColor('#241F19')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('🗑')
          .height(34)
          .fontSize(16)
          .fontColor('#6F583F')
          .backgroundColor('#FFFDF8')
          .border({ width: 1, color: '#E7DCCC' })
          .borderRadius(Theme.radius.pill)
          .onClick(() => this.requestClearHistory())
      }
      .width('100%')

      if (this.searchHistory.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.searchHistory, (item: SearchHistoryItem) => {
            Button(item.keyword)
              .height(36)
              .fontColor('#5E5143')
              .fontSize(13)
              .backgroundColor('#FFFDF8')
              .border({ width: 1, color: '#E7DCCC' })
              .borderRadius(Theme.radius.pill)
              .margin({ right: 8, bottom: 8 })
              .padding({ left: 14, right: 14 })
              .onClick(() => this.applyHistoryKeyword(item))
          }, (item: SearchHistoryItem) => `${item.keyword}-${item.updatedAt}`)
        }
        .width('100%')
      } else {
        Text('暂无搜索历史。搜索后会保留最近关注的主题。')
          .fontColor('#8B7B68')
          .fontSize(13)
          .lineHeight(20)
          .padding(16)
          .backgroundColor('#FFFDF8')
          .border({ width: 1, color: '#E7DCCC' })
          .borderRadius(18)
      }
    }
    .width('100%')
  }
```

- [ ] **Step 3: Add confirmation dialog builder before `StatusBanner`**

Insert before `StatusBanner`:

```ts
  @Builder
  ClearHistoryDialog() {
    Column() {
      Blank()
      Column({ space: 14 }) {
        Text('删除搜索记录？')
          .fontColor('#241F19')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Text('删除后将清空当前搜索历史，是否继续？')
          .fontColor('#6F5F4D')
          .fontSize(14)
          .lineHeight(22)
        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontColor('#5E5143')
            .backgroundColor('#F4EDE3')
            .borderRadius(14)
            .onClick(() => this.cancelClearHistory())
          Button('删除')
            .layoutWeight(1)
            .height(42)
            .fontColor('#FFFDF8')
            .backgroundColor('#A94D3F')
            .borderRadius(14)
            .onClick(() => this.confirmClearHistory())
        }
        .width('100%')
      }
      .width('86%')
      .padding(20)
      .backgroundColor('#FFFDF8')
      .borderRadius(24)
      .shadow({ radius: 24, color: '#33000000', offsetX: 0, offsetY: 10 })
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }
```

- [ ] **Step 4: Run a compile check**

Run:

```bash
hvigorw --mode module -p module=entry assembleHap
```

Expected: no syntax errors in new builders.

### Task 7: Polish result cards to match the new visual system

**Files:**
- Modify: `entry/src/main/ets/pages/SearchPage.ets:210-309`

- [ ] **Step 1: Replace `ResultSummary`**

Replace `ResultSummary()` with:

```ts
  @Builder
  ResultSummary() {
    if (!this.hasSearched) {
      Text('搜索结果会显示在这里，推荐和历史会帮助你更快回到感兴趣的主题。')
        .fontColor('#8B7B68')
        .fontSize(14)
    } else if (this.results.length > 0) {
      Text(`找到 ${this.results.length} 本图书`)
        .fontColor('#241F19')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
    } else if (!this.busyText && !this.errorText) {
      Text('没有找到匹配结果，试试换一个主题、作者或你想解决的问题。')
        .fontColor('#8B7B68')
        .fontSize(14)
        .lineHeight(22)
    }
  }
```

- [ ] **Step 2: Replace color values in `ResultCard`**

Inside `ResultCard`, keep the structure but replace visual values as follows:

```ts
coverColor: book.coverColor || '#F2E7D6',
.fontColor('#241F19')
.fontColor('#8B7B68')
.fontColor('#6F583F')
.backgroundColor('#F4EDE3')
.fontColor('#FFFDF8')
.backgroundColor('#A94D3F')
.backgroundColor('#FFFDF8')
.border({ width: 1, color: '#E7DCCC' })
.shadow({ radius: 14, color: '#10000000', offsetX: 0, offsetY: 8 })
```

The final `ResultCard` should still use `BookCover`, show title/author/tags/summary, and keep `查看详情` and `开始阅读` actions.

- [ ] **Step 3: Run a compile check**

Run:

```bash
hvigorw --mode module -p module=entry assembleHap
```

Expected: no syntax errors after result card polish.

### Task 8: Manual verification

**Files:**
- Verify: `entry/src/main/ets/pages/SearchPage.ets`

- [ ] **Step 1: Build the Harmony app**

Run:

```bash
hvigorw --mode module -p module=entry assembleHap
```

Expected: build succeeds. If the local machine lacks Harmony build prerequisites, capture the exact missing-tool error and report it.

- [ ] **Step 2: Run the app or preview target available in this project**

Use the project's normal HarmonyOS run method from DevEco Studio or existing project scripts.

Expected visual checks:
- Search bar placeholder reads `搜索你感兴趣的内容`.
- Recommendation section appears below the search bar.
- Recommendation cards explain why a book is recommended.
- Search history appears below recommendations.
- Trash icon is visible on the right side of the search history header.
- Tapping the trash icon opens the confirmation dialog.
- Tapping cancel keeps search history.
- Tapping delete clears search history.
- Search results still show and book detail/reader navigation still work.

---

## Self-review

- Spec coverage: Search placeholder, dynamic recommendation behavior, behavior signal ordering, search history, trash action, delete confirmation, restrained professional visual style, empty states, and narrow-screen readability are all covered by tasks.
- Placeholder scan: No TBD/TODO/later placeholders remain.
- Type consistency: `SearchHistoryItem` and `SearchRecommendationCard` are defined before use. `ProfileBundle`, `RecommendationBook`, `ShelfStoreState`, `ShelfHistoryRecord`, `ChatRecord`, and `PlanItem` match imported existing types.
