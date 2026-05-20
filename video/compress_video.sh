#!/bin/bash
# 讲座/直播视频压缩脚本 (macOS 硬件加速)
# 用法:
#   ./compress_video.sh video1.mp4 video2.mp4          # 压缩指定文件
#   ./compress_video.sh *.mp4                           # 批量压缩
#   ./compress_video.sh -o /output/dir video.mp4        # 指定输出目录
#   ./compress_video.sh -q 50 video.mp4                 # 自定义画质 (默认 65, 范围 1-100)
#   ./compress_video.sh -s video.mp4                    # 软编码模式 (更小但更慢)

set -euo pipefail

# 默认参数
QUALITY=65
OUTPUT_DIR=""
SUFFIX="_compressed"
SOFTWARE_MODE=false
FPS=30
AUDIO_BITRATE="128k"

usage() {
    echo "讲座/直播视频压缩脚本 (macOS 硬件加速)"
    echo ""
    echo "用法: $0 [选项] <文件1.mp4> [文件2.mp4 ...]"
    echo ""
    echo "选项:"
    echo "  -q <数字>    画质 (默认 65, 范围 1-100, 越小文件越小)"
    echo "  -o <目录>    输出目录 (默认与源文件同目录)"
    echo "  -s           软编码模式 (文件更小但速度慢很多)"
    echo "  -f <帧率>    输出帧率 (默认 30)"
    echo "  -h           显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 video.mp4                          # 硬件加速压缩"
    echo "  $0 -q 50 video.mp4                    # 更小文件"
    echo "  $0 -s video.mp4                       # 软编码 (最省空间)"
    echo "  $0 -o ~/Desktop/compressed *.mp4      # 批量输出到指定目录"
}

while getopts "q:o:sf:h" opt; do
    case $opt in
        q) QUALITY="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        s) SOFTWARE_MODE=true ;;
        f) FPS="$OPTARG" ;;
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

# 检测是否有硬件编码器
HW_ENCODER=""
if ! $SOFTWARE_MODE; then
    if ffmpeg -encoders 2>/dev/null | grep -q "hevc_videotoolbox"; then
        HW_ENCODER="hevc_videotoolbox"
        echo "检测到 VideoToolbox 硬件加速"
    else
        echo "未检测到硬件编码器，使用软编码"
        SOFTWARE_MODE=true
    fi
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
    extension="${input##*.}"

    if [ -n "$OUTPUT_DIR" ]; then
        filename=$(basename "$basename")
        output="$OUTPUT_DIR/${filename}${SUFFIX}.${extension}"
    else
        output="${basename}${SUFFIX}.${extension}"
    fi

    if [ -f "$output" ]; then
        echo "[$current/$total] 跳过: 输出文件已存在 - $output"
        continue
    fi

    # 获取源文件信息
    src_size=$(du -sh "$input" | cut -f1)
    src_info=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null)
    src_mins=$(echo "$src_info / 60" | bc 2>/dev/null || echo "?")

    if $SOFTWARE_MODE; then
        mode_info="软编码 H.265 / CRF 28 / ${FPS}fps"
    else
        mode_info="硬件加速 H.265 / q:v ${QUALITY} / ${FPS}fps"
    fi

    echo "[$current/$total] 压缩中: $input"
    echo "  源文件: ${src_size}, 时长约 ${src_mins} 分钟"
    echo "  参数: ${mode_info} / AAC ${AUDIO_BITRATE}"
    echo ""

    start_time=$(date +%s)
    total_duration=$(echo "$src_info" | awk '{printf "%d", $1}')

    if $SOFTWARE_MODE; then
        cmd=(ffmpeg -i "$input"
            -c:v libx265 -crf 28 -preset fast -r "$FPS" -tag:v hvc1
            -c:a aac -b:a "$AUDIO_BITRATE"
            -movflags +faststart -y "$output")
    else
        cmd=(ffmpeg -i "$input"
            -c:v hevc_videotoolbox -q:v "$QUALITY" -r "$FPS" -tag:v hvc1
            -c:a aac -b:a "$AUDIO_BITRATE"
            -movflags +faststart -y "$output")
    fi

    # 运行 ffmpeg（前台运行，Ctrl+C 自然终止所有进程）
    progress_file=$(mktemp)
    log_file=$(mktemp)

    # 后台监控进度文件，实时显示格式化进度
    (
        while sleep 2; do
            out_time=$(grep -a '^out_time_ms=' "$progress_file" 2>/dev/null | tail -1 | cut -d= -f2)
            if [ -n "$out_time" ] && [ "$out_time" != "N/A" ]; then
                current_sec=$((out_time / 1000000))
                if [ "$total_duration" -gt 0 ] 2>/dev/null && [ "$current_sec" -gt 0 ]; then
                    pct=$((current_sec * 100 / total_duration))
                    [ $pct -gt 100 ] && pct=100
                    h=$((current_sec / 3600))
                    m=$(((current_sec % 3600) / 60))
                    s=$((current_sec % 60))
                    elapsed_now=$(($(date +%s) - start_time))
                    if [ $elapsed_now -gt 0 ]; then
                        speed_x=$(echo "scale=1; $current_sec / $elapsed_now" | bc 2>/dev/null || echo "?")
                        eta=$(( (total_duration - current_sec) * elapsed_now / current_sec ))
                        eta_m=$((eta / 60))
                        eta_s=$((eta % 60))
                        printf "\r  进度: %3d%% | %02d:%02d:%02d / %02d:%02d:%02d | %.1fx | 剩余 %dm%02ds  " \
                            $pct $h $m $s \
                            $((total_duration/3600)) $(((total_duration%3600)/60)) $((total_duration%60)) \
                            $speed_x $eta_m $eta_s
                    fi
                fi
            fi
        done
    ) &
    monitor_pid=$!

    # 前台运行 ffmpeg；EXIT trap 确保任何退出都清理临时文件和监控进程
    trap "kill $monitor_pid 2>/dev/null; wait $monitor_pid 2>/dev/null; rm -f '$progress_file' '$log_file'" EXIT
    "${cmd[@]}" -progress "$progress_file" 2>"$log_file"
    exit_code=$?
    trap - EXIT
    kill "$monitor_pid" 2>/dev/null; wait "$monitor_pid" 2>/dev/null || true
    rm -f "$progress_file" "$log_file"

    if [ "$exit_code" -eq 0 ]; then
        end_time=$(date +%s)
        elapsed=$((end_time - start_time))
        mins=$((elapsed / 60))
        secs=$((elapsed % 60))

        dst_size=$(du -sh "$output" | cut -f1)
        src_bytes=$(stat -f%z "$input" 2>/dev/null || stat -c%s "$input")
        dst_bytes=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output")
        ratio=$(echo "scale=1; $dst_bytes * 100 / $src_bytes" | bc)

        printf "\n"
        echo "  完成! 耗时 ${mins}m${secs}s"
        echo "  ${src_size} -> ${dst_size} (原始的 ${ratio}%)"
        echo ""
        success=$((success + 1))
    else
        printf "\n"
        echo "  失败: $input"
        rm -f "$output"
        failed=$((failed + 1))
    fi
done

echo "========================================="
echo "全部完成: 成功 ${success}, 失败 ${failed}, 共 ${total} 个文件"
