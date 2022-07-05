#!/bin/bash -e

beep

cd /root/

./flash_bios.sh

./flash_openwrt.sh

beep
sleep 1
beep
sleep 1
beep

poweroff -f
