#!/bin/bash
PHP_VERSION="5.6.23"
WXPHP_VERSION="master"
WXWIDGETS_VERSION="3.0.2"

TOPDIR=`pwd`

function download_extract()
{
    # Download extract PHP
    if [ ! -e "php-${PHP_VERSION}.tar.gz" ]; then
        wget -O php-$PHP_VERSION.tar.gz http://php.net/get/php-$PHP_VERSION.tar.gz/from/this/mirror
    fi

    if [ -e "php-${PHP_VERSION}" ]; then
        echo "Removing old PHP build files..."
        rm -rf php-$PHP_VERSION
    fi

    echo "Extracting PHP..."
    tar -xzf php-$PHP_VERSION.tar.gz

    # Download extract wxPHP
    if [ ! -e "${WXPHP_VERSION}.tar.gz" ]; then
        wget https://github.com/wxphp/wxphp/archive/master.tar.gz
    fi

    if [ -e "wxphp-${WXPHP_VERSION}" ]; then
        echo "Removing old wxPHP build files..."
        rm -rf wxphp-$WXPHP_VERSION
    fi

    echo "Extracting wxPHP..."
    tar -xzf $WXPHP_VERSION.tar.gz

    # Download extract patch wxWidgets
    if [ ! -e "wxWidgets-$WXWIDGETS_VERSION.tar.bz2" ]; then
        wget https://github.com/wxWidgets/wxWidgets/releases/download/v$WXWIDGETS_VERSION/wxWidgets-$WXWIDGETS_VERSION.tar.bz2
    fi
    cd wxphp-master
    tar -xjf ../wxWidgets-$WXWIDGETS_VERSION.tar.bz2

    local gcc_ver=`gcc -v 2>&1 | grep "gcc version 6"`
    if [ "$gcc_ver" != "" ]; then
        cd wxWidgets-$WXWIDGETS_VERSION
        patch -p1 -i ../../wxgtk-gcc6.patch
    fi

    cd $TOPDIR
}

