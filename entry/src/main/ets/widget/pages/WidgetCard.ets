import { ThemeDef, themeOf } from '../../model/Types';

let storage: LocalStorage = new LocalStorage();

@Entry(storage)
@Component
struct WidgetCard {
  // 卡片数据通过 FormBindingData 下发到 LocalStorage
  @LocalStorageProp('dimension') dimension: string = '2*2';
  @LocalStorageProp('done') done: string = '0';
  @LocalStorageProp('goal') goal: string = '4';
  @LocalStorageProp('min') min: string = '0';
  @LocalStorageProp('streak') streak: string = '0';
  @LocalStorageProp('trees') trees: string = '0';
  @LocalStorageProp('progressPct') progressPct: string = '0';
  @LocalStorageProp('date') dateText: string = '';

  private get theme(): ThemeDef {
    return themeOf('green');
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme.cardBg)

      if (this.dimension === '4*4') {
        this.largeLayout()
      } else if (this.dimension === '2*4' || this.dimension === '4*2') {
        this.wideLayout()
      } else {
        this.compactLayout()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  compactLayout() {
    Column() {
      Text('🍅')
        .fontSize(28)
      Text(this.done + '/' + this.goal)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.cardText)
        .margin({ top: 2 })
      Text('今日番茄')
        .fontSize(11)
        .fontColor('#999999')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  wideLayout() {
    Row() {
      this.metricCell('🍅', this.done + '/' + this.goal, '番茄', '#1A1A1A')
      this.metricCell('🔥', this.streak, '连签', '#FFB74D')
      this.metricCell('🌳', this.trees, '棵树', this.theme.primary)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  metricCell(icon: string, value: string, label: string, color: string) {
    Column() {
      Text(icon)
        .fontSize(22)
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 2 })
      Text(label)
        .fontSize(9)
        .fontColor('#999999')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  largeLayout() {
    Column() {
      Row() {
        Text('🌿 青番')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.primary)
        Blank()
        Text('🍅 ' + this.done + '/' + this.goal)
          .fontSize(12)
          .fontColor(this.theme.cardText)
      }
      .width('100%')

      Row() {
        Text(this.min + ' 分钟')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.cardText)
        Blank()
        Text('🔥 ' + this.streak + ' 天')
          .fontSize(12)
          .fontColor('#FFB74D')
      }
      .width('100%')
      .margin({ top: 6 })

      Stack() {
        Row()
          .width('100%')
          .height(6)
          .backgroundColor('#F2F2F2')
          .borderRadius(3)
        Row()
          .width(this.progressPct + '%')
          .height(6)
          .backgroundColor(this.theme.primary)
          .borderRadius(3)
      }
      .width('100%')
      .alignContent(Alignment.Start)
      .margin({ top: 8 })

      Row() {
        Text('🌳 ' + this.trees + ' 棵树')
          .fontSize(11)
          .fontColor(this.theme.cardText)
        Blank()
        Text('开始专注 ›')
          .fontSize(11)
          .fontColor(this.theme.primary)
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .justifyContent(FlexAlign.Center)
  }
}
