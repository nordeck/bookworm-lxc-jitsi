# ------------------------------------------------------------------------------
# BUILDER-PJPROJECT.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="$TAG-builder"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"
PROJECT_REPO="https://github.com/jitsi/pjproject"
PROJECT_BRANCH="jibri-2.13-dev1"

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_BUILD_PJPROJECT" = true ]] && exit

echo
echo "------------------------ PJPROJECT ------------------------"

# ------------------------------------------------------------------------------
# CONTAINER
# ------------------------------------------------------------------------------
# start the container
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING

# wait for the network to be up
for i in $(seq 0 9); do
    lxc-attach -n $MACH -- ping -c1 host.loc && break || true
    sleep 1
done

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
# pjproject releated packages
lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get $APT_PROXY -y install libv4l-dev libsdl2-dev libavcodec-dev \
    libavdevice-dev libavfilter-dev libavformat-dev libavutil-dev \
    libswscale-dev libasound2-dev libopus-dev libvpx-dev
EOS

# ------------------------------------------------------------------------------
# PJPROJECT
# ------------------------------------------------------------------------------
# build
lxc-attach -n $MACH -- zsh <<EOS
set -e
mkdir -p /home/dev/src
chown dev:dev /home/dev/src
rm -rf /home/dev/src/pjproject
EOS

lxc-attach -n $MACH -- zsh <<EOS
set -e
su -l dev <<EOSS
    set -e

    cd ~/src
    git clone -b $PROJECT_BRANCH $PROJECT_REPO
    cd pjproject

    ./configure
    make dep
    make
EOSS
EOS

# store
mkdir -p /root/$TAG-store
cp $ROOTFS/home/dev/src/pjproject/pjsip-apps/bin/pjsua-x86_64-unknown-linux-gnu \
    /root/$TAG-store/pjsua

# ------------------------------------------------------------------------------
# CONTAINER SERVICES
# ------------------------------------------------------------------------------
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
