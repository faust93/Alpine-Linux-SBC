#!/bin/bash

set -e

# wget https://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/aarch64-linux-gnu/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz
export CLANG_PATH=/opt/toolc/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin
export PATH="$CLANG_PATH:$PATH"
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM64=aarch64-linux-gnu-
export ARCH=arm64

DEVICE="nanopi_np2"

# Image config
IMG_MEDIA="alpine_$DEVICE.img"
IMG_SIZE="500M"

# U-Boot config
# 'radxa' or 'mainline' - use mainline or Radxa U-Boot
UBOOT="mainline"
UBOOT_REPO="https://github.com/friendlyarm/u-boot.git"
UBOOT_BRANCH="sunxi-v2017.x"
UBOOT_CONFIG="nanopi_h5"
UBOOT_DIR="u-boot-$DEVICE"

# Kernel config
KERNEL_REPO="https://github.com/friendlyarm/linux.git"
KERNEL_BRANCH="sunxi-4.16.y"
KERNEL_DIR="kernel-sunxi"
KERNEL_CONFIG="nanopi_np2"
KERNEL_DTB="sun50i-h5-nanopi-neo-plus2"

ROOTFS_TARBALL="alpine-minirootfs-3.18.0-aarch64.tar.gz"
ROOTFS_TARBALL_URL="http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/$ROOTFS_TARBALL"

LFW="https://mirrors.edge.kernel.org/pub/linux/kernel/firmware/linux-firmware-20230210.tar.xz"

OUT="out/$DEVICE"
mountpt='rootfs'

finish() {
    echo -e "\e[31m MAKE IMAGE FAILED.\e[0m"
    exit -1
}
trap finish ERR

make_image_file() {
    local filename="$1"
    rm -f "$filename"*
    truncate -s "$IMG_SIZE" "$filename"
}

parition_media() {
local media="$1"
       echo -e "\e[33m Creating partition table \e[0m"
       sfdisk "${media}" <<__EOF__
unit: sectors
part1 : start=2048, size=131072, Id=83
part2 :                          Id=83
__EOF__
sync
}

format_media() {
    local media="$1"
    local lodev="$(losetup -f)"
    losetup -P "$lodev" "$media" && sync
    mkfs.ext2 -U 614e0000-0000-4b53-8000-1d28000054a9 "${lodev}p1" && sync
    mkfs.f2fs -U 624e0000-0000-4b53-8000-1d28000054a9 "${lodev}p2" && sync
    losetup -d "$lodev" && sync
}

mount_media() {
    local media="$1"
    echo -e "\e[33m Mounting image \e[0m"

    lodev="$(losetup -f)"
    losetup -P "$lodev" "$media" && sync

    mkdir -p "$mountpt"
    mount -n "${lodev}p2" "$mountpt"
    mkdir -p "$mountpt/boot"
    mount -n "${lodev}p1" "$mountpt/boot"
    echo "media $media successfully mounted on $mountpt"
}

umount_media() {
    echo -e "\e[33m Unmounting image \e[0m"
    umount "$mountpt/boot"
    umount "$mountpt"
    losetup -d "$lodev" && sync
    echo "media $media successfully unmounted on $mountpt"
}

script_mkscr_sh() {
cat <<-EOF
#!/bin/sh

if [ ! -x /usr/bin/mkimage ]; then
    echo 'mkimage not found, please install uboot tools: u-boot-tools'
    exit 1
fi

mkimage -A arm64 -O linux -T script -C none -n 'u-boot boot script' -d boot.txt boot.scr
EOF
}

