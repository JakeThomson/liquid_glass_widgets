#!/bin/bash
set -e
echo "Starting ffmpeg — Row 1: 1.mov + 3.mov..."
ffmpeg -i "docs/assets/video/1.mov" \
       -i "docs/assets/video/3.mov" \
       -filter_complex "[0:v]setpts=PTS-STARTPTS,scale=450:-2[v0]; \
                        [1:v]setpts=PTS-STARTPTS,scale=450:-2[v1]; \
                        [v0][v1]hstack=inputs=2[v]" \
       -map "[v]" -vcodec libx264 -crf 23 -preset fast -an -pix_fmt yuv420p -y docs/assets/hero_row1.mp4
echo "Row 1 done!"

echo "Starting ffmpeg — Row 2: 2.mov + 4.mov..."
ffmpeg -i "docs/assets/video/2.mov" \
       -i "docs/assets/video/4.mov" \
       -filter_complex "[0:v]setpts=PTS-STARTPTS,scale=450:-2[v0]; \
                        [1:v]setpts=PTS-STARTPTS,scale=450:-2[v1]; \
                        [v0][v1]hstack=inputs=2[v]" \
       -map "[v]" -vcodec libx264 -crf 23 -preset fast -an -pix_fmt yuv420p -y docs/assets/hero_row2.mp4
echo "Row 2 done!"
