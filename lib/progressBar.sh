#!/bin/bash

# Original Author : Teddy Skarin
# Original Code from https://github.com/fearside/ProgressBar/blob/master/progressbar.sh, accessed 6/16/21
# Modified by Mark McDermott 6/16/21
# @param {Integer} percent done (integer from 0 to 100, no % symbol)
# @param {String} ETA (time left) in HH:MM:SS format

floor() {
  floor=$(awk -v var="$1" 'BEGIN{printf "%d", var}')
  echo "$floor"
}

roundP() {
  rounded=$(printf "%.0f\n" $1)
  echo "$rounded"
}

# @param is one line of ffmpeg progress output (this is run on every line with "out_time=")
# @param total length of output video in seconds
getPercentDone() {
  secDecimal=$(echo $1 | awk -F':' '{print $3}')
  sec=$(roundP $secDecimal)
  min=$(echo $1 | awk -F':' '{print $2}')
  minInSec=$(echo "$min*60" | bc -l)
  time=$(echo "$sec+$minInSec" | bc -l)
  percentDecimal=$(echo "$time/$2*100" | bc -l)
  percent=$(roundP $percentDecimal)
  if [[ $percent -eq 0 ]]; then # TODO: this is a hack which throws off the numbers for the first few seconds - could fix this.
    percent=1 # don't divide by zero if percent is still 0. instead just fudge it for those first few seconds and say it's at 1 percent.
  fi
  echo "$percent"
}

# param is start time (seconds from epoch)
getElapsed() {
  elapsed=$(( $(date +%s) - $1 ))
  echo "$elapsed"
}

# @param percent done
# @param seconds elapsed
getEta() {
  totalSec=$(echo "$2/$1*100" | bc -l)
  remainingSec=$(echo "$totalSec-$2" | bc -l)
  remainingSecRounded=$(roundP $remainingSec)
  remainingMinDecimal=$(echo "$remainingSecRounded/60" | bc -l)
  remainingMinFloor="$(floor $remainingMinDecimal)"

  if [[ $remainingMinFloor -gt 59 ]]; then
    remainingHours=$(echo "$remainingMinFloor/60" | bc -l)
    remainingHoursDecimal=$(echo "$remainingSecRounded-$remainingMinFloorInSeconds" | bc -l)
    remainingHoursRounded=$(roundP $remainingHoursDecimal)
  else
    remainingHoursRounded=0
  fi

  if [[ $remainingHoursRounded -lt 10 ]]; then
    hrStr="0$remainingHoursRounded"
  else
    hrStr="$remainingHoursRounded"
  fi

  if [[ $remainingMinFloor -gt 0 ]]; then
    remainingMinFloorInSeconds=$(echo "$remainingMinFloor*60" | bc -l)
    remainingSecRounded=$(echo "$remainingSecRounded-$remainingMinFloorInSeconds" | bc -l)
  fi

  if [[ $remainingMinFloor -lt 10 ]]; then
    minStr="0$remainingMinFloor"
  else
    minStr="$minStr"
  fi

  if [[ $remainingSecRounded -lt 10 ]]; then
    secStr="0$remainingSecRounded"
  else
    secStr="$remainingSecRounded"
  fi

  etaStr="$hrStr:$minStr:$secStr"
  echo "$etaStr"
}

progressBarPrep() {
  cat /dev/null > temp/ffmpeg-progress.log
}

progressBarCleanUp() {
  echo "" # prints a newline so prompt isn't after progress bar on same line
  tput civis -- normal # unhide cursor
  rm -f temp/ffmpeg-progress.log
  rm -f temp/pid
}

printProgressBar() {
  # Process data
    percentDone=$1
    eta=$2

  	let _progress=(${percentDone}*100/100*100)/100
  	let _done=(${_progress}*4)/10
  	let _left=40-$_done
  # Build progressbar string lengths
  	_done=$(printf "%${_done}s")
  	_left=$(printf "%${_left}s")

  # Build progressbar strings and print the ProgressBar line
  # Output example: Progress : [############                ] 45%     00:01:14
  if [[ $percentDone -lt 10 ]]; then  # this keeps the eta from jumping one space to the right when the percent becomes two digits instead of one
    printf "\rProgress : [${_done// /#}${_left// /-}] ${_progress}%%       $eta"
  else
    printf "\rProgress : [${_done// /#}${_left// /-}] ${_progress}%%      $eta"
  fi
}

# @param {Integer} total output video length in seconds
runFfmpegProgressBar() {
  sleep 5
  progressBarPrep

  # progress bar
  start=$(date +%s)
  thisTotalLength=$1

  tput civis -- invisible  # hide cursor
  ( tail -f temp/ffmpeg-progress.log & echo $! >&3 ) 3>temp/pid |
  while IFS= read line;
   do
     if [[ $line == "out_time="* ]];
      then
        percentDone=$(getPercentDone $line $thisTotalLength)
        secondsElapsed=$(getElapsed $start)
        # echo "1: $percentDone $secondsElapsed"
        eta=$(getEta $percentDone $secondsElapsed)
        # echo "2: $percentDone $secondsElapsed"

        #echo "ETA: $eta"

        printProgressBar $percentDone $eta
     fi
     if [[ $line == *"end" ]];
      then kill $(<temp/pid);
     fi;
  done

  progressBarCleanUp
}


# init ffmpeg data
# totalLength=59
# ffmpeg -t $totalLength -i /Users/markmcdermott/Movies/youtube/normal/1-min.mp4  -i /Users/markmcdermott/Desktop/misc/lofi/playlist-1/playhard.mp3 -loglevel quiet -shortest -y -map 0:v:0 -map 1:a:0 test.mp4 -progress ffmpeg-progress.log &
# runFfmpegProgressBar $totalLength
