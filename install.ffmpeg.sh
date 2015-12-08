#!/bin/bash
#
# Copyright (c) 2015 imm studios, z.s.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
##############################################################################
## COMMON UTILS

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TEMPDIR=/tmp/$(basename "${BASH_SOURCE[0]}")

function error_exit {
    printf "\n\033[0;31mInstallation failed\033[0m\n"
    cd $BASEDIR
    exit 1
}

function finished {
    printf "\n\033[0;92mInstallation completed\033[0m\n"
    cd $BASEDIR
    exit 0
}


if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   error_exit 
fi

if [ ! -d $TEMPDIR ]; then
    mkdir $TEMPDIR || error_exit
fi

## COMMON UTILS
##############################################################################

YASM_VERSION="1.3.0"
FFMPEG_VERSION="2.8.3"
NVENC_VERSION="5.0.1"
VPX_VERSION="1.5.0"
OPUS_VERSION="1.1.1"

REPOS=(
    "https://github.com/mstorsjo/fdk-aac"
    "git://git.videolan.org/x264.git"
    "https://github.com/videolan/x265"
    "https://github.com/martastain/bmd-sdk"
)

if [ -z "$PREFIX" ]; then
    PREFIX="/usr/local"
fi


function install_prerequisites {
    apt-get -y install\
        build-essential \
        unzip \
        cmake \
        checkinstall \
        git \
        libtool \
        autoconf \
        automake \
        pkg-config \
        libtool-bin \
        sox \
        libfftw3-dev \
        fontconfig \
        libfontconfig \
        libfontconfig-dev \
        frei0r-plugins \
        frei0r-plugins-dev \
        libass-dev \
        flite1-dev \
        libfreetype6-dev \
        libmp3lame-dev \
        libtwolame-dev \
        libopenjpeg-dev \
        librtmp-dev \
        libschroedinger-dev \
        libopus-dev \
        libspeex-dev \
        libtheora-dev \
        libvorbis-dev \
        libwavpack-dev \
        libxvidcore4 \
        libxvidcore-dev \
        libzvbi-dev || exit 1
}


function download_repos {
    cd $TEMPDIR
    for i in ${REPOS[@]}; do
        MNAME=`basename $i`
        if [ -d $MNAME ]; then
            cd $MNAME
            git pull || return 1
            cd ..
        else
            git clone $i || return 1
        fi
    done
    return 0
}


function install_yasm {
    cd $TEMPDIR
    wget http://www.tortall.net/projects/yasm/releases/yasm-${YASM_VERSION}.tar.gz || return 1
    echo "Extracting YASM"
    tar -xf yasm-${YASM_VERSION}.tar.gz
    cd yasm-${YASM_VERSION}
    ./configure --prefix=$PREFIX || return 1
    make || return 1
    make install || return 1
    return 0
}


function install_fdk_aac {
    cd $TEMPDIR/fdk-aac
    autoreconf -fiv || return 1
    ./configure --prefix=$PREFIX || return 1
    make || return 1
    make install || return 1
    return 0
}

function install_opus {
    cd $TEMPDIR
    wget http://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz
    tar -xf opus-${OPUS_VERSION}.tar.gz
    cd opus-${OPUS_VERSION}
    ./configure --prefix=$PREFIX \
        --disable-static || return 1
    make || return 1
    make install || return 1
    return 0
}

function install_nvenc {
    cd $TEMPDIR
    wget http://developer.download.nvidia.com/compute/nvenc/v5.0/nvenc_${NVENC_VERSION}_sdk.zip || return 1
    unzip nvenc_${NVENC_VERSION}_sdk.zip || return 1
    cp nvenc_${NVENC_VERSION}_sdk/Samples/common/inc/* /usr/include/
    return 0
}


function install_vpx {
    cd $TEMPDIR
    wget http://storage.googleapis.com/downloads.webmproject.org/releases/webm/libvpx-${VPX_VERSION}.tar.bz2
    tar -xf libvpx-${VPX_VERSION}.tar.bz2
    cd libvpx-${VPX_VERSION}
    ./configure \
        --prefix=$PREFIX \
        --disable-examples \
        --disable-unit-tests ||  return 1
    make || return 1
    make install || return 1
    make clean
    ldconfig
    return 0
}


function install_x264 {
    cd $TEMPDIR/x264
    ./configure --prefix=$PREFIX \
        --enable-pic \
        --enable-shared \
        --disable-lavf || return 1
    make || return 1
    make install || return 1
    ldconfig
    return 0
}


function install_x265 {
    cd $TEMPDIR/x265
    cmake source/
    make || return 1
    make install || return 1
    return 0
}


function install_bmd {
    cd $TEMPDIR
    cp bmd-sdk/* /usr/include/
    return 1
}


function install_ffmpeg {
    cd $TEMPDIR
    wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 || return 1
    echo "Extracting ffmpeg"
    tar -xf ffmpeg-${FFMPEG_VERSION}.tar.bz2 || return 1
    cd ffmpeg-${FFMPEG_VERSION}

    ./configure --prefix=$PREFIX \
      --enable-nonfree \
      --enable-gpl \
      --enable-version3 \
      --enable-shared \
      --enable-pic \
    \
      --enable-fontconfig            `# enable fontconfig` \
      --enable-frei0r                `# enable frei0r video filtering` \
      --enable-libass                `# enable libass subtitles rendering` \
      --enable-libfdk-aac            `# enable AAC encoding via FDK AAC` \
      --enable-libflite              `# enable flite voice synthesis support via libflite` \
      --enable-libfreetype           `# enable libfreetype` \
      --enable-libmp3lame            `# enable MP3 encoding via libmp3lame` \
      --enable-libopenjpeg           `# enable JPEG2000 de/encoding via OpenJPEG` \
      --enable-libopus               `# enable Opus de/encoding via libopus` \
      --enable-librtmp               `# enable RTMP[E] support via librtmp` \
      --enable-libschroedinger       `# enable Dirac de/encoding via libschroedinger` \
      --enable-libspeex              `# enable Speex de/encoding via libspeex` \
      --enable-libtheora             `# enable Theora encoding via libtheora` \
      --enable-libtwolame            `# enable MP2 encoding via libtwolame` \
      --enable-libvorbis             `# enable Vorbis en/decoding via libvorbis,` \
`#      --enable-libvpx                 enable VP8 and VP9 de/encoding via libvpx` \
      --enable-libwavpack            `# enable wavpack encoding via libwavpack` \
      --enable-libx264               `# enable H.264 encoding via x264` \
      --enable-libx265               `# enable HEVC encoding via x265` \
      --enable-libxvid               `# enable Xvid encoding via xvidcore,` \
      --enable-libzvbi               `# enable teletext support via libzvbi` \
      --enable-decklink              `# enable Blackmagick DeckLink I/O support` \
      --enable-nvenc                 `# enable Enable nvenc` || return 1

    make || return 1
    make install || return 1
    make clean
    ldconfig
    return 0
}

################################################


install_prerequisites || error_exit
download_repos || error_exit

install_yasm || error_exit
install_fdk_aac || error_exit
install_opus || error_exit
#install_vpx || error_exit # Enable VPX again in 2.8.4
install_x264 || error_exit
install_x265 || error_exit
install_nvenc || error_exit
install_bmd || error_exit
install_ffmpeg || error_exit

finished