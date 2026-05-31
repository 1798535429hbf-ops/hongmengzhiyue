import { Theme } from './Theme';

@Component
export struct BookCover {
  bookId: number = 0;
  title: string = '';
  difficulty: string = '';
  coverColor: string = Theme.softStone;
  widthValue: number = 108;
  heightValue: number = 148;
  titleSize: number = 13;

  private assetForBook(bookId: number): Resource {
    if (bookId === 1) {
      return $r('app.media.cover_ai_modern');
    }
    if (bookId === 2) {
      return $r('app.media.cover_machine_learning');
    }
    if (bookId === 3) {
      return $r('app.media.cover_deep_learning');
    }
    if (bookId === 4) {
      return $r('app.media.cover_algorithm');
    }
    if (bookId === 5) {
      return $r('app.media.cover_english');
    }
    if (bookId === 6) {
      return $r('app.media.cover_classic');
    }
    if (bookId === 7 || bookId === 9) {
      return $r('app.media.cover_system');
    }
    return $r('app.media.cover_design');
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.coverColor || Theme.softStone);

      Image(this.assetForBook(this.bookId))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover);

      Column() {
        Blank()
        Column({ space: 4 }) {
          Text(this.title || 'Book')
            .fontColor(Theme.onDark)
            .fontSize(this.titleSize)
            .fontWeight(FontWeight.Regular)
            .maxLines(2)
            .lineHeight(this.titleSize + 3)
          if (this.difficulty) {
            Text(this.difficulty)
              .fontColor(Theme.coralSoft)
              .fontSize(10)
              .fontWeight(FontWeight.Regular)
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding(10)
      .backgroundColor('#1A000000');
    }
    .width(this.widthValue)
    .height(this.heightValue)
    .borderRadius(Theme.radius.md)
    .clip(true);
  }
}
