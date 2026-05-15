#!/bin/bash
set -e
cd "$(dirname "$0")"

D=3.0      # display seconds per image
T=0.7      # crossfade seconds
W=1080
H=1920
FPS=30
IN=$(echo "$D + $T" | bc)   # each source clip length with buffer

# Per-image: blurred fill background + sharp fitted foreground
build_clip() {
  echo "[$1:v]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},gblur=sigma=30,eq=brightness=-0.06[bg$1];[$1:v]scale=${W}:${H}:force_original_aspect_ratio=decrease[fg$1];[bg$1][fg$1]overlay=(W-w)/2:(H-h)/2,setsar=1,fps=${FPS},format=yuv420p,trim=duration=${IN},setpts=PTS-STARTPTS[v$1];"
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
FONT="/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"
TITLE="こだわりのアメニティ"
SUB="― 見えないところにこそ、本気を ―"
FILTER="${FILTER}[x4]drawbox=y=ih*0.60:w=iw:h=ih*0.20:color=black@0.32:t=fill,"
FILTER="${FILTER}drawtext=fontfile='${FONT}':text='${TITLE}':fontcolor=white:fontsize=82:x=(w-text_w)/2:y=h*0.645:shadowcolor=black@0.7:shadowx=2:shadowy=2:alpha='if(lt(t,0.6),0,if(lt(t,1.2),(t-0.6)/0.6,1))',"
FILTER="${FILTER}drawtext=fontfile='${FONT}':text='${SUB}':fontcolor=white@0.92:fontsize=40:x=(w-text_w)/2:y=h*0.645+128:shadowcolor=black@0.7:shadowx=2:shadowy=2:alpha='if(lt(t,0.9),0,if(lt(t,1.5),(t-0.9)/0.6,1))',"
FILTER="${FILTER}format=yuv420p[vout]"

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
