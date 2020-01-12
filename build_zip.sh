#!/bin/bash
##
#  Copyright (C) 2015, Samsung Electronics, Co., Ltd.
#  Written by System S/W Group, S/W Platform R&D Team,
#  Mobile Communication Division.
#
#  Edited by Bode327
##

set -e -o pipefail

DATE=$(date +'%Y%m%d-%H%M')
NAME=Optimized_Kernel_OC

export ANDROID_MAJOR_VERSION=p
export ARCH=arm64
export LOCALVERSION=-${VERSION}-${NAME}

KERNEL_PATH=$(pwd)
KERNEL_ZIP=${KERNEL_PATH}/zip_kernel
KERNEL_ZIP_NAME=${NAME}_${VERSION}.zip
KERNEL_IMAGE=${KERNEL_ZIP}/Image
DT_IMG=${KERNEL_ZIP}/dtb*.img
OUTPUT_PATH=${KERNEL_PATH}/output

export CROSS_COMPILE=/home/bode/Downloads/AOSP-GCC-4.9-master/bin/aarch64-linux-android-
#export CROSS_COMPILE=/home/bode/Downloads/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-gnu-7.5.0-9.0/bin/aarch64-linux-gnu-

JOBS=`grep processor /proc/cpuinfo | wc -l`

# Colors
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

function build() {
	clear;

	BUILD_START=$(date +"%s");
	echo -e "$cyan"
	echo "***********************************************";
	echo "              Compiling Optimized kernel          	     ";
	echo -e "***********************************************$nocol";
	echo -e "$red";

	if [ ! -e ${OUTPUT_PATH} ]; then
		mkdir ${OUTPUT_PATH};
	fi;

	echo -e "Initializing defconfig...$nocol";
	time make O=output ${DEFCONFIG}
	echo -e "$red";
	echo -e "Building kernel...$nocol";
	time make O=output -j${JOBS}
	#time make O=output DTC_EXT=dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y
	#python $(pwd)/libufdt-master-utils/src/mkdtboimg.py create ${OUTPUT_PATH}/arch/arm64/boot/dtbo.img ${OUTPUT_PATH}/arch/arm64/boot/dts/exynos/*.dtb*
	time make O=output -j${JOBS} dtbs;
	find ${KERNEL_PATH} -name "Image" -exec mv -f {} ${KERNEL_ZIP} \;
	find ${KERNEL_PATH} -name "dtb*.img" -exec mv -f {} ${KERNEL_ZIP} \;

	BUILD_END=$(date +"%s");
	DIFF=$(($BUILD_END - $BUILD_START));
	echo -e "$yellow";
	echo -e "Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol";
}

function make_zip() {
	echo -e "$red";
	echo -e "Making flashable zip...$nocol";

	cd ${KERNEL_ZIP};
	make -j${JOBS};
}

function make_savedefconfig() {
	echo -e "$red";
	echo -e "Saving new defconfig...$nocol";

	make O=output -j${JOBS} ${DEFCONFIG};
	make O=output -j${JOBS} savedefconfig;
	mv -f ${OUTPUT_PATH}/defconfig ${KERNEL_PATH}/arch/$ARCH/configs/$DEFCONFIG;

	echo -e "$yellow";
	echo -e "Done! $nocol";
}

function rm_if_exist() {
	if [ -e $1 ]; then
		rm -rf $1;
	fi;
}

function clean() {
	echo -e "$red";
	echo -e "Cleaning build environment...$nocol";
	make -j${JOBS} mrproper;

	rm_if_exist ${OUTPUT_PATH};
	rm_if_exist ${DT_IMG};

	cd ${KERNEL_ZIP};
	make -j${JOBS} clean;
	rm -rf ${DT_IMG};
	rm -rf ${KERNEL_IMAGE};

	echo -e "$yellow";
	echo -e "Done!$nocol";
}

function menu() {
	echo;
	echo -e "***********************************************************************";
	echo "     Optimized_Kernel for ${DEVICE_NAME}";
	echo -e "***********************************************************************";
	echo "Choices:";
	echo "1. Cleanup source";
	echo "2. Build kernel";
	echo "3. Build kernel then make flashable ZIP";
	echo "4. Make flashable ZIP package";
	echo "5. Save new defconfig";
	echo "Leave empty to exit this script (it'll show invalid choice)";
}

function select_device() {
	echo "Select which device you want to build for";
	echo "1. Samsung Galaxy A30 (Exynos) (SM-A305X)";
	echo "2. Samsung Galaxy A40 (Exynos) (SM-A405X)";
	echo "3. Samsung Galaxy A20 (Exynos) (SM-A205X)";
	read -n 1 -p "Choice: " -s device;	
	case ${device} in
		1) export DEFCONFIG=bode_exynos7904-a30_defconfig
		   export DEVICE="a30"
		   export DEVICE_NAME="Samsung Galaxy A30 (Exynos) (SM-A305X)"
		   menu;;
		2) export DEFCONFIG=bode_exynos7904-a40_defconfig
		   export DEVICE="A40"
		   export DEVICE_NAME="Samsung Galaxy A40 (Exynos) (SM-A405X)"
		   menu;;
		3) export DEFCONFIG=bode_exynos7884A-a20_defconfig
		   export DEVICE="A20"
		   export DEVICE_NAME="Samsung Galaxy A20 (Exynos) (SM-A205X)"
		   menu;;
		*) echo
		   echo "Invalid choice entered. Exiting..."
		   sleep 2;
		   exit 1;;
	esac
}

function main() {
	clear;
	if [ "${USE_CCACHE}" == "1" ]; then
		CCACHE_PATH=/usr/local/bin/ccache;
		export CROSS_COMPILE="${CCACHE_PATH} ${CROSS_COMPILE}";
		export JOBS=8;
		echo -e "$red";
		echo -e "You have enabled ccache through *export USE_CCACHE=1*, now using ccache...$nocol";
	fi;

	select_device;

	read -n 1 -p "Select your choice: " -s choice;
	case ${choice} in
		1) clean;;
		2) build;;
		3) build
		   make_zip;;
		4) make_zip;;
		5) make_savedefconfig;;
		*) echo
		   echo "Invalid choice entered. Exiting..."
		   sleep 2;
		   exit 1;;
	esac
}

main $@
