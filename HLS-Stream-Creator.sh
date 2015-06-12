#!/bin/bash
#
# A very simple BASH script to take an input video and split it down into Segments 
# before creating an M3U8 Playlist, allowing the file to be served using HLS
#
#

######################################################################################
#
# Copyright (c) 2013, Ben Tasker
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
# 
#   Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
#   Redistributions in binary form must reproduce the above copyright notice, this
#   list of conditions and the following disclaimer in the documentation and/or
#   other materials provided with the distribution.
# 
#   Neither the name of Ben Tasker nor the names of his
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
######################################################################################

# Basic config
OUTPUT_DIRECTORY=${OUTPUT_DIRECTORY:-'./output'}

# Change this if you want to specify a path to use a specific version of FFMPeg
FFMPEG=${FFMPEG:-'ffmpeg'}

# Number of threads which will be used for transcoding. With newer FFMPEGs and x264
# encoders "0" means "optimal". This is normally the number of CPU cores.
NUMTHREADS=${NUMTHREADS:-"0"}

# Video codec for the output video. Will be used as an value for the -vcodec argument
VIDEO_CODEC=${VIDEO_CODEC:-"libx264"}

# Video codec for the output video. Will be used as an value for the -acodec argument
AUDIO_CODEC=${AUDIO_CODEC:-"libfdk_aac"}

# Additional flags for ffmpeg
FFMPEG_FLAGS=${FFMPEG_FLAGS:-""}

# If the input is a live stream (i.e. linear video) this should be 1
LIVE_STREAM=${LIVE_STREAM:-0}

# Video bitrates to use in output (comma seperated list if you want to create an adaptive stream.)
# leave null to use the input bitrate
OP_BITRATES=${OP_BITRATES:-''}

# Lets put our functions here


## Output the script's CLI Usage
#
#
function print_usage(){

cat << EOM
HTTP Live Stream Creator
Version 1

Copyright (C) 2013 B Tasker, D Atanasov
Released under BSD 3 Clause License
See LICENSE


Usage: HLS-Stream-Creator.sh -[l] [-c segmentcount] -i [inputfile] -s [segmentlength(seconds)] -o [outputdir] -b [bitrates]

	-i	Input file
	-s	Segment length (seconds)
	-o	Output directory (default: ./output)
	-l	Input is a live stream
	-c	Number of segments to include in playlist (live streams only) - 0 is no limit
	-b	Output video Bitrates (comma seperated list for adaptive streams)

Deprecated Legacy usage:
	HLS-Stream-Creator.sh inputfile segmentlength(seconds) [outputdir='./output']

EOM

exit

}


function createStream(){

# For VoD and single bitrate streams the variables we need will exist in Global scope.
# for live adaptive streams though, that won't be the case, so we need to take them as arguments
# Some are global though, so we'll leave those as is

playlist_name="$1"
output_name="$2"

$FFMPEG -i "$INPUTFILE" \
    -loglevel error -y \
    -vcodec "$VIDEO_CODEC" \
    -acodec "$AUDIO_CODEC" \
    -threads "$NUMTHREADS" \
    -map 0 \
    -flags \
    -global_header \
    -f segment \
    -segment_list "$playlist_name" \
    -segment_time "$SEGLENGTH" \
    -segment_format mpeg_ts \
    $FFMPEG_ADDITIONAL \
    $FFMPEG_FLAGS \
    $OUTPUT_DIRECTORY/"$output_name" 

}



# This is used internally, if the user wants to specify their own flags they should be
# setting FFMPEG_FLAGS
FFMPEG_ADDITIONAL=''
LIVE_SEGMENT_COUNT=0

# Get the input data

# This exists to maintain b/c
LEGACY_ARGS=1

# If even one argument is supplied, switch off legacy argument style
while getopts "i:o:s:c:b:l" flag
do
	LEGACY_ARGS=0
        case "$flag" in
                i) INPUTFILE="$OPTARG";;
                o) OUTPUT_DIRECTORY="$OPTARG";;
                s) SEGLENGTH="$OPTARG";;
		l) LIVE_STREAM=1;;
		c) LIVE_SEGMENT_COUNT="$OPTARG";;
		b) OP_BITRATES="$OPTARG";;
        esac
done


if [ "$LEGACY_ARGS" == "1" ]
then
  # Old Basic Usage is 
  # cmd.sh inputfile segmentlength 

  INPUTFILE=${INPUTFILE:-$1}
  SEGLENGTH=${SEGLENGTH:-$2}
  if ! [ -z "$3" ]
  then
    OUTPUT_DIRECTORY=$3
  fi
fi


# Check we've got the arguments we need
if [ "$INPUTFILE" == "" ] || [ "$SEGLENGTH" == "" ]
then
  print_usage
fi

# FFMpeg is a pre-requisite, so let check for it
if hash $FFMPEG 2> /dev/null
then
  # FFMpeg exists
  echo "ffmpeg command found.... continuing"
else
  # FFMPeg doesn't exist, uh-oh!
  echo "Error: FFmpeg doesn't appear to exist in your PATH. Please addresss and try again"
  exit 1
fi


# Now we want to make sure out input file actually exists
# This will need tweaking in future if we want to allow a RTMP stream (for example) to be used as input
if ! [ -f "$INPUTFILE" ]
then
  echo "Error: You gave me an incorrect filename. Please re-run specifying something that actually exists!"
  exit 1
fi

# Check output directory exists otherwise create it
if [ ! -w $OUTPUT_DIRECTORY ]
then
  echo "Creating $OUTPUT_DIRECTORY"
  mkdir -p $OUTPUT_DIRECTORY
fi

if [ "$LIVE_STREAM" == "1" ]
then
    FFMPEG_ADDITIONAL+="-segment_list_flags +live"

    if [ "$LIVE_SEGMENT_COUNT" -gt 0 ]
    then
	FFMPEG_ADDITIONAL+=" -segment_list_size $LIVE_SEGMENT_COUNT"
    fi
fi

# Pulls file name from INPUTFILE which may be an absolute or relative path.
INPUTFILENAME=${INPUTFILE##*/}

# Finally, lets build the output filename format
OUT_NAME=$INPUTFILENAME"_%05d.ts"
PLAYLIST_NAME="$OUTPUT_DIRECTORY/$INPUTFILENAME.m3u8"

echo "Generating HLS segments - this may take some time"

# Processing Starts

createStream $PLAYLIST_NAME $OUT_NAME

# Will deal with exit statuses shortly.
#|| exit 1
