#!/bin/bash

# Copyright (c) shogo4405 and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD 3-Clause License found in the
# LICENSE file in the root directory of this source tree.

set -euo pipefail

function clone_and_patch() {
    if [ ! -d librist ] ; then
        git clone https://github.com/eerimoq/librist
        pushd librist
        git checkout a29aed54e4dc32fda108977b309c3df5b91148d5
        popd
    fi
}

function build() {
    rm -rf build
    mkdir -p build/iphone
    pushd build/iphone
    meson setup ../../librist \
          --default-library=static \
          --buildtype=release \
          -D builtin_mbedtls=true \
          -D test=false \
          --cross-file ../../iphone.txt
    ninja
    popd
    mkdir -p build/iossimulator
    pushd build/iossimulator
    meson setup ../../librist \
          --default-library=static \
          --buildtype=release \
          -D builtin_mbedtls=true \
          -D test=false \
          --cross-file ../../iossimulator.txt
    ninja
    popd
}

function create_xcframework() {
    rm -rf include
    cp -r build/iphone/include .
    cp -r librist/include .
    cp module.modulemap include/librist/module.modulemap
    rm -rf librist.xcframework
    xcodebuild \
        -create-xcframework \
        -library build/iphone/librist.a \
        -headers include \
        -library build/iossimulator/librist.a \
        -headers include \
        -output librist.xcframework
    zip -r librist.xcframework.zip librist.xcframework
    swift package compute-checksum librist.xcframework.zip
}

clone_and_patch
build
create_xcframework
