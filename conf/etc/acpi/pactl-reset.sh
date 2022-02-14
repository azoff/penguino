#!/usr/bin/env zsh

su azoff -c 'pactl set-default-sink alsa_output.pci-0000_00_1f.3.analog-stereo' >> /home/azoff/last-pactl-reset
su azoff -c 'pactl set-default-source alsa_input.usb-Samson_Technologies_Samson_Meteor_Mic-00.analog-stereo' >> /home/azoff/last-pactl-reset
