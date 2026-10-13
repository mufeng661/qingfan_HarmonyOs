/**
 * 徽章图标 —— 与小程序端（design/miniprogram.html 的 const I）保持一致的线性描边图标。
 *
 * 小程序用 SVG path 绘制（stroke=currentColor / strokeWidth 1.5~1.6 / round cap），
 * ArkTS 没有 SVG，这里用 Canvas 按同样的 24×24 viewBox 路径坐标重绘：
 * - 坐标按 size/24 缩放，与 SVG viewBox 行为一致；
 * - 描边宽度随 size 等比缩放（小程序 SVG 的 stroke 也随 viewBox 缩放）；
 * - 圆角端点 / 圆角拐点与小程序一致。
 */

export type BadgeIconKey = 'flame' | 'leaf' | 'star' | 'trophy' | 'lock' | 'tomato';

export interface BadgeGlyph {
  key: BadgeIconKey;
  paths: string[];
  // 24 基准下的描边宽度：flame/leaf/trophy/lock = 1.6，star = 1.5（与小程序一致）
  strokeWidth: number;
}

export const BADGE_GLYPHS: BadgeGlyph[] = [
  {
    key: 'flame',
    strokeWidth: 1.6,
    paths: [
      'M12 21c-3.5 0-6-2.5-6-6 0-3 2-4.5 3-6.5C10.5 11 11 12 12 12c1 0 1.5-1.5 1.5-3 2 1.5 4.5 4 4.5 7 0 3-2.5 5-6 5Z',
      'M12 21c-2 0-3.5-1.5-3.5-3.5 0-1.8 1.3-2.6 2-3.7'
    ]
  },
  {
    key: 'leaf',
    strokeWidth: 1.6,
    paths: [
      'M4 20C4 11 10 5 20 4c0 10-6 16-16 16Z',
      'M4 20C8 14 13 10 18 8'
    ]
  },
  {
    key: 'star',
    strokeWidth: 1.5,
    paths: [
      'M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1 5.9-5.2-2.8-5.2 2.8 1-5.9-4.3-4.1 5.9-.8L12 3.5Z'
    ]
  },
  {
    key: 'trophy',
    strokeWidth: 1.6,
    paths: [
      'M7 4h10v5a5 5 0 0 1-10 0V4Z',
      'M7 6H4.5A2.5 2.5 0 0 0 7 10.5',
      'M17 6h2.5A2.5 2.5 0 0 1 17 10.5',
      'M12 14v3M8 20h8M10 17h4'
    ]
  },
  {
    key: 'lock',
    strokeWidth: 1.6,
    paths: [
      'M5 12.5A2.5 2.5 0 0 1 7.5 10h9a2.5 2.5 0 0 1 2.5 2.5v5A2.5 2.5 0 0 1 16.5 20h-9A2.5 2.5 0 0 1 5 17.5Z',
      'M8 10V7a4 4 0 0 1 8 0v3'
    ]
  },
  {
    key: 'tomato',
    strokeWidth: 1.6,
    paths: [
      // 果身：四段三次贝塞尔闭合（注意：解析器不支持 s/S 平滑命令，须全用 C）
      'M12 8.5C7 8.5 4 11 4 14.5 4 18 7.5 21 12 21 16.5 21 20 18 20 14.5 20 11 17 8.5 12 8.5Z',
      // 左侧高光弧
      'M8.2 12.6c-1 1-1.4 2.3-1.3 3.6',
      // 果梗
      'M12 8.5V5.5',
      // 左右萼叶
      'M12 8.5C10.6 6.6 8.6 6 6.5 6.3c1.2 1.9 3 2.8 5.5 2.2',
      'M12 8.5c1.4-1.9 3.4-2.5 5.5-2.2-1.2 1.9-3 2.8-5.5 2.2'
    ]
  }
];

