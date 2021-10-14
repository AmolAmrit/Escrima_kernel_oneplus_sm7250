#! /bin/bash

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2020 Panchajanya1999 <rsk52959@gmail.com>
 # Copyright (c) 2019-2020 iamsaalim <saalimquadri1@gmail.com>
 # Copyright (c) 2021 Amol Amrit <amol.amrit03@outlook.com>
 #
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

#Kernel building script

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

# Constants
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
cyan='\033[0;36m'
yellow='\033[0;33m'
blue='\033[0;34m'
default='\033[0m'

##--------------------------------------------------------##
##----------Basic Informations and Variables--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$PWD

# Kernel Version
VERSION="X1-Chidori"

# The name of the device for which the kernel is built
#MODEL="OnePlus Nord"

# The codename of the device
DEVICE="avicii"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=vendor/lito-perf_defconfig

# Specify compiler.
# 'clang' or 'gcc'
COMPILER=clang

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=0

# Generate a full DEFCONFIG prior building. 1 is YES | 0 is NO(default)
DEF_REG=0

# Build dtbo.img (select this only if your source has support to building dtbo.img)
# 1 is YES | 0 is NO(default)
BUILD_DTBO=1

# Silence the compilation
# 1 is YES(default) | 0 is NO
SILENCE=0

# The name of the Kernel, to name the ZIP
ZIPNAME="Escrima-$VERSION"

# Set Date and Time Zone
DATE=$(TZ=Asia/Kolkata date +"%Y%m%d-%T")


##----------------------------------------------------------------------------------##
##----------Now Its time for other stuffs like cloning, exporting, etc--------------##

 clone() {
	echo " "
	if [ $COMPILER = "clang" ]
	then
		msg "|| Cloning Proton Clang-12 ||"
		git clone --depth=1 https://github.com/kdrag0n/proton-clang.git /home/amolamrit/clang-llvm

		# Toolchain Directory defaults to clang-llvm
		TC_DIR=/home/amolamrit/clang-llvm
	elif [ $COMPILER = "gcc" ]
	then
		msg "|| Cloning GCC 9.3.0 baremetal ||"
		git clone --depth=1 https://github.com/arter97/arm64-gcc.git gcc64
		git clone --depth=1 https://github.com/arter97/arm32-gcc.git gcc32
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32
	fi

	msg "|| Cloning libufdt ||"
	git clone https://android.googlesource.com/platform/system/libufdt /home/amolamrit/scripts/ufdt/libufdt
}


##----------------------------------------------------------------------------##
##----------Export more variables --------------------------------------------##

exports() {
	export KBUILD_BUILD_USER="AmolAmrit"
        export KBUILD_BUILD_HOST="Nightwing"
	export ARCH=arm64
	export SUBARCH=arm64

	if [ $COMPILER = "clang" ]
	then
		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$PATH
	elif [ $COMPILER = "gcc" ]
	then
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	fi

	export PATH KBUILD_COMPILER_STRING
	PROCS=$(nproc --all)
	export PROCS
}


##---------------------------------------------------------##
##--------------------Now Build it-------------------------##

build_kernel() {
	if [ $INCREMENTAL = 0 ]
	then
		msg "|| Cleaning Sources ||"
		make clean && make mrproper && rm -rf out && rm -rf AnyKernel3/Image && rm -rf AnyKernel3/*.zip
	fi


	make O=out $DEFCONFIG

        BUILD_START=$(date +"%s")

	if [ $COMPILER = "clang" ]
	then
		MAKE+=(
			CROSS_COMPILE=aarch64-linux-gnu- \
			CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
			CC=clang \
			AR=llvm-ar \
			OBJDUMP=llvm-objdump \
			STRIP=llvm-strip \
                        DTC_EXT=$KERNEL_DIR/dtc
		)
	elif [ $COMPILER = "gcc" ]
	then
		MAKE+=(
			CROSS_COMPILE_ARM32=arm-eabi- \
			CROSS_COMPILE=aarch64-elf- \
			AR=aarch64-elf-ar \
			OBJDUMP=aarch64-elf-objdump \
			STRIP=aarch64-elf-strip
		)
	fi

	if [ $SILENCE = "1" ]
	then
		MAKE+=( -s )
	fi

	msg "|| Started Compilation ||"
	make -j"$PROCS" O=out \
		NM=llvm-nm \
		OBJCOPY=llvm-objcopy \
		LD=ld.lld "${MAKE[@]}" 2>&1

		if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image ]
	    then
	    	msg "|| Kernel successfully compiled ||"
	    	if [ $BUILD_DTBO = 1 ]
			then
				msg "|| Building DTBO ||"
				python2 "/home/amolamrit/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
				create "$KERNEL_DIR/out/arch/arm64/boot/dtbo.img" --page_size=4096 "$KERNEL_DIR/out/arch/arm64/boot/dts/vendor/qcom/avicii-overlay-dvt.dtbo"
			fi
				gen_zip

		fi

}
##-----------------------------------------------------------##
##--------------Compile AnyKernel Zip------------------------##

gen_zip() {
	msg "|| Zipping into a flashable zip ||"
	mv "$KERNEL_DIR"/out/arch/arm64/boot/Image AnyKernel3
        mv "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img AnyKernel3

	cd AnyKernel3 || exit
	zip -r9 $ZIPNAME-$DEVICE-$DATE.zip * -x .git README.md

##-----------------Uploading-------------------------------##

msg "|| Uploading ||"
cp *.zip /var/www/html/builds/avicii/Escrima
	cd ..
}

clone
exports
build_kernel

# Build complete
BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$green Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$default"

##----------------*****-----------------------------##
