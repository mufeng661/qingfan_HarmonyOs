import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY } from '../model/Types';

interface AiCard {
  emoji: string;
  title: string;
  desc: string;
  cta: string;
  action: () => void;
}

@Entry
@Component
struct AIAssistant {
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  cards(): AiCard[] {
    return [
      {
        emoji: '🧠',
        title: 'AI 自动排序待办',
        desc: '一键让 AI 按难易度重排你的今日待办，先难后易，把最费脑的放在精力最旺时完成。',
        cta: '立即排序',
        action: () => { router.pushUrl({ url: 'pages/Home' }); }
      },
      {
        emoji: '⏰',
        title: '高效时段建议',
        desc: '基于你的历史专注记录，AI 推荐今日最佳专注窗口。',
        cta: '查看建议',
        action: () => { router.pushUrl({ url: 'pages/AIChat' }); }
      },
      {
        emoji: '📈',
        title: '本周洞察报告',
        desc: '深度分析专注时长、打断原因与连续性，生成个性化改进建议。',
        cta: '查看报告',
        action: () => { router.pushUrl({ url: 'pages/Stats' }); }
      },
      {
        emoji: '💬',
        title: '问问 AI',
        desc: '与青番 AI 助手对话，聊聊你的专注困扰或定制今日目标。',
        cta: '开始对话',
        action: () => { router.pushUrl({ url: 'pages/AIChat' }); }
      }
    ];
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(28).fontColor(this.t.ink)
          .padding({ left: 8, right: 8 })
          .onClick(() => { router.back(); })
        Text('AI 智能助手').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.t.ink)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text(' ').fontSize(18).padding({ left: 8, right: 8 })
      }
      .width('100%')
      .padding({ top: 44, bottom: 16, left: 12, right: 12 })

      // 顶部欢迎
      Row() {
        Column() {
          Text('AI').fontFamily(FONT_DISPLAY).fontSize(15).fontColor('#FFFFFF')
        }
        .width(44).height(44).borderRadius(14)
        .backgroundColor(this.t.leaf)
        .justifyContent(FlexAlign.Center)

        Column() {
          Text('Hi，我是青番 AI').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.t.ink)
          Text('更懂你的专注节奏').fontSize(12).fontColor(this.t.ink2).margin({ top: 2 })
        }
        .margin({ left: 12 })
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.t.leafSoft)
      .borderRadius(16)
      .margin({ left: 16, right: 16 })

      Scroll() {
        Column() {
          Text('AI 能力').fontSize(13).fontColor(this.t.ink2)
            .margin({ top: 16, bottom: 8 })
            .width('100%')

          ForEach(this.cards(), (c: AiCard) => {
            this.aiCard(c)
          })

          Column().height(40)
        }
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }

  @Builder
  aiCard(c: AiCard) {
    Column() {
      Row() {
        Text(c.emoji).fontSize(28)
        Text(c.title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.t.ink)
          .margin({ left: 10 }).layoutWeight(1)
      }
      .width('100%')

      Text(c.desc).fontSize(13).fontColor(this.t.ink2).margin({ top: 8 }).lineHeight(20).width('100%')

      Row() {
        Blank()
        Text(c.cta + ' ›')
          .fontSize(13).fontColor(this.t.leafDeep)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(this.t.leafSoft)
          .borderRadius(14)
          .onClick(() => { c.action(); })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.t.surface)
    .borderRadius(16)
    .border({ width: 1, color: this.t.line })
    .margin({ top: 8 })
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
  }
}
