import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf } from '../model/Types';

@Entry
@Component
struct Complete {
  @State taskId: string = '';
  @State customTitle: string = '';
  @State expGain: number = 20;
  @State bounce: number = 0;

  aboutToAppear() {
    const p = router.getParams() as Record<string, Object>;
    if (p) {
      this.taskId = (p['taskId'] ?? '') as string;
      this.customTitle = (p['title'] ?? '') as string;
      this.expGain = (p['exp'] ?? 20) as number;
    }
    let i = 0;
    const id = setInterval(() => {
      i += 1;
      this.bounce = i;
      if (i >= 10) clearInterval(id);
    }, 180);
  }

  taskTitle(): string {
    if (this.customTitle.length > 0) {
      return this.customTitle;
    }
    return AppState.instance.tasks.find(t => t.id === this.taskId)?.title ?? '';
  }

  goHome() {
    router.replaceUrl({ url: 'pages/Home' });
  }

  build() {
    Stack() {
      // 背景
      Column()
        .width('100%').height('100%')
        .linearGradient({ angle: 160, colors: [['#5E7A52', 0], ['#39503A', 1]] })

      // 居中卡片
      Column() {
        // confetti + 番茄
        Stack() {
          Row({ space: 18 }) {
            Text('●').fontSize(8).fontColor('#E07A5F')
            Text('■').fontSize(8).fontColor('#6E9B57')
            Text('●').fontSize(8).fontColor('#D9A441')
            Text('■').fontSize(8).fontColor('#E07A5F')
            Text('●').fontSize(8).fontColor('#6E9B57')
          }
          .margin({ top: 6 })
        }
        .height(52)

        Text('🍅')
          .fontSize(46)
          .scale({ x: 1 + (this.bounce % 2) * 0.04, y: 1 + (this.bounce % 2) * 0.04 })
          .animation({ duration: 300, curve: Curve.EaseInOut })

        Text('专注完成！')
          .fontFamily('serif')
          .fontSize(19)
          .fontColor('#2C3A28')
          .margin({ top: 8 })
        Text('「' + this.taskTitle() + '」已完成')
          .fontSize(12.5)
          .fontColor('#84917D')
          .margin({ top: 6 })

        Row({ space: 12 }) {
          this.reward('🔥', '番茄 +1', '#E07A5F')
          this.reward('⭐', '经验 +' + this.expGain, '#D9A441')
          this.reward('🌳', '种下 1 棵树', '#4C7A3E')
        }
        .margin({ top: 14, bottom: 14 })

        Row() {
          Text('太棒了').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
        }
        .width('100%').height(44).borderRadius(13)
        .backgroundColor('#6E9B57')
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.goHome(); })
      }
      .width(290)
      .padding(22)
      .backgroundColor('#FFFFFF')
      .borderRadius(22)
      .shadow({ radius: 30, color: '#00000033', offsetY: 12 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  reward(icon: string, label: string, c: string) {
    Row({ space: 5 }) {
      Text(icon).fontSize(15).fontColor(c)
      Text(label).fontSize(12.5).fontColor('#84917D')
    }
  }
}
