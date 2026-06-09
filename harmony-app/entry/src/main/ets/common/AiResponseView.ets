import { common, Want, wantConstant } from '@kit.AbilityKit';
import { ToolTrace } from './ApiClient';
import { openReader } from './Navigation';
import { SourceRef } from './Models';
import { Theme } from './Theme';

@Component
export struct AiResponseView {
  @Prop answer: string = '';
  @Prop reasoning: string = '';
  @Prop followUpSuggestion: string = '';
  @Prop sources: SourceRef[] = [];
  @Prop toolTrace: ToolTrace[] = [];
  @Prop busy: boolean = false;
  @Prop statusText: string = '';
  @Prop emptyText: string = '';
  @Prop dark: boolean = false;
  @Prop compact: boolean = false;
  @Prop maxAnswerLines: number = 0;
  @State showReasoning: boolean = false;

  surfaceColor(): string {
    return this.dark ? '#0D2233' : '#FFFFFF';
  }

  nestedSurfaceColor(): string {
    return this.dark ? '#13283A' : '#F7F8FC';
  }

  textColor(): string {
    return this.dark ? Theme.onDark : '#20233A';
  }

  mutedColor(): string {
    return this.dark ? Theme.onDarkSoft : '#73788C';
  }

  accentColor(): string {
    return this.dark ? Theme.coralSoft : Theme.mobileBlue;
  }

  sourceBookId(source: SourceRef): number {
    return Math.max(0, Math.round(source.book_id || source.bookId || 0));
  }

  sourceChapterId(source: SourceRef): string {
    return (source.chapterId || source.chapter_id || '').trim();
  }

  sourceUrl(source: SourceRef): string {
    const direct: string = (source.url || '').trim();
    if (direct) {
      return direct;
    }
    const inferred: string = (source.source || '').trim();
    if (this.isHttpUrl(inferred)) {
      return inferred;
    }
    return '';
  }

  isHttpUrl(value: string): boolean {
    return /^https?:\/\//i.test((value || '').trim());
  }

