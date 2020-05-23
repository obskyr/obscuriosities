#!/usr/bin/env bash

dir=$1
if [ -z "$dir" ]
then
    dir=.
fi

pngs=$(find $dir -type f -name '*.png')
jpegs="$(find $dir -type f -name '*.jpeg') $(find $dir -type f -name '*.jpg')"

if [ ! -z "$pngs" ]
then
    # The order here is meaningful: PNGOUT has better detection for mode
    # conversions that save space, so doing that in advance may let OptiPNG
    # yield better results.
    for png in $pngs
    do
        pngout.exe $png
    done
    optipng $pngs
fi

if [ ! -z "$jpegs" ]
then
    jpegoptim $jpegs
fi
