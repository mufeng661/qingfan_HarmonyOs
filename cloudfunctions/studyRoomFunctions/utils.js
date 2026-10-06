function now() {
  return Date.now();
}

// 北京时间日期（YYYY-MM-DD）
function dateKeyOf(ts) {
  const d = new Date(Number(ts) + 8 * 3600 * 1000);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return y + "-" + m + "-" + day;
}

function todayKey() {
  return dateKeyOf(Date.now());
}

function dateKeyOffset(days) {
  return dateKeyOf(Date.now() + days * 86400000);
}

function ok(data) {
  return { success: true, data: data === undefined ? null : data };
}

function fail(message, code, extra) {
  const error = { code: code || "ERROR", message: message || "请求失败" };
  if (extra && typeof extra === "object") {
    Object.keys(extra).forEach((k) => {
      error[k] = extra[k];
    });
  }
  return { success: false, error: error };
}

function toPositiveInt(value, fallback) {
  const n = parseInt(value, 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

function isUuid(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(value || ""));
}

function isRoomId(value) {
  return /^\d{6}$/.test(String(value || ""));
}

function isValidRoomId(value) {
  return isRoomId(value) || isUuid(value);
}

function adminIds() {
  return String(process.env.ADMIN_USER_IDS || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function roleVisitor() {
  return process.env.ROLE_VISITOR || "游客";
}

function roleUser() {
  return process.env.ROLE_USER || "用户";
}

function roleAdmin() {
  return process.env.ROLE_ADMIN || "管理员";
}

function resolveRole(userId) {
  if (!userId) return roleVisitor();
  return adminIds().indexOf(userId) > -1 ? roleAdmin() : roleUser();
}

module.exports = {
  now,
  dateKeyOf,
  todayKey,
  dateKeyOffset,
  ok,
  fail,
  toPositiveInt,
  isUuid,
  isRoomId,
  isValidRoomId,
  adminIds,
  resolveRole,
  roleVisitor,
  roleUser,
  roleAdmin,
};
