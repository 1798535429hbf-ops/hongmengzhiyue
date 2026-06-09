import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const APP_DARK_MODE_KEY: string = 'smartread_dark_mode';
export const APP_AUTO_APPEARANCE_KEY: string = 'smartread_auto_appearance';
export const APP_FONT_FAMILY_KEY: string = 'smartread_font_family';
export const APP_ONE_HAND_MODE_KEY: string = 'smartread_one_hand_mode';
export const APP_READER_PAGE_MODE_KEY: string = 'smartread_reader_page_mode';
export const APP_SCRIPT_VARIANT_KEY: string = 'smartread_script_variant';
export const APP_VOLUME_PAGE_TURN_KEY: string = 'smartread_volume_page_turn';

const SETTINGS_PREFERENCES_NAME: string = 'smartread_app_settings';
const DEFAULT_FONT_FAMILY: string = 'system';
const DEFAULT_READER_PAGE_MODE: string = 'scroll';
const DEFAULT_SCRIPT_VARIANT: string = 'simplified';

interface ScriptCharPair {
  simplified: string;
  traditional: string;
}

const SCRIPT_CHAR_PAIRS: ScriptCharPair[] = [
  { simplified: '书', traditional: '書' }, { simplified: '读', traditional: '讀' },
  { simplified: '阅', traditional: '閱' }, { simplified: '习', traditional: '習' },
  { simplified: '学', traditional: '學' }, { simplified: '设', traditional: '設' },
  { simplified: '置', traditional: '置' }, { simplified: '体', traditional: '體' },
  { simplified: '简', traditional: '簡' }, { simplified: '繁', traditional: '繁' },
  { simplified: '开', traditional: '開' }, { simplified: '启', traditional: '啟' },
  { simplified: '关', traditional: '關' }, { simplified: '闭', traditional: '閉' },
  { simplified: '页', traditional: '頁' }, { simplified: '键', traditional: '鍵' },
  { simplified: '音', traditional: '音' }, { simplified: '量', traditional: '量' },
  { simplified: '单', traditional: '單' }, { simplified: '手', traditional: '手' },
  { simplified: '模', traditional: '模' }, { simplified: '式', traditional: '式' },
  { simplified: '翻', traditional: '翻' }, { simplified: '计', traditional: '計' },
  { simplified: '划', traditional: '劃' }, { simplified: '录', traditional: '錄' },
  { simplified: '问', traditional: '問' }, { simplified: '题', traditional: '題' },
  { simplified: '标', traditional: '標' }, { simplified: '签', traditional: '籤' },
  { simplified: '记', traditional: '記' }, { simplified: '节', traditional: '節' },
  { simplified: '后', traditional: '後' }, { simplified: '续', traditional: '續' },
  { simplified: '点', traditional: '點' }, { simplified: '击', traditional: '擊' },
  { simplified: '个', traditional: '個' }, { simplified: '为', traditional: '為' },
  { simplified: '与', traditional: '與' }, { simplified: '这', traditional: '這' },
  { simplified: '选', traditional: '選' }, { simplified: '择', traditional: '擇' },
  { simplified: '导', traditional: '導' }, { simplified: '航', traditional: '航' },
  { simplified: '账', traditional: '帳' }, { simplified: '号', traditional: '號' },
  { simplified: '头', traditional: '頭' }, { simplified: '像', traditional: '像' },
  { simplified: '昵', traditional: '暱' }, { simplified: '称', traditional: '稱' },
  { simplified: '邮', traditional: '郵' }, { simplified: '箱', traditional: '箱' },
  { simplified: '密', traditional: '密' }, { simplified: '码', traditional: '碼' },
  { simplified: '登', traditional: '登' }, { simplified: '录', traditional: '錄' },
  { simplified: '退', traditional: '退' }, { simplified: '出', traditional: '出' },
  { simplified: '换', traditional: '換' }, { simplified: '绑', traditional: '綁' },
  { simplified: '定', traditional: '定' }, { simplified: '重', traditional: '重' },
  { simplified: '新', traditional: '新' }, { simplified: '旧', traditional: '舊' },
  { simplified: '保', traditional: '保' }, { simplified: '存', traditional: '存' },
  { simplified: '资', traditional: '資' }, { simplified: '料', traditional: '料' },
  { simplified: '当', traditional: '當' }, { simplified: '前', traditional: '前' },
  { simplified: '用', traditional: '用' }, { simplified: '户', traditional: '戶' },
  { simplified: '兴', traditional: '興' }, { simplified: '趣', traditional: '趣' },
  { simplified: '课', traditional: '課' }, { simplified: '程', traditional: '程' },
  { simplified: '拓', traditional: '拓' }, { simplified: '展', traditional: '展' },
  { simplified: '专', traditional: '專' }, { simplified: '业', traditional: '業' },
  { simplified: '门', traditional: '門' }, { simplified: '通', traditional: '通' },
  { simplified: '识', traditional: '識' }, { simplified: '经', traditional: '經' },
  { simplified: '济', traditional: '濟' }, { simplified: '艺', traditional: '藝' },
  { simplified: '术', traditional: '術' }, { simplified: '历', traditional: '歷' },
  { simplified: '史', traditional: '史' }, { simplified: '文', traditional: '文' },
  { simplified: '化', traditional: '化' }, { simplified: '观', traditional: '觀' },
  { simplified: '察', traditional: '察' }, { simplified: '写', traditional: '寫' },
  { simplified: '作', traditional: '作' }, { simplified: '达', traditional: '達' },
  { simplified: '清', traditional: '清' }, { simplified: '空', traditional: '空' },
  { simplified: '加', traditional: '加' }, { simplified: '全', traditional: '全' },
  { simplified: '部', traditional: '部' }, { simplified: '分', traditional: '分' },
  { simplified: '类', traditional: '類' }, { simplified: '库', traditional: '庫' },
  { simplified: '更', traditional: '更' }, { simplified: '多', traditional: '多' },
  { simplified: '刷', traditional: '刷' }, { simplified: '立', traditional: '立' },
  { simplified: '即', traditional: '即' }, { simplified: '效', traditional: '效' },
  { simplified: '随', traditional: '隨' }, { simplified: '系', traditional: '系' },
  { simplified: '统', traditional: '統' }, { simplified: '时', traditional: '時' },
  { simplified: '间', traditional: '間' }, { simplified: '变', traditional: '變' },
  { simplified: '外', traditional: '外' }, { simplified: '观', traditional: '觀' },
  { simplified: '护', traditional: '護' }, { simplified: '眼', traditional: '眼' },
  { simplified: '深', traditional: '深' }, { simplified: '色', traditional: '色' },
  { simplified: '已', traditional: '已' }, { simplified: '未', traditional: '未' },
  { simplified: '请', traditional: '請' }, { simplified: '输', traditional: '輸' },
  { simplified: '入', traditional: '入' }, { simplified: '验', traditional: '驗' },
  { simplified: '证', traditional: '證' }, { simplified: '成', traditional: '成' },
  { simplified: '功', traditional: '功' }, { simplified: '失', traditional: '失' },
  { simplified: '败', traditional: '敗' }, { simplified: '错', traditional: '錯' },
  { simplified: '误', traditional: '誤' }, { simplified: '源', traditional: '源' },
  { simplified: '摘', traditional: '摘' }, { simplified: '章', traditional: '章' },
  { simplified: '本', traditional: '本' }, { simplified: '正', traditional: '正' },
  { simplified: '行', traditional: '行' }, { simplified: '间', traditional: '間' },
  { simplified: '距', traditional: '距' }, { simplified: '亮', traditional: '亮' },
  { simplified: '度', traditional: '度' }, { simplified: '自', traditional: '自' },
  { simplified: '动', traditional: '動' }, { simplified: '速', traditional: '速' },
  { simplified: '慢', traditional: '慢' }, { simplified: '中', traditional: '中' },
  { simplified: '快', traditional: '快' }, { simplified: '止', traditional: '止' },
  { simplified: '夜', traditional: '夜' }, { simplified: '纯', traditional: '純' },
  { simplified: '白', traditional: '白' }, { simplified: '绿', traditional: '綠' },
  { simplified: '藏', traditional: '藏' }, { simplified: '购', traditional: '購' },
  { simplified: '买', traditional: '買' }, { simplified: '借', traditional: '借' },
  { simplified: '约', traditional: '約' }, { simplified: '渠', traditional: '渠' },
  { simplified: '道', traditional: '道' }, { simplified: '找', traditional: '找' },
  { simplified: '搜', traditional: '搜' }, { simplified: '索', traditional: '索' },
  { simplified: '推', traditional: '推' }, { simplified: '荐', traditional: '薦' },
  { simplified: '伴', traditional: '伴' }, { simplified: '答', traditional: '答' },
  { simplified: '案', traditional: '案' }, { simplified: '来', traditional: '來' },
  { simplified: '回', traditional: '回' }, { simplified: '写', traditional: '寫' },
  { simplified: '确', traditional: '確' }, { simplified: '认', traditional: '認' },
  { simplified: '消', traditional: '消' }, { simplified: '页', traditional: '頁' },
  { simplified: '题', traditional: '題' },
];

