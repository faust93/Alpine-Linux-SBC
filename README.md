## Alpine Linux image builder

A set of scripts to build Alpine Linux bootable image for the following set of SBCs:

 * NanoPi NEO Air
 * RockPi S
 * RockPi 3A

#### Requirements

 * parted
 * mkfs.ext2, mkfs.f2fs
 * git
 * gcc-arm/aarch64 toolchains
 * u-boot-tools swig libpython-dev
 * qemu qemu-user-static-binfmt qemu-user qemu-user-static (for stage2 script)
 * sudo rights

#### Build

Before building check build scripts, uEnv and stage-2 files for tuning options like user, passwords, timezones and other options.

