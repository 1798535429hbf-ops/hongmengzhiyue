const SPLASH_SOURCE_WIDTH: number = 853;
const SPLASH_SOURCE_HEIGHT: number = 1844;

@Component
export struct SplashScreen {
  @Prop pageWidth: number = 390;
  @Prop pageHeight: number = 780;

  private shouldShowWholeImage(): boolean {
    if (this.pageWidth <= 0 || this.pageHeight <= 0) {
      return false;
    }
    const aspect: number = this.pageWidth / this.pageHeight;
    return this.pageWidth >= 720 || aspect >= 0.7;
  }

  private coverScale(): number {
    if (this.pageWidth <= 0 || this.pageHeight <= 0) {
      return 1;
    }
    const widthScale: number = this.pageWidth / SPLASH_SOURCE_WIDTH;
    const heightScale: number = this.pageHeight / SPLASH_SOURCE_HEIGHT;
    if (this.shouldShowWholeImage()) {
      return Math.min(widthScale, heightScale);
    }
    return Math.max(widthScale, heightScale);
  }

  private coverWidth(): number {
    return Math.ceil(SPLASH_SOURCE_WIDTH * this.coverScale());
  }

  private coverHeight(): number {
    return Math.ceil(SPLASH_SOURCE_HEIGHT * this.coverScale());
  }

  private coverX(): number {
    return Math.floor((this.pageWidth - this.coverWidth()) / 2);
  }

  private coverY(): number {
    if (this.shouldShowWholeImage()) {
      return Math.floor((this.pageHeight - this.coverHeight()) / 2);
    }
    const croppedHeight: number = this.coverHeight() - this.pageHeight;
    if (croppedHeight <= 0) {
      return 0;
    }
    if (this.pageWidth > this.pageHeight) {
      return Math.floor(-croppedHeight * 0.47);
    }
    if (this.pageWidth >= 600) {
      return Math.floor(-croppedHeight * 0.44);
    }
    return Math.floor(-croppedHeight / 2);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($r('app.media.launch_splash'))
        .width(this.coverWidth())
        .height(this.coverHeight())
        .objectFit(ImageFit.Fill)
        .position({ x: this.coverX(), y: this.coverY() });
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor('#F3EEE7')
    .onClick(() => {});
  }
}
