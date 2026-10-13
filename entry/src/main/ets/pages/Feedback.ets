import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY } from '../model/Types';
import { Store } from '../model/Store';

interface FeedbackItem {
  text: string;
  contact: string;
  at: number;
}

@Entry
@Component
struct Feedback {
  @State content: string = '';
  @State contact: string = '';
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  submit() {
    const v = this.content.trim();
    if (!v) {
      promptAction.showToast({ message: '请先填写反馈内容', duration: 1500 });
      return;
    }
    Store.getArr<FeedbackItem>('qf_feedback_' + AppState.userKey()).then((list: FeedbackItem[]) => {
      list.push({ text: v, contact: this.contact, at: Date.now() });
      Store.setArr('qf_feedback_' + AppState.userKey(), list);
      this.content = '';
      this.contact = '';
      promptAction.showToast({ message: '已提交，感谢反馈！', duration: 1500 });
    });
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(26).fontColor(this.t.ink).width(26)
          .onClick(() => { router.back(); })
        Text('意见反馈').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text(' ').fontSize(26).width(26)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 10 })

      Column() {
        TextArea({ placeholder: '说说你的建议或遇到的问题…', text: this.content })
          .height(140)
          .backgroundColor(this.t.surface2)
          .borderRadius(12)
          .fontColor(this.t.ink)
          .placeholderColor(this.t.ink3)
          .onChange((v: string) => { this.content = v; })

        TextInput({ placeholder: '联系方式（选填）', text: this.contact })
          .height(46)
          .backgroundColor(this.t.surface2)
          .borderRadius(12)
          .margin({ top: 10 })
          .fontColor(this.t.ink)
          .placeholderColor(this.t.ink3)
          .onChange((v: string) => { this.contact = v; })

        Row() {
          Text('提交反馈').fontSize(15).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .height(48)
        .borderRadius(14)
        .backgroundColor(this.t.leaf)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 14 })
        .onClick(() => { this.submit(); })

        Text('感谢你的反馈，我们会认真对待每一条建议。')
          .fontSize(11).fontColor(this.t.ink3).margin({ top: 12 }).width('100%')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(this.t.surface)
      .borderRadius(18)
      .border({ width: 1, color: this.t.line })
      .margin({ left: 22, right: 22 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }
}
