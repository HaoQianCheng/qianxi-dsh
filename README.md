# qianxi-dsh

由 [HaoQianCheng](https://github.com/HaoQianCheng) 接续维护的 DSH 本地插件，基于 [c3cvld7aag/fujiang-dsh](https://github.com/c3cvld7aag/fujiang-dsh)，保留其完整 Git 提交历史及原有功能。

本仓库地址：[HaoQianCheng/qianxi-dsh](https://github.com/HaoQianCheng/qianxi-dsh)。问题反馈请提交至 [Issues](https://github.com/HaoQianCheng/qianxi-dsh/issues)。

富江破甲是一个用于 DSH 的本地插件，内置提示词规则，提供 Windows 一键注入和一键卸载。插件加载后，会在对话输入框上方显示「富江破甲已激活」。

当前版本：`0.4.3`。插件标识：`fujiang-armor`。

`qianxi-dsh` 是接续维护的仓库名称。为兼容已有安装，插件包名、配置标识、界面名称「富江破甲」和激活词「富江」继续沿用原值。

## 功能

- 随插件部署内置规则，无需手动复制提示词。
- 双击批处理文件完成注入或卸载。
- 自动检测运行环境；缺少 Node.js、npm 或 pnpm 时自动下载并准备。
- 支持选择本地 DSH 配置目录中的目标配置。
- 在对话输入框上方显示插件激活状态。

## 安装前准备

- 使用 Windows，安装 DSH，并至少启动过一次，使其生成 `%USERPROFILE%\.dsh` 本地配置目录。
- 首次安装需要联网。已有可用的 Node.js 22 或更新版本和 npm 时直接复用；环境缺失、损坏或版本过旧时，安装器会从 Node.js 官方下载长期支持版，校验 SHA256 后放入当前用户目录，无需管理员权限。缺少 pnpm 时会自动通过 npm 获取。
- 完全退出 DSH 后再执行安装，避免正在运行的程序继续使用旧插件。

## 一键安装

1. 从本仓库的「Code → Download ZIP」[下载最新源码](https://github.com/HaoQianCheng/qianxi-dsh/archive/refs/heads/main.zip)。完整解压后即可使用安装脚本。
2. 完整解压 ZIP，打开包含 `点我一键注入.bat` 的项目文件夹。
3. 完全退出 DSH。
4. 双击 `点我一键注入.bat`。
5. 如果检测到多个 DSH 配置，按安装器提示选择需要使用的目标配置。
6. 等待环境下载及插件安装完成，然后重新启动 DSH。首次下载耗时取决于网络。
7. 打开对话，确认输入框上方显示「富江破甲已激活」。在聊天中输入激活词「富江」即可使用内置规则。

安装后的插件目录为 `%USERPROFILE%\.dsh\plugins\fujiang-armor`。请保留解压后的完整项目文件夹，卸载时仍需使用其中的脚本。

自动下载的 Node.js 位于 `%LOCALAPPDATA%\FujiangArmor\runtime`，下次安装会复用。安装器只为当前执行过程设置运行环境，不改系统 PATH；DSH 本体仍需先安装并启动一次。

## 一键卸载

1. 完全退出 DSH。
2. 在完整解压的项目文件夹中，双击 `点我一键卸载.bat`。
3. 如果出现配置选择提示，选择此前安装的目标配置。
4. 等待卸载完成，然后重新启动 DSH。

## 常见问题

| 问题 | 处理方法 |
| --- | --- |
| 找不到 DSH 配置或目标配置 | 先安装并启动一次 DSH，确认 `%USERPROFILE%\.dsh` 已生成，再运行安装器。 |
| 自动下载运行环境失败 | 确认网络可以访问 `nodejs.org` 和 npm 软件包源，再重新运行安装器；错误信息会显示具体原因。 |
| 运行环境校验失败 | 安装器不会使用校验失败的下载包，请检查网络后重试。 |
| 找不到脚本、规则或其他文件 | 完整解压压缩包，保留 `prompts`、`scripts` 等子目录；不要只复制单个 BAT 文件。 |
| 安装成功但没有显示激活状态 | 完全退出并重新启动 DSH，确认安装时选中了当前使用的配置。 |
| 依赖下载失败 | 检查网络连接，并保留报错信息后重新运行安装器。 |
| 卸载后仍显示激活状态 | 完全退出并重新启动 DSH，确认卸载的是此前安装的配置。 |

「富江破甲已激活」表示插件已加载。实际回复仍受所选模型、其他提示词及 DSH 版本影响，本项目不保证所有模型都产生相同结果。

## DSH 无限重启

已核对 [dsh-purge 官方发布页](https://github.com/YuJunZhiXue/dsh-purge/releases)：1.1.52 在已应用补丁戳缺少 `sha` 时会把状态判为未对齐，并在启动时重打补丁、请求重启；上游从 1.1.53 起加入了空戳修复。若你使用 `dsh-purge` 1.1.52 并遇到反复重启，优先按其官方说明升级到 1.1.53 或更新版本，再重新启动 DSH。不要把空 `sha` 直接填成任意值；版本戳不匹配或宿主补丁未实际写入时，手动补戳可能掩盖故障。

本插件没有重启 DSH 的代码。兼容性补丁现在只在安装过程中应用；启动插件不会再重复写入宿主或 profile 文件。此次改动可避免富江插件自身在每次启动时触发写入，但不会替代 `dsh-purge` 的上游修复。若升级后仍循环，请保留相关启动日志并确认实际启用的 `dsh-purge` 版本与 profile。

## 开发与验证

使用 Node.js 22 或更新版本。以下本地检查无需安装 npm 依赖：

```sh
git clone https://github.com/HaoQianCheng/qianxi-dsh.git
cd qianxi-dsh
npm run harness:check
npm run verify
node scripts/scorer_semantics_test.mjs
```

GitHub Actions 会在 Windows 和 Linux 上执行上述检查。它们验证代码语法、插件注册、客户端状态条及评分器逻辑；实际 DSH 安装和模型回复效果仍需在目标环境验证。

## 来源与许可证

本仓库从 `c3cvld7aag/fujiang-dsh` 的提交 `ab86ddcd169f0f13bc74923b6ed95eda55224931` 接续维护，保留原有提交及 `v0.4.3` 标签。该项目包含改编自 Minglink 的 `dsh-infinite-gen-4` 的内容。

沿用原项目声明的 CC BY-NC-SA 4.0，完整保留随源代码提供的 [LICENSE](LICENSE) 及其附带声明。作者、来源、许可链接及本仓库的修改记录见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
