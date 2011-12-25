GPS 2 HTML Report
================

This is a utility written in Haskell, to generate HTML reports from GPS track files.

Included in the report:

* Details of the journey... journey time, distance travelled etc..
* Diagrams charting speed, elevation, accumulated distance etc..
* OpenStreetMap diagram highlighting the GPS track

An example can be seen [here](http://www.macs.hw.ac.uk/~rs46/gps2htmlreport/3/index.html).

The hackage page is [here](http://hackage.haskell.org/package/gps2htmlReport).

Installation
------------
A user first of all needs to install the Haskell Platform, and a few additional system packages - **GraphcsMagick** and **Cairo** . For
exmaple, on an RPM-based machine, as root:

```
># yum install haskell-platform GraphicsMagick cairo gtk2hs-buildtools
```


The **recommended** way to install the gps2HtmlReport program, is to
grab it via hackage:

```
cabal update
cabal install gps2htmlReport
```

Or to install the version in the github repository:

```
git clone git://github.com/robstewart57/Gps2HtmlReport.git
cd Gps2HtmlReport
cabal update
cabal configure
cabal install
```

Prerequisites
-------------
First of all, you need to have your GPS date in a GPX file. There are
many gpx exporters available. I use my Android phone to take GPX
tracks, with a great application,
[OSMTracker](https://code.google.com/p/osmtracker-android/). This
application allows you to export your GPS tracks to GPX. I am sure that there are plenty of good applications for iOS to perform the same function. And I'm aware that GPS devices allow .gpx files to be extracted from GPS logs.

Usage
-----
The program will search for all files ending in ".gpx", and for each one, generate a HTML report.

```
$ cd $location_of_gpx_files
$ ls
1.gpx
$ gps2HtmlReport --help

gps2HtmlReport [OPTIONS]
  A Haskell utility to generate HTML page reports of GPS Tracks and Track
  overlays on OpenStreetMap tiles

Common flags:
  -i --imageonly  Generates only an image of the track overlay on an
                  OpenStreetMap layer
  -a --archive    Produce tar archive for web and image files
     --hashnames  Create reports in hashed directory names
  -h --help       Display help message
  -v --version    Print version information
  -V --Verbose    Loud verbosity
  -q --quiet      Quiet verbosity
```


Problems
-----

If you receive this error when trying to run the program:

```
can't load .so/.DLL for: stdc++ (libstdc++.so: cannot open shared object file: No such file or directory)
```

... then you are experiencing this bug: [#5289](http://hackage.haskell.org/trac/ghc/ticket/5289).

To fix this

* Fedora 32bit:  $# ln -vs $(gcc --print-file-name=libstdc++.so) /usr/lib/
* Fedora 64bit:  $# ln -vs $(gcc --print-file-name=libstdc++.so) /usr/lib64/
* Ubuntu 32bit:  $# ln -vs $(gcc --print-file-name=libstdc++.so) /usr/local/lib/
* Ubuntu 64bit:  $# ln -vs $(gcc --print-file-name=libstdc++.so) /usr/local/lib64/

If you experience other problems, please let me know - and preferrably
sending me the problematic .gpx file.

Credits
-------

Thanks to [Thomas DuBuisson](http://www.haskellers.com/user/TomMD), for implementing the `gps' package and contributing it to Hackage.
