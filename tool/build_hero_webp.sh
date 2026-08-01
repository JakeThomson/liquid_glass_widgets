#!/bin/bash
set -e

TMPDIR1=$(mktemp -d)
TMPDIR2=$(mktemp -d)
trap "rm -rf $TMPDIR1 $TMPDIR2" EXIT

echo "→ Extracting Row 1 frames (1.mov + 3.mov) at 12fps..."
ffmpeg -i "docs/assets/video/1.mov" \
       -i "docs/assets/video/3.mov" \
       -filter_complex "[0:v]setpts=PTS-STARTPTS,scale=400:-2,fps=12[v0]; \
                        [1:v]setpts=PTS-STARTPTS,scale=400:-2,fps=12[v1]; \
                        [v0][v1]hstack=inputs=2[v]" \
       -map "[v]" "$TMPDIR1/frame_%04d.png" -hide_banner -loglevel error
echo "  Frames: $(ls $TMPDIR1 | wc -l | tr -d ' ')"

echo "→ Assembling Row 1 animated WebP..."
img2webp -loop 0 -lossy -q 80 -d 83 "$TMPDIR1"/frame_*.png -o docs/assets/hero_row1.webp
echo "  Size: $(du -sh docs/assets/hero_row1.webp | cut -f1)"

echo "→ Extracting Row 2 frames (2.mov + 4.mov) at 12fps..."
ffmpeg -i "docs/assets/video/2.mov" \
       -i "docs/assets/video/4.mov" \
       -filter_complex "[0:v]setpts=PTS-STARTPTS,scale=400:-2,fps=12[v0]; \
                        [1:v]setpts=PTS-STARTPTS,scale=400:-2,fps=12[v1]; \
                        [v0][v1]hstack=inputs=2[v]" \
       -map "[v]" "$TMPDIR2/frame_%04d.png" -hide_banner -loglevel error
echo "  Frames: $(ls $TMPDIR2 | wc -l | tr -d ' ')"

echo "→ Assembling Row 2 animated WebP..."
img2webp -loop 0 -lossy -q 80 -d 83 "$TMPDIR2"/frame_*.png -o docs/assets/hero_row2.webp
echo "  Size: $(du -sh docs/assets/hero_row2.webp | cut -f1)"

echo "Done!"
