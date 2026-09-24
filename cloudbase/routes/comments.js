// cloudfunctions/routes/comments.js
// 青番自我介绍项目 —— 评论（嵌套 / 父子）后端路由
// 依赖: @cloudbase/node-sdk (v3，需支持 app.rdb())
//
// 说明
// ----
// 数据表 public.comments（CloudBase PostgreSQL）字段：
//   id           bigint  PK, IDENTITY 自增（插入时省略，由数据库分配）
//   project_id   varchar NOT NULL  留言板键（如 'qingfan'，单板可固定同一值）
//   parent_id    bigint  NULL       父留言 id；NULL = 一级留言（自引用 + 级联外键）
//   nickname     varchar NOT NULL   昵称
//   content      varchar NOT NULL   内容
//   role         varchar 默认 'guest'（登录用户可传 'user'）
//   created_at   bigint  NOT NULL   毫秒时间戳
//   updated_at   bigint  NOT NULL   毫秒时间戳
//
// RLS 策略（已在迁移 20260921130100_comments_backend 中建立）：
//   SELECT 对所有人开放；INSERT/UPDATE/DELETE 仅 service_role（云函数默认凭证，绕过 RLS）。
//   因此：前端只调用本云函数，不要在前端用 app.rdb() 直连写 PG。

const cloudbase = require('@cloudbase/node-sdk');

// 云函数内使用当前环境凭证（service_role，自动绕过 RLS，可写）
const app = cloudbase.init({});
const db = app.rdb();

const MAX_NICK = 40;
const MAX_CONTENT = 1000;

function ok(data) { return { code: 0, data }; }
function fail(message) { return { code: -1, message }; }

// 把扁平列表组装成嵌套树：parent_id 串联 children
function toTree(rows) {
  const nodes = new Map();
  rows.forEach(r => nodes.set(Number(r.id), { ...r, children: [] }));
  const roots = [];
  nodes.forEach(node => {
    const pid = node.parent_id == null ? null : Number(node.parent_id);
    if (pid != null && nodes.has(pid)) nodes.get(pid).children.push(node);
    else roots.push(node);
  });
  return roots;
}

async function list(projectId) {
  if (!projectId) throw new Error('projectId 必填');
  const { data, error } = await db.from('comments_self')
    .select('*')
    .eq('project_id', projectId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return toTree(data || []);
}

async function create({ project_id, parent_id, nickname, content, role }) {
  if (!project_id || !nickname || !content) {
    throw new Error('project_id / nickname / content 必填');
  }
  const now = Date.now();
  const row = {
    project_id: String(project_id),
    parent_id: parent_id == null ? null : Number(parent_id),
    nickname: String(nickname).slice(0, MAX_NICK),
    content: String(content).slice(0, MAX_CONTENT),
    role: role || 'guest',
    created_at: now,
    updated_at: now,
    // id 省略，由 IDENTITY 自动生成
  };

  // 若是回复，校验父留言存在且属于同一 project_id（避免跨板挂接）
  if (row.parent_id != null) {
    const { data: p, error: e2 } = await db
      .from('comments_self')
      .select('id', 'project_id')
      .eq('id', row.parent_id)
      .single();
    if (e2) throw e2;
    if (!p) throw new Error('parent_id 不存在');
    if (p.project_id !== row.project_id) throw new Error('父留言不属于同一 project_id');
  }

  const { data, error } = await db.from('comments_self').insert(row).select();
  if (error) throw error;
  return data && data[0];
}

async function remove(id) {
  const nid = Number(id);
  if (!Number.isInteger(nid)) throw new Error('id 非法');
  // 级联删除其子留言（表上 ON DELETE CASCADE）
  const { error } = await db.from('comments_self').delete().eq('id', nid);
  if (error) throw error;
  return { deleted: true };
}

// 云函数入口：event.action ∈ { list, create, delete }
exports.main = async (event, context) => {
  try {
    const { action } = event;
    if (action === 'list') return ok(await list(event.projectId));
    if (action === 'create') return ok(await create(event));
    if (action === 'delete') return ok(await remove(event.id));
    return fail('unknown action: ' + action);
  } catch (e) {
    return fail(e.message || String(e));
  }
};

// ---- 接入中央 router 的示例（按你仓库里 routes/*.js 的实际框架调整）----
// tcb-router 风格：
//   const TcbRouter = require('tcb-router');
//   const router = new TcbRouter();
//   const comments = require('./routes/comments');
//   router.post('/comments/list', async ctx => { ctx.body = await comments.main({ action: 'list', projectId: ctx._req.body.projectId }); });
//   router.post('/comments/create', async ctx => { ctx.body = await comments.main({ action: 'create', ...ctx._req.body }); });
//   router.post('/comments/delete', async ctx => { ctx.body = await comments.main({ action: 'delete', id: ctx._req.body.id }); });
//   exports.main = router.serve();
//
// 或直接在你已有的 routes 分发器里调用 exports.main({ action, ... })。
module.exports = exports;
