#!/usr/bin/env bash

# Copyright  2014 Nickolay V. Shmyrev
#            2014 Brno University of Technology (Author: Karel Vesely)
# Apache 2.0

. ./path.sh

cd $exactDataDir

if [ ! -f TEDLIUM_release1.tar.gz ]; then
    echo "Downloading \"http://www.openslr.org/resources/7/TEDLIUM_release1.tar.gz\". "
    wget http://www.openslr.org/resources/7/TEDLIUM_release1.tar.gz || exit 1
    tar -xf TEDLIUM_release1.tar.gz
fi

# Language models (Cantab Research):
if [ ! -d cantab-TEDLIUM ]; then
    echo "Downloading \"http://www.openslr.org/resources/27/cantab-TEDLIUM.tar.bz2\". "
    wget http://www.openslr.org/resources/27/cantab-TEDLIUM.tar.bz2 || exit 1
    tar -xf cantab-TEDLIUM.tar.bz2
fi

