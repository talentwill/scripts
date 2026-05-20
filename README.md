# scripts

个人工具脚本集合，用于 macOS 多设备间的工具同步和版本管理。

## 目录结构

```
video/    视频处理工具（压缩、转码、剪辑等）
audio/    音频处理工具（格式转换、降噪等）
dev/      开发辅助工具（代码生成、项目脚手架等）
system/   系统维护工具（清理、备份、配置等）
```

## 使用方法

确保 `~/.zshrc` 中包含：

```bash
for dir in ~/scripts/*/; do
    export PATH="$dir:$PATH"
done
```

## 新增脚本

1. 将脚本放入对应分类目录
2. `chmod +x` 添加执行权限
3. `git add / commit / push`
