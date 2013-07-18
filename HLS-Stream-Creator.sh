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
#   Neither the name of the {organization} nor the names of its
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

# Change this if you want to specify a path to use a specific version of FFMPeg
FFMPEG='ffmpeg'

# Lets put our functions here


## Output the script's CLI Usage
#
#
function print_usage(){

cat << EOM
HTTP Live Stream Creator
Version 1

Copyright (C) 2013 B Tasker
Released under BSD 3 Clause License
See LICENSE


Usage: HLS-Stream-Creator.sh inputfile segmentlength(seconds)

EOM

exit

}


## Create the Initial M3U8 file including the requisite headers
#
# Usage: create_m3u8 streamname segmentlength
#
function create_m3u8(){

# We'll add some more headers in a later version, basic support is all we need for now
# The draft says we need CRLF so we'll use SED to ensure that happens
cat << EOM | sed 's/$/\r/g' > output/$1.m3u8
#EXTM3U
#EXT-X-TARGETDURATION:$2
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-VERSION:3
EOM
}


## Append a movie segment to the M3U8
#
# Usage: append_segment streamname SegmentLength(Seconds) SegmentFilename
#
function append_segment(){

cat << EOM | sed 's/$/\r/g' >> output/$1.m3u8
#EXTINF:$2
$3
EOM
}


## Close the M3U8 file
#
# Found that ffplay skips the first few segments if this isn't included.
#
# Usage: close_m3u8 streamname
#
function close_m3u8(){
cat << EOM | sed 's/$/\r/g' >> output/$1.m3u8
#EXT-X-ENDLIST
EOM
}


# The fun begins! Think of this as function main


# Get the input data

# Basic Usage is going to be
# cmd.sh inputfile segmentlength 

INPUTFILE=$1
SEGLENGTH=$2


# Check we've got the arguments we need
if [ "$INPUTFILE" == "" ] || [ "$SEGLENGTH" == "" ]
then
  print_usage
fi



# FFMpeg is a pre-requisite, so let check for it
if hash ffmpeg 2> /dev/null
then
  # FFMpeg exists
  echo "ffmpeg command found.... continuing"
else
  # FFMPeg doesn't exist, uh-oh!
  echo "Error: FFmpeg doesn't appear to exist in your PATH. Please addresss and try again"
  exit 1
fi


# Now we want to make sure out input file actually exists
if ! [ -f "$INPUTFILE" ]
then
  echo "Error: You gave me an incorrect filename. Please re-run specifying something that actually exists!"
  exit 1
fi



# OK, so from here, what we want to do is to split the file into appropriately sized chunks,
# re-encoding each to H.264 with MP3 audio, all to go into an MPEG2TS container
#
# The protocol appears to support MP4 as well though, so we may well look at that later.
#
# Essentially we want to create the chunks by running
#
# ffmpeg -i "$INPUTFILE" -vcodec libx264 -acodec mp3 -ss "START_POINT" -t "$SEGLENGTH" -f mpegts output/"$INPUTFILE"_"$N".ts

# First we need the duration of the video
DURATION=$($FFMPEG -i "$INPUTFILE" 2>&1 | grep Duration | cut -f 4 -d ' ')

# Now we need to break out the duration into a time we can use
DUR_H=$(echo "$DURATION" | cut -d ':' -f 1)
DUR_M=$(echo "$DURATION" | cut -d ':' -f 2)
DUR_X=$(echo "$DURATION" | cut -d ':' -f 3 | cut -d '.' -f 1)

# Calculate the duration in seconds
let "DURATION_S = ( DUR_H * 60 + DUR_M ) * 60 + DUR_X"


# Check we've not got empty media
if [ "$DURATION_S" == "0" ]
then
  echo "You've given me an empty media file!"
  exit 1
fi


# Now we've got our Duration, we need to work out how many segments to create
N='1'
START_POS='0'
let 'N_FILES = DURATION_S / SEGLENGTH + 1'

# For now, INPUTFILENAME is going to == INPUTFILE
# Later, we'll change so that INPUTFILE could be an absolute path, whilst INPUTFILENAME will just be the filename
INPUTFILENAME=$INPUTFILE


# Create the M3U8 file
create_m3u8 "$INPUTFILENAME" "$SEGLENGTH"

# Finally, lets build the output filename format
OUT_NAME=$INPUTFILENAME"_%03d.ts"



# Processing Starts

while [ "$START_POS" -lt "$DURATION_S" ]
do

  OUTPUT=$( printf "$OUT_NAME" "$N" )
  echo "Creating $OUTPUT ($N/$N_FILES)..."
  $FFMPEG -i "$INPUTFILE" -loglevel quiet -vcodec libx264 -acodec mp3 -ss "$START_POS" -t "$SEGLENGTH" -f mpegts output/"$OUTPUT"

  let "N = N + 1"
  let "START_POS = START_POS + SEGLENGTH"

  # If we're on the last segment, the duration may be less than the seglenth, so we need to reflect this in the m3u8
  if ! [ "$START_POS" -lt "$DURATION_S" ]
  then
    SEG_DURATION=$($FFMPEG -i output/"$OUTPUT" 2>&1 | grep Duration | cut -f 4 -d ' ')
    # Now we need to break out the duration into a time we can use
    DUR_H=$(echo "$SEG_DURATION" | cut -d ':' -f 1)
    DUR_M=$(echo "$SEG_DURATION" | cut -d ':' -f 2)
    DUR_X=$(echo "$SEG_DURATION" | cut -d ':' -f 3 | cut -d '.' -f 1)

    # Calculate the duration in seconds
    let "SEGLENGTH = ( DUR_H * 60 + DUR_M ) * 60 + DUR_X"
  fi

  # Append the file reference to the M3U8
  append_segment "$INPUTFILENAME" "$SEGLENGTH" "$OUTPUT"

done

# Add the close tag (ffplay gives some weird behaviour without this!)
close_m3u8 "$INPUTFILENAME"