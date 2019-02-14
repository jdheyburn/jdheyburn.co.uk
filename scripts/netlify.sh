#!/usr/bin/env bash

# https://github.com/netlify/build-image/issues/183#issuecomment-419199649

#cwd=$(pwd)
#cd ./jdheyburn.co.uk
#git submodule update --init --recursive
#cd $cwd

HUGO_FLAVOUR="hugo_extended"
HUGO_VERSION="0.54.0"

rm -rf *.deb
wget --no-clobber http://security.ubuntu.com/ubuntu/pool/main/g/gcc-5/libstdc++6_5.4.0-6ubuntu1~16.04.10_amd64.deb 2>/dev/null || exit 1
wget --no-clobber https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/${HUGO_FLAVOUR}_${HUGO_VERSION}_Linux-64bit.deb 2>/dev/null || exit 1
grep "hugo=" ~/.bashrc || echo "alias hugo='LD_LIBRARY_PATH=$(pwd)/tmp/usr/lib/x86_64-linux-gnu $(pwd)/tmp/usr/local/bin/hugo'" >> ~/.bashrc
find -name '*.deb' -exec dpkg -x {} $(pwd)/tmp \;
rm -rf *.deb

export LD_LIBRARY_PATH=$(pwd)/tmp/usr/lib/x86_64-linux-gnu
export PATH=$(pwd)/tmp/usr/local/bin:$PATH

hugo