function nightByClock(): boolean {
  const hour: number = new Date().getHours();
  return hour >= 20 || hour < 7;
}

function readBool(value: preferences.ValueType, fallback: boolean): boolean {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    return value === 'true';
  }
  return fallback;
}

function readString(value: preferences.ValueType, fallback: string): string {
  return typeof value === 'string' && value.length > 0 ? value : fallback;
}

function traditionalChar(ch: string): string {
  for (let i = 0; i < SCRIPT_CHAR_PAIRS.length; i++) {
    if (SCRIPT_CHAR_PAIRS[i].simplified === ch) {
      return SCRIPT_CHAR_PAIRS[i].traditional;
    }
  }
  return ch;
}

export class AppSettings {
  private static async prefs(context: common.UIAbilityContext): Promise<preferences.Preferences> {
    return await preferences.getPreferences(context, SETTINGS_PREFERENCES_NAME);
  }

  static ensureDefaults(): void {
    if (AppStorage.get<boolean>(APP_DARK_MODE_KEY) === undefined) {
      AppStorage.setOrCreate(APP_DARK_MODE_KEY, false);
    }
    if (AppStorage.get<boolean>(APP_AUTO_APPEARANCE_KEY) === undefined) {
      AppStorage.setOrCreate(APP_AUTO_APPEARANCE_KEY, false);
    }
    if (AppStorage.get<string>(APP_FONT_FAMILY_KEY) === undefined) {
      AppStorage.setOrCreate(APP_FONT_FAMILY_KEY, DEFAULT_FONT_FAMILY);
    }
    if (AppStorage.get<boolean>(APP_ONE_HAND_MODE_KEY) === undefined) {
      AppStorage.setOrCreate(APP_ONE_HAND_MODE_KEY, false);
    }
    if (AppStorage.get<string>(APP_READER_PAGE_MODE_KEY) === undefined) {
      AppStorage.setOrCreate(APP_READER_PAGE_MODE_KEY, DEFAULT_READER_PAGE_MODE);
    }
    if (AppStorage.get<string>(APP_SCRIPT_VARIANT_KEY) === undefined) {
      AppStorage.setOrCreate(APP_SCRIPT_VARIANT_KEY, DEFAULT_SCRIPT_VARIANT);
    }
    if (AppStorage.get<boolean>(APP_VOLUME_PAGE_TURN_KEY) === undefined) {
      AppStorage.setOrCreate(APP_VOLUME_PAGE_TURN_KEY, false);
    }
  }

