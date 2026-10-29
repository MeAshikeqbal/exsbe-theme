#!/usr/bin/env bash
# Generate the Exsbe sound theme: soft, short glass-like chimes (sine + overtones, fast attack,
# exponential decay, a little room). Writes sounds/exsbe/stereo/*.oga; run after editing.
set -euo pipefail
out="$(cd "$(dirname "$0")" && pwd)/exsbe"
mkdir -p "$out/stereo"

# note FREQ START [DECAY GAIN] -> one expression term
note() {
  local f=$1 s=$2 d=${3:-6} g=${4:-0.5}
  echo "+if(gte(t,$s),$g*(sin(2*PI*$f*(t-$s))+0.22*sin(4*PI*$f*(t-$s))+0.06*sin(6*PI*$f*(t-$s)))*exp(-(t-$s)*$d)*min(1,(t-$s)*400),0)"
}

# sound NAME LENGTH NOTE... (each NOTE is "freq start [decay gain]")
sound() {
  local name=$1 len=$2 expr=0 n; shift 2
  for n in "$@"; do expr+=$(note $n); done
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "aevalsrc='$expr':s=48000:d=$len" \
    -af "aecho=0.8:0.5:45|80:0.18|0.10,afade=t=out:st=$(awk "BEGIN{print $len-0.15}"):d=0.15,pan=stereo|c0=c0|c1=c0,volume=-4dB,alimiter=limit=0.7" \
    -c:a libvorbis -q:a 4 "$out/stereo/$name.oga"
}

# C major pentatonic around C5-C7
C5=523.25 E5=659.25 G5=783.99 A5=880.00 C6=1046.5 D6=1174.7 E6=1318.5 G6=1568.0 A4=440.00 D5=587.33

sound desktop-login        1.8 "$C5 0 4 .4" "$E5 .12 4 .4" "$G5 .24 4 .4" "$C6 .36 3 .45"
sound desktop-logout       1.4 "$G5 0 4 .4" "$E5 .14 4 .4" "$C5 .28 3 .45"
sound message-new-instant  0.9 "$E6 0 8 .35" "$A5 .09 6 .35"
sound message              0.9 "$G5 0 7 .35" "$C6 .09 6 .35"
sound dialog-information   0.8 "$C6 0 7 .4"
sound dialog-question      0.9 "$G5 0 7 .35" "$D6 .1 6 .35"
sound dialog-warning       1.0 "$A5 0 7 .4" "$A5 .16 7 .4"
sound dialog-error         1.1 "$D5 0 6 .45" "$A4 .14 5 .45"
sound completion-success   1.0 "$C6 0 6 .35" "$G6 .1 6 .3"
sound completion-fail      1.0 "$E5 0 6 .4" "$C5 .12 5 .4"
sound device-added         0.8 "$G5 0 8 .35" "$D6 .08 7 .35"
sound device-removed       0.8 "$D6 0 8 .35" "$G5 .08 7 .35"
sound audio-volume-change  0.25 "$C6 0 30 .3"
sound bell                 0.7 "$E6 0 7 .3"
sound bell-window-system   0.7 "$E6 0 7 .3"
sound battery-low          1.0 "$E5 0 6 .4" "$E5 .2 6 .4"
sound trash-empty          0.6 "$G6 0 18 .2" "$E6 .05 16 .2" "$C6 .1 14 .2"
sound theme-demo           1.8 "$C5 0 4 .4" "$E5 .12 4 .4" "$G5 .24 4 .4" "$C6 .36 3 .45"

cat > "$out/index.theme" <<'T'
[Sound Theme]
Name=Exsbe
Comment=Soft chimes for the Exsbe desktop
Inherits=ocean,freedesktop
Directories=stereo
Example=theme-demo

[stereo]
OutputProfile=stereo
T
