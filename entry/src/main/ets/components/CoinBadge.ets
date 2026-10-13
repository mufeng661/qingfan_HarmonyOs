/**
 * 3D 奖章：结构参考视频中的「成就徽章墙」——
 * 风车纹圆环 + 白色币心 + 中心线性徽章图标，自动左右摆动旋转（±30°），也可拖动检视。
 * 配色按徽章稀有度阶段固定：0 未解锁(灰) / 1 青铜 / 2 白银 / 3 黄金 / 4 钻石。
 * 「我的」页徽章弹窗与「我的徽章」独立页详情弹窗共用。
 */

import { drawGlyphCentered } from './BadgeIcon';

interface TierPalette {
  face: string;   // 风车主色
  face2: string;  // 风车交替亮色（形成纹路）
  side: string;   // 侧面厚度暗色
  side2: string;  // 侧面交替色
  glyph: string;  // 币心图标/装饰环颜色
}

// 每个稀有度阶段的固定配色（face/face2 交替构成风车纹）
const TIERS: TierPalette[] = [
  { face: '#D5D9DE', face2: '#C2C7CE', side: '#9BA1A9', side2: '#878D96', glyph: '#7A8088' }, // 0 未解锁·灰
  { face: '#CE9367', face2: '#B87B4E', side: '#8F5A31', side2: '#7C4C27', glyph: '#6E4520' }, // 1 青铜
  { face: '#DDE2E9', face2: '#C3CAD3', side: '#98A1AC', side2: '#848D99', glyph: '#6B7480' }, // 2 白银
  { face: '#F3CB5C', face2: '#E9B83A', side: '#BE8F1E', side2: '#A67B15', glyph: '#8A6410' }, // 3 黄金
  { face: '#8ED9EC', face2: '#6CC6E0', side: '#3F97B2', side2: '#32839C', glyph: '#2A7189' }  // 4 钻石
];

@Component
export struct CoinBadge {
  // 币心线性图标（始终显示徽章自身图案，颜色随稀有度阶段）
  @Prop @Watch('redraw') iconKey: string = 'star';
  @Prop @Watch('redraw') tier: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private startAngle: number = 0;
  @State angle: number = 0;
  private timerId: number = -1;
  private tick: number = 0;
  private dragging: boolean = false;
  private ready: boolean = false;

  palette(): TierPalette {
    let t: number = Math.round(this.tier);
    if (t < 0) {
      t = 0;
    }
    if (t > TIERS.length - 1) {
      t = TIERS.length - 1;
    }
    return TIERS[t];
  }

  aboutToAppear() {
    // 自动摆动：angle = 30°·sin(t)，周期约 3.5s
    this.timerId = setInterval(() => {
      if (!this.ready || this.dragging) {
        return;
      }
      this.tick += 0.06;
      this.angle = 30 * Math.sin(this.tick);
      this.draw();
    }, 33);
  }

  aboutToDisappear() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  redraw() {
    this.draw();
  }

  // 椭圆路径：直接用 ellipse 定义（ArkUI Canvas 在绘制时才应用矩阵）
  coinPath(cx: number, cy: number, rx: number, ry: number) {
    this.ctx.beginPath();
    this.ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
    this.ctx.closePath();
  }

