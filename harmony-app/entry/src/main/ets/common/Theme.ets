export class ThemeRadius {
  readonly xs: number = 4;
  readonly sm: number = 8;
  readonly md: number = 16;
  readonly lg: number = 22;
  readonly xl: number = 30;
  readonly pill: number = 32;
  readonly full: number = 9999;
}

export class ThemeSpace {
  readonly xxs: number = 2;
  readonly xs: number = 6;
  readonly sm: number = 8;
  readonly md: number = 12;
  readonly lg: number = 16;
  readonly xl: number = 24;
  readonly xxl: number = 32;
  readonly xxxl: number = 48;
  readonly section: number = 80;
}

export class ThemeType {
  readonly heroDisplay: number = 48;
  readonly productDisplay: number = 40;
  readonly sectionDisplay: number = 32;
  readonly sectionHeading: number = 28;
  readonly cardHeading: number = 22;
  readonly featureHeading: number = 18;
  readonly bodyLarge: number = 16;
  readonly body: number = 14;
  readonly button: number = 14;
  readonly caption: number = 12;
  readonly micro: number = 11;
  readonly monoLabel: number = 12;
}

export class Theme {
  static readonly canvas: string = '#FFFFFF';
  static readonly canvasAlt: string = '#F7F7F4';
  static readonly surface: string = '#FFFFFF';
  static readonly softStone: string = '#EEECE7';
  static readonly paleGreen: string = '#EDFCE9';
  static readonly paleBlue: string = '#F1F5FF';
  static readonly ink: string = '#212121';
  static readonly primary: string = '#17171C';
  static readonly primaryPressed: string = '#000000';
  static readonly deepGreen: string = '#003C33';
  static readonly darkNavy: string = '#071829';
  static readonly actionBlue: string = '#1863DC';
  static readonly focusBlue: string = '#4C6EE6';
  static readonly coral: string = '#FF7759';
  static readonly coralSoft: string = '#FFAD9B';
  static readonly line: string = '#D9D9DD';
  static readonly borderLight: string = '#E5E7EB';
  static readonly cardBorder: string = '#F2F2F2';
  static readonly muted: string = '#93939F';
  static readonly slate: string = '#75758A';
  static readonly bodyMuted: string = '#616161';
  static readonly onPrimary: string = '#FFFFFF';
  static readonly onDark: string = '#FFFFFF';
  static readonly surfaceAlt: string = '#EEECE7';
  static readonly surfaceMuted: string = '#F5F4F0';
  static readonly dark: string = '#17171C';
  static readonly darkSoft: string = '#24242B';
  static readonly darkPanel: string = '#101820';
  static readonly primarySoft: string = '#EDFCE9';
  static readonly textOnPrimary: string = '#FFFFFF';
  static readonly textOnDark: string = '#FFFFFF';
  static readonly onDarkSoft: string = '#B8BCC6';
  static readonly accentTeal: string = '#003C33';
  static readonly accentAmber: string = '#FF7759';
  static readonly body: string = '#616161';
  static readonly mutedSoft: string = '#75758A';
  static readonly error: string = '#B30000';
  static readonly success: string = '#12704C';
  static readonly warning: string = '#A86600';
  static readonly shadowSoft: string = '0 1px 3px rgba(20, 20, 19, 0.08)';
  static readonly mobileCanvas: string = '#FBFBFD';
  static readonly mobileSurface: string = '#FFFFFF';
  static readonly mobileSurfaceSoft: string = '#F7F8FC';
  static readonly mobileWarmSurface: string = '#FFF5EF';
  static readonly mobileSidebar: string = '#F5F6FA';
  static readonly mobileLine: string = '#E7E9F0';
  static readonly mobileText: string = '#20233A';
  static readonly mobileSubtext: string = '#7B7F95';
  static readonly mobileMuted: string = '#A3A9BB';
  static readonly mobileBlue: string = '#5D82FF';
  static readonly mobileBlueSoft: string = '#EAF0FF';
  static readonly mobileRed: string = '#FF5C58';
  static readonly mobileOrange: string = '#FF8B2A';
  static readonly mobilePurple: string = '#8A63FF';
  static readonly mobilePeach: string = '#FFF2E8';
  static readonly mobileGreen: string = '#63C39B';
  static readonly mobileShadow: string = '#120F2A';
  static readonly radius: ThemeRadius = new ThemeRadius();
  static readonly space: ThemeSpace = new ThemeSpace();
  static readonly type: ThemeType = new ThemeType();
}
