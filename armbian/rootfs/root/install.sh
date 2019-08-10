#!/bin/sh

mnt="/mnt/sda2"
emmc="/mnt/mmcblk1p2"

echo "Start copy openwrt to emmc... "

[ ! -e /dev/mmcblk1p2 ] && echo "Failed! " && exit

[ ! -d $mnt ] && {
    mkdir -p $mnt
    mount -o rw /dev/sda2 $mnt
}

rm -rf $emmc/*
cp -r $mnt/* $emmc/
rm -f $emmc/root/install.sh
sync

echo "Done! "