  // 3D 奖章：侧面厚度带 + 正面风车环（在压缩坐标系中绘制，随角度横向收窄）
  draw() {
    const ctx = this.ctx;
    const size = 230;
    const cx = size / 2;
    const cy = size / 2;
    const R = size / 2 - 12;
    const rad = this.angle * Math.PI / 180;
    const c = Math.cos(rad);
    const faceScale = Math.max(0.08, Math.abs(c));
    const thickness = R * 0.26;
    // 厚度随 |sin| 变化：正对时为 0，±30° 时约 0.5×thickness
    const off = thickness * Math.abs(Math.sin(rad));
    // 旋转方向：正角厚度带露在右侧，负角镜像到左侧（双向摆动的观感）
    const dir: number = this.angle >= 0 ? 1 : -1;
    const nearX = cx - dir * off / 2;
    const p = this.palette();

    ctx.clearRect(0, 0, size, size);

    // 侧面厚度带（从后往前叠画，暗色交替）
    const bands = 12;
    for (let i = bands; i >= 1; i--) {
      const k = i / bands;
      const x = nearX + dir * off * k;
      this.coinPath(x, cy, R * faceScale, R);
      ctx.fillStyle = (i % 2 === 0) ? p.side : p.side2;
      ctx.fill();
    }

    // 正面：translate + scale 后按圆形坐标绘制，倾斜时自动压成椭圆
    ctx.save();
    ctx.translate(nearX, cy);
    ctx.scale(faceScale, 1);

    // 风车环：每段外弧与内弧错开 twist 角形成漩涡，主色/亮色交替构成纹路
    const M = 16;
    const seg = Math.PI * 2 / M;
    const twist = seg * 0.85;
    const rIn = R * 0.60;
    for (let i = 0; i < M; i++) {
      const a0 = i * seg;
      ctx.beginPath();
      ctx.arc(0, 0, R, a0, a0 + seg);
      ctx.lineTo(rIn * Math.cos(a0 + seg + twist), rIn * Math.sin(a0 + seg + twist));
      ctx.arc(0, 0, rIn, a0 + seg + twist, a0 + twist, true);
      ctx.closePath();
      ctx.fillStyle = (i % 2 === 0) ? p.face : p.face2;
      ctx.fill();
    }

    // 白色币心（轻微径向渐变）
    const rg = ctx.createRadialGradient(0, -rIn * 0.3, rIn * 0.1, 0, 0, rIn);
    rg.addColorStop(0, '#FFFFFF');
    rg.addColorStop(1, '#F1ECDD');
    ctx.beginPath();
    ctx.arc(0, 0, rIn, 0, Math.PI * 2);
    ctx.fillStyle = rg;
    ctx.fill();

    // 币心装饰：外圈细环 + 内圈虚线感细环（颜色随稀有度阶段）
    ctx.beginPath();
    ctx.arc(0, 0, rIn - 5, 0, Math.PI * 2);
    ctx.lineWidth = 2.5;
    ctx.strokeStyle = p.face2;
    ctx.stroke();
    ctx.globalAlpha = 0.4;
    ctx.beginPath();
    ctx.arc(0, 0, rIn - 10, 0, Math.PI * 2);
    ctx.lineWidth = 1.2;
    ctx.strokeStyle = p.glyph;
    ctx.stroke();
    ctx.globalAlpha = 1;

    // 图标底衬：阶段色淡色圆盘，衬托中心图案
    ctx.globalAlpha = 0.12;
    ctx.beginPath();
    ctx.arc(0, 0, rIn - 14, 0, Math.PI * 2);
    ctx.fillStyle = p.face2;
    ctx.fill();
    ctx.globalAlpha = 1;

    // 左上高光
    ctx.beginPath();
    ctx.ellipse(-R * 0.38, -R * 0.42, R * 0.30, R * 0.12, -0.55, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    ctx.fill();

    // 币心线性徽章图标（始终显示徽章自身图案，颜色随稀有度阶段；柔和投影增加立体感）
    ctx.save();
    ctx.shadowColor = 'rgba(60,50,20,0.25)';
    ctx.shadowBlur = 8;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = 2.5;
    drawGlyphCentered(ctx, this.iconKey, 0, rIn * 0.06, rIn, p.glyph);
    ctx.restore();
    ctx.restore();
  }

  build() {
    Canvas(this.ctx)
      .width(230).height(230)
      .onReady(() => {
        this.ready = true;
        this.angle = 0;
        this.draw();
      })
      .gesture(
        PanGesture()
          .onActionStart((e: GestureEvent) => {
            this.dragging = true;
            this.startAngle = this.angle;
          })
          .onActionUpdate((e: GestureEvent) => {
            this.angle = Math.max(-30, Math.min(30, this.startAngle + e.offsetX * 0.5));
            this.draw();
          })
          .onActionEnd((e: GestureEvent) => {
            this.dragging = false;
          })
      )
  }
}
