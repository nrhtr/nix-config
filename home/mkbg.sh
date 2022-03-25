#!/usr/bin/env bash

options=$(getopt -o c: --long colours: -- "$@")
eval set -- "$options"

while true; do
    case "$1" in
        -c|--colours)
            shift
            colour_string=$1
            ;;
        --)
            shift
            break
            ;;
    esac
    shift
done

bilinear() {
    IFS=':' read -r -a colours <<< "$colour_string"
    col1="#${colours[0]}"
    col2="#${colours[1]}"
    col3="#${colours[2]}"
    col4="#${colours[3]}"

    size="1366:768"
    #size=$(swaymsg -t get_outputs | jq '.[0].current_mode | .width, "x", .height' -j)

    convert \( xc:"$col1" xc:"$col2" +append \) \( xc:"$col3" xc:"$col4" +append \) -append -size "$size" xc: +swap -fx 'v.p{i/(w-1),j/(h-1)}' ./wallpaper.png
}

bilinear
