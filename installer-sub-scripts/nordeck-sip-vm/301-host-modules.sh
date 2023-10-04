# ------------------------------------------------------------------------------
# HOST-MODULES.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="$TAG-sip-host"
cd $MACHINES/$MACH

export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_HOST_MODULES" = true ]] && exit

echo
echo "---------------------- HOST MODULES ----------------------"

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
apt-get $APT_PROXY -y install uuid-runtime
apt-get $APT_PROXY -y install kmod alsa-utils
apt-get $APT_PROXY -y --no-install-recommends install linux-headers-$ARCH \
    build-essential
apt-get $APT_PROXY -y --no-install-recommends install v4l2loopback-dkms \
    v4l2loopback-utils

# ------------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# ------------------------------------------------------------------------------
# snd_aloop config
cp etc/modprobe.d/alsa-loopback.vm.conf /etc/modprobe.d/
[[ -z "$(egrep '^snd_aloop' /etc/modules)" ]] && \
    cat etc/modules.custom.alsa >>/etc/modules

# load snd_aloop
rmmod -f snd_aloop || true
modprobe snd_aloop || true

# v4l2loopback config
cp etc/modprobe.d/v4l2loopback.vm.conf /etc/modprobe.d/
[[ -z "$(egrep '^v4l2loopback' /etc/modules)" ]] && \
    cat etc/modules.custom.v4l2 >>/etc/modules

# load v4l2loopback
rmmod -f v4l2loopback || true
modprobe v4l2loopback || true

# ------------------------------------------------------------------------------
# CHECKS
# ------------------------------------------------------------------------------
if [[ "$DONT_CHECK_SND_ALOOP" != true ]] && \
   [[ -z "$(grep snd_aloop /proc/modules)" ]]; then
    cat <<EOF

This kernel ($(uname -r)) does not support snd_aloop module or it is not
up-to-date.

Please install the standard Linux kernel package and reboot with it.
Probably it is "linux-image-$ARCH" for your case.

EOF
    exit 1
fi

if [[ "$DONT_CHECK_V4L2LOOPBACK" != true ]] && \
   [[ -z "$(grep v4l2loopback /proc/modules)" ]]; then
    cat <<EOF

This kernel ($(uname -r)) does not support v4l2loopback module or it is not
up-to-date.

Please install the standard Linux kernel package and reboot with it.
Probably it is "linux-image-$ARCH" for your case.

EOF
    exit 1
fi
