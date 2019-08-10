#!/bin/bash

red="\033[31m"
green="\033[32m"
white="\033[0m"

out_dir=out
openwrt_dir=openwrt
boot_dir="/media/boot"
rootfs_dir="/media/rootfs"
loop=


if [ -d $out_dir ]; then
    sudo rm -rf $out_dir
fi

sudo mkdir -p $rootfs_dir
mkdir -p $out_dir/openwrt


# 挂载/解压openwrt固件
cd $openwrt_dir
if [ -f *rootfs.tar.gz ]; then
    sudo tar -xzf *rootfs.tar.gz -C ../$out_dir/openwrt
elif [ -f *ext4-factory.img.gz ]; then
    gzip -d *ext4-factory.img.gz
elif [ -f *root.ext4.gz ]; then
    gzip -d *root.ext4.gz
elif [ -f *ext4-factory.img ] || [ -f *root.ext4 ]; then
    [ ]
else
    echo -e "$red \nopenwrt目录下不存在固件或固件类型不受支持! $white" && exit
fi

if [ -f *ext4-factory.img ]; then
    loop=$(sudo losetup -P -f --show *ext4-factory.img)
    sudo mount -o rw ${loop}p2 $rootfs_dir
    [ $? -ne 0 ] && echo -e "$red \n挂载OpenWrt镜像失败! $white" && exit
elif [ -f *root.ext4 ]; then
    sudo mount -o loop *root.ext4 $rootfs_dir
fi


# 拷贝openwrt rootfs
echo -e "$green \n提取OpenWrt ROOTFS... $white"
cd ../$out_dir
if df -h | grep $rootfs_dir > /dev/null 2>&1; then
    sudo cp -r $rootfs_dir/* openwrt/ && sync
    sudo umount $rootfs_dir
    [ $loop ] && sudo losetup -d $loop
fi

sudo cp -r ../armbian/rootfs/* openwrt/ && sync
sudo chown -R root:root openwrt/
# sudo sed -i '/FAILSAFE/a\\n\tulimit -n 51200' openwrt/etc/init.d/boot


# 制作可启动镜像
echo && read -p "请输入ROOTFS分区大小(单位MB)，默认256M: " rootfssize
[ $rootfssize ] || rootfssize=256

armbiansize=$(sudo du -hs ../armbian/rootfs | cut -d "M" -f 1)
openwrtsize=$(sudo du -hs openwrt | cut -d "M" -f 1)
toltalszie=$(($armbiansize+$openwrtsize))

[ $rootfssize -lt $toltalszie ] && echo -e "$red \nROOTFS分区最少需要 $toltalszie M! $white" && exit

echo -e "$green \n生成空镜像(.img)... $white"
fallocate -l $(($rootfssize+64))M "$(date +%Y-%m-%d)-openwrt-n1-auto-generate.img"

echo -e "$green \n分区... $white"
echo -e "n\n\n\n\n+128M\nn\n\n\n\n\nw" | fdisk *.img > /dev/null 2>&1
echo -e "t\n1\ne\nw" | fdisk *.img > /dev/null 2>&1

echo -e "$green \n格式化... $white"
loop=$(sudo losetup -P -f --show *.img)
if [ $loop ]; then
    sudo mkfs.vfat -n "BOOT" ${loop}p1 > /dev/null 2>&1
    sudo mke2fs -F -q -t ext4 -L "ROOTFS" -m 0 ${loop}p2 > /dev/null 2>&1
    sudo e2fsck -n ${loop}p2 > /dev/null 2>&1
else
    echo -e "$red \n格式化失败! $white" && exit
fi


# 拷贝到可启动镜像
echo -e "$green \n拷贝文件到启动镜像... $white"

sudo mkdir -p $boot_dir

sudo mount -o rw ${loop}p1 $boot_dir
sudo mount -o rw ${loop}p2 $rootfs_dir

cd ../
sudo cp -r armbian/boot/* $boot_dir
sudo mv $out_dir/openwrt/* $rootfs_dir
sync


# 取消挂载
if df -h | grep $boot_dir > /dev/null 2>&1 ; then
    sudo umount $boot_dir
fi

if df -h | grep $rootfs_dir > /dev/null 2>&1 ; then
    sudo umount $rootfs_dir
fi

[ $loop ] && sudo losetup -d $loop


# 清理残余
sudo rm -rf $boot_dir
sudo rm -rf $rootfs_dir
sudo rm -rf $out_dir/openwrt


echo -e "$green \n制作成功, 输出文件夹 --> $out_dir $white"

