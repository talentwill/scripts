# scripts

个人工具脚本集合，用于 macOS 多设备间的工具同步和版本管理。

## 安装

```bash
git clone git@github.com:talentwill/scripts.git ~/scripts
```

在 `~/.zshrc` 末尾添加：

```bash
for dir in ~/scripts/*/; do
    export PATH="$dir:$PATH"
done
```

然后 `source ~/.zshrc` 即可全局使用所有脚本。

## 工具列表

### video/compress_video.sh — 视频压缩

使用 H.265/HEVC 压缩视频，优先 macOS 硬件加速（VideoToolbox），无硬件则自动回退软编码。

```bash
compress_video.sh video.mp4                     # 硬件加速压缩
compress_video.sh *.mp4                          # 批量压缩
compress_video.sh -q 50 video.mp4                # 更小文件 (默认 65, 范围 1-100)
compress_video.sh -s video.mp4                   # 软编码模式 (更小但更慢)
compress_video.sh -f 24 video.mp4                # 自定义帧率 (默认 30)
compress_video.sh -o ~/Desktop/compressed *.mp4  # 指定输出目录
```

输出文件自动添加 `_compressed` 后缀，已存在则跳过。

### audio/extract_mp3.sh — 视频提取 MP3

从视频文件中提取音频为 MP3，自动检测源音频编码选择最优模式。

```bash
extract_mp3.sh video.mp4                    # 提取为 320kbps MP3
extract_mp3.sh *.mp4                        # 批量提取
extract_mp3.sh -q 256 video.mp4             # 指定码率 (128/192/256/320)
extract_mp3.sh -o ~/Desktop video.mp4       # 指定输出目录
extract_mp3.sh -c video.mp4                 # 强制复制模式 (源音频必须是 MP3)
```

| 源音频 | 行为 | 损耗 |
|--------|------|------|
| MP3 | 直接复制流 | 零损耗 |
| AAC/其他 | 转码 320kbps MP3 | 最高品质转码 |

### macos/readlink.sh — 跨平台 readlink

macOS 兼容的 `readlink -f` 实现，解析符号链接的最终物理路径。

```bash
readlink.sh /path/to/symlink
```

## 新增脚本

1. 将脚本放入对应分类目录
2. `chmod +x` 添加执行权限
3. 更新本 README 的工具列表
4. `git add / commit / push`
