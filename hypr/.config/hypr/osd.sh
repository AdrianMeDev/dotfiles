#!/bin/sh
# Feedback for the media keys (media.lua): one mako notification per kind that is replaced in place.
# Usage: osd.sh volume|mic|brightness
kind=${1:?usage: osd.sh volume|mic|brightness}
case "$kind" in
volume | mic)
    if [ "$kind" = volume ]; then
        target=@DEFAULT_AUDIO_SINK@ title=Volume
    else
        target=@DEFAULT_AUDIO_SOURCE@ title=Microphone
    fi
    line=$(wpctl get-volume "$target") || exit 0
    pct=$(printf '%s\n' "$line" | awk '{printf "%d", $2 * 100 + 0.5}')
    case "$line" in *MUTED*) text="muted" ;; *) text="$pct%" ;; esac
    ;;
brightness)
    title=Brightness
    pct=$(brightnessctl -m | cut -d, -f4 | tr -d %) || exit 0
    text="$pct%"
    ;;
*)
    exit 2
    ;;
esac
exec notify-send -t 1500 -h "string:x-canonical-private-synchronous:osd-$kind" -h "int:value:$pct" "$title" "$text"
