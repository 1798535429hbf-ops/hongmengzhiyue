import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ApiClient } from './ApiClient';
import { ProfileBundle, UserProfile } from './Models';

export const SESSION_USER_ID_KEY: string = 'smartread_session_user_id';
export const SESSION_USER_NAME_KEY: string = 'smartread_session_user_name';
export const SESSION_PROFILE_JSON_KEY: string = 'smartread_session_profile_json';

const SESSION_PREFERENCES_NAME: string = 'smartread_user_session';
const STORED_PROFILE_KEY: string = 'profile_json';

function normalizeUserId(value: string | number): number {
  if (typeof value === 'number') {
    return Number.isFinite(value) && value > 0 ? Math.floor(value) : 0;
  }
  const parsed: number = Number(value.trim());
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 0;
}

function parseProfile(raw: string): UserProfile | null {
  if (!raw) {
    return null;
  }
  try {
    const profile = JSON.parse(raw) as UserProfile;
    if (profile && Number.isFinite(profile.id) && profile.id > 0) {
      return profile;
    }
  } catch (_) {
  }
  return null;
}

function putSessionInAppStorage(profile: UserProfile | null): void {
  if (!profile) {
    AppStorage.setOrCreate(SESSION_USER_ID_KEY, 0);
    AppStorage.setOrCreate(SESSION_USER_NAME_KEY, '');
    AppStorage.setOrCreate(SESSION_PROFILE_JSON_KEY, '');
    return;
  }
  AppStorage.setOrCreate(SESSION_USER_ID_KEY, profile.id);
  AppStorage.setOrCreate(SESSION_USER_NAME_KEY, profile.name || `用户 ${profile.id}`);
  AppStorage.setOrCreate(SESSION_PROFILE_JSON_KEY, JSON.stringify(profile));
}

export class UserSession {
  static currentUserId(): number {
    const value = AppStorage.get<number>(SESSION_USER_ID_KEY);
    return typeof value === 'number' && Number.isFinite(value) && value > 0 ? Math.floor(value) : 0;
  }

  static currentUserName(): string {
    const value = AppStorage.get<string>(SESSION_USER_NAME_KEY);
    return value || '';
  }

  static currentProfile(): UserProfile | null {
    const raw = AppStorage.get<string>(SESSION_PROFILE_JSON_KEY);
    return parseProfile(raw || '');
  }

  static isLoggedIn(): boolean {
    return UserSession.currentUserId() > 0;
  }

  private static async sessionPreferences(context: common.UIAbilityContext): Promise<preferences.Preferences> {
    return await preferences.getPreferences(context, SESSION_PREFERENCES_NAME);
  }

  static async bootstrap(context: common.UIAbilityContext): Promise<UserProfile | null> {
    try {
      const prefs = await UserSession.sessionPreferences(context);
      const raw: string = await prefs.get(STORED_PROFILE_KEY, '') as string;
      const profile = parseProfile(raw);
      putSessionInAppStorage(profile);
      return profile;
    } catch (_) {
      putSessionInAppStorage(null);
      return null;
    }
  }

  static async persist(context: common.UIAbilityContext, profile: UserProfile): Promise<void> {
    const prefs = await UserSession.sessionPreferences(context);
    await prefs.put(STORED_PROFILE_KEY, JSON.stringify(profile));
    await prefs.flush();
    putSessionInAppStorage(profile);
  }

  static async login(context: common.UIAbilityContext, userIdText: string): Promise<UserProfile> {
    const userId = normalizeUserId(userIdText);
    if (userId <= 0) {
      throw new Error('请输入有效的用户 ID 或学号。');
    }
    const bundle: ProfileBundle = await ApiClient.profile(userId);
    if (!bundle.profile || !Number.isFinite(bundle.profile.id) || bundle.profile.id <= 0) {
      throw new Error('后端没有返回可用的用户画像，请先注册。');
    }
    await UserSession.persist(context, bundle.profile);
    return bundle.profile;
  }

  static async loginWithPhone(context: common.UIAbilityContext, phone: string, password: string): Promise<UserProfile> {
    const profile: UserProfile = await ApiClient.loginWithPhone(phone, password);
    await UserSession.persist(context, profile);
    return profile;
  }

  static async registerWithPhone(context: common.UIAbilityContext, phone: string, password: string): Promise<UserProfile> {
    const profile: UserProfile = await ApiClient.registerWithPhone(phone, password);
    await UserSession.persist(context, profile);
    return profile;
  }

  static async loginWithProvider(context: common.UIAbilityContext, provider: string): Promise<UserProfile> {
    const profile: UserProfile = await ApiClient.providerLogin(provider, `${provider}_demo`);
    await UserSession.persist(context, profile);
    return profile;
  }

  static async register(context: common.UIAbilityContext, profile: UserProfile): Promise<UserProfile> {
    const userId = normalizeUserId(profile.id);
    if (userId <= 0) {
      throw new Error('请输入有效的用户 ID 或学号。');
    }
    const draft: UserProfile = {
      id: userId,
      account: profile.account || String(userId),
      phone: profile.phone || String(userId),
      name: profile.name || `智阅同学 ${userId}`,
      major: profile.major || '待完善专业',
      grade: profile.grade || '大二',
      interests: profile.interests || '课程延伸阅读,专业入门,AI 伴读',
      goal: profile.goal || '找到合适的书并持续读下去',
      channels: profile.channels || 'library,jd,dangdang,second_hand',
    };
    const savedProfile: UserProfile = await ApiClient.saveProfile(draft);
    let nextProfile: UserProfile = savedProfile;
    try {
      const bundle: ProfileBundle = await ApiClient.profile(savedProfile.id);
      if (bundle.profile && bundle.profile.id > 0) {
        nextProfile = bundle.profile;
      }
    } catch (_) {
    }
    await UserSession.persist(context, nextProfile);
    return nextProfile;
  }

  static async logout(context: common.UIAbilityContext): Promise<void> {
    const prefs = await UserSession.sessionPreferences(context);
    await prefs.put(STORED_PROFILE_KEY, '');
    await prefs.flush();
    putSessionInAppStorage(null);
  }
}
