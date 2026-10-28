#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="fujiang-armor"
TARGET_PLUGINS=("$PLUGIN_NAME")
DSH_ROOT="${DSH_HOME:-$HOME/.dsh}"
PLUGINS_DIR="${DSH_ROOT}/plugins"
if [[ -n "${DSH_PROFILE:-}" && ( "$DSH_PROFILE" == *'/'* || "$DSH_PROFILE" == *'\'* || "$DSH_PROFILE" == '.' || "$DSH_PROFILE" == '..' ) ]]; then
  echo 'DSH_PROFILE 必须是单个配置目录名。' >&2; exit 1
fi
if [[ -n "${DSH_PROFILE:-}" && ! -f "$DSH_ROOT/profiles/$DSH_PROFILE/package.json" ]]; then
  echo "未找到指定配置 $DSH_PROFILE，已停止卸载。" >&2; exit 1
fi
[[ -d "$DSH_ROOT/profiles" ]] || { echo '未找到 DSH profiles 目录。' >&2; exit 1; }
KEEP_SHARED=0
for other in "$DSH_ROOT"/profiles/*; do
  [[ -f "$other/package.json" ]] || continue
  if [[ -n "${DSH_PROFILE:-}" && "${other##*/}" != "$DSH_PROFILE" ]]; then
    if node -e 'const fs=require("fs");const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.exit(p.dependencies?.["fujiang-armor"] ? 0 : 1)' "$other/package.json"; then KEEP_SHARED=1; fi
  fi
done

echo "==> 查找 profile 配置..."
for pDir in "$DSH_ROOT"/profiles/*; do
  [[ -z "${DSH_PROFILE:-}" || "${pDir##*/}" == "$DSH_PROFILE" ]] || continue
  pkgPath="${pDir}/package.json"
  patchPath="${pDir}/cordis.patch.yml"

  if [[ -f "${pkgPath}" ]]; then
    node - "${pkgPath}" "${patchPath}" "${TARGET_PLUGINS[@]}" <<'NODE'
const fs = require("fs");
const [pkgPath, patchPath, ...legacy] = process.argv.slice(2);
if (fs.existsSync(pkgPath)) {
  const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
  let changed = false;
  if (pkg.dependencies) {
    for (const old of legacy) {
      if (pkg.dependencies[old]) { delete pkg.dependencies[old]; changed = true; }
    }
  }
  if (pkg.dsh && pkg.dsh.profile && pkg.dsh.profile.bundles) {
    pkg.dsh.profile.bundles = pkg.dsh.profile.bundles.filter(b => !legacy.includes(b));
    changed = true;
  }
  if (changed) {
    fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + "\n");
    console.log("    [OK] package.json 已更新: " + pkgPath);
  }
}

if (fs.existsSync(patchPath)) {
  let patchContent = fs.readFileSync(patchPath, "utf8");
  for (const old of legacy) {
    const reg = new RegExp("^([ \\t]*)-[ \\t]+insert:[ \\t]*\\r?\\n[ \\t]+-[ \\t]+id:[ \\t]+" + old + "[ \\t]*(?:\\r?\\n|(?![\\s\\S]))[\\s\\S]*?(?=^\\1-[ \\t]|(?![\\s\\S]))", "gm");
    patchContent = patchContent.replace(reg, "");
  }
  fs.writeFileSync(patchPath, patchContent.trim() + "\n");
  console.log("    [OK] cordis.patch.yml 已更新: " + patchPath);
}
NODE

    for old in "${TARGET_PLUGINS[@]}"; do
      rm -rf "${pDir}/node_modules/${old}" 2>/dev/null || true
    done

    (cd "${pDir}" && if command -v pnpm >/dev/null 2>&1; then pnpm install; else npm exec --yes --package=pnpm@10 -- pnpm install; fi)
  fi
done

for old in "${TARGET_PLUGINS[@]}"; do
  if [[ "$KEEP_SHARED" == 0 && -d "${PLUGINS_DIR}/${old}" ]]; then
    [[ ! -L "${PLUGINS_DIR}/${old}" ]] || { echo '插件目录是链接，请先检查。' >&2; exit 1; }
    rm -rf "${PLUGINS_DIR}/${old}"
    echo "    [OK] 已删除插件目录: ${PLUGINS_DIR}/${old}"
  fi
done

echo "==> 富江破甲卸载完成，请重启 DeepSeek Harness。"