  static async bootstrap(context: common.UIAbilityContext): Promise<void> {
    AppSettings.ensureDefaults();
    try {
      const store = await AppSettings.prefs(context);
      const autoAppearance: boolean = readBool(await store.get(APP_AUTO_APPEARANCE_KEY, false), false);
      const darkMode: boolean = autoAppearance
        ? nightByClock()
        : readBool(await store.get(APP_DARK_MODE_KEY, false), false);
      AppStorage.setOrCreate(APP_AUTO_APPEARANCE_KEY, autoAppearance);
      AppStorage.setOrCreate(APP_DARK_MODE_KEY, darkMode);
      AppStorage.setOrCreate(APP_FONT_FAMILY_KEY, readString(await store.get(APP_FONT_FAMILY_KEY, DEFAULT_FONT_FAMILY), DEFAULT_FONT_FAMILY));
      AppStorage.setOrCreate(APP_ONE_HAND_MODE_KEY, readBool(await store.get(APP_ONE_HAND_MODE_KEY, false), false));
      AppStorage.setOrCreate(APP_READER_PAGE_MODE_KEY, AppSettings.normalizeReaderPageMode(readString(await store.get(APP_READER_PAGE_MODE_KEY, DEFAULT_READER_PAGE_MODE), DEFAULT_READER_PAGE_MODE)));
      AppStorage.setOrCreate(APP_SCRIPT_VARIANT_KEY, readString(await store.get(APP_SCRIPT_VARIANT_KEY, DEFAULT_SCRIPT_VARIANT), DEFAULT_SCRIPT_VARIANT));
      AppStorage.setOrCreate(APP_VOLUME_PAGE_TURN_KEY, readBool(await store.get(APP_VOLUME_PAGE_TURN_KEY, false), false));
    } catch (_) {
      AppSettings.ensureDefaults();
    }
  }

