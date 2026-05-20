#!/bin/bash
# 从视频文件提取 MP3（智能模式）
# 用法:
#   ./extract_mp3.sh video.mp4                    # 提取音频为 MP3
#   ./extract_mp3.sh *.mp4                        # 批量提取
#   ./extract_mp3.sh -o /output/dir video.mp4     # 指定输出目录
#   ./extract_mp3.sh -q 320 video.mp4             # 指定码率 (默认 320)
#   ./extract_mp3.sh -c video.mp4                 # 强制复制模式（源音频必须是 MP3）

set -euo pipefail

# 默认参数
BITRATE="320k"
OUTPUT_DIR=""
COPY_MODE=false

usage() {
    echo "从视频文件提取 MP3"
    echo ""
    echo "用法: $0 [选项] <文件1.mp4> [文件2.mp4 ...]"
    echo ""
    echo "选项:"
    echo "  -q <码率>    MP3 码率 (默认 320, 可选 128/192/256/320)"
    echo "  -o <目录>    输出目录 (默认与源文件同目录)"
    echo "  -c           复制模式 (源音频必须是 MP3，零损耗)"
    echo "  -h           显示帮助"
    echo ""
    echo "说明:"
    echo "  源音频为 MP3 时，自动使用复制模式（零损耗）"
    echo "  源音频为 AAC/其他时，转码为 320kbps MP3（最高品质）"
}

while getopts "q:o:ch" opt; do
    case $opt in
        q) BITRATE="${OPTARG}k" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        c) COPY_MODE=true ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
    echo "错误: 请指定至少一个视频文件"
    usage
    exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
    echo "错误: 未找到 ffmpeg，请先安装: brew install ffmpeg"
    exit 1
fi

if [ -n "$OUTPUT_DIR" ] && [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

total=$#
current=0
success=0
failed=0

for input in "$@"; do
    current=$((current + 1))

    if [ ! -f "$input" ]; then
        echo "[$current/$total] 跳过: 文件不存在 - $input"
        failed=$((failed + 1))
        continue
    fi

    basename="${input%.*}"

    if [ -n "$OUTPUT_DIR" ]; then
        filename=$(basename "$basename")
        output="$OUTPUT_DIR/${filename}.mp3"
    else
        output="${basename}.mp3"
    fi

    if [ -f "$output" ]; then
        echo "[$current/$total] 跳过: 输出文件已存在 - $output"
        continue
    fi

    # 检测源音频编码
    src_codec=$(ffprobe -v quiet -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$input" 2>/dev/null)
    src_size=$(du -sh "$input" | cut -f1)
    src_duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null)
    src_mins=$(echo "$src_duration / 60" | bc 2>/dev/null || echo "?")

    if $COPY_MODE || [ "$src_codec" = "mp3" ]; then
        mode="复制 (零损耗)"
        cmd=(ffmpeg -i "$input"
            -vn -c:a copy
            -y "$output")
    else
        mode="转码 ${BITRATE}"
        cmd=(ffmpeg -i "$input"
            -vn -c:a libmp3lame -b:a "$BITRATE"
            -y "$output")
    fi

    echo "[$current/$total] 提取中: $input"
    echo "  源文件: ${src_size}, 时长约 ${src_mins} 分钟, 音频: ${src_codec}"
    echo "  模式: ${mode}"
    echo ""

    start_time=$(date +%s)

    if "${cmd[@]}" 2>/dev/null; then
        end_time=$(date +%s)
        elapsed=$((end_time - start_time))

        dst_size=$(du -sh "$output" | cut -f1)

        echo "  完成! 耗时 ${elapsed}s"
        echo "  输出: ${dst_size}"
        echo ""
        success=$((success + 1))
    else
        echo "  失败: $input"
        rm -f "$output"
        failed=$((failed + 1))
    fi
done

echo "========================================="
echo "全部完成: 成功 ${success}, 失败 ${failed}, 共 ${total} 个文件"
