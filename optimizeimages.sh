#!/usr/bin/env bash

dir=$1
if [ -z "$dir" ]
then
    dir=.
fi

# pngs=$(find $dir -type f -name '*.png')
jpegs="$(find $dir -type f -name '*.jpeg') $(find $dir -type f -name '*.jpg')"

for png in $pngs
do
    pngout.exe $png
done

if [ ! -z "$jpegs" ]
then
    jpegoptim $jpegs
fi
