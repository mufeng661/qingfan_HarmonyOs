import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppState } from '../model/AppState';
import { DailyStats } from '../model/Types';
import { pad2 } from '../model/Store';

const DOMAIN = 0x0000;
// formId -> 卡片尺寸 的持久化文件名（进程被回收后靠它恢复）
const DIM_PREFS = 'qf_widget_dims';

// 桌面小组件（FR-10）
// 规格：2*2（多邻国式极简卡）/ 2*4（宽卡，承接原 4*4 的全部内容）。
// 4*4 已下架（form_config 的 supportDimensions 不再声明），但 dimNameOf 仍保留 4*4 分支：
// 桌面若残留改动前添加的 4*4 卡片，其尺寸已持久化在 Preferences 里，刷新时要能正确还原。
// HarmonyOS 卡片规格无 4*2，对应为 2*4（横向长条）。
export default class QfWidgetAbility extends FormExtensionAbility {
  // formId -> dimension（内存缓存；miss 时回落 Preferences）
  private dimMap: Map<string, string> = new Map();
  private prefs: preferences.Preferences | null = null;

  onAddForm(want: Want): formBindingData.FormBindingData {
    const dim: string = this.dimensionOf(want);
    const formId: string = this.identityOf(want);
    hilog.info(DOMAIN, 'testTag', `onAddForm formId=${formId} dim=${dim}`);
    if (formId.length > 0) {
      this.dimMap.set(formId, dim);
      this.persistDim(formId, dim);
    }
    return this.buildFormData(dim);
  }

  onCastToNormalForm(formId: string): void {
    hilog.info(DOMAIN, 'testTag', 'onCastToNormalForm');
  }

  onUpdateForm(formId: string): void {
    // 系统定时刷新（form_config 的 updateDuration）不携带尺寸参数，而且此时本 Ability
    // 很可能已被回收重建（内存里的 dimMap 为空）——所以按「内存 → Preferences → 2*2」逐级回退，
    // 否则一张 4×4 卡片会在半小时后悄悄变回 2×2 的小布局。
    this.dimOf(formId).then((dim: string) => {
      const data: formBindingData.FormBindingData = this.buildFormData(dim);
      formProvider.updateForm(formId, data).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', `updateForm failed, code: ${err.code}`);
      });
    });
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, 'testTag', `onFormEvent ${formId} ${message}`);
  }

  onRemoveForm(formId: string): void {
    this.dimMap.delete(formId);
    this.forgetDim(formId);
  }

  private async loadPrefs(): Promise<preferences.Preferences | null> {
    if (this.prefs !== null) {
      return this.prefs;
    }
    try {
      const p: preferences.Preferences = await preferences.getPreferences(this.context, DIM_PREFS);
      this.prefs = p;
      return p;
    } catch (e) {
      return null;
    }
  }

  private async dimOf(formId: string): Promise<string> {
    const cached: string | undefined = this.dimMap.get(formId);
    if (cached !== undefined) {
      return cached;
    }
    const p: preferences.Preferences | null = await this.loadPrefs();
    if (p !== null) {
      try {
        const v: preferences.ValueType = await p.get(formId, '');
        if (typeof v === 'string') {
          const s: string = v as string;
          if (s.length > 0) {
            this.dimMap.set(formId, s);
            return s;
          }
        }
      } catch (e) {
        hilog.error(DOMAIN, 'testTag', 'read dim failed');
      }
    }
    return '2*2';
  }

  private persistDim(formId: string, dim: string): void {
    this.loadPrefs().then((p: preferences.Preferences | null) => {
      if (p === null) {
        return;
      }
      p.put(formId, dim).then(() => {
        p.flush();
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', `persist dim failed, code: ${err.code}`);
      });
    });
  }

  private forgetDim(formId: string): void {
    this.loadPrefs().then((p: preferences.Preferences | null) => {
      if (p === null) {
        return;
      }
      p.delete(formId).then(() => {
        p.flush();
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', `forget dim failed, code: ${err.code}`);
      });
    });
  }

  private identityOf(want: Want): string {
    const params: Record<string, Object> | undefined = want?.parameters;
    if (params === undefined) {
      return '';
    }
    const v: Object | undefined = params[formInfo.FormParam.IDENTITY_KEY];
    if (typeof v === 'string') {
      return v as string;
    }
    return '';
  }

  private dimensionOf(want: Want): string {
    const params: Record<string, Object> | undefined = want?.parameters;
    if (params !== undefined) {
      const d: Object | undefined = params[formInfo.FormParam.DIMENSION_KEY];
      // 系统（桌面长按添加 / 卡片管理页）下发的是 formInfo.FormDimension 枚举**数字**：
      // Dimension_1_2=1 / Dimension_2_2=2 / Dimension_2_4=3 / Dimension_4_4=4。
      // 注意 formInfo.FormParam 的 SDK 注释写的就是 `DIMENSION_KEY: FormDimension.Dimension_1_2`。
      // 之前这里只认字符串 '2*2'，数字一律匹配不上 → 永远回退 '2*2'，
      // 于是 2×4 / 4×4 卡片也按 2×2 的布局渲染。
      if (typeof d === 'number') {
        return QfWidgetAbility.dimNameOf(d as number);
      }
      // 容错：个别入口 / 旧版本可能给字符串
      if (typeof d === 'string') {
        return d as string;
      }
    }
    return '2*2';
  }

  private static dimNameOf(code: number): string {
    if (code === formInfo.FormDimension.Dimension_2_4) {
      return '2*4';
    }
    if (code === formInfo.FormDimension.Dimension_4_4) {
      return '4*4';
    }
    return '2*2';
  }

  private buildFormData(dim: string): formBindingData.FormBindingData {
    const key: string = AppState.todayKey();
    const stats: Record<string, DailyStats> = AppState.instance.stats;
    let s: DailyStats | undefined = undefined;
    if (stats[key] !== undefined) {
      s = stats[key];
    }
    const done: number = s !== undefined ? s.pomodoroCount : 0;
    const goal: number = AppState.instance.challengeGoal;
    const min: number = s !== undefined ? s.focusMinutes : 0;
    const user = AppState.instance.user;
    const streak: number = user !== null ? user.streak : 0;

    let totalPomos: number = 0;
    const keys: string[] = Object.keys(stats);
    for (let i = 0; i < keys.length; i++) {
      const item: DailyStats | undefined = stats[keys[i]];
      if (item !== undefined) {
        totalPomos += item.pomodoroCount;
      }
    }
    const totalTrees: number = Math.floor(totalPomos / 10);

    const now: Date = new Date();
    const dateStr: string = pad2(now.getMonth() + 1) + '月' + pad2(now.getDate()) + '日';

    // 所有尺寸都把完整字段推下去：卡片页的 @LocalStorageProp 一旦拿不到对应 Key，
    // 就只能退回声明处的默认值（0），会出现「切到 4×4 却显示 0 分钟」这类假数据。
    // 统一全量下发，尺寸差异只体现在 WidgetCard 用哪几个字段。
    const payload: Record<string, string> = {};
    payload['dimension'] = dim;
    payload['title'] = '🌿 青番';
    payload['done'] = done.toString();
    payload['goal'] = goal.toString();
    payload['min'] = min.toString();
    payload['streak'] = streak.toString();
    payload['trees'] = totalTrees.toString();
    payload['date'] = dateStr;
    payload['progressPct'] = goal > 0 ? Math.min(100, Math.floor(done / goal * 100)).toString() : '0';
    return formBindingData.createFormBindingData(payload);
  }
}
