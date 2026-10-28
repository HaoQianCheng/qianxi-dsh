#!/usr/bin/env bash
# 富江破甲安装脚本
set -euo pipefail

PLUGIN_NAME="fujiang-armor"
PLUGIN_LABEL="富江破甲"
LEGACY_PLUGINS=()
DSH_ROOT="${DSH_HOME:-$HOME/.dsh}"
PLUGINS_DIR="$DSH_ROOT/plugins"
DEST_DIR="$PLUGINS_DIR/$PLUGIN_NAME"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -n "${DSH_PROFILE:-}" && ( "$DSH_PROFILE" == *'/'* || "$DSH_PROFILE" == *'\'* || "$DSH_PROFILE" == '.' || "$DSH_PROFILE" == '..' ) ]]; then
  echo 'DSH_PROFILE 必须是单个配置目录名。' >&2; exit 1
fi

step() { printf "\n==> %s\n" "$1"; }
ok()   { printf "    [OK] %s\n" "$1"; }
warn() { printf "    [!] %s\n" "$1"; }
err()  { printf "    [X] %s\n" "$1" >&2; }

# ---------- 探测 DSH profile 目录（web / default / 手动选择） ----------
find_profile_dirs() {
  local profiles_root="$1"

  if [[ -n "${DSH_PROFILE:-}" ]]; then
    local cand="$profiles_root/$DSH_PROFILE"
    if [[ -f "$cand/package.json" ]]; then echo "$cand"; return 0; fi
    err "DSH_PROFILE 指定的配置不存在：$cand。已停止，不会改动其他配置。"
    return 1
  fi

  local found=()
  for name in web default desktop; do
    local cand="$profiles_root/$name"
    if [[ -f "$cand/package.json" ]]; then found+=("$cand"); fi
  done
  if [[ ${#found[@]} -gt 0 ]]; then printf '%s\n' "${found[@]}"; return 0; fi

  local dirs=()
  for d in "$profiles_root"/*/; do
    [[ -d "$d" && -f "$d/package.json" ]] && dirs+=("$d")
  done
  if [[ ${#dirs[@]} -eq 1 ]]; then echo "${dirs[0]}"; return 0; fi
  if [[ ${#dirs[@]} -gt 1 ]]; then
    echo "检测到多个 DSH profile，请选择要安装的目标：" >&2
    for i in "${!dirs[@]}"; do printf "  [%d] %s\n" "$((i+1))" "${dirs[$i]}" >&2; done
    read -rp "请输入序号: " sel
    local idx=$((sel-1))
    if (( idx >= 0 && idx < ${#dirs[@]} )); then echo "${dirs[$idx]}"; return 0; fi
    err "选择无效，退出。"
    exit 1
  fi
  return 1
}

# ---------- [1] 检查环境 ----------
step "检查环境"

[[ -d "$DSH_ROOT" ]] || { err "未找到 DSH 目录：$DSH_ROOT"; exit 1; }
PROFILE_OUTPUT="$(find_profile_dirs "$DSH_ROOT/profiles")" || {
  err "未找到 DSH profile 目录（$DSH_ROOT/profiles 下没有含 package.json 的目录）。"
  echo "可通过环境变量指定：DSH_PROFILE=web（或 default）后重新运行。"
  exit 1
}
mapfile -t PROFILE_DIRS <<< "$PROFILE_OUTPUT"
for p in "${PROFILE_DIRS[@]}"; do ok "DSH profile 目录：$p"; done

command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 || { err '需要 Node.js 22+ 和 npm。'; exit 1; }
node -e 'if (Number(process.versions.node.split(".")[0]) < 22) process.exit(1)' || { err '需要 Node.js 22+。'; exit 1; }
run_pnpm() {
  if command -v pnpm >/dev/null 2>&1; then pnpm "$@";
  else npm exec --yes --package=pnpm@10 -- pnpm "$@"; fi
}
[[ "$SRC_DIR" != "$DEST_DIR" ]] || { err '请从下载包或 npx 运行安装器。'; exit 1; }
[[ ! -L "$DEST_DIR" ]] || { err '插件目标目录是链接，请先检查。'; exit 1; }

# ---------- [1.5] 清理旧版残留 ----------
step "检查旧版本"

node "$SRC_DIR/scripts/lib/migrate.js" "$DSH_ROOT" "${PROFILE_DIRS[@]}" >/dev/null
ok "旧版注册与依赖已迁移，配置备份已保留。"

for old in "${LEGACY_PLUGINS[@]}"; do
  if [[ -d "$PLUGINS_DIR/$old" ]]; then
    rm -rf "$PLUGINS_DIR/$old"
    ok "已清理旧版插件目录：$PLUGINS_DIR/$old"
  fi
done

# ---------- [2] 复制插件（自动覆盖旧版） ----------
step "复制插件文件"

mkdir -p "$PLUGINS_DIR"
if [[ -d "$DEST_DIR" ]]; then
  warn "检测到已存在的 $PLUGIN_NAME 目录，自动覆盖更新"
  rm -rf "$DEST_DIR"
fi
mkdir -p "$DEST_DIR"
for entry in package.json index.js client.js cordis.patch.yml LICENSE THIRD-PARTY-NOTICES.md prompts scripts bin; do
  cp -R "$SRC_DIR/$entry" "$DEST_DIR/"
done
ok "插件已复制到：$DEST_DIR"

# ---------- [3] 备份 package.json ----------
step "备份 package.json"

for p in "${PROFILE_DIRS[@]}"; do
  BACKUP_ID="$(node -e 'console.log(Date.now() + "-" + process.pid)')"
  BAK_PATH="$p/package.json.bak-$BACKUP_ID"
  cp "$p/package.json" "$BAK_PATH"
  if [[ -f "$p/cordis.patch.yml" ]]; then cp "$p/cordis.patch.yml" "$p/cordis.patch.yml.bak-$BACKUP_ID"; fi
  ok "备份完成：$BAK_PATH"
done

# ---------- [4] 写入依赖与 bundles（幂等 + 迁移旧版） ----------
step "写入 profile 配置"

for p in "${PROFILE_DIRS[@]}"; do
  PKG_PATH="$p/package.json"
  PATCH_PATH="$p/cordis.patch.yml"
  node - "$PKG_PATH" "$PATCH_PATH" "$PLUGIN_NAME" "${LEGACY_PLUGINS[@]}" <<'NODE'
const fs = require("fs");
const [pkgPath, patchPath, name, ...legacy] = process.argv.slice(2);
const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
pkg.dependencies = pkg.dependencies || {};
for (const old of legacy) delete pkg.dependencies[old];
pkg.dependencies[name] = "file:../../plugins/" + name;
if (pkg.dsh && pkg.dsh.profile && pkg.dsh.profile.bundles) {
  pkg.dsh.profile.bundles = pkg.dsh.profile.bundles.filter((b) => !legacy.includes(b) && b !== name);
}
fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + "\n");

let patchContent = fs.existsSync(patchPath) ? fs.readFileSync(patchPath, "utf8") : "";
let cleanedPatch = patchContent.replace(/^\s*\[\]\s*$/m, "");
for (const old of legacy) {
  const reg = new RegExp("^\\s*-\\s*insert:\\s*\\r?\\n\\s*-\\s*id:\\s*" + old + "[\\s\\S]*?(?=(^\\s*-\\s*insert:|\\z))", "gm");
  cleanedPatch = cleanedPatch.replace(reg, "");
}
cleanedPatch = cleanedPatch.trim();
const overlayBlock = "- id: system-prompt\n  config:\n    includeHarnessIdentity: false\n    personaPrefix: \"\"\n    personaSuffix: Your working directory is {{cwd}}.\n- insert:\n    - id: " + name + "\n      name: '" + name + "'\n      config:\n        enabled: true\n        autoApplyOnStart: true";

if (!new RegExp("^\\s*-\\s*id:\\s*" + name, "m").test(cleanedPatch)) {
  if (cleanedPatch && !/id:\s*system-prompt/.test(cleanedPatch)) {
    cleanedPatch = cleanedPatch + "\n\n" + overlayBlock;
  } else if (!cleanedPatch) {
    cleanedPatch = overlayBlock;
  } else {
    const insertBlock = "- insert:\n    - id: " + name + "\n      name: '" + name + "'\n      config:\n        enabled: true\n        autoApplyOnStart: true";
    cleanedPatch = cleanedPatch + "\n\n" + insertBlock;
  }
}
fs.writeFileSync(patchPath, cleanedPatch + "\n");
NODE
  ok "package.json 与 cordis.patch.yml 已更新：$p"

  # ---------- [4.5] 自动应用 0.1.6 核心兼容补丁 ----------
  node --input-type=module - "$SRC_DIR/scripts/lib/patcher.js" "$DSH_ROOT" <<'NODE'
import { pathToFileURL } from 'node:url';
const patcher = await import(pathToFileURL(process.argv[2]).href);
patcher.applyAllPatches({ dshHome: process.argv[3] });
NODE
  ok "0.1.6 核心指令过滤与兼容补丁已就绪"

  # ---------- [5] pnpm install ----------
  step "安装依赖（pnpm install）"

  # pnpm 对 file: 依赖是复制进 node_modules 而非实时链接；先清除旧拷贝，
  # 强制 pnpm 重新同步，避免更新插件后 index.js/client.js 不同步
  if [[ -d "$p/node_modules/$PLUGIN_NAME" ]]; then
    rm -rf "$p/node_modules/$PLUGIN_NAME"
    ok "已清除 node_modules 旧拷贝，pnpm 将重新同步"
  fi
  for old in "${LEGACY_PLUGINS[@]}"; do
    if [[ -d "$p/node_modules/$old" ]]; then rm -rf "$p/node_modules/$old"; fi
  done

  # 优先建立软链接
  mkdir -p "$p/node_modules"
  ln -sfn "$DEST_DIR" "$p/node_modules/$PLUGIN_NAME" 2>/dev/null || true

  (
    cd "$p"
    if ! run_pnpm install; then
      err "pnpm install 失败，请手动执行：cd $p && pnpm install"
      exit 1
    fi
  )
  ok "依赖安装完成"
done

# ---------- [6] 完成 ----------
step "安装完成"

cat <<EOF

  $PLUGIN_LABEL v0.4.3 已安装！
  目标 profile：$(printf '%s ' "${PROFILE_DIRS[@]}" | sed 's/ *$//')
  最后一步：重启 DeepSeek Harness（Web 版刷新页面 / 桌面版重新打开），新建会话即可生效。
  验证方法：重启后输入框上方应显示绿色状态条「富江破甲已激活」。
  卸载方法：运行 node bin/qianxi-dsh.mjs uninstall，或使用 npx 安装命令将 install 改为 uninstall。
EOF
