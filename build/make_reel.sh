#!/bin/bash
set -e
cd "$(dirname "$0")"

D=4.5      # display seconds per image
T=0.7      # crossfade seconds
W=1080
H=1920
FPS=30
IN=$(echo "$D + $T" | bc)   # each source clip length with buffer
FONT="/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"

# drawtext with outline + shadow (no background band), fades in within the clip
dt() { # text size y fadestart [alpha_max]
  local txt="$1" size="$2" yy="$3" fs="$4" am="${5:-1}"
  echo "drawtext=fontfile='${FONT}':text='${txt}':fontcolor=white@${am}:fontsize=${size}:x=(w-text_w)/2:y=${yy}:bordercolor=black@0.5:borderw=4:shadowcolor=black@0.55:shadowx=2:shadowy=2:alpha='if(lt(t\,${fs})\,0\,if(lt(t\,${fs}+0.6)\,(t-${fs})/0.6\,1))'"
}

# Per-scene telop (text + placement crafted individually)
scene_text() {
  case "$1" in
    0) echo "$(dt 'こだわりのアメニティ' 84 'h*0.43' 0.4),$(dt '― 細部に宿る、もてなしの心 ―' 38 'h*0.43+128' 0.7 0.92)" ;;
    1) echo "$(dt '肌にふれるものだから' 60 'h*0.78' 0.5),$(dt 'ひとつずつ、選ぶ。' 60 'h*0.78+86' 0.8)" ;;
    2) echo "$(dt '香りも、佇まいも。' 66 'h*0.15' 0.5)" ;;
    3) echo "$(dt '見えないところにこそ' 62 'h*0.48' 0.5),$(dt '本気を。' 62 'h*0.48+88' 0.8)" ;;
    4) echo "$(dt 'その一室が、空くのを待っています' 50 'h*0.72' 0.5),$(dt 'ご予約はプロフィールのリンクから' 36 'h*0.72+92' 0.9 0.95)" ;;
  esac
}

# Per-image: blurred fill background + sharp fitted foreground + per-scene text
build_clip() {
  echo "[$1:v]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},gblur=sigma=30,eq=brightness=-0.06[bg$1];[$1:v]scale=${W}:${H}:force_original_aspect_ratio=decrease[fg$1];[bg$1][fg$1]overlay=(W-w)/2:(H-h)/2,setsar=1,$(scene_text $1),fps=${FPS},format=yuv420p,trim=duration=${IN},setpts=PTS-STARTPTS[v$1];"
}

FILTER=""
for i in 0 1 2 3 4; do FILTER="${FILTER}$(build_clip $i)"; done

# Chain xfade transitions
off=$(echo "$D - $T" | bc)
FILTER="${FILTER}[v0][v1]xfade=transition=fade:duration=${T}:offset=${off}[x1];"
acc=$(echo "$D + $D - $T" | bc)
n=2
for nxt in x2 x3 x4; do
  off=$(echo "$acc - $T" | bc)
  FILTER="${FILTER}[x$((n-1))][v${n}]xfade=transition=fade:duration=${T}:offset=${off}[${nxt}];"
  acc=$(echo "$acc + $D - $T" | bc)
  n=$((n+1))
done
FILTER="${FILTER}[x4]format=yuv420p[vout]"

ffmpeg -y \
  -loop 1 -t "$IN" -i img1.jpg \
  -loop 1 -t "$IN" -i img2.jpg \
  -loop 1 -t "$IN" -i img3.jpg \
  -loop 1 -t "$IN" -i img4.jpg \
  -loop 1 -t "$IN" -i img5.jpg \
  -filter_complex "$FILTER" \
  -map "[vout]" \
  -r "$FPS" -c:v libx264 -profile:v high -pix_fmt yuv420p -preset medium -crf 18 \
  -movflags +faststart \
  ../reel_amenity.mp4