export function glyphOf(key: string): BadgeGlyph {
  for (let i = 0; i < BADGE_GLYPHS.length; i++) {
    if (BADGE_GLYPHS[i].key === key) {
      return BADGE_GLYPHS[i];
    }
  }
  return BADGE_GLYPHS[0];
}

// ====== 极简 SVG path 解析（支持图标库用到的命令：M L H V C A Z，含小写相对）======

// 画笔状态：当前位置 + 当前子路径起点（供 Z 闭合回跳）
class Pen {
  x: number = 0;
  y: number = 0;
  startX: number = 0;
  startY: number = 0;
}

// 把一段不含字母的数字串拆成单个数字：
// "0-6-2.5" → ["0","-6","-2.5"]；"1.5.5" → ["1.5",".5"]；"12 21" → ["12","21"]
function splitNumbers(seg: string): string[] {
  const out: string[] = [];
  let i = 0;
  const n: number = seg.length;
  while (i < n) {
    const c: string = seg.charAt(i);
    if (c === ' ' || c === ',' || c === '\n' || c === '\t' || c === '\r') {
      i += 1;
      continue;
    }
    let j: number = i;
    if (c === '-' || c === '+') {
      j += 1;
    }
    let sawDot = false;
    while (j < n) {
      const cj: string = seg.charAt(j);
      if (cj >= '0' && cj <= '9') {
        j += 1;
      } else if (cj === '.' && !sawDot) {
        sawDot = true;
        j += 1;
      } else {
        break;
      }
    }
    if (j === i) {
      // 非法字符（不应出现），跳过
      i += 1;
      continue;
    }
    out.push(seg.substring(i, j));
    i = j;
  }
  return out;
}

// 按 24×24 viewBox 的坐标绘制一条 path，scale 为像素/单位
function pathToCanvas(ctx: CanvasRenderingContext2D, d: string, scale: number, pen: Pen): void {
  // 令牌化：命令字母 / 单个数字
  const tokens: string[] = [];
  let i = 0;
  const n: number = d.length;
  while (i < n) {
    const ch: string = d.charAt(i);
    if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
      tokens.push(ch);
      i += 1;
      continue;
    }
    let j: number = i;
    while (j < n) {
      const c: string = d.charAt(j);
      if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
        break;
      }
      j += 1;
    }
    const nums: string[] = splitNumbers(d.substring(i, j));
    for (let t = 0; t < nums.length; t++) {
      tokens.push(nums[t]);
    }
    i = j;
  }

  let cmd: string = '';
  let k: number = 0;

  const isLetter = (s: string): boolean => {
    const c: string = s.charAt(0);
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
  };
  const nx = (): number => {
    if (k >= tokens.length || isLetter(tokens[k])) {
      return 0;
    }
    const v = Number.parseFloat(tokens[k]);
    k += 1;
    return Number.isNaN(v) ? 0 : v;
  };

  while (k < tokens.length) {
    const tk: string = tokens[k];
    if (isLetter(tk)) {
      cmd = tk;
      k += 1;
      if (cmd === 'Z' || cmd === 'z') {
        ctx.closePath();
        pen.x = pen.startX;
        pen.y = pen.startY;
        continue;
      }
    }
    if (cmd === '') {
      k += 1;
      continue;
    }

    if (cmd === 'M' || cmd === 'm') {
      let ax: number = nx();
      let ay: number = nx();
      if (cmd === 'm') {
        ax += pen.x;
        ay += pen.y;
      }
      pen.x = ax;
      pen.y = ay;
      pen.startX = ax;
      pen.startY = ay;
      ctx.moveTo(ax * scale, ay * scale);
      // SVG 规范：M 之后的隐式连续坐标按 L 处理
      cmd = (cmd === 'M') ? 'L' : 'l';
    } else if (cmd === 'L' || cmd === 'l') {
      let ax: number = nx();
      let ay: number = nx();
      if (cmd === 'l') {
        ax += pen.x;
        ay += pen.y;
      }
      pen.x = ax;
      pen.y = ay;
      ctx.lineTo(ax * scale, ay * scale);
    } else if (cmd === 'H' || cmd === 'h') {
      let ax: number = nx();
      if (cmd === 'h') {
        ax += pen.x;
      }
      pen.x = ax;
      ctx.lineTo(ax * scale, pen.y * scale);
    } else if (cmd === 'V' || cmd === 'v') {
      let ay: number = nx();
      if (cmd === 'v') {
        ay += pen.y;
      }
      pen.y = ay;
      ctx.lineTo(pen.x * scale, ay * scale);
    } else if (cmd === 'C' || cmd === 'c') {
      let x1: number = nx();
      let y1: number = nx();
      let x2: number = nx();
      let y2: number = nx();
      let x3: number = nx();
      let y3: number = nx();
      if (cmd === 'c') {
        x1 += pen.x;
        y1 += pen.y;
        x2 += pen.x;
        y2 += pen.y;
        x3 += pen.x;
        y3 += pen.y;
      }
      ctx.bezierCurveTo(x1 * scale, y1 * scale, x2 * scale, y2 * scale, x3 * scale, y3 * scale);
      pen.x = x3;
      pen.y = y3;
    } else if (cmd === 'A' || cmd === 'a') {
      const rx: number = Math.abs(nx());
      const ry: number = Math.abs(nx());
      const rot: number = nx();
      const large: boolean = nx() !== 0;
      const sweep: boolean = nx() !== 0;
      let ex: number = nx();
      let ey: number = nx();
      if (cmd === 'a') {
        ex += pen.x;
        ey += pen.y;
      }
      if (rx === 0 || ry === 0) {
        ctx.lineTo(ex * scale, ey * scale);
      } else {
        arcToBezier(ctx, pen.x, pen.y, rx, ry, rot, large, sweep, ex, ey, scale);
      }
      pen.x = ex;
      pen.y = ey;
    } else {
      // 未知命令：跳过一个令牌，避免死循环
      k += 1;
    }
  }
}

