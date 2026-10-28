#!/usr/bin/env node
import { readFileSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
const help = `qianxi-dsh — DeepSeek Harness 插件安装工具

用法：qianxi-dsh <install|uninstall> [--home <DSH目录>] [--profile <配置名>] [--dry-run]

  install       安装或更新插件（请先完全退出 DSH）
  uninstall     卸载插件（请先完全退出 DSH）
  --home        DSH 配置根目录，默认 DSH_HOME 或用户目录下的 .dsh
  --profile     仅处理指定配置，默认沿用安装器自动检测
  --dry-run     仅显示执行计划，不修改文件
  --help        显示帮助
  --version     显示版本

支持 Windows 和 Linux；需要 Node.js 22+。没有 Node.js 的 Windows 用户可下载 ZIP 后双击安装。`;

function main(args) {
  if (!args.length || args.includes("--help") || args.includes("-h")) {
    console.log(help);
    return 0;
  }
  if (args.length === 1 && args[0] === "--version") {
    console.log(pkg.version);
    return 0;
  }
  if (Number(process.versions.node.split(".")[0]) < 22) throw new Error("需要 Node.js 22 或更新版本。");
  const command = args.shift();
  if (!["install", "uninstall"].includes(command)) throw new Error(`未知命令：${command}。运行 --help 查看用法。`);
  const env = { ...process.env, DSH_INSTALL_NO_PAUSE: "1" };
  let dryRun = false;
  while (args.length) {
    const flag = args.shift();
    if (flag === "--dry-run") { dryRun = true; continue; }
    if (!["--home", "--profile"].includes(flag)) throw new Error(`未知选项：${flag}`);
    const value = args.shift();
    if (!value || value.startsWith("--")) throw new Error(`${flag} 缺少参数。`);
    env[flag === "--home" ? "DSH_HOME" : "DSH_PROFILE"] = flag === "--home" ? resolve(value) : value;
  }
  if (env.DSH_PROFILE && (/[\\/\x00-\x1f]/.test(env.DSH_PROFILE) || [".", ".."].includes(env.DSH_PROFILE))) {
    throw new Error("--profile 必须是单个配置目录名，不能包含路径。");
  }
  if (!["win32", "linux"].includes(process.platform)) throw new Error("当前安装器支持 Windows 和 Linux。");
  const windows = process.platform === "win32";
  const script = join(root, "scripts", "install", `${command}.${windows ? "ps1" : "sh"}`);
  if (!existsSync(script)) throw new Error(`安装包不完整，缺少 ${script}`);
  const executable = windows
    ? join(process.env.SystemRoot || "C:\\Windows", "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
    : "bash";
  const childArgs = windows ? ["-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script] : [script];
  if (windows && command === "install") childArgs.push("-NoPause");
  if (dryRun) {
    console.log(JSON.stringify({ command, executable, args: childArgs, home: env.DSH_HOME || "~/.dsh", profile: env.DSH_PROFILE || "自动检测" }, null, 2));
    return 0;
  }
  const result = spawnSync(executable, childArgs, { env, stdio: "inherit", windowsHide: true });
  if (result.error) throw new Error(`无法启动安装器：${result.error.message}`);
  return result.status ?? 1;
}

try { process.exitCode = main(process.argv.slice(2)); }
catch (error) { console.error(`qianxi-dsh: ${error.message}`); process.exitCode = 1; }
