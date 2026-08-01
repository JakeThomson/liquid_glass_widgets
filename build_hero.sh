#!/bin/bash
set -e
echo "Starting ffmpeg..."
ffmpeg -i "docs/assets/video/1.mov" \
       -i "docs/assets/video/2.mov" \
       -i "docs/assets/video/3.mov" \
       -filter_complex "[0:v]setpts=PTS-STARTPTS,scale=300:-2[v0]; \
                        [1:v]setpts=PTS-STARTPTS,scale=300:-2[v1]; \
                        [2:v]setpts=PTS-STARTPTS,scale=300:-2[v2]; \
                        [v0][v1][v2]hstack=inputs=3[v]" \
       -map "[v]" -vcodec libx264 -crf 23 -preset fast -an -pix_fmt yuv420p -y docs/assets/hero.mp4
echo "Done!"
