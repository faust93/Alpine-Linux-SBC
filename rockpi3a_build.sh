#!/bin/bash

set -e

# wget https://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/aarch64-linux-gnu/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz
export CLANG_PATH=/opt/toolc/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin

export PATH="$CLANG_PATH:$PATH"
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM64=aarch64-linux-gnu-
export ARCH=arm64

DEVICE="rock3a"

# Image config
IMG_MEDIA="alpine_$DEVICE.img"
IMG_SIZE="500M"

# U-Boot config
# 'radxa' or 'mainline' - use mainline or Radxa U-Boot
UBOOT="radxa"
UBOOT_REPO="https://github.com/radxa/u-boot.git"
UBOOT_BRANCH="stable-4.19-rock3"
UBOOT_CONFIG="rock-3a-rk3568"
UBOOT_DIR="u-boot-$DEVICE"
# UBOOT_REPO="https://github.com/u-boot/u-boot.git"
# UBOOT_BRANCH="v2023.01" // mainline uboot branch

# Kernel config
KERNEL_REPO="https://github.com/friendlyarm/kernel-rockchip.git"
KERNEL_BRANCH="nanopi5-v5.10.y_opt"
KERNEL_DIR="kernel-rockchip"
KERNEL_CONFIG="rockchip"
KERNEL_DTB="rk3568-rock-3a"

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

