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
./HLS-Stream-Creator.sh inputfile segmentlength(seconds)
```

So to split a video file called *example.avi* into segments of 10 seconds, we'd run

```
./HLS-Stream-Creator.sh example.avi 10
```



Output
-------

As of version 1, the HLS resources will be output to the directory *output*. These will consist of video segments encoded in H.264 with MP3 audio (should be AAC really, but I'd compiled *ffmpeg* without) and an m3u8 file in the format

>\#EXTM3U
>\#EXT-X-MEDIA-SEQUENCE:0
>\#EXT-X-VERSION:3
>\#EXT-X-TARGETDURATION:10
>\#EXTINF:10, no desc
>example_001.ts
>\#EXTINF:10, no desc
>example_002.ts
>\#EXTINF:10, no desc
>example_003.ts
>\#EXTINF:5, no desc
>example_004.ts
>\#EXT-X-ENDLIST





Using a Specific FFMPEG binary
-------------------------------

There may be occasions where you don't want to use the *ffmpeg* that appears in PATH. At the top of the script, the ffmpeg command is defined, so change this to suit your needs

```
FFMPEG='/path/to/different/ffmpeg'
```



License
--------

HLS-Stream-Creator is licensed under the [BSD 3 Clause License](http://opensource.org/licenses/BSD-3-Clause) and is Copyright (C) 2013 [Ben Tasker](http://www.bentasker.co.uk)