// SVG 弧线（端点参数）→ 三次贝塞尔近似（按 SVG 规范 F.6.5 转中心参数后分段）
function arcToBezier(
  ctx: CanvasRenderingContext2D, px: number, py: number,
  rxIn: number, ryIn: number, phiDeg: number, large: boolean, sweep: boolean,
  ex: number, ey: number, scale: number
): void {
  const rx: number = Math.abs(rxIn);
  const ry: number = Math.abs(ryIn);
  const phi: number = phiDeg * Math.PI / 180;
  const cp: number = Math.cos(phi);
  const sp: number = Math.sin(phi);

  const dx2: number = (px - ex) / 2;
  const dy2: number = (py - ey) / 2;
  const x1p: number = cp * dx2 + sp * dy2;
  const y1p: number = -sp * dx2 + cp * dy2;

  let rx2: number = rx;
  let ry2: number = ry;
  const lam: number = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lam > 1) {
    const sc: number = Math.sqrt(lam);
    rx2 = sc * rx;
    ry2 = sc * ry;
  }

  const sign: number = (large === sweep) ? -1 : 1;
  let num: number = rx2 * rx2 * ry2 * ry2 - rx2 * rx2 * y1p * y1p - ry2 * ry2 * x1p * x1p;
  if (num < 0) {
    num = 0;
  }
  const den: number = rx2 * rx2 * y1p * y1p + ry2 * ry2 * x1p * x1p;
  const co: number = sign * Math.sqrt(den === 0 ? 0 : num / den);
  const cxp: number = co * (rx2 * y1p) / ry2;
  const cyp: number = co * -(ry2 * x1p) / rx2;
  const cx: number = cp * cxp - sp * cyp + (px + ex) / 2;
  const cy: number = sp * cxp + cp * cyp + (py + ey) / 2;

  const angle = (ux: number, uy: number, vx: number, vy: number): number => {
    const dd: number = Math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
    let c: number = dd === 0 ? 1 : (ux * vx + uy * vy) / dd;
    if (c > 1) {
      c = 1;
    }
    if (c < -1) {
      c = -1;
    }
    const sg: number = (ux * vy - uy * vx < 0) ? -1 : 1;
    return sg * Math.acos(c);
  };

  const ux: number = (x1p - cxp) / rx2;
  const uy: number = (y1p - cyp) / ry2;
  const vx: number = (-x1p - cxp) / rx2;
  const vy: number = (-y1p - cyp) / ry2;

  const th1: number = angle(1, 0, ux, uy);
  let dth: number = angle(ux, uy, vx, vy);
  if (!sweep && dth > 0) {
    dth -= 2 * Math.PI;
  } else if (sweep && dth < 0) {
    dth += 2 * Math.PI;
  }

  const nseg: number = Math.ceil(Math.abs(dth / (Math.PI / 2)));
  const dt: number = dth / nseg;
  const t: number = (4 / 3) * Math.tan(dt / 4);
  let th: number = th1;
  let sx: number = px;
  let sy: number = py;
  for (let i = 0; i < nseg; i++) {
    const th2: number = th + dt;
    const cos1: number = Math.cos(th);
    const sin1: number = Math.sin(th);
    const cos2: number = Math.cos(th2);
    const sin2: number = Math.sin(th2);
    const e2x: number = cx + rx2 * cp * cos2 - ry2 * sp * sin2;
    const e2y: number = cy + rx2 * sp * cos2 + ry2 * cp * sin2;
    const d1x: number = -rx2 * cp * sin1 - ry2 * sp * cos1;
    const d1y: number = -rx2 * sp * sin1 + ry2 * cp * cos1;
    const d2x: number = -rx2 * cp * sin2 - ry2 * sp * cos2;
    const d2y: number = -rx2 * sp * sin2 + ry2 * cp * cos2;
    ctx.bezierCurveTo(
      (sx + t * d1x) * scale, (sy + t * d1y) * scale,
      (e2x - t * d2x) * scale, (e2y - t * d2y) * scale,
      e2x * scale, e2y * scale
    );
    sx = e2x;
    sy = e2y;
    th = th2;
  }
}

