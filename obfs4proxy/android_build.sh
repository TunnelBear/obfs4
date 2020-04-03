#!/bin/bash

# Copyright (C) 2019 Tunnelbear Inc.
# Convenience script for generating proxy binaries for Android devices

NDK=""
PROJECT_SRC=""

help() { echo -e "Help: $0 [-s <PATH_TO_PROJECT_SRC>] [-n <PATH_TO_NDK_R16>] [-h] \n" 1>&2;}

while getopts ":s:n:h" opt; do
  case ${opt} in
		s)
			PROJECT_SRC="$OPTARG"
			;;
		n)
			NDK="$OPTARG"
			;;
		h)
			help
			exit 0
			;;
		*)
			echo "Invalid flag."
			help
			exit 1
			;;
  esac
done
shift $((OPTIND-1))

help

if [[ -z $PROJECT_SR ]] ; then
	echo "Path to Android project not provided through '-s' flag, will not automatically copy binaries when completed."
fi

if [[ -z $NDK ]] ; then
	NDK="$HOME/Library/Android/sdk/ndk-bundle"
	echo "Path to NDK-bundle not provided through '-n' flag, will use default directory: $NDK"
fi

# Check if previous android-toolchains exist and remove them
if ls /tmp/android-toolchain-* 1> /dev/null 2>&1; then
	echo "Removing previous android-toolchains from /tmp/ ..."
	rm -r /tmp/android-toolchain-*
	echo "Done!"
fi

# Check if previous pieproxy builds exist and remove them
if [[ -d ./out ]]; then
	echo "Removing previous pieproxy builds from ./out ..."
	rm -r ./out
	echo "Done!"
fi

if [ ! -d "${NDK}" ]; then
	echo "Android NDK path not specified!"
	echo "Please set \$NDK before starting this script!"
	exit 1;
fi

# Our targets are x86, x86_64, armeabi, armeabi-v7a, armv8;
# To remove targets, simply delete them from the bracket.

targets=(386 amd64 armv5 armv7 arm64)
export GOPATH=`pwd`
export GOOS=android
export CGO_ENABLED=1

for arch in ${targets[@]}; do
	echo -e "\n"
	# Initialize variables
	go_arch=$arch
	ndk_platform="android-16"
	suffix=$arch

	if [ "$arch" = "386" ]; then
		ndk_arch="x86"
		suffix="x86"
		binary="i686-linux-android-gcc"
	elif [ "$arch" = "amd64" ]; then
		ndk_platform="android-21"
		ndk_arch="x86_64"
		suffix="x86_64"
		binary="x86_64-linux-android-gcc"
	elif [ "$arch" = "armv5" ]; then
		export GOARM=5
		go_arch="arm"
		ndk_arch="arm"
		suffix="armeabi"
		binary="arm-linux-androideabi-gcc"
	elif [ "$arch" = "armv7" ]; then
		export GOARM=7
		go_arch="arm"
		ndk_arch="arm"
		suffix="armeabi-v7a"
		binary="arm-linux-androideabi-gcc"
	elif [ "$arch" = "arm64" ]; then
		ndk_arch="arm64"
		ndk_platform="android-21"
		suffix="arm64-v8a"
		binary="aarch64-linux-android-gcc"
	fi
	export GOARCH=${go_arch}
	export NDK_TOOLCHAIN=/tmp/android-toolchain-${ndk_arch}

	# Only generate toolchain if it does not already exist
	if [ ! -d $NDK_TOOLCHAIN ]; then
		echo "Generating ${suffix} toolchain..."
		$NDK/build/tools/make-standalone-toolchain.sh \
		--arch=${ndk_arch} --platform=${ndk_platform} --install-dir=$NDK_TOOLCHAIN
	fi
	export CC=$NDK_TOOLCHAIN/bin/${binary}

	echo "Starting compilation for $suffix..."
	go build -buildmode=pie -ldflags '-w -s -extldflags=-pie' -o ./out/${suffix}/pieproxy
	if [ $? -eq 0 ]; then
		echo "Build succeeded!"
	else
		echo "Build failed. Exiting."
		exit 1;
	fi

	if [ -z $PROJECT_SRC ]; then
		echo "Android \$PROJECT_SRC dir not defined. Not copying binaries."
	else
		target_dir=$PROJECT_SRC/libs/${suffix}/libexecpieproxy.so
		cp ./out/${suffix}/pieproxy $target_dir
		echo "Copied pieproxy binary to:" $target_dir
	fi
done
