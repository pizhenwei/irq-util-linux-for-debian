#!/bin/bash
set -xe

ISSUENET=`cat /etc/issue.net`
CONTROLDEP=

case $ISSUENET in
  "Debian GNU/Linux 9")
    echo "debian 9"
    CONTROLDEP="Depends: libncurses5, libncursesw5, libudev1"
    ;;

  "Debian GNU/Linux 10")
    echo "debian 10"
    CONTROLDEP="Depends: libncurses6, libncursesw6, libudev1"
    ;;
esac

# try to get the latest code
UTIL_LINUX_SRC=util-linux
if [[ -d "$UTIL_LINUX_SRC" ]]; then
    echo "$UTIL_LINUX_SRC exists. try to pull ..."
    cd $UTIL_LINUX_SRC
    git pull
    cd -
else
    echo "$UTIL_LINUX_SRC not exists. try to clone ..."
    git clone https://github.com/util-linux/util-linux.git
fi

apt-get install -y asciidoctor bison flex gettext

CPUS=$(cat /proc/cpuinfo | grep processor | wc -l)
RELEASE_DIR=`pwd`

BUILD_DIR=build
BIN_DIR=$BUILD_DIR/usr/local/bin/
COMPLETION_DIR=$BUILD_DIR/usr/share/bash-completion/completions
MAN_DIR=$BUILD_DIR/usr/share/man/man1

# try to clean previous files
rm -rf $BUILD_DIR *.deb

# start to build source code
cd $UTIL_LINUX_SRC
GITVERSION=$(./tools/git-version-gen)

./autogen.sh

./configure --enable-irqtop --enable-lsirq
make all -j $CPUS
rm -f irqtop lsirq lsblk

# get config options from config.h
CONFIG_OPTS=`grep -w "#define" config.h | grep HAVE | awk '{print "-D"$2"="$3}' | tr "\n" " "`

# staticly build to avoid libsmartcols.so.X conflict
gcc sys-utils/irqtop.c sys-utils/irq-common.c .libs/libsmartcols.a -g -o irqtop -I include -I libsmartcols/src -lncurses -DPACKAGE_STRING="0.1" -D_GNU_SOURCE $CONFIG_OPTS
gcc sys-utils/lsirq.c sys-utils/irq-common.c .libs/libsmartcols.a -g -o lsirq -I include -I libsmartcols/src -lncurses -DPACKAGE_STRING="0.1" -D_GNU_SOURCE $CONFIG_OPTS
gcc misc-utils/lsblk.c misc-utils/lsblk-properties.c misc-utils/lsblk-devtree.c misc-utils/lsblk-mnt.c .libs/libmount.a .libs/libsmartcols.a .libs/libuuid.a .libs/libblkid.a -g -o lsblk -I include -I libblkid/src -I libsmartcols/src -I libmount/src -ludev -DPACKAGE_STRING="0.1" -D_GNU_SOURCE $CONFIG_OPTS

# start to copy target files
cd $RELEASE_DIR
mkdir -p $BUILD_DIR/DEBIAN
cp control $BUILD_DIR/DEBIAN/control
sed -i "s/^Version:.*$/Version: $GITVERSION/" $BUILD_DIR/DEBIAN/control
echo $CONTROLDEP >> $BUILD_DIR/DEBIAN/control

mkdir -p $BIN_DIR
cp $UTIL_LINUX_SRC/irqtop $BIN_DIR
cp $UTIL_LINUX_SRC/lsirq $BIN_DIR
cp $UTIL_LINUX_SRC/lsblk $BIN_DIR

mkdir -p $COMPLETION_DIR
cp $UTIL_LINUX_SRC/bash-completion/irqtop $COMPLETION_DIR
cp $UTIL_LINUX_SRC/bash-completion/lsirq $COMPLETION_DIR

mkdir -p $MAN_DIR
cp $UTIL_LINUX_SRC/sys-utils/irqtop.1 $MAN_DIR
cp $UTIL_LINUX_SRC/sys-utils/lsirq.1 $MAN_DIR

dpkg-deb -b $BUILD_DIR $RELEASE_DIR/irq-util-linux_$GITVERSION.deb
