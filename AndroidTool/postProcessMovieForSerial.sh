#!/bin/sh

#  postprocessmovie.sh
#  Bugs
#
#  Created by Morten Just Petersen on 4/10/15.
#  Copyright (c) 2015 Morten Just Petersen. All rights reserved.


#adb="/usr/local/bin/adb"

thisdir=$1 # $1 is the bundle resources path directly from the calling script file
serial=$2
width=$3
height=$4
bitrate=$5 #carryover since this file shares arg structure with recordmovie
screenRecFolder=$6
generateGif=$7

adb=$thisdir/adb

deviceName=$("$adb" -s $serial shell getprop ro.product.name)
buildId=$("$adb" -s $serial shell getprop ro.build.id)
ldap=$(whoami)
now=$(date +'%m%d%Y%H%M%S')
finalFileName=$deviceName$buildId$ldap$now
finalFileName="${finalFileName//[$'\t\r\n ']}"

echo "###### $screenRecFolder"
mkdir -p "$screenRecFolder"
cd "$screenRecFolder"


chara=$("$adb" -s $serial shell getprop ro.build.characteristics)
if [[ $chara == *"watch"* ]]

then # -- Watch ---
    echo 'Copying from watch...'
    "$adb" -s $serial pull /sdcard/screencapture.raw
    "$adb" -s $serial shell rm /sdcard/screencapture.raw

    echo '#Converting...'

    $thisdir/ffmpeg -f rawvideo -vcodec rawvideo -s $width"x"$height -pix_fmt rgb24 -r 10 -i screencapture.raw  -an -c:v libx264 -pix_fmt yuv420p $finalFileName.mp4

    #    $thisdir/ffmpeg -f rawvideo -vcodec rawvideo -pix_fmt rgb24 -r 10 -i screencapture.raw  -an -c:v libx264 -pix_fmt yuv420p $finalFileName.mp4

    if [ "$generateGif" = true ] ; then
    echo 'Generating gif...'
    $thisdir/ffmpeg -i $finalFileName.mp4 $finalFileName.gif
    fi

    echo 'Cleaning up...'
    rm screencapture.raw

else # -- Phone ---
    counter=1
    while "$adb" -s $serial shell "[ -f /sdcard/capture_$counter.mp4 ]"; do
      echo 'copying from phone...'
      "$adb" -s $serial pull /sdcard/capture_$counter.mp4
      echo 'cleaning up'
      "$adb" -s $serial shell rm /sdcard/capture_$counter.mp4
      (( counter++ ))
    done

    counter=1
    $thisdir/ffmpeg -i capture_$counter.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts inter_$counter.ts
    counter=2
    files="concat:inter_1.ts"
    while [ -f capture_$counter.mp4 ]; do
      $thisdir/ffmpeg -i capture_$counter.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts inter_$counter.ts
      files="$files|inter_$counter.ts"
      rm capture_$counter.mp4
      (( counter++ ))
    done

    echo "$files"

    $thisdir/ffmpeg -i "$files" -c copy -bsf:a aac_adtstoasc output_$now.mp4

    counter=1
    while [ -f capture_$counter.mp4 ]; do
      rm inter_$counter.ts
      (( counter++ ))
    done



    # if [ "$generateGif" = true ] ; then
    # echo 'Generating gif...'
    # $thisdir/ffmpeg -i $finalFileName.mp4 $finalFileName.gif
    # fi
fi

echo 'Opening file...'
open output_$now.mp4
