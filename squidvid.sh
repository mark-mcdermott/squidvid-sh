#!/usr/local/bin/bash

# Attribution-NonCommercial-NoDerivatives 4.0 International (CC BY-NC-ND 4.0) Copyright 2021 Mark McDermott <mark@markmcdermott.io>
# see accompanying LICENSE.md file for details
# You are free to:
# Share — copy and redistribute the material in any medium or format
# The licensor cannot revoke these freedoms as long as you follow the license terms.
# Under the following terms:
# Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
# NonCommercial — You may not use the material for commercial purposes.
# NoDerivatives — If you remix, transform, or build upon the material, you may not distribute the modified material.
# No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.

# Written with ffmpeg version 4.4 and GNU bash version 5.1.8(1)-release (x86_64-apple-darwin20.3.0)
# Your results will likely differ with differnt versions of either.
#
# Mark McDermott 6/11/21
# mark@markmcdermott.io
# https://markmcdermott.io
# https://github.com/mark-mcdermott
#
# This script follows google's shell styleguide: https://google.github.io/styleguide/shellguide.html

source ./lib/progressBar.sh

main() {

    trap "exit 1" TERM                    # used by the error handling function to kill the process
    export TOP_PID=$$                     # process id for program

    declare -A squidvid

    squidvid[options,num_songs]=2
    numSongs=2                            # set options
    quickTest=true
    quickTestTotalLength=14               # seconds
    songBasePath=/Users/markmcdermott/Desktop/misc/lofi/playlist-
    fontFilepath=/Library/Fonts/Helvetica-Bold.ttf
    vid=/Users/markmcdermott/Movies/youtube/long/beach-3-hr-skip-first-min.mp4
    quality=ultrafast
    outputBaseFilename=stream
    albumArtCoordinates=W*0.036:H*0.59    # W is screen width, w is image width (W/2-w/2:H/2-h/2 centers)
    fontColor=white
    fontSize=120
    textCoordinates=x=w*.035:y=h*.95-text_h
    textLineSpacing=25
    tempFolder=temp
    tempSongTextBaseFilename=tempSongTextFile #basename of temporary text file with song name and song artist (fullname will be like tempSongTextFile-1.txt)
    outputFolder=output
    vidSkipToPoint=0:01:00               # means skip the first minute of the video (skips over the watermarked parts)

    declare -a songs                     # declare arrays
    declare -a images
    declare -a titles
    declare -a artists
    declare -a texts
    declare -a lengths
    declare -a startPoints
    declare -a endPoints

    $(preVidSetup)                        # delete temp files, print a blank line, create log file
    songDir=$(getSongDir)                 # get song dir (there are two, it's chosen at random)
    for (( i=0; i<${squidvid[options,num_songs]}; i++))        # loop through each mp3
    do                                    # get the album art, song title, artist name, song length (sec), song startpoint (sec), and song endpoint (sec) and puts all that in its respective array
      song=$(getSongFromDir "$songDir")
      songPath="$songDir/$song"
      image=$(getAlbumArt "$songPath")
      text=$(getSongText "$songPath" "$i")
      length=$(getLength "$songPath")
      startPoint=$(getStartPoint "$i")
      endPoint=$(getEndPoint "$startPoint" "$length")
      songs[$i]=$song
      images[$i]=$image
      texts[$i]=$text
      lengths[$i]=$length
      startPoints[$i]=$startPoint
      endPoints[$i]=$endPoint
    done

    finalIndex=$numSongs-1                # moving from one-based list of songs to zero-based array
    totalLength=${endPoints[$finalIndex]} # get total length of vid in seconds (just the sum of the length of all the songs)
    outputFilename=$(getOutputFilename)
    outputPathAndFile="$outputFolder/$outputFilename"
    vidStr=$(getVidStr)                   # get ffmpeg command's arguments for input video, input songs and input images (album art images)
    inputSongsStr=$(getSongsStr "$numSongs")
    inputImagesStr=$(getImagesStr "$numSongs")
    filterStr=$(getFilterStr "$numSongs")
    outputStr=$(getOutputFileStr "$outputPathAndFile")
    ffmpegArguments=$vidStr$inputSongsStr$inputImagesStr$filterStr$outputStr

    ffmpeg $ffmpegArguments &             # run ffmpeg command (process input vid, songs and album art and render output video)
    runFfmpegProgressBar $totalLength     # run progress bar
    # echo "ffmpeg $ffmpegArguments"      # for debugging

    $(deleteTempFiles)                    # clean up (delete temp album art and temp title/artist text files)

}




## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Some necessary pre-vid setup
#
# Cleans up temp files in case program stopped early in the previous run.
# Cleans up test output mp4 files.
# Makes a blank line.
# Creates progress.txt file for progress info.
#
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
preVidSetup() {
  $(deleteTempFiles)                    # clean up temp files in case program stopped early in the previous run
  $(deleteTestOutputFiles)              # clean up test output mp4 files
  echo ""                               # make a blank line
  touch temp/ffmpeg-progress.log        # create progress.txt file for progress info
}



## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Rounds decimal number to nearest integer value
#
# From https://askubuntu.com/a/574474
#
# @param  {Decimal}
# @return {Integer}
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
round() {

  # myError "parameter not a number" "${FUNCNAME}" "${LINENO}"
  # printf %.4f $(echo "$1" | bc -l)
  num=$1
  if ! [[ -n $num ]]; then error "No paramater passed to function" ${LINENO} ${FUNCNAME}; fi  # check if a param was passed
  if ! [[ $num =~ ^[0-9]+(\.[0-9]+)?$ ]]; then error "Paramater not a number" ${LINENO} ${FUNCNAME[@]}; fi  # check if param is a number
  thisRounded=$(printf "%.0f\n" $num)
  echo $thisRounded
  #printf %.4f $(echo "$num" | bc -l)
}

