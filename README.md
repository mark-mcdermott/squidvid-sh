# Lofi Multisong Music Vid

This bash script takes mp3 files and a mp4 video and makes a multisong music video. The resulting video is one long unbroken, continuous mp4 video file overlayed with the inputed mp3 songs along with their title, artist and album art. Think a lofi stream on youtube type style video - like a 30 minute background video of waves on a beach with the songs, text and album art overlayed.

## Setup
This was written with ffmpeg version 4.4 and GNU bash version 5.1.8. Your results will likely differ with differnt versions of either. Install both and then set your paths at the top of the lofi-multisong-music-vid.sh. Uncomment the songDir path line and also comment out the `songDir=$(getSongDir)` line in the getSong() function. Set the numSongs variable - the script will grab that many songs randomly for the video.

## To Run
Make sure you have executable permission on the .sh file (do chmod +x lofi-multisong-music-vid.sh) and do ./lofi-multisong-music-vid.sh to run it.

### Results
The resulting vid will look something like this screenshot:
![Example vid](screenshot-example.png)
