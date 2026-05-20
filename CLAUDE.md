# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

个人 macOS 工具脚本集合，通过 GitHub 私有仓库在多台 Mac 设备间同步（笔记本、Mac Studio、Mac mini）。脚本按功能分类存放在子目录中，通过 `~/.zshrc` 中的 PATH 配置全局可用。

## Script Conventions

所有 shell 脚本遵循统一风格：

- Shebang: `#!/bin/bash`
- 安全模式: `set -euo pipefail`
- 每个脚本必须包含 `usage()` 函数和 `-h` 帮助选项
- 支持批量文件处理（`for input in "$@"`）
- 输出文件已存在时自动跳过，不覆盖
- 使用 ffmpeg 的脚本需检测 ffmpeg 是否安装
- macOS 兼容: 避免 GNU-only 命令，优先使用 POSIX 兼容写法

## Dependencies

- `ffmpeg` / `ffprobe` — 视频和音频处理脚本依赖
- macOS 原生命令 — 部分脚本使用 `stat -f%z`（macOS 版）而非 `stat -c%s`（Linux 版）

## Adding New Scripts

1. 放入对应分类子目录（video/ audio/ dev/ system/ macos/ 等）
2. `chmod +x` 添加执行权限
3. 如果脚本有外部依赖，在脚本头部注释或 usage 中说明