/**
 * 在指定画布上以 (cx, cy) 为中心绘制线性描边徽章图标。
 * 供 BadgeIcon 组件与 CoinBadge 币心图案共用。
 */
export function drawGlyphCentered(
  ctx: CanvasRenderingContext2D, key: string, cx: number, cy: number, size: number, color: string
): void {
  const g: BadgeGlyph = glyphOf(key);
  const scale: number = size / 24;
  ctx.save();
  ctx.translate(cx - size / 2, cy - size / 2);
  ctx.lineWidth = g.strokeWidth * scale;
  ctx.strokeStyle = color;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  const pen: Pen = new Pen();
  for (let i = 0; i < g.paths.length; i++) {
    ctx.beginPath();
    pathToCanvas(ctx, g.paths[i], scale, pen);
    ctx.stroke();
  }
  ctx.restore();
}

/**
 * 线性描边徽章图标（对齐小程序 I.flame / I.leaf / I.star / I.trophy / I.lock）。
 * 颜色由外部传入（等价 SVG 的 currentColor 语义）。
 */
@Component
export struct BadgeIcon {
  @Prop iconKey: string = 'star';
  // 注意：不能用 size 作属性名 —— 与 CustomComponent 内置 size() 通用方法冲突
  @Prop iconSize: number = 24;
  @Prop color: string = '#000000';

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  draw(): void {
    const s: number = this.iconSize;
    this.ctx.clearRect(0, 0, s, s);
    drawGlyphCentered(this.ctx, this.iconKey, s / 2, s / 2, s, this.color);
  }

  build() {
    Canvas(this.ctx)
      .width(this.iconSize)
      .height(this.iconSize)
      .onReady(() => { this.draw(); })
  }
}