apply_patches() {
    # pinctrl: rockchip: Add pinctrl route types
    # https://github.com/u-boot/u-boot/commit/32b2ea9818c6157bfc077de487b78e78536ab4a8
    git -C u-boot cherry-pick 32b2ea9818c6157bfc077de487b78e78536ab4a8

    # mmc: rockchip_dw_mmc: fix DDR52 8-bit mode handling
    # https://github.com/u-boot/u-boot/commit/ea0f7662531fd360abf300691c85ceff5a0d0397
    git -C u-boot cherry-pick ea0f7662531fd360abf300691c85ceff5a0d0397

    # rockchip: sdram: add basic support for sdram reg info version 3
    # https://github.com/u-boot/u-boot/commit/bde73b14f0f46760f1a0ec84a9474ed93a22e496
    git -C u-boot cherry-pick bde73b14f0f46760f1a0ec84a9474ed93a22e496

    # rockchip: sdram: add dram bank with usable memory beyond 4GB
    # https://github.com/u-boot/u-boot/commit/2ec15cabe973efd9a4f5324b48f566a03c8663d5
    # git -C u-boot cherry-pick 2ec15cabe973efd9a4f5324b48f566a03c8663d5
    git -C u-boot format-patch -1 2ec15cabe973efd9a4f5324b48f566a03c8663d5
    sed -i 's/CFG_SYS_SDRAM_BASE/CONFIG_SYS_SDRAM_BASE/g' u-boot/0001-rockchip-sdram-add-dram-bank-with-usable-memory-beyo.patch
    git -C u-boot am 0001-rockchip-sdram-add-dram-bank-with-usable-memory-beyo.patch
    rm u-boot/0001-rockchip-sdram-add-dram-bank-with-usable-memory-beyo.patch

    # binman: Add support for a rockchip-tpl entry
    # https://github.com/u-boot/u-boot/commit/05b978be5f5c5494044bd749f9b6b38f2bb5e0cc
    # rockchip: Use an external TPL binary on RK3568
    # https://github.com/u-boot/u-boot/commit/4773e9d5ed4c12e02759f1d732bb66006139037a
    # Revert "board: rockchip: Fix binman_init failure on EVB-RK3568"
    # https://github.com/u-boot/u-boot/commit/d1bdffa8a2409727a270c8edaa5d82fdc4eee1a3

    # rockchip: mkimage: Add rv1126 support
    # https://github.com/u-boot/u-boot/commit/6d70d826f553a321193ad917cd651fc5b12739ac
    git -C u-boot cherry-pick 6d70d826f553a321193ad917cd651fc5b12739ac

    # rockchip: mkimage: Update init size limit for RK3568
    # https://github.com/u-boot/u-boot/commit/5fc5a840d4cf189616aba3a4a7bf10c4ac8edc83
    git -C u-boot cherry-pick 5fc5a840d4cf189616aba3a4a7bf10c4ac8edc83

    # binman: Mark mkimage entry missing when its subnodes is missing
    # https://github.com/u-boot/u-boot/commit/40389c2a462256da7f2348bed791c8ba2ae6eec6

    # arm64: dts: rockchip: rk3568: Add Radxa ROCK 3 Model A board support
    # https://github.com/u-boot/u-boot/commit/b44c54f600abf7959977579f6bfc2670835a52b0
    git -C u-boot cherry-pick b44c54f600abf7959977579f6bfc2670835a52b0

    # rockchip: rk3568: Move DM_RESET in arch kconfig
    # https://github.com/u-boot/u-boot/commit/5f5b1cf3fff1c12d12207e1c415aff9bdcb432cc
    git -C u-boot cherry-pick 5f5b1cf3fff1c12d12207e1c415aff9bdcb432cc

    # dt-bindings: rockchip: Sync rockchip, vop2.h from Linux
    # https://github.com/u-boot/u-boot/commit/1bb92d7cb310dec146abed88b446e983b16150b5
    git -C u-boot cherry-pick 1bb92d7cb310dec146abed88b446e983b16150b5

    # phy: rockchip: inno-usb2: Add support #address_cells = 2
    # https://github.com/u-boot/u-boot/commit/d538efb9adcfa28e238c26146f58e040b0ffdc5b

    # phy: rockchip-inno-usb2: Add USB2 PHY for rk3568
    # https://github.com/u-boot/u-boot/commit/3da15f0b49a22743b6ed5756e4082287a384bc83
    git -C u-boot cherry-pick 3da15f0b49a22743b6ed5756e4082287a384bc83

    # drivers: phy: add naneng combphy for rk3568
    # https://github.com/u-boot/u-boot/commit/82220526ac9887c39d2d5caa567a20378b3122b7
    git -C u-boot cherry-pick 82220526ac9887c39d2d5caa567a20378b3122b7

    # arm64: dts: rk356x-u-boot: Drop combphy1 assigned-clocks/rates
    # https://github.com/u-boot/u-boot/commit/3abfd33e5715ad31c4c358704a2506c9d52a6189
    git -C u-boot cherry-pick 3abfd33e5715ad31c4c358704a2506c9d52a6189

    # rockchip: rk3568: add rk3568 pinctrl driver
    # https://github.com/u-boot/u-boot/commit/1977d746aa54ae197a9d5f24414680d3ca321fb1
    git -C u-boot cherry-pick 1977d746aa54ae197a9d5f24414680d3ca321fb1

    # rockchip: rk3568: Select DM_REGULATOR_FIXED
    # https://github.com/u-boot/u-boot/commit/2c9919857475807f5e09707e0e79a36a2a60215e
    git -C u-boot cherry-pick 2c9919857475807f5e09707e0e79a36a2a60215e

    # gpio: gpio-rockchip: parse gpio-ranges for bank id
    # https://github.com/u-boot/u-boot/commit/904b8700f81cbc6a49c4f693744a4d2c6c393d6d
    git -C u-boot cherry-pick 904b8700f81cbc6a49c4f693744a4d2c6c393d6d

    # arm64: dts: rockchip: Sync rk356x from Linux main
    # https://github.com/u-boot/u-boot/commit/e2df30c6c64919e11ba0ba33c813d29d949aa7c1
    git -C u-boot cherry-pick e2df30c6c64919e11ba0ba33c813d29d949aa7c1

    # rockchip: rk3568: add boot device detection
    # https://github.com/u-boot/u-boot/commit/0d61f8e5f1c0035c3ee105d940b5b8d90bcec5b0
    git -C u-boot cherry-pick 0d61f8e5f1c0035c3ee105d940b5b8d90bcec5b0

    # rockchip: rk3568: enable automatic power savings
    # https://github.com/u-boot/u-boot/commit/95ef2aaedc7adeb2dcb922c6525d5b3df1b198e5
    git -C u-boot cherry-pick 95ef2aaedc7adeb2dcb922c6525d5b3df1b198e5

    # arm64: dts: rockchip: add gpio-ranges property to gpio nodes
    # https://github.com/u-boot/u-boot/commit/e92754e20cca37dcd62e195499ade25186d5f5e5
    git -C u-boot cherry-pick e92754e20cca37dcd62e195499ade25186d5f5e5

    for patch in ../patches/uboot_mainline/*.patch; do
        git -C u-boot am "../$patch"
    done
}

make_image_file() {
    local filename="$1"
    rm -f "$filename"*
    truncate -s "$IMG_SIZE" "$filename"
}

parition_media() {
local media="$1"
       echo -e "\e[33m Creating partition table \e[0m"
       sfdisk "${media}" <<__EOF__
label: gpt
unit: sectors
first-lba: 2048
part1 : start=32768, size=131072, uuid=614e0000-0000-4b53-8000-1d28000054a9, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=boot, bootable
part2 :                           uuid=624e0000-0000-4b53-8000-1d28000054a9, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=rootfs
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
    cp -f overlays/${device}/*.dtbo "$mountpt/boot/overlays/"

    cp -f "$uenv" "$mountpt/boot/uEnv.txt"
    cp -f "$boottxt" "$mountpt/boot/boot.txt"

    # use bundled mkimage from U-Boot mainline, Radxa's one is broken
    ./tools/mkimage -A arm64 -O linux -T script -C none -n 'u-boot boot script' -d "$mountpt/boot/boot.txt" "$mountpt/boot/boot.scr"

    echo "$(script_mkscr_sh)" > "$mountpt/boot/mkscr.sh"

    install -m 644 "$OUT/$KERNEL_DTB.dtb" "$mountpt/boot"
    ln -sf $(basename "$KERNEL_DTB.dtb") "$mountpt/boot/dtb"

    install -m 755 "$OUT/Image" "$mountpt/boot"
}

# Stage2 system provisioning
stage2()
{
    cp /usr/bin/qemu-aarch64-static "$mountpt/usr/bin/"
    cp stage2.sh "$mountpt/root/"

    mount -t proc none "$mountpt/proc"
    mount -o bind /dev "$mountpt/dev"

    chroot "$mountpt/" /usr/bin/qemu-aarch64-static /bin/sh /root/stage2.sh
}

stage2_cleanup()
{
    rm "$mountpt/usr/bin/qemu-aarch64-static"
    rm "$mountpt/root/stage2.sh"
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
        if [ "$UBOOT" == "mainline" ]; then
            git clone "$UBOOT_REPO" "$UBOOT_DIR"
            git -C "$UBOOT_DIR" fetch --tags

            if ! git -C "$UBOOT_DIR" branch | grep -q $UBOOT_BRANCH; then
                git -C "$UBOOT_DIR" checkout -b $UBOOT_BRANCH $UBOOT_BRANCH
                apply_patches
            elif [ "_$UBOOT_BRANCH" != "_$(git -C u-boot branch | sed -n -e 's/^\* \(.*\)/\1/p')" ]; then
                git -C "$UBOOT_DIR" checkout $UBOOT_BRANCH
            fi
        else
            git clone "$UBOOT_REPO" -b "$UBOOT_BRANCH" --depth 1 "$UBOOT_DIR"

            echo "Applying U-Boot radxa patches.."
            for patch in ../patches/uboot_radxa/*.patch; do
                git -C "$UBOOT_DIR" am "../$patch"
            done
        fi
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
    pushd "./src/$UBOOT_DIR"

    make ${UBOOT_CONFIG}_defconfig
    make -j$(nproc) BL31=../../rkbin/rk3568_bl31_v1.36.elf spl/u-boot-spl.bin u-boot.dtb u-boot.itb
    ./tools/mkimage -n rk3568 -T rksd -d ../../rkbin/rk3568_ddr_1560MHz_v1.15.bin:spl/u-boot-spl.bin idbloader.img

    cp -f u-boot.itb ../../${OUT}/
    cp -f idbloader.img ../../${OUT}/
    popd
    echo -e "\e[36m U-boot IMAGE READY! \e[0m"
}

build_kernel()
{
    echo -e "\e[33m Building Linux kernel for $KERNEL_CONFIG \e[0m"
    make -C "src/$KERNEL_DIR" ${KERNEL_CONFIG}_defconfig
    make -j$(nproc) -C "src/$KERNEL_DIR" ${KERNEL_DTB}.img
    cp -f "src/$KERNEL_DIR/arch/arm64/boot/dts/rockchip/${KERNEL_DTB}.dtb" ${OUT}/
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
dd bs=4K seek=8 if="$OUT/idbloader.img" of="$OUT/$IMG_MEDIA" conv=notrunc
dd bs=4K seek=2048 if="$OUT/u-boot.itb" of="$OUT/$IMG_MEDIA" conv=notrunc,fsync
