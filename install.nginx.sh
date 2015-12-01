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

NGINX_VERSION="1.9.7"
ZLIB_VERSION="1.2.8"
PCRE_VERSION="8.37"
OPENSSL_VERSION="1.0.2d"

REPO_URL="http://repo.imm.cz"

MODULES=(
    "https://github.com/arut/nginx-rtmp-module"
    "https://github.com/pagespeed/ngx_pagespeed"
    "https://github.com/openresty/echo-nginx-module"
    "https://github.com/openresty/headers-more-nginx-module"
    "https://github.com/wandenberg/nginx-push-stream-module"
)



function install_prerequisites {
    apt-get -y install \
        git \
        build-essential \
        curl \
        libxml2 \
        libxml2-dev \
        libxslt-dev
}



function download_all {
    cd $TEMPDIR

    #
    # NGINX SOURCES
    #

    wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
    tar -xvf nginx-${NGINX_VERSION}.tar.gz
    rm nginx-${NGINX_VERSION}

    #
    # Libs
    #

    LIBS=(
        "zlib-${ZLIB_VERSION}"
        "pcre-${PCRE_VERSION}"
        "openssl-${OPENSSL_VERSION}"
    )

    for LIB in ${LIBS[@]}; do
        wget $REPO_URL/${LIB}.tar.gz || return 1
        tar -xvf ${LIB}.tar.gz || return 1
        rm ${LIB}.tar.gz
    done

    #
    # Modules
    #

    for i in ${MODULES[@]}; do
        MNAME=`basename $i`
        if [ -d $MNAME ]; then
            cd $MNAME
            git pull || return 1
            cd ..
        else
            git clone $i || return 1
        fi
    done

    #
    # Pagespeed download
    #

    cd $TEMPDIR/ngx_pagespeed
    wget https://dl.google.com/dl/page-speed/psol/1.9.32.10.tar.gz
    tar -xzvf 1.9.32.10.tar.gz
    cd $TEMPDIR

}





function build_nginx {
    cd $TEMPDIR
    #
    # Configure
    #

    cd nginx-${NGINX_VERSION}

    CMD="./configure \
        --prefix=/usr/share/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --pid-path=/run/nginx.pid \
        --lock-path=/var/lock/nginx.lock \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/access.log \
        --user=www-data \
        --group=www-data"

     CMD=$CMD" \
        --with-pcre=$TEMPDIR/pcre-$PCRE_VERSION \
        --with-zlib=$TEMPDIR/zlib-$ZLIB_VERSION \
        --with-openssl=$TEMPDIR/openssl-$OPENSSL_VERSION \
        --with-http_stub_status_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_ssl_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-http_xslt_module \
        --without-mail_pop3_module \
        --without-mail_smtp_module \
        --without-mail_imap_module"
    
     for i in ${MODULES[@]}; do
        MNAME=`basename $i`
        CMD=$CMD" --add-module=$TEMPDIR/$MNAME"
     done
     
     $CMD || return 1
     make && make install || return 1

     return 0
}

function post_install {
    echo "Running post-install configuration..."
    
    HTMLDIR="/var/www"
    DEFAULTDIR="$HTMLDIR/default"

    if [ ! -d $HTMLDIR ]; then
        mkdir $HTMLDIR
    fi

    if [ ! -d $DEFAULTDIR ]; then
        mkdir $DEFAULTDIR
        cp nginx/http.conf $DEFAULTDIR
        cp nginx/index.html $DEFAULTDIR
    fi

    cd $BASEDIR
    cp nginx/nginx.conf /etc/nginx/nginx.conf || return 1
    cp nginx/cache.conf /etc/nginx/cache.conf || return 1
    cp nginx/nginx.service /lib/systemd/system/nginx.service || return 1
    
    return 0
}

function start_nginx {
    echo "(re)starting NGINX service..."
    systemctl daemon-reload
    service nginx stop
    service nginx start
}


##############################################################################
# TASKS

install_prerequisites || error_exit
download_all || error_exit
build_nginx || error_exit
post_install || error_exit
start_nginx || error_exit
finished
