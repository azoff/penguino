#!/usr/bin/env zsh

su azoff -c 'pactl set-default-sink alsa_output.usb-ZOOM_Corporation_ZOOM_P4_Audio_000000000000-00.iec958-stereo.monitor' >> /home/azoff/last-pactl-reset
su azoff -c 'pactl set-default-source alsa_input.usb-ZOOM_Corporation_ZOOM_P4_Audio_000000000000-00.analog-stereo.2' >> /home/azoff/last-pactl-reset
