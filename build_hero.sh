#!/bin/bash
set -e
echo "Starting ffmpeg..."
ffmpeg -i "docs/assets/video/Simulator Screen Recording - iPhone 17 - 2026-07-31 at 12.15.03.mov" \
       -i "docs/assets/video/Simulator Screen Recording - iPhone 17 - 2026-07-31 at 12.15.43.mov" \
       -i "docs/assets/video/Simulator Screen Recording - iPhone 17 - 2026-07-31 at 12.18.01.mov" \
       -filter_complex "[0:v]trim=start=1:duration=8,setpts=PTS-STARTPTS,scale=300:-2[v0]; \
                        [1:v]trim=start=1:duration=8,setpts=PTS-STARTPTS,scale=300:-2[v1]; \
                        [2:v]trim=start=1:duration=8,setpts=PTS-STARTPTS,scale=300:-2[v2]; \
                        [v0][v1][v2]hstack=inputs=3[v]" \
       -map "[v]" -vcodec libx264 -crf 23 -preset fast -an -pix_fmt yuv420p -y docs/assets/hero.mp4
echo "Done!"
