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



# Lets put our functions here

function print_usage(){

  echo "Usage: HLS-Stream-Creator.sh inputfile segmentlength"
  exit

}




# The fun begins!


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
  exit
fi


# Now we want to make sure out input file actually exists
if ! [ -f "$INPUTFILE" ]
then
  echo "Error: You gave me an incorrect filename. Please re-run specifying something that actually exists!"
  exit
fi


# OK, so from here, what we want to do is to split the file into appropriately sized chunks,
# re-encoding each to H.264 with MP3 audio, all to go into an MPEG2TS container
#
# The protocol appears to support MP4 as well though, so we may well look at that later.

