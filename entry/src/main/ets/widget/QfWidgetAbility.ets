import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppState } from '../model/AppState';
import { DailyStats } from '../model/Types';
import { pad2 } from '../model/Store';

const DOMAIN = 0x0000;

// 桌面小组件（FR-10）
// 支持 2*2 / 2*4 / 4*4 三种尺寸；HarmonyOS 卡片规格无 4*2，对应为 2*4（横向长条）
export default class QfWidgetAbility extends FormExtensionAbility {
  // formId -> dimension
  private dimMap: Map<string, string> = new Map();

  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, 'testTag', 'QfWidgetAbility onAddForm');
    const dim: string = this.dimensionOf(want);
    const formId: string = this.identityOf(want);
    if (formId.length > 0) {
      this.dimMap.set(formId, dim);
    }
    return this.buildFormData(dim);
  }

  onCastToNormalForm(formId: string): void {
    hilog.info(DOMAIN, 'testTag', 'onCastToNormalForm');
  }

  onUpdateForm(formId: string): void {
    let dim: string = '2*2';
    const saved: string | undefined = this.dimMap.get(formId);
    if (saved !== undefined) {
      dim = saved;
    }
    const data: formBindingData.FormBindingData = this.buildFormData(dim);
    formProvider.updateForm(formId, data).catch((err: BusinessError) => {
      hilog.error(DOMAIN, 'testTag', `updateForm failed, code: ${err.code}`);
    });
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, 'testTag', `onFormEvent ${formId} ${message}`);
  }

  onRemoveForm(formId: string): void {
    if (this.dimMap.has(formId)) {
      this.dimMap.delete(formId);
    }
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
      if (typeof d === 'string') {
        return d as string;
      }
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

    const payload: Record<string, string> = {};
    payload['done'] = done.toString();
    payload['goal'] = goal.toString();
    payload['date'] = dateStr;

    if (dim === '4*4') {
      payload['dimension'] = '4*4';
      payload['title'] = '🌿 青番';
      payload['min'] = min.toString();
      payload['streak'] = streak.toString();
      payload['trees'] = totalTrees.toString();
      payload['progressPct'] = goal > 0 ? Math.min(100, Math.floor(done / goal * 100)).toString() : '0';
    } else if (dim === '2*4' || dim === '4*2') {
      payload['dimension'] = '2*4';
      payload['streak'] = streak.toString();
      payload['trees'] = totalTrees.toString();
    } else {
      payload['dimension'] = '2*2';
    }
    return formBindingData.createFormBindingData(payload);
  }
}