floor() {
  floor=$(awk -v var="$1" 'BEGIN{printf "%d", var}')
  echo "$floor"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Randomly picks one of two mp3 directories
#
# This is obviously custom to my setup - you will want to change this most likely.
# I have two mp3 playlist folders: playlist-1 and playlist-2.
# Path returned does #not* have a trailing forward slash at the end.
#
# @return {String} full path. ie, /Users/markmcdermott/Desktop/misc/lofi/playlist-1
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getSongDir() {
  if ! [[ -n $songBasePath ]]; then error "Song base path not set" ${LINENO} ${FUNCNAME}; fi      # check if song base path was specified in the options
  num=$((1 + $RANDOM % 2))
  fullPath=$songBasePath$num
  if ! [[ -n $fullPath ]]; then error "Song directory output is blank" ${LINENO} ${FUNCNAME}; fi  # check if output is blank
  echo $fullPath
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Randomly picks a mp3 file from a given mp3 folder
#
# Param path does not have trailing forward slash at end.
#
# @param  {String} path to mp3 folder. ie, /Users/markmcdermott/Desktop/misc/lofi/playlist-1
# @return {String} mp3 filename with no path. ie, dancer.mp3
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getSongFromDir() {
  if ! [[ -n $1 ]]; then error "No paramater passed to function" ${LINENO} ${FUNCNAME}; fi  # check if a param was passed
  randomFile=$(ls $1 | shuf -n 1) # get one random file
  if ! [[ -n $randomFile ]]; then error "Random file is blank" ${LINENO} ${FUNCNAME}; fi       # check if output is blank
  if ! [[ $randomFile =~ .mp3$ ]]; then error "File not a mp3 file" ${LINENO} ${FUNCNAME}; fi  # check if output is a mp3 file
  echo $randomFile
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Randomly picks a mp3 song from one of two mp3 folders
#
# I have two mp3 playlist folders: playlist-1 and playlist-2 - it chooses one,
# then randomly chooses an mp3 from that folder.
# This is obviously custom to my setup - you will want to change this most likely.
#
# @return {String} mp3 filename with no path. ie, dancer.mp3
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getSong() {
  songDir=$(getSongDir) # you will want to tweak this unless you have the exact same two folder playlist system i do
  song=$(getSongFromDir "$songDir")
  if ! [[ -n $song ]]; then error "Song file is blank" ${LINENO} ${FUNCNAME}; fi              # check if output is blank
  if ! [[ $song =~ .mp3$ ]]; then error "Song file not a mp3 file" ${LINENO} ${FUNCNAME}; fi  # check if output is a mp3 file
  echo $song
}


## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Takes in mp3 filename and returns an image filename
#
# Takes in something like dancer.mp3 and returns something to dancer.jpg
#
# @param  {String} song filename (no path beforehand) that ends in .mp3
# @return {String} same base filename, but now ends in .jpg
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getAlbumArtFilename() {
  if ! [[ -n $1 ]]; then error "No paramater passed to function" ${LINENO} ${FUNCNAME}; fi  # check if a param was passed
  if ! [[ $1 =~ .mp3$ ]]; then error "Param file not a mp3 file" ${LINENO} ${FUNCNAME}; fi  # check if input is a mp3 file
  baseFilename=$(basename -s .mp3 "$1")
  imageName=$baseFilename.jpg
  if ! [[ $imageName =~ .jpg$ ]]; then error "Output file not a jpg file" ${LINENO} ${FUNCNAME}; fi  # check if output is a jpg file
  echo $imageName
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Creates album art jpg file
#
# Function does two things (maybe refactor into two functions):
# 1) returns image filename. ie, coffee.jpg
# 2) as a side effect, it creates jpg image file
#    (in same folder as this squidvid.sh file is)
#
# @param  {String} mp3 song path/filename
# @return {String} image filename ie, coffee.jpg
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getAlbumArt() {
  if ! [[ -n $1 ]]; then error "No paramater passed to function" ${LINENO} ${FUNCNAME}; fi  # check if a param was passed
  if ! [[ -n $tempFolder ]]; then error "Temp folder not set in options" ${LINENO} ${FUNCNAME}; fi  # check if temp folder set in options
  if ! [[ $1 =~ .mp3$ ]]; then error "Param string does not contain a mp3 file" ${LINENO} ${FUNCNAME}; fi  # check if input is a mp3 file
  imageFilename=$(getAlbumArtFilename "$1")
  if ! [[ -n $imageFilename ]]; then error "Image filename is empty" ${LINENO} ${FUNCNAME}; fi  # check if image filename was found
  ffmpeg -i "$1" "./$tempFolder/$imageFilename" -y -loglevel quiet
  tempImageFileCount=`ls -1 ./$tempFolder/*.jpg 2>/dev/null | wc -l`
  if [ $tempImageFileCount -eq 0 ] ; then error "No temp album art jpgs created" ${LINENO} ${FUNCNAME}; fi  # check if album art was created
  echo "$imageFilename"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get mp3 song length in seconds
#
# @param  {String} mp3 song path/filename
# @return {Decimal} lenth of song as number with four decimal places
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getLength() {
  thisSongPath=$1
  if ! [[ -n $thisSongPath ]]; then error "No paramater passed to function" ${LINENO} ${FUNCNAME}; fi  # check if a param was passed
  if ! [[ $thisSongPath =~ .mp3$ ]]; then error "Param string does not contain a mp3 file" ${LINENO} ${FUNCNAME}; fi  # check if input is a mp3 file
  if [ "$quickTest" = true ]
  then
    halfTotalLength=$(echo "scale=0; $quickTestTotalLength/2" | bc)
    thisLength=$halfTotalLength
  else
    thisLength=`ffprobe -show_entries stream=duration -of compact=p=0:nk=1 -v fatal "$1"` # gets decimal length in seconds (like 208.353412)
  fi
  thisLengthRounded=$(round $thisLength) # round decimal to four places
  if ! [[ -n $thisLengthRounded ]]; then error "Song length not calculated" ${LINENO} ${FUNCNAME}; fi
  echo $thisLengthRounded
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get song title
#
# @param  {String} mp3 song path/filename
# @return {String} song title (all lowercase)
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getTitle() {
  if ! [[ -n $1 ]]; then error "No paramater passed to function" ${LINENO} ${FUNCNAME}; fi  # check if a param was passed
  if ! [[ $1 =~ .mp3$ ]]; then error "Param string does not contain a mp3 file" ${LINENO} ${FUNCNAME}; fi  # check if input is a mp3 file
  title=`ffprobe -v error -show_entries format_tags=title -of default=nw=1:nk=1 "$1"`
  title=$(echo "$title" | tr '[:upper:]' '[:lower:]') # make lowercase
  if ! [[ -n $title ]]; then error "Song title is empty" ${LINENO} ${FUNCNAME}; fi
  echo "$title"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get artist name
#
# @param  {String} mp3 song path/filename
# @return {String} artist name ie (all lowercase), ie blvk
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getArtist() {
  if ! [[ -n $1 ]]; then error "No paramater passed to function" ${LINENO} ${FUNCNAME}; fi  # check if a param was passed
  if ! [[ $1 =~ .mp3$ ]]; then error "Param string does not contain a mp3 file" ${LINENO} ${FUNCNAME}; fi  # check if input is a mp3 file
  artist=`ffprobe -v error -show_entries format_tags=artist -of default=nw=1:nk=1 "$1"`
  artist=$(echo "$artist" | tr '[:upper:]' '[:lower:]') # make lowercase
  if ! [[ -n $artist ]]; then error "Artist name is empty" ${LINENO} ${FUNCNAME}; fi
  echo "$artist"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get song title and song artist
#
# Function does two things (maybe refactor into two functions):
# 1) returns song title and artist ie, dancer\nblvk
# 2) as a side effect, it writes title/artist to a temp text file
# Writing to a text file is a hacky workaround for the way ffmpeg does not
# handle multiline text well and does not handle spaces in text well.
# In complex filters the line break is not parsed and the two lines
# are just outputted like dancer\nblvk. You can put anything in the text file,
# so these textfiles have title on one line and song on the next line.
# Also spaces often break the whole program so a song name like
# Dancer In The Dark would break on the first space, stopping the whole program.
#
# @param  {String} mp3 song path/filename
# @param  {Integer} number of current song
# @return {String} song title and artist as one line like "dancer\nblvk"
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getSongText() {
  if ! [[ -n $1 ]]; then error "No mp3 path/file paramater passed to function" ${LINENO} ${FUNCNAME}; fi  # check if a param was passed
  if ! [[ $1 =~ .mp3$ ]]; then error "Param string does not contain a mp3 file" ${LINENO} ${FUNCNAME}; fi  # check if input is a mp3 file
  if ! [[ -n $2 ]]; then error "No song number paramater passed to function" ${LINENO} ${FUNCNAME}; fi
  if ! [[ $2 =~ ^[0-9]+$ ]]; then error "Song number paramater not a number" ${LINENO} ${FUNCNAME}; fi
  title=$(getTitle "$1")
  if ! [[ -n $title ]]; then error "Song title is empty" ${LINENO} ${FUNCNAME}; fi
  artist=$(getArtist "$1")
  if ! [[ -n $artist ]]; then error "Song artist is empty" ${LINENO} ${FUNCNAME}; fi
  text="$title\n$artist"
  if ! [[ -n $text ]]; then error "Song overlay text is empty" ${LINENO} ${FUNCNAME}; fi
  if [[ $text = "\n" ]]; then error "Song  overlay text is empty" ${LINENO} ${FUNCNAME}; fi
  songNum=$(echo "scale=0; $2+1" | bc) # zero index to one index
  printf "$text" > "./$tempFolder/$tempSongTextBaseFilename-$songNum.txt"         # create temp file with song title & artist (temp file is a hacky way to keep special characters like spaces from throwing an error in ffmpeg. it's also the only way to get the newline character between the title & artist to render correctly)
  tempTextFileCount=`ls -1 ./$tempFolder/*.txt 2>/dev/null | wc -l`
  if [ $tempTextFileCount -eq 0 ] ; then error "No temp text files created" ${LINENO} ${FUNCNAME}; fi
  echo "$titleArtistStr"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Calculates song start point in seconds
#
# Loops through all previous songs and sums all their lengths
# return number is the number of seconds from the start of the whole video
# to the start point of the current song.
# So if this is song three and the previous two songs were each 60 seconds long,
# the start point of this song is 120.0000 seconds.
#
# @param  {Integer} number of songs processed so far, including current song
# @return {Decimal} number of seconds, with four decimal places
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getStartPoint() {
  if ! [[ -n $1 ]]; then error "Song num not passed to function" ${LINENO} ${FUNCNAME}; fi  # check if a param was passed
  if ! [[ $1 =~ ^[0-9]+$ ]]; then error "Song number paramater not a number" ${LINENO} ${FUNCNAME}; fi
  thisStartPoint=0
  for (( j=0; j<$i; j++ ))
  do
    thisStartPoint=$(echo "scale=4; $thisStartPoint+${lengths[$j]}" | bc)
  done
  if ! [[ $thisStartPoint =~ ^[0-9]+(\.[0-9]+)?$ ]]; then error "Song start point paramater not a decimal" ${LINENO} ${FUNCNAME}; fi
  echo "$thisStartPoint"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Calculates song end point in seconds
#
# Sums start point of current song and the length of the current song.
# Return value is number of seconds from start of whole video to end of current song.
#
# @param  {Decimal} start point of current song in seconds
# @param  {Decimal} length of current song in seconds
# @return {Decimal} end point of current song in seconds
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getEndPoint() {
  if ! [[ -n $1 ]]; then error "Start point not passed to function" ${LINENO} ${FUNCNAME}; fi
  if ! [[ -n $2 ]]; then error "Song length not passed to function" ${LINENO} ${FUNCNAME}; fi
  if ! [[ $1 =~ ^[0-9]+(\.[0-9]+)?$ ]]; then error "Song start point paramater not a number" ${LINENO} ${FUNCNAME}; fi
  if ! [[ $2 =~ ^[0-9]+(\.[0-9]+)?$ ]]; then error "Song length paramater not a number" ${LINENO} ${FUNCNAME}; fi
  thisEndPoint=$(echo "scale=4; $1+$2" | bc)
  if ! [[ -n $thisEndPoint ]]; then error "End point variable is empty" ${LINENO} ${FUNCNAME}; fi
  if ! [[ $thisEndPoint =~ ^[0-9]+(\.[0-9]+)?$ ]]; then error "EndPoint not a decimal" ${LINENO} ${FUNCNAME}; fi
  if (( $(echo "$thisEndPoint < 0.0001" | bc -l) )); then error "EndPoint is zero" ${LINENO} ${FUNCNAME}; fi
  echo "$thisEndPoint"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Calculates the total length of the video in seconds
#
# If testing boolean var quickTest is true, this just sets the
# total length of the whole vid equal to the quickTestTotalLength variable.
# Otherwise, it just grabs the endpoint of the last song and uses that.
#
# @return {Decimal} length of whole video in seconds, with four decimal places
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getTotalLength() {
  if [ "$quickTest" = true ]
  then
    thisTotalLength=$quickTestTotalLength
  else
    finalIndex=$numSongs-1 # moving from one-based list of songs to zero-based array
    thisTotalLength=${endPoints[$finalIndex]}
  fi
  if ! [[ -n $thisTotalLength ]]; then error "Total length variable is empty" ${LINENO} ${FUNCNAME}; fi
  if ! [[ $thisTotalLength =~ ^[0-9]+(\.[0-9]+)?$ ]]; then error "Total length not a number" ${LINENO} ${FUNCNAME}; fi
  if [[ $thisTotalLength -eq 0 ]]; then error "Total length is zero" ${LINENO} ${FUNCNAME}; fi
  echo "$thisTotalLength"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Gets final output mp4 filename
#
# Example: stream-32-mins-0616211521.mp4
# Numbers at end of filename are MMDDYYHHMM
#
# @return {String} final output mp4 filename
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getOutputFilename() {
  _currentDate=$(date +'%m%d%y%H%M')
  _minsLong=$(echo "scale=0; $totalLength/60" | bc)
  _outputFilename="$outputBaseFilename-$_minsLong-mins-$_currentDate.mp4"
  echo "$_outputFilename"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get video input argument string for ffmpeg command
#
# -ss means "start at" (it skips to specified timestamp in HH:MM:SS format)
# -t means duration (how long to play the vid from the start point in seconds)
# -i is the input video filepath/filename
# Example output: -ss 00:01:00 -t 300 -i /Users/markmcdermott/Movies/youtube/long/beach-3-hr-skip-first-min.mp4
# See https://ffmpeg.org/ffmpeg.html#toc-Description for ffmpeg input file option details
#
# @return {String} ffmpeg video input argument string
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getVidStr() {
  vidStr="-ss $vidSkipToPoint -t $totalLength -i $vid "
  if ! [[ -n $vidStr ]]; then error "video input argument string is empty" ${LINENO} ${FUNCNAME}; fi
  echo "$vidStr"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get song input argument string for ffmpeg command
#
# -i is the input songs filepath/filename
# -t means duration (how long to play the vid from the start point in seconds)
# Example output: -i /Users/markmcdermott/Desktop/misc/lofi/playlist-1/dancer.mp3 -i /Users/markmcdermott/Desktop/misc/lofi/playlist-1/summer.mp3
# If testing boolean var quickTest is true, this also adds a duration option,
# so only part of the song used. It uses the length set in the length array.
# See https://ffmpeg.org/ffmpeg.html#toc-Description for ffmpeg input file option details
#
# @return {String} ffmpeg songs input argument string
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getSongsStr() {
  inputSongsStr=''
  for (( i=0; i<$numSongs; i++))
  do
    if [ "$quickTest" = true ]
    then
      inputSongsStr+="-t ${lengths[$i]} -i $songDir/${songs[$i]} "
    else
      inputSongsStr+="-i $songDir/${songs[$i]} "
    fi
  done
  if ! [[ -n $inputSongsStr ]]; then error "song input argument string is empty" ${LINENO} ${FUNCNAME}; fi
  echo "$inputSongsStr"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get images input argument string for ffmpeg command
#
# -i is the input images filepath/filename
# Example output: -i dancer.jpg -i sunshine.jpg
# See https://ffmpeg.org/ffmpeg.html#toc-Description for ffmpeg input file option details
#
# @return {String} ffmpeg images input argument string
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getImagesStr() {
  inputImagesStr=''
  for (( i=0; i<$numSongs; i++))
  do
    inputImagesStr+="-i $tempFolder/${images[$i]} "
  done
  if ! [[ -n $inputImagesStr ]]; then error "images input argument string is empty" ${LINENO} ${FUNCNAME}; fi
  echo "$inputImagesStr"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get ffmpeg filter argument string
#
# This 1) adds the song title/artist text overlay to each song,
# 2) uses the song start and end times to specify how long each overlay should show.,
# 3) adds labels to each overlay and uses previous overlay labels to start the next overlay
# Example output: -filter_complex [1:0][2:0]concat=n=2:v=0:a=1[aud],[0:v][3:v]overlay=W*0.036:H*0.59:enable='between(t,0,146.7820)'[temp0],[temp0]drawtext=fontfile=/Library/Fonts/Helvetica-Bold.ttf:fontcolor=white:fontsize=120:x=w*.035:y=h*.95-text_h:line_spacing=25:textfile=temp/tempSongTextFile-1.txt:enable='between(t,0,146.7820)'[temp1],[temp1][4:v]overlay=W*0.036:H*0.59:enable='between(t,146.7820,269.6359)'[temp2],[temp2]drawtext=fontfile=/Library/Fonts/Helvetica-Bold.ttf:fontcolor=white:fontsize=120:x=w*.035:y=h*.95-text_h:line_spacing=25:textfile=temp/tempSongTextFile-2.txt:enable='between(t,146.7820,269.6359)'
#
# @return {String} ffmpeg filter argument string
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getFilterStr() {
  # start of filter string
  filterStr='-filter_complex '

  # audio filter - concat all the songs. create [aud] out label
  for (( i=1; i<=$numSongs; i++))
  do
    filterStr+='['$i':0]'
  done
  filterStr+='concat=n='$numSongs':v=0:a=1[aud],'

  # image & text overlay filters
  tempNum=0                                       # tempNum is a counter for the [tempx] output labels for the overlays
  for (( i=1; i<=$numSongs; i++))                 # loop through all songs
  do
    imageNum=$(echo "scale=0; $numSongs+$i" | bc) # get image num (there are the same number of songs as there are song album art images, so image num is sum of number of songs and this song number)
    iMinus1=$(echo "scale=0; $i-1" | bc)          # go from one-based song number to zero based arrays that store song info
    firstStartPoint=${startPoints[$iMinus1]}      # get song start point (seconds from beginning of vid)
    firstEndPoint=${endPoints[$iMinus1]}          # get song end point (seconds from beginning of vid)
    tempTextFile="$tempFolder/$tempSongTextBaseFilename-$i.txt"

    if [[ $i -eq 1 ]]
    then
      filterStr+="[0:v]"                          # if the first song, use the inital video stream as input
    else
      filterStr+="[temp$tempNum]"                 # if not first song, use the temp output label created in previous iteration
      tempNum=$(echo "scale=0; $tempNum+1" | bc)  # increment the tempNum counter for next temp label
    fi
    filterStr+="[$imageNum:v]overlay=$albumArtCoordinates:enable='between(t,$firstStartPoint,$firstEndPoint)'[temp$tempNum],"  # sets the image art coordinates, the start/end time to show the image and outputs the [tempx] label
    filterStr+="[temp$tempNum]"                   # use the [tempx] label from the image art as input
    tempNum=$(echo "scale=0; $tempNum+1" | bc)    # increment the tempNum counter for next temp label
    filterStr+="drawtext=fontfile=$fontFilepath:fontcolor=$fontColor:fontsize=$fontSize:$textCoordinates:line_spacing=$textLineSpacing:textfile=$tempTextFile:enable='between(t,$firstStartPoint,$firstEndPoint)'"   # place the song title and song artist text and set the start and end times to show the text
    if [[ $i -ne $numSongs ]]
    then
      filterStr+="[temp$tempNum],"                      # if not the last song, then set the out label and use a comma so next filter can start
    fi
  done
  if ! [[ -n $filterStr ]]; then error "filter string is empty" ${LINENO} ${FUNCNAME}; fi
  echo "$filterStr"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get output mp4 filename
#
# name will have the form stream-x-mins-MMDDYYHHMM.mp4
#
# @param   {Decimal} total length of output video mp4 in seconds
# @return  {String} output mp4 filename
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# getOutputFilename() {
#   thisTotalLength=$1
#   echo "$thisTotalLength"
#   date=$(date +'%m%d%y%H%M')
#   mins=$(echo "scale=0; $thisTotalLength/60" | bc)
#   thisOutputFilename="$outputBaseFilename-$mins-mins-$date.mp4"
#   echo "$thisOutputFilename"
# }

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get ffmpeg output argument string
#
# This generates the last part of the ffmpeg command, the output file argument.
# -map [aud] maps the concatenated audio files to the output file
# -preset ultrafast sets the quality to low and the render time to fast (it is actually still quite a high quality)
# -y automatically says yes to any questions ffmpeg asks
# -loglevel quiet makes ffmpeg log almost nothing to the console
# the .mp4 file at the end of the line is the final rendered video file
# example output: -map [aud] -preset ultrafast -y -loglevel quiet output/stream-4-mins-0613211648.mp4
#
# @param   {String} output mp4 path/filename
# @return  {String} ffmpeg output argument string
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getOutputFileStr() {
  if ! [[ -n $1 ]]; then error "output path/filename parameter not passed" ${LINENO} ${FUNCNAME}; fi
  if ! [[ ${#1} -ge 27 ]]; then error "output filename parameter is not at least 30 characters long (x/stream-x-mins-MMDDYYHHMM.mp4)" ${LINENO} ${FUNCNAME}; fi
  outputPathAndFilename=$1
  # outputStr=" -map [aud] -preset $quality -y -loglevel quiet $outputPathAndFilename -stats"
  # outputStr=" -map [aud] -preset $quality -y -loglevel quiet $outputPathAndFilename"
  # outputStr=" -map [aud] -preset $quality -y -loglevel quiet $outputPathAndFilename -progress $tempFolder/ffmpeg-progress.log &"
  outputStr=" -map [aud] -preset $quality -y -loglevel quiet $outputPathAndFilename -progress $tempFolder/ffmpeg-progress.log"

  #outputStr=" -map [aud] -preset $quality -y -loglevel quiet -progress - -nostats $outputFolder/$outputFilename"
  # outputStr=" -map [aud] -preset $quality -y -loglevel quiet $outputFolder/$outputFilename -progress progress.txt"
  # outputStr=" -map [aud] -preset $quality -y -loglevel quiet $outputFolder/$outputFilename"
  # outputStr=" -map [aud] -preset $quality -y -loglevel quiet -vstats -vstats_file ffmpeg_stats.txt $outputFolder/$outputFilename 2>/dev/null & PID=$! &&"
  if ! [[ -n $outputStr ]]; then error "output string is empty" ${LINENO} ${FUNCNAME}; fi
  if ! [[ ${#outputStr} -ge 53 ]]; then error "output filename parameter is not at least 53 characters long (-map [aud] -preset x -y -loglevel quiet x/<28+ chars path/file> -stats)" ${LINENO} ${FUNCNAME}; fi
  echo "$outputStr"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Get total number of frames the output mp4 file will have
#
# This can be run right after ffmpeg starts - the ffmpeg output
# file is generated early and contains the total frame number,
# even before those frames have actually been generated.
#
# @param   {String} output mp4 path/filename
# @return  {Integer} number of total frames of mp4 file
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
getNumFramesTotal() {
  if ! [[ -n $1 ]]; then error "output mp4 path/filename parameter not passed" ${LINENO} ${FUNCNAME[0]}; fi
  if ! [[ ${#1} -ge 7 ]]; then error "output mp4 path/filename parameter is not at least 7 characters long (x/x.mp4)" ${LINENO} ${FUNCNAME}; fi
  outputFilepath=$1
  numFrames=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 $outputFilepath)
  if ! [[ -n $numFrames ]]; then error "numFrames variable is empty" ${LINENO} ${FUNCNAME}; fi
  if ! [[ $numFrames =~ ^[0-9]+$ ]]; then error "numFrames value is not a number" ${LINENO} ${FUNCNAME}; fi
  echo "$numFrames"
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Deletes output files less than one minute
#
# Delets any output files created during prior test runs
# Test output files have stream-0-mins in filename
#
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
deleteTestOutputFiles() {
  find $outputFolder/ -type f -name 'stream-0-mins*' -delete
}

  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
 # Deletes temp files
 #
 # As clean up after video is generated, this function deletes the temp
 # album art and title/song text files that are in a temp folder.
 #
  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
deleteTempFiles() {
  rm -f ./$tempFolder/*
}

# show_progress() #while ffmpeg is running, parse the stats file and read current frame. Divide by sum of all frames
# {
# while kill -0 $PID >/dev/null 2>&1
# do
#     VSTATS=$(awk '{gsub(/frame=/, "")}/./{line=$1-1} END{print line}' ffmpeg_stats.txt | sed "s/frame=\([^0-9]\)//g" | sed "s/\(.*\) fps.*/\1/p")
#     VSTATS=$((VSTATS+0))
#     if [ $VSTATS -gt $FR_CNT ]; then
#         if [ $VSTATS -gt 99 ]; then
#             VSTATS=$((VSTATS+1))
#         fi
#         FR_CNT=$VSTATS
#         echo $((VSTATS*100/FRAMES))
#     fi
# done # | dialog --title "Converting ..." --gauge "\nInput-Datei:\n$NAME\n\nOutput-Datei:\n$OUTN" 15 70 0
# }

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
# Error handling
#
# This needs the trap "exit 1" TERM export TOP_PID=$$ at top of script.
# I don't really know why this works, but it kills the top
# process without the normal annoying kill message output.
#
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ####
error() {
  errStr="Error: $1. line $2. "
  i=1
  for arg in "$@"
  do
    if [ $i -gt 2 ] && [ $i -lt "$#" ]; then
      errStr="$errStr$arg()"
    fi
    if [ $i -gt 2 ] && [ $i -lt $(echo "scale=0; $#-1" | bc) ]; then
      errStr="$errStr, "
    fi
    ((i=i+1))
  done
  echo "$errStr."  >&2
  kill -s TERM $TOP_PID
}

# this lets the function definitions go below where they're called instead of above where they're called
# this just calls main to start. after everything runs, it exits.
main "$@"; exit 0