function generate_appdir()
{
    echo "Generating AppDir skeleton..."

    if [ -e "wxphp.AppDir" ]; then
        rm -rf wxphp.AppDir
    fi

    mkdir -p wxphp.AppDir/usr/bin

    mkdir -p wxphp.AppDir/usr/share/icons/hicolor/scalable/apps/

    cp launcher/* wxphp.AppDir/usr/bin

    cp wxphp-$WXPHP_VERSION/artwork/icon.svg wxphp.AppDir/wxphp.svg

    cp wxphp-$WXPHP_VERSION/artwork/icon.svg wxphp.AppDir/usr/share/icons/hicolor/scalable/apps/wxphp-icon.svg

    chmod 0755 wxphp.AppDir/usr/bin/wxphp
    chmod 0755 wxphp.AppDir/usr/bin/shell
    chmod 0755 wxphp.AppDir/usr/bin/wxphp.wrapper

    # Generate desktop file
    echo "[Desktop Entry]" > wxphp.AppDir/wxphp.desktop
    echo "Name=wxPHP" >> wxphp.AppDir/wxphp.desktop
    echo "Exec=wxphp" >> wxphp.AppDir/wxphp.desktop
    echo "Icon=wxphp" >> wxphp.AppDir/wxphp.desktop
    echo "Terminal=false" >> wxphp.AppDir/wxphp.desktop
    echo "Type=Application" >> wxphp.AppDir/wxphp.desktop
    echo "Categories=Development;" >> wxphp.AppDir/wxphp.desktop
    echo "Comment=wxPHP execution shell." >> wxphp.AppDir/wxphp.desktop
    echo "StartupNotify=true" >> wxphp.AppDir/wxphp.desktop

    gcc -o AppRun AppRun.c

    cp AppRun wxphp.AppDir/
}

function php_build()
{
    echo "Building PHP..."
    cd php-$PHP_VERSION
    ./buildconf --force

    PREFIX=/usr
    SYSCONFDIR=/C/etc/php
    CONFIG_PATH=/C/etc/php
    SCAN_CONFIG_PATH=/C/etc/php/conf.d
    EXTENSION_DIR=/usr/lib/modules

    export EXTENSION_DIR

    ./configure \
        --prefix="$PREFIX" \
        --sysconfdir="$SYSCONFDIR" \
        --with-config-file-path="$CONFIG_PATH" \
        --with-config-file-scan-dir="$SCAN_CONFIG_PATH" \
        --enable-cli --disable-cgi --disable-fpm \
        --enable-short-tags \
        --enable-pdo --with-pdo-sqlite \
        --enable-ftp \
        --enable-mbstring \
        --enable-zip \
        --enable-libxml \
        --enable-simplexml \
        --enable-xml \
        --enable-xmlreader \
        --enable-xmlwriter \
        --enable-bcmath \
        --enable-calendar \
        --enable-ctype \
        --enable-dom \
        --enable-fileinfo \
        --enable-filter \
        --enable-shmop \
        --enable-sysvsem \
        --enable-sysvshm \
        --enable-sysvmsg \
        --enable-json \
        --enable-mbregex \
        --enable-mbstring \
        --enable-sockets \
        --enable-tokenizer \
        --enable-pcntl \
        --enable-phar \
        --enable-posix \
        --with-gd --enable-gd-native-ttf \
        --with-sqlite3 \
        --with-mhash \
        --with-mcrypt \
        --with-pcre-regex \
        --with-readline \
        --with-libedit \
        --with-curl \
        --with-openssl \
        --with-zlib

    make INSTALL_ROOT=$TOPDIR/wxphp.AppDir -j `nproc`

    make INSTALL_ROOT=$TOPDIR/wxphp.AppDir install

    cd $TOPDIR

    mv wxphp.AppDir/C/etc wxphp.AppDir/
    rm -rf wxphp.AppDir/C
    mkdir -p wxphp.AppDir/etc/php/conf.d

    echo "zend_extension=opcache.so" > wxphp.AppDir/etc/php/conf.d/opcache.ini
    echo "opcache.memory_consumption=128" >> wxphp.AppDir/etc/php/conf.d/opcache.ini
    echo "opcache.interned_strings_buffer=8" >> wxphp.AppDir/etc/php/conf.d/opcache.ini
    echo "opcache.max_accelerated_files=4000" >> wxphp.AppDir/etc/php/conf.d/opcache.ini
    echo "opcache.revalidate_freq=60" >> wxphp.AppDir/etc/php/conf.d/opcache.ini
    echo "opcache.fast_shutdown=1" >> wxphp.AppDir/etc/php/conf.d/opcache.ini
    echo "opcache.enable_cli=1" >> wxphp.AppDir/etc/php/conf.d/opcache.ini
    echo ";opcache.save_comments=0" >> wxphp.AppDir/etc/php/conf.d/opcache.ini
    echo "opcache.enable_file_override=1" >> wxphp.AppDir/etc/php/conf.d/opcache.ini

    echo

    echo "patching php binary..."
    sed -i -e 's|/C/|../|g' wxphp.AppDir/usr/bin/php
    sed -i -e 's|/usr/|././/|g' wxphp.AppDir/usr/bin/php
    strip -s wxphp.AppDir/usr/bin/php

    echo "patching phpize script...."
    sed -i -e 's|prefix='"'"'/usr'"'"'|prefix="'`pwd`/wxphp.AppDir/usr'"|g' wxphp.AppDir/usr/bin/phpize
    sed -i -e 's|datarootdir='"'"'/usr/php'"'"'|datarootdir="'`pwd`/wxphp.AppDir/usr/php'"|g' wxphp.AppDir/usr/bin/phpize

    echo "patching php-config script...."
    sed -i -e 's|prefix="/usr"|prefix="'`pwd`/wxphp.AppDir/usr'"|g' wxphp.AppDir/usr/bin/php-config
    sed -i -e 's|datarootdir="/usr/php"|datarootdir="'`pwd`/wxphp.AppDir/usr/php'"|g' wxphp.AppDir/usr/bin/php-config
    sed -i -e 's|extension_dir='"'"'/usr/lib/modules'"'"'|extension_dir="'`pwd`/wxphp.AppDir/usr/lib/modules'"|g' wxphp.AppDir/usr/bin/php-config
}

function wxphp_build()
{
    cd wxphp-$WXPHP_VERSION
    $TOPDIR/wxphp.AppDir/usr/bin/phpize
    ./configure --with-php-config=$TOPDIR/wxphp.AppDir/usr/bin/php-config
    make -j `nproc`
    make install

    cd $TOPDIR

    strip -s wxphp.AppDir/usr/lib/modules/wxwidgets.so
}

function copy_dependencies()
{
    # Check if the paths are vaild
    [[ ! -e $1 ]] && echo "Not a vaild input $1" && exit 1
    [[ -d $2 ]] || echo "No such directory $2 creating..."&& mkdir -p "$2"

    # Get the library dependencies
    deps=$(ldd $1 | awk 'BEGIN{ORS=" "}$1~/^\//{print $1}$3~/^\//{print $3}' | sed 's/,$/\n/')

    # Copy the deps
    for dep in $deps
    do
        echo "Copying $dep to $2"
        cp -u "$dep" "$2"
    done
}

function clean_dependencies()
{
    for lib in $(ls wxphp.AppDir/usr/lib); do
        lib=wxphp.AppDir/usr/lib/$lib

        if [ -d "$lib" ]; then
            continue
        fi

        if [ "$(strings $lib | grep /etc)" != "" ]; then
            echo "Removing $lib with /etc hardcoded..."
            rm -f $lib
            continue
        fi

        if [ "$(strings $lib | grep /usr)" != "" ]; then
            echo "Removing $lib with /usr hardcoded..."
            rm -f $lib
        fi
    done
}

# Main
download_extract
generate_appdir
php_build
wxphp_build

echo "Copying PHP dependencies..."
copy_dependencies wxphp.AppDir/usr/bin/php wxphp.AppDir/usr/lib

echo "Copying wxPHP dependencies..."
copy_dependencies wxphp.AppDir/usr/lib/modules/wxwidgets.so wxphp.AppDir/usr/lib

clean_dependencies

AppImageAssistant wxphp.AppDir wxphp
