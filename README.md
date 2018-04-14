HLS-Stream-Creator
==================

Introduction
-------------

HLS-Stream-Creator is a simple BASH Script designed to take a media file, segment it and create an M3U8 playlist for serving using HLS.
There are numerous tools out there which are far better suited to the task, and offer many more options. This project only exists because I was asked to look
into HTTP Live Streaming in depth, so after reading the [IETF Draft](http://tools.ietf.org/html/draft-pantos-http-live-streaming-11 "HLS on IETF") I figured I'd start with the basics by creating a script to encode arbitrary video into a VOD style HLS feed.



Usage
------

Usage is incredibly simple

```
./HLS-Stream-Creator.sh -[lf] [-c segmentcount] -i [inputfile] -s [segmentlength(seconds)] -o [outputdir] -b [bitrates]


Deprecated Legacy usage:
	HLS-Stream-Creator.sh inputfile segmentlength(seconds) [outputdir='./output']

```

So to split a video file called *example.avi* into segments of 10 seconds, we'd run

```
./HLS-Stream-Creator.sh -i example.avi -s 10
```

**Arguments**

```
    Mandatory Arguments:

	-i [file]	Input file
	-s [s]		Segment length (seconds)

    Optional Arguments:

	-o [directory]	Output directory (default: ./output)
	-c [count]	Number of segments to include in playlist (live streams only) - 0 is no limit
	-e      	Encrypt the HLS segments (a key will be generated automatically)
	-b [bitrates]	Output video Bitrates in kb/s (comma seperated list for adaptive streams)
	-p [name]	Playlist filename prefix
	-t [name]	Segment filename prefix
	-l		Input is a live stream
	-f		Foreground encoding only (adaptive non-live streams only)
	-S		Name of a subdirectory to put segments into
	-2		Use two-pass encoding
	-q [quality]	Change encoding to CFR with [quality]
	-C		Use constant bitrate as opposed to variable bitrate
```


Adaptive Streams
------------------

As of [HLS-6](http://projects.bentasker.co.uk/jira_projects/browse/HLS-6.html) the script can now generate adaptive streams with a top-level variant playlist for both VoD and Linear input streams.

In order to create seperate bitrate streams, pass a comma seperated list in with the *-b* option

```
./HLS-Stream-Creator.sh -i example.avi -s 10 -b 28,64,128,256
```

By default, transcoding for each bitrate will be forked into the background - if you wish to process the bitrates sequentially, pass the *-f* option

```
./HLS-Stream-Creator.sh -i example.avi -s 10 -b 28,64,128,256 -f
```

In either case, in accordance with the HLS spec, the audio bitrate will remain unchanged.

#### Multiple Resolutions

As of [HLS-27](https://projects.bentasker.co.uk/jira_projects/browse/HLS-27.html) it is possible to (optionally) specify a resolution as well as the desired bitrate by appending it to the bitrate it applies to:

```
./HLS-Stream-Creator.sh -i example.avi -s 10 -b 128-600x400,256-1280x720,2000
```

In the example above, the first two bitrates will use their specified resolutions, whilst the last will use whatever resolution the source video uses.


The format to use is
```
[bitrate]-[width]x[height]
```

Note: There are currently no checks to ensure the specified resolution isn't larger than the source media, so you'll need to check this yourself (for the time being).

You should [consider the potential ramifications of player behaviour](https://projects.bentasker.co.uk/jira_projects/browse/HLS-27.html#comment2186312) before using this functionality.



Encrypted Streams
-------------------

HLS-Stream-Creator can also create encrypted HLS streams, it's enabled by passing *-e*

```
./HLS-Stream-Creator.sh -i example.avi -e -s 10 -b 28,64,128,256

```

The script will generate a 128 bit key and save it to a *.key* file in the same directory as the segments. Each segment will be AES-128 encrypted using an IV which corresponds to it's segment number (the [default behaviour](https://developer.apple.com/library/content/technotes/tn2288/_index.html#//apple_ref/doc/uid/DTS40012238-CH1-ENCRYPT) for HLS).

The manifests will then be updated to include the necessary `EXT-X-KEY` tag:

```
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-ALLOW-CACHE:YES
#EXT-X-KEY:METHOD=AES-128,URI=big_buck_bunny_720p_stereo.avi.key
#EXT-X-TARGETDURATION:17
#EXTINF:10.500000,
big_buck_bunny_720p_stereo.avi_1372_00000.ts
```



Output
-------

As of version 1, the HLS resources will be output to the directory *output* (unless a different directory has been specified with *-o*). These will consist of video segments encoded in H.264 with AAC audio and an m3u8 file in the format

>\#EXTM3U  
>\#EXT-X-MEDIA-SEQUENCE:0  
>\#EXT-X-VERSION:3  
>\#EXT-X-TARGETDURATION:10  
>\#EXTINF:10, no desc  
>example_00001.ts  
>\#EXTINF:10, no desc  
>example_00002.ts  
>\#EXTINF:10, no desc  
>example_00003.ts  
>\#EXTINF:5, no desc  
>example_00004.ts  
>\#EXT-X-ENDLIST



Using a Specific FFMPEG binary
-------------------------------

There may be occasions where you don't want to use the *ffmpeg* that appears in PATH. At the top of the script, the ffmpeg command is defined, so change this to suit your needs

```
FFMPEG='/path/to/different/ffmpeg'
```


H265 details
------------

Check has been added for libx265 to enforce bitrate limits for H265 since it uses additional parameters.



Audio Codec Availability
--------------------------

Because *libfdk_aac* is a non-free codec, and is not available in all builds, commit 0796feb switched the default audio codec to *aac*.

However, in older versions of ffmpeg, aac was marked as experimental - this includes the packages currently in the repos for Ubuntu Xenial. As a result, when running the script, you may see the following error

```
The encoder 'aac' is experimental but experimental codecs are not enabled, add '-strict -2' if you want to use it.
```

There are two ways to work around this. If you have the libfdk_aac codec installed, you can specify that it should be used instead
```
export AUDIO_CODEC="libfdk_aac"
```

Alternatively, you can update the ffmpeg flags to enable experimental codecs
```
export FFMPEG_FLAGS='-strict -2'
```

And the re-run HLS-Stream-Creator.

[HLS-23](http://projects.bentasker.co.uk/jira_projects/browse/HLS-23.html) will, in future, update the script to check for this automatically.




Additional Environment Variables
-------------------------------

There are few environment variables which can control the ffmpeg behaviour.

* `VIDEO_CODEC` - The encoder which will be used by ffmpeg for video streams. Examples: _libx264_, _nvenc_
* `AUDIO_CODEC` - Encoder for the audio streams. Examples: _aac_, _libfdk_acc_, _mp3_, _libfaac_
* `NUMTHREADS` - A number which will be passed to the `-threads` argument of ffmpeg. Newer ffmpegs with modern libx264 encoders will use the optimal number of threads by default.
* `FFMPEG_FLAGS` - Additional flags for ffmpeg. They will be passed without any modification.

Example usage:

```
export VIDEO_CODEC="nvenc"
export FFMPEG_FLAGS="-pix_fmt yuv420p -profile:v"
./HLS-Stream-Creator.sh example.avi 10
```


OS X Users
------------

Segment encryption won't work out of the box on OS X as it relies on arguments which the BSD `grep` and `sed` commands don't support. In order to use encryption on OS X you must first install their GNU counterparts

```
brew install gnu-sed --with-default-names
brew install grep --with-default-names
```


Automation
-----------

HLS-Stream-Creator was originally created as a short bit of research and has since grown significantly. The consequence of this, is that it was primarily focused on being run manually.

Although still not a perfect solution to automation, an example of [automating HLS-Stream-Creator can be found here](https://snippets.bentasker.co.uk/page-1804131128-Automating-HLS-Stream-Creator-Python.html). Better automation support will hopefully be added sometime in the future (pull requests very welcome).



License
--------

HLS-Stream-Creator is licensed under the [BSD 3 Clause License](http://opensource.org/licenses/BSD-3-Clause) and is Copyright (C) 2013 [Ben Tasker](http://www.bentasker.co.uk)


Issue Tracking
----------------

Although the Github issue tracker can be used, the bulk of project management (such as it is) happens in JIRA. See [projects.bentasker.co.uk](http://projects.bentasker.co.uk/jira_projects/browse/HLS.html) for a HTML mirror of the tracking.
