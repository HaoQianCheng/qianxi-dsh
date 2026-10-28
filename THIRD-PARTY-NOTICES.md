# 第三方来源及许可证

本项目包含改编自 Minglink 的 `dsh-infinite-gen-4` 项目的内容。

- 原作者：Minglink
- 上游项目：https://github.com/Minglink/dsh-infinite-gen-4
- 许可证：Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International（CC BY-NC-SA 4.0）
- 许可证全文：https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode

本分发版已作修改，包括调整项目名称和展示内容、将兼容补丁限定在安装过程中应用、增加 Windows 安装/卸载脚本，以及在缺少 Node.js/npm/pnpm 时自动准备运行环境。

改编自上述项目的内容依照 CC BY-NC-SA 4.0 继续共享。上游附带的 `LICENSE` 文件已随本项目保留。

## qianxi-dsh 接续维护记录

- 当前维护者：[HaoQianCheng](https://github.com/HaoQianCheng)
- 当前仓库：https://github.com/HaoQianCheng/qianxi-dsh
- 直接来源：[c3cvld7aag/fujiang-dsh](https://github.com/c3cvld7aag/fujiang-dsh)
- 接续基线：[ab86ddcd169f0f13bc74923b6ed95eda55224931](https://github.com/c3cvld7aag/fujiang-dsh/commit/ab86ddcd169f0f13bc74923b6ed95eda55224931)，包含原有 6 个提交及 `v0.4.3` 标签。
- 接续日期：2026-10-28。

本仓库保留上述基线中的完整 `LICENSE` 文件、Minglink 署名、原有来源说明及修改说明；接续维护的改编内容继续依照 CC BY-NC-SA 4.0 共享。

2026-10-28 核对时，历史来源地址 `Minglink/dsh-infinite-gen-4` 已重定向到 [Minglink/dsh-infinite-gen-5](https://github.com/Minglink/dsh-infinite-gen-5)，后者当前 `LICENSE` 提供 CC BY-NC-SA 4.0 全文。这里保留历史来源名称，且不以新版上游的许可证文件替换直接来源随附的 `LICENSE`。

本仓库此次接续修改：

- 补充仓库名称、维护者、下载入口及问题反馈地址。
- 在包元数据中声明当前仓库、主页和 Issues 地址，保留插件 ID、显示名称、版本及激活词。
- 将提示词资源校验值更新为接续基线实际保存的 SHA256，固定资源换行格式；提示词内容保持与基线一致。
- 增加 Windows/Linux 本地验证的 GitHub Actions 配置及生成文件忽略规则。