  static fontFamilyValue(fontFamily: string): string {
    if (fontFamily === 'serif') {
      return 'Songti SC';
    }
    if (fontFamily === 'rounded') {
      return 'HarmonyOS Sans SC';
    }
    return 'HarmonyOS Sans';
  }

  static scriptText(text: string, variant: string): string {
    if (variant !== 'traditional' || !text) {
      return text;
    }
    let result: string = '';
    for (let i = 0; i < text.length; i++) {
      result += traditionalChar(text.charAt(i));
    }
    return result;
  }

  static autoDarkMode(): boolean {
    return nightByClock();
  }

  static normalizeReaderPageMode(value: string): string {
    return value === 'page' ? 'page' : DEFAULT_READER_PAGE_MODE;
  }

  static async setDarkMode(context: common.UIAbilityContext | undefined, value: boolean): Promise<void> {
    AppStorage.setOrCreate(APP_DARK_MODE_KEY, value);
    if (!context) {
      return;
    }
    const store = await AppSettings.prefs(context);
    await store.put(APP_DARK_MODE_KEY, value);
    await store.flush();
  }

  static async setAutoAppearance(context: common.UIAbilityContext | undefined, value: boolean): Promise<void> {
    AppStorage.setOrCreate(APP_AUTO_APPEARANCE_KEY, value);
    if (value) {
      AppStorage.setOrCreate(APP_DARK_MODE_KEY, nightByClock());
    }
    if (!context) {
      return;
    }
    const store = await AppSettings.prefs(context);
    await store.put(APP_AUTO_APPEARANCE_KEY, value);
    if (value) {
      await store.put(APP_DARK_MODE_KEY, nightByClock());
    }
    await store.flush();
  }

  static async setFontFamily(context: common.UIAbilityContext | undefined, value: string): Promise<void> {
    AppStorage.setOrCreate(APP_FONT_FAMILY_KEY, value || DEFAULT_FONT_FAMILY);
    if (!context) {
      return;
    }
    const store = await AppSettings.prefs(context);
    await store.put(APP_FONT_FAMILY_KEY, value || DEFAULT_FONT_FAMILY);
    await store.flush();
  }

  static async setOneHandMode(context: common.UIAbilityContext | undefined, value: boolean): Promise<void> {
    AppStorage.setOrCreate(APP_ONE_HAND_MODE_KEY, value);
    if (!context) {
      return;
    }
    const store = await AppSettings.prefs(context);
    await store.put(APP_ONE_HAND_MODE_KEY, value);
    await store.flush();
  }

  static async setReaderPageMode(context: common.UIAbilityContext | undefined, value: string): Promise<void> {
    const next: string = AppSettings.normalizeReaderPageMode(value);
    AppStorage.setOrCreate(APP_READER_PAGE_MODE_KEY, next);
    if (!context) {
      return;
    }
    const store = await AppSettings.prefs(context);
    await store.put(APP_READER_PAGE_MODE_KEY, next);
    await store.flush();
  }

  static async setScriptVariant(context: common.UIAbilityContext | undefined, value: string): Promise<void> {
    const next: string = value === 'traditional' ? 'traditional' : DEFAULT_SCRIPT_VARIANT;
    AppStorage.setOrCreate(APP_SCRIPT_VARIANT_KEY, next);
    if (!context) {
      return;
    }
    const store = await AppSettings.prefs(context);
    await store.put(APP_SCRIPT_VARIANT_KEY, next);
    await store.flush();
  }

  static async setVolumePageTurn(context: common.UIAbilityContext | undefined, value: boolean): Promise<void> {
    AppStorage.setOrCreate(APP_VOLUME_PAGE_TURN_KEY, value);
    if (!context) {
      return;
    }
    const store = await AppSettings.prefs(context);
    await store.put(APP_VOLUME_PAGE_TURN_KEY, value);
    await store.flush();
  }
}
