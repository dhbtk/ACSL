#!/bin/sh
cd public/tracks
mogrify -path . -resize 256x *_preview.png
mogrify -path . -resize 256x256 -background transparent -gravity center -extent 256x256 *_outline.png
cd ../cars
mogrify -path . -resize 256x256 -background black -gravity center -extent 256x256 -quality 70 *.jpg