# Unpack rootfs image, install linux kernel, modules, dtb, firmware & u-boot script
setup_rootfs()
{
    local uenv="$1"
    local boottxt="$2"
    local device="$3"

    echo -e "\e[33m Unpack rootfs image, install linux kernel, modules, dtb, firmware & u-boot script \e[0m"

    (set -x; tar -C "$mountpt/" -xf "src/${ROOTFS_TARBALL}")
    (set -x; cp -rf firmware/${device}/* "$mountpt/lib/firmware/" )
    (set -x; make -C "src/$KERNEL_DIR/" INSTALL_MOD_PATH="$(pwd)/$mountpt/" modules_install && cp -f modules/${device}/* "$mountpt/etc/modules-load.d/")

    chmod 775 "$mountpt" "$mountpt/boot"
    mkdir "$mountpt/boot/overlays"
#    cp -f overlays/${device}/*.dtbo "$mountpt/boot/overlays/"

    cp -f "$uenv" "$mountpt/boot/uEnv.txt"
    cp -f "$boottxt" "$mountpt/boot/boot.txt"

    # use bundled mkimage from U-Boot mainline, Radxa's one is broken
    ./tools/mkimage -A arm64 -O linux -T script -C none -n 'u-boot boot script' -d "$mountpt/boot/boot.txt" "$mountpt/boot/boot.scr"

    echo "$(script_mkscr_sh)" > "$mountpt/boot/mkscr.sh"

    install -m 644 "$OUT/$KERNEL_DTB.dtb" "$mountpt/boot"
    ln -sf $(basename "$KERNEL_DTB.dtb") "$mountpt/boot/dtb"

    install -m 755 "$OUT/Image" "$mountpt/boot"

    # blobs
    install -m 755 blobs/brcm_patchram_plus "$mountpt/bin"
    install -m 755 blobs/bt_radio "$mountpt/usr/bin"
    cp -f blobs/bt_radio.service "$mountpt/etc/init.d/bt_radio"
    chmod 755 "$mountpt/etc/init.d/bt_radio"
}

# Stage2 system provisioning
stage2()
{
    cp /usr/bin/qemu-aarch64-static "$mountpt/usr/bin/"
    cp stage2_nanopi_np2.sh "$mountpt/root/"

    mount -t proc none "$mountpt/proc"
    mount -o bind /dev "$mountpt/dev"

    chroot "$mountpt/" /usr/bin/qemu-aarch64-static /bin/sh /root/stage2_nanopi_np2.sh
}

stage2_cleanup()
{
    rm "$mountpt/usr/bin/qemu-aarch64-static"
    rm "$mountpt/root/stage2_nanopi_np2.sh"
    umount "$mountpt/proc"
    umount "$mountpt/dev"
}

# external dependencies
deps()
{
    [ ! -d "src" ] && mkdir src
    [ ! -d "$OUT" ] && mkdir "$OUT"

    echo -e "\e[33m Download dependencies \e[0m"
    if [[ -e "src/$ROOTFS_TARBALL" ]]; then
        echo "Skipping rootfs dl, file already exists"
    else
        wget -O "src/$ROOTFS_TARBALL" "$ROOTFS_TARBALL_URL"
    fi

    if [ ! -d "./src/$UBOOT_DIR" ]; then
        pushd ./src
        git clone "$UBOOT_REPO" -b "$UBOOT_BRANCH" --depth 1 "$UBOOT_DIR"
        popd
    else
        echo "Skipping uboot dl, folder already exists"
    fi

    if [ ! -d "src/$KERNEL_DIR" ]; then
        git clone "$KERNEL_REPO" -b ${KERNEL_BRANCH} --depth 1 "src/$KERNEL_DIR"
    else
        echo "Skipping kernel dl, folder already exists"
    fi

}

build_uboot()
{
    echo "==> Building U-Boot for $UBOOT_CONFIG"
    pushd "./src/${UBOOT_DIR}"
    make -j$(nproc) ${UBOOT_CONFIG}_defconfig all
    cp -f spl/sunxi-spl.bin ../../${OUT}/
    cp -f u-boot.itb ../../${OUT}/
    popd

    echo -e "\e[36m U-boot IMAGE READY! \e[0m"
}

build_kernel()
{
    echo -e "\e[33m Building Linux kernel for $KERNEL_CONFIG \e[0m"
    make -C "src/$KERNEL_DIR" ${KERNEL_CONFIG}_defconfig
    make -j$(nproc) -C "src/$KERNEL_DIR" all
    cp -f "src/$KERNEL_DIR/arch/arm64/boot/dts/allwinner/${KERNEL_DTB}.dtb" ${OUT}/
    cp -f "src/$KERNEL_DIR/arch/arm64/boot/Image" ${OUT}/
    chmod 755 "$OUT/Image"
}

# Main
if [ 0 -ne $(id -u) ]; then
    echo -e "\e[31m Must be run as root \e[0m"
    exit 9
fi

deps
build_uboot
build_kernel
make_image_file "$OUT/$IMG_MEDIA"
parition_media  "$OUT/$IMG_MEDIA"
format_media    "$OUT/$IMG_MEDIA"
mount_media     "$OUT/$IMG_MEDIA"
setup_rootfs    "uEnv-$DEVICE.txt" "boot-$DEVICE.txt" "$DEVICE"

echo -e "\e[33m Start system provisioning \e[0m"
stage2
stage2_cleanup
umount_media

rm -rf "$mountpt"

echo -e "\e[33m Installing u-boot \e[0m"
dd if="${OUT}/sunxi-spl.bin" of="$OUT/$IMG_MEDIA" bs=1024 seek=8 conv=fsync,notrunc
dd if="${OUT}/u-boot.itb" of="$OUT/$IMG_MEDIA" bs=1024 seek=40 conv=fsync,notrunc
