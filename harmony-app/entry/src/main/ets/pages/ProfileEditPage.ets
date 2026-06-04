import { ApiClient } from '../common/ApiClient';
import { UserProfile, emptyProfile } from '../common/Models';
import { goBack } from '../common/Navigation';
import { Theme } from '../common/Theme';
import { UserSession } from '../common/UserSession';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct ProfileEditPage {
  @State pageWidth: number = 390;
  @State profile: UserProfile = emptyProfile();
  @State nickname: string = '';
  @State intro: string = '';
  @State busyText: string = '';
  @State errorText: string = '';
  @State toastText: string = '';
  @State showToast: boolean = false;

  aboutToAppear(): void {
    this.loadProfile();
  }

  hostContext(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext | undefined;
  }

  isCompact(): boolean {
    return this.pageWidth < 360;
  }

  async loadProfile(): Promise<void> {
    const userId = UserSession.currentUserId();
    if (userId <= 0) {
      this.errorText = '请先登录后再编辑资料';
      this.profile = emptyProfile();
      this.nickname = '';
      this.intro = '';
      return;
    }
    this.busyText = '正在加载资料';
    this.errorText = '';
    try {
      const bundle = await ApiClient.profile(userId);
      this.profile = bundle.profile || UserSession.currentProfile() || emptyProfile();
      this.nickname = this.profile.name || '';
      this.intro = this.profile.goal || '';
    } catch (err) {
      this.profile = UserSession.currentProfile() || emptyProfile();
      this.nickname = this.profile.name || '';
      this.intro = this.profile.goal || '';
      this.errorText = `资料加载失败：${err}`;
    } finally {
      this.busyText = '';
    }
  }

  async saveProfile(): Promise<void> {
    const context = this.hostContext();
    if (!context) {
      this.flashToast('当前页面上下文不可用');
      return;
    }
    if (UserSession.currentUserId() <= 0) {
      this.flashToast('请先登录');
      return;
    }
    const nextName = this.nickname.trim();
    const nextIntro = this.intro.trim();
    if (!nextName) {
      this.flashToast('昵称不能为空');
      return;
    }
    this.busyText = '正在保存资料';
    this.errorText = '';
    try {
      const draft: UserProfile = {
        id: this.profile.id,
        account: this.profile.account || String(this.profile.id),
        phone: this.profile.phone || '',
        name: nextName,
        major: this.profile.major || '',
        grade: this.profile.grade || '',
        interests: this.profile.interests || '',
        goal: nextIntro || this.profile.goal || '',
        channels: this.profile.channels || '',
      };
      const saved = await ApiClient.saveProfile(draft);
      this.profile = saved;
      this.nickname = saved.name || '';
      this.intro = saved.goal || '';
      await UserSession.persist(context, saved);
      this.flashToast('资料已保存');
    } catch (err) {
      this.errorText = `保存失败：${err}`;
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
        if (this.errorText) {
          this.StatusBanner(this.errorText, Theme.mobileRed)
        }
        if (this.busyText) {
          this.StatusBanner(this.busyText, Theme.mobileBlue)
        }
        Column() {
          this.AvatarRow()
          this.EditRow('昵称', this.nickname, '请输入昵称', 'name')
          this.EditRow('社区简介', this.intro, '添加个人简介', 'intro')
        }
        .width('100%')
        .padding({ left: 32, right: 32, top: 10 })

        Blank()

        Button('保存')
          .width('86%')
          .height(48)
          .fontColor('#FFFFFF')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#EF3340')
          .borderRadius(24)
          .margin({ bottom: 28 })
          .onClick(() => this.saveProfile())
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')

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
    .onAreaChange((_, area) => {
      const nextWidth = typeof area.width === 'number' ? area.width : Number(area.width);
      if (Number.isFinite(nextWidth) && nextWidth > 0) {
        this.pageWidth = nextWidth;
      }
    })
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontColor('#191A1F')
        .fontSize(48)
        .fontWeight(FontWeight.Regular)
        .width(54)
        .height(58)
        .textAlign(TextAlign.Center)
        .onClick(() => goBack())
      Text('编辑社区资料')
        .fontColor('#202124')
        .fontSize(this.isCompact() ? 25 : 29)
        .fontWeight(FontWeight.Regular)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('')
        .width(54)
    }
    .width('100%')
    .height(92)
    .padding({ left: 18, right: 18, top: 22 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  AvatarRow() {
    Row() {
      Text('头像')
        .fontColor('#202124')
        .fontSize(this.isCompact() ? 23 : 26)
        .layoutWeight(1)

      Image($r('app.media.profile_avatar'))
        .width(54)
        .height(54)
        .borderRadius(27)
        .backgroundColor('#F4F5F7')

      Text('›')
        .fontColor('#B8BCC5')
        .fontSize(34)
        .width(28)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(92)
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 0.5 }, color: '#EEF0F4' })
  }

  @Builder
  EditRow(label: string, value: string, placeholder: string, field: string) {
    Row({ space: 16 }) {
      Text(label)
        .fontColor('#202124')
        .fontSize(this.isCompact() ? 23 : 26)
        .width(field === 'name' ? 86 : 134)
      TextInput({ placeholder, text: value })
        .layoutWeight(1)
        .height(54)
        .fontColor('#32343A')
        .fontSize(this.isCompact() ? 18 : 21)
        .textAlign(TextAlign.End)
        .placeholderColor('#8D929D')
        .backgroundColor('transparent')
        .padding({ left: 0, right: 0 })
        .onChange((text: string) => {
          if (field === 'name') {
            this.nickname = text;
          } else {
            this.intro = text;
          }
        })
      Text('›')
        .fontColor('#B8BCC5')
        .fontSize(34)
        .width(28)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(92)
    .alignItems(VerticalAlign.Center)
    .border({ width: { bottom: 0.5 }, color: '#EEF0F4' })
  }

  @Builder
  StatusBanner(text: string, color: string) {
    Text(text)
      .fontColor('#FFFFFF')
      .fontSize(13)
      .lineHeight(18)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(color)
      .borderRadius(8)
      .width('86%')
      .margin({ bottom: 8 })
  }
}
