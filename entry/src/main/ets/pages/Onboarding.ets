import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY } from '../model/Types';

interface Slide {
  key: string;
  icon: string;
  color: string;
  tag: string;
  title: string;
  pain: string;
  fix: string;
}

@Entry
@Component
struct Onboarding {
  @State idx: number = 0;
  @State replay: boolean = false;
  private swiper: SwiperController = new SwiperController();
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, Object>;
    if (p && p['replay']) {
      this.replay = p['replay'] as boolean;
    }
  }

  private steps(): Slide[] {
    const t = this.t;
    const slides: Slide[] = [
      { key: 'ai', icon: '✨', color: t.leaf, tag: 'AI 更懂你', title: '会思考的番茄钟', pain: '普通番茄钟只会倒数，不懂你何时效率高、为什么分心。', fix: '青番用 AI 分析专注数据，自动排待办、推荐最佳专注时段、洞察每一次打断。' },
      { key: 'todo', icon: '🍅', color: t.tomato, tag: '待办 + 专注', title: '列好计划，一键开始', pain: '待办清单和计时器是两套工具，列了计划却总懒得开始。', fix: '先列今日计划，长按拖动或让 AI 按难易自动排序，点「开始」直接进入锁屏倒计时。' },
      { key: 'study', icon: '👥', color: t.leafDeep, tag: '自习室 · 共学', title: '坚持，不再孤单', pain: '一个人专注最容易半途而废。', fix: '在自习室和朋友一起自习、互相监督；签到经验、好友排行，让每一份坚持都有回响。' },
      { key: 'growth', icon: '📊', color: t.gold, tag: '看得见的成长', title: '每一天都在进步', pain: '努力过却看不到记录，动力慢慢就散了。', fix: '专注时长分布、高效时段、每日完成时间轴，把你的成长清清楚楚地记下来。' }
    ];
    return slides;
  }

  private isLast(): boolean {
    return this.idx === this.steps().length - 1;
  }

  async finishOnboarding() {
    if (this.replay) {
      router.back();
      return;
    }
    await AppState.saveOnboarded(true);
    router.replaceUrl({ url: 'pages/Home' });
  }

  private goNext(): void {
    if (this.isLast()) {
      this.finishOnboarding();
    } else {
      this.swiper.showNext();
    }
  }

  @Builder
  slideView(s: Slide) {
    Column() {
      Column() {
        Text(s.icon)
          .fontSize(46)
      }
      .width(96)
      .height(96)
      .borderRadius(30)
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 42, color: 'rgba(110,155,87,0.18)', offsetY: 18 })
      .justifyContent(FlexAlign.Center)

      Text(s.tag)
        .fontSize(12)
        .fontColor(s.color)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1.2)
        .padding({ left: 15, right: 15, top: 5, bottom: 5 })
        .borderRadius(99)
        .backgroundColor('rgba(110,155,87,0.10)')
        .margin({ top: 28 })

      Text(s.title)
        .fontFamily(FONT_DISPLAY)
        .fontSize(27)
        .fontColor(this.t.ink)
        .margin({ top: 18 })

      Text(s.pain)
        .fontSize(13)
        .fontColor(this.t.ink3)
        .lineHeight(23)
        .textAlign(TextAlign.Center)
        .width(268)
        .margin({ top: 18 })

      Text(s.fix)
        .fontSize(13)
        .fontColor(this.t.ink)
        .lineHeight(23)
        .textAlign(TextAlign.Center)
        .width(268)
        .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 40, right: 40, bottom: 110 })
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      // 顶部：跳过
      Row() {
        Blank()
        if (!this.isLast()) {
          Text('跳过')
            .fontSize(13)
            .fontColor(this.t.ink3)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => { this.finishOnboarding(); })
        }
      }
      .width('100%')
      .padding({ top: 16, right: 20 })

      // 内容：横向滑动轮播
      Swiper(this.swiper) {
        ForEach(this.steps(), (s: Slide) => {
          this.slideView(s)
        }, (s: Slide) => s.key)
      }
      .layoutWeight(1)
      .indicator(false)
      .loop(false)
      .duration(380)
      .curve(Curve.FastOutSlowIn)
      .onChange((i: number) => { this.idx = i; })

      // 底部：圆点 + 按钮
      Column() {
        Row({ space: 8 }) {
          ForEach(this.steps(), (s: Slide, i: number) => {
            Column()
              .width(i === this.idx ? 22 : 7)
              .height(7)
              .borderRadius(99)
              .backgroundColor(i === this.idx ? this.t.leaf : 'rgba(44,58,40,0.18)')
              .animation({ duration: 300, curve: Curve.EaseInOut })
              .onClick(() => { this.swiper.changeIndex(i); })
          }, (s: Slide) => s.key)
        }

        Row() {
          Text(this.replay ? '完成' : (this.isLast() ? '开始使用' : '下一步'))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .letterSpacing(1.2)
          if (!this.isLast() && !this.replay) {
            Text('›').fontSize(16).fontColor('#FFFFFF').margin({ left: 6 })
          }
        }
        .width('100%')
        .height(50)
        .borderRadius(14)
        .backgroundColor(this.t.leaf)
        .shadow({ radius: 24, color: 'rgba(110,155,87,0.32)', offsetY: 10 })
        .justifyContent(FlexAlign.Center)
        .margin({ top: 22 })
        .onClick(() => { this.goNext(); })
      }
      .width('100%')
      .padding({ left: 34, right: 34, bottom: 38 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [[this.t.brandGrad1, 0], [this.t.brandGrad2, 1]] })
  }
}
