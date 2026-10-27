#!/usr/bin/env bash
# Generate Exsbe.colors (KDE color scheme) from the shared graphite palette.
set -euo pipefail
ACC=143,164,192      # fallback accent; Plasma replaces it with the wallpaper accent
FG=230,230,232; FGI=168,168,176
LINK=143,180,217; VIS=180,148,214; NEG=224,122,122; NEU=224,196,122; POS=143,199,154

group() { # name bgNormal bgAlternate [fgNormal]
cat <<G
[Colors:$1]
BackgroundAlternate=$3
BackgroundNormal=$2
DecorationFocus=$ACC
DecorationHover=$ACC
ForegroundActive=$ACC
ForegroundInactive=$FGI
ForegroundLink=$LINK
ForegroundNegative=$NEG
ForegroundNeutral=$NEU
ForegroundNormal=${4:-$FG}
ForegroundPositive=$POS
ForegroundVisited=$VIS

G
}

{
cat <<H
[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=112,111,110
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

H
group Button        46,46,50 56,56,61
group Complementary 28,28,31 42,42,46
group Header        43,43,47 35,35,38
echo "[Colors:Header][Inactive]"; group x 35,35,38 43,43,47 | tail -n +2
group Selection     $ACC 96,110,130
group Tooltip       43,43,47 35,35,38
group View          28,28,31 33,33,36
group Window        35,35,38 42,42,46
cat <<T
[General]
ColorScheme=Exsbe
Name=Exsbe
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground=43,43,47
activeBlend=$FG
activeForeground=$FG
inactiveBackground=35,35,38
inactiveBlend=$FGI
inactiveForeground=$FGI
T
} > "$(dirname "$0")/Exsbe.colors"
