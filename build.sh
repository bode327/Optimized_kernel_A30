#!/bin/bash

export ANDROID_MAJOR_VERSION=p
export ARCH=arm64

time make bode_exynos7904-a30_defconfig
time make