  sourceHost(value: string): string {
    const trimmed: string = (value || '').trim();
    if (!trimmed) {
      return '';
    }
    const withoutProtocol: string = trimmed.replace(/^https?:\/\//i, '');
    const host: string = withoutProtocol.split('/')[0].trim();
    return host;
  }

  sourceTitle(source: SourceRef): string {
    return source.title || '来源';
  }

  sourceSubtitle(source: SourceRef): string {
    const parts: string[] = [];
    const sourceLabel: string = (source.source || '').trim();
    if (sourceLabel && !this.isHttpUrl(sourceLabel)) {
      parts.push(sourceLabel);
    }
    const url: string = this.sourceUrl(source);
    if (url) {
      const host: string = this.sourceHost(url);
      if (host) {
        parts.push(host);
      } else {
        parts.push('外部链接');
      }
    }
    const chapterId: string = this.sourceChapterId(source);
    if (chapterId) {
      parts.push(chapterId);
    }
    if (parts.length === 0 && this.sourceBookId(source) > 0) {
      parts.push(`书籍 #${this.sourceBookId(source)}`);
    }
    return parts.join(' · ');
  }

  sourceActionLabel(source: SourceRef): string {
    if (this.sourceUrl(source)) {
      return '打开链接';
    }
    if (this.sourceChapterId(source)) {
      return '继续阅读';
    }
    if (this.sourceBookId(source) > 0) {
      return '查看书籍';
    }
    return '查看来源';
  }

  sourceTargetHint(source: SourceRef): string {
    if (this.sourceUrl(source)) {
      return '外部网页';
    }
    if (this.sourceChapterId(source)) {
      return '书内章节';
    }
    if (this.sourceBookId(source) > 0) {
      return '书籍详情';
    }
    return '来源详情';
  }

  async openExternalUrl(url: string): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext | undefined;
    if (!context) {
      return;
    }
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: url,
      type: 'text/html',
      flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION,
    };
    await context.startAbility(want);
  }

  async openSource(source: SourceRef): Promise<void> {
    const url: string = this.sourceUrl(source);
    if (url) {
      try {
        await this.openExternalUrl(url);
        return;
      } catch (_) {
      }
    }
    const bookId: number = this.sourceBookId(source);
    const chapterId: string = this.sourceChapterId(source);
    if (bookId > 0 && chapterId) {
      openReader(bookId, chapterId);
      return;
    }
    if (bookId > 0) {
      openReader(bookId);
    }
  }

  responseBorderColor(): string {
    return this.dark ? '#20374A' : '#E7E9F0';
  }

  normalizeText(value: string): string {
    return (value || '').trim();
  }

  extractReasoningFromAnswer(): string {
    const text: string = this.normalizeText(this.answer);
    if (!text) {
      return '';
    }

    const thinkBlocks: string[] = text.match(/<think>[\s\S]*?<\/think>/g) || [];
    if (thinkBlocks.length > 0) {
      const chunks: string[] = [];
      for (let i = 0; i < thinkBlocks.length; i++) {
        const chunk: string = thinkBlocks[i]
          .replace(/^<think>/, '')
          .replace(/<\/think>$/, '')
          .trim();
        if (chunk) {
          chunks.push(chunk);
        }
      }
      if (chunks.length > 0) {
        return chunks.join('\n\n');
      }
    }

    const labels: string[] = ['思考过程：', '思考过程:', '思考：', '思考:', 'Thinking:', 'Reasoning:'];
    for (let i = 0; i < labels.length; i++) {
      const index: number = text.indexOf(labels[i]);
      if (index === 0) {
        const chunk: string = text.substring(labels[i].length).trim();
        if (chunk) {
          return chunk;
        }
      }
    }
    return '';
  }

  stripAnswerPrefix(value: string): string {
    let text: string = this.normalizeText(value);
    if (!text) {
      return '';
    }

    const answerMarkers: string[] = ['回答：', '回答:', '答案：', '答案:', '最终回答：', '最终回答:', '最终答案：', '最终答案:', '结论：', '结论:', 'Final answer:', 'Final Answer:'];
    for (let i = 0; i < answerMarkers.length; i++) {
      const index: number = text.indexOf(answerMarkers[i]);
      if (index >= 0 && index < 80) {
        text = text.substring(index + answerMarkers[i].length).trim();
        break;
      }
    }
    return text;
  }

  cleanAnswer(): string {
    let value: string = this.normalizeText(this.answer);
    if (!value) {
      return '';
    }
    value = value.replace(/<think>[\s\S]*?<\/think>/g, '').trim();
    value = this.stripAnswerPrefix(value);
    return value;
  }

  traceText(): string {
    const values: string[] = [];
    for (let i = 0; i < this.toolTrace.length; i++) {
      const trace = this.toolTrace[i];
      const detail: string = trace.detail || trace.details || '';
      values.push(`${trace.tool || '工具'} · ${trace.status || 'unknown'}${detail ? ` · ${detail}` : ''}`);
    }
    return values.join('\n');
  }

  visibleReasoning(): string {
    const direct: string = this.normalizeText(this.reasoning);
    if (direct) {
      return direct;
    }
    const extracted: string = this.extractReasoningFromAnswer();
    if (extracted) {
      return extracted;
    }
    return this.traceText();
  }

  hasReasoning(): boolean {
    return !!this.visibleReasoning();
  }

  busyLabel(): string {
    return this.statusText || '正在思考';
  }

  reasoningHint(): string {
    if (this.normalizeText(this.reasoning)) {
      return '点开可查看完整思路与证据链';
    }
    if (this.extractReasoningFromAnswer()) {
      return '模型把思考过程放在了回答里，点开可展开';
    }
    if (this.traceText()) {
      return '这里显示工具轨迹，方便你回看推理路径';
    }
    return '当前没有返回独立思考内容';
  }

  reasoningPreview(): string {
    const text: string = this.visibleReasoning();
    if (!text) {
      return '';
    }
    if (this.showReasoning) {
      return text;
    }
    const lines: string[] = text.split('\n');
    const preview: string[] = [];
    for (let i = 0; i < lines.length && preview.length < 2; i++) {
      const line: string = this.normalizeText(lines[i]);
      if (line) {
        preview.push(line);
      }
    }
    return preview.join('\n');
  }

  toggleReasoning(): void {
    this.showReasoning = !this.showReasoning;
  }

  build() {
    Column({ space: this.compact ? 10 : 13 }) {
      if (this.busy || this.statusText) {
        Row({ space: 8 }) {
          if (this.busy) {
            LoadingProgress()
              .width(this.compact ? 12 : 14)
              .height(this.compact ? 12 : 14)
              .color(this.accentColor())
          } else {
            Row() {}
              .width(7)
              .height(7)
              .borderRadius(4)
              .backgroundColor(this.accentColor())
              .opacity(0.55)
          }
          Text(this.busyLabel())
            .fontColor(this.accentColor())
            .fontSize(this.compact ? 12 : 13)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
      }

      if (this.cleanAnswer()) {
        Text(this.cleanAnswer())
          .fontColor(this.textColor())
          .fontSize(this.compact ? 14 : 15)
          .lineHeight(this.compact ? 22 : 25)
          .maxLines(this.maxAnswerLines > 0 ? this.maxAnswerLines : 100)
          .width('100%')
      } else if (!this.busy && this.emptyText) {
        Text(this.emptyText)
          .fontColor(this.mutedColor())
          .fontSize(this.compact ? 13 : 14)
          .lineHeight(this.compact ? 20 : 22)
          .width('100%')
      }

      if (this.visibleReasoning()) {
        Column({ space: 8 }) {
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text('思考过程')
                .fontColor(this.textColor())
                .fontSize(this.compact ? 13 : 14)
                .fontWeight(FontWeight.Medium)
              Text(this.reasoningHint())
                .fontColor(this.mutedColor())
                .fontSize(this.compact ? 11 : 12)
                .lineHeight(16)
                .maxLines(2)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Row({ space: 6 }) {
              Text(this.showReasoning ? '收起' : '展开')
                .fontColor(this.accentColor())
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
              Image($r('app.media.icon_chevron_right'))
                .width(13)
                .height(13)
                .fillColor(this.accentColor())
                .rotate({ angle: this.showReasoning ? 90 : 0 })
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(this.nestedSurfaceColor())
          .borderRadius(14)
          .onClick(() => this.toggleReasoning())

          if (this.showReasoning) {
            Text(this.visibleReasoning())
              .fontColor(this.mutedColor())
              .fontSize(12)
              .lineHeight(18)
              .padding(12)
              .backgroundColor(this.nestedSurfaceColor())
              .borderRadius(12)
              .width('100%')
              .maxLines(100)
          } else {
            Text(this.reasoningPreview())
              .fontColor(this.mutedColor())
              .fontSize(12)
              .lineHeight(18)
              .padding(12)
              .backgroundColor(this.nestedSurfaceColor())
              .borderRadius(12)
              .width('100%')
              .maxLines(this.compact ? 2 : 3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
      }

      if (this.followUpSuggestion) {
        Text(`下一步：${this.followUpSuggestion}`)
          .fontColor(this.accentColor())
          .fontSize(this.compact ? 12 : 13)
          .lineHeight(20)
          .width('100%')
      }

      if (this.sources.length > 0) {
        Column({ space: 8 }) {
          Text('参考依据')
            .fontColor(this.textColor())
            .fontSize(this.compact ? 13 : 14)
            .fontWeight(FontWeight.Bold)
          ForEach(this.sources.slice(0, this.compact ? 3 : 4), (source: SourceRef) => {
            Column({ space: 8 }) {
              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(this.sourceTitle(source))
                    .fontColor(this.textColor())
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.sourceSubtitle(source) || this.sourceTargetHint(source))
                    .fontColor(this.mutedColor())
                    .fontSize(11)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Row({ space: 4 }) {
                  Text(this.sourceActionLabel(source))
                    .fontColor(this.accentColor())
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                  Image($r('app.media.icon_chevron_right'))
                    .width(12)
                    .height(12)
                    .fillColor(this.accentColor())
                }
                .alignItems(VerticalAlign.Center)
              }
              .width('100%')

              Text(source.text || '')
                .fontColor(this.mutedColor())
                .fontSize(12)
                .lineHeight(18)
                .maxLines(this.compact ? 3 : 4)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding(10)
            .backgroundColor(this.nestedSurfaceColor())
            .borderRadius(10)
            .hitTestBehavior(HitTestMode.Block)
            .onClick(() => {
              void this.openSource(source);
            })
          }, (source: SourceRef, index: number) => `${source.chunk_id}-${index}-${source.source}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(this.compact ? 12 : 16)
    .backgroundColor(this.surfaceColor())
    .borderRadius(this.compact ? 14 : 18)
    .border({ width: 1, color: this.responseBorderColor() })
  }
}
