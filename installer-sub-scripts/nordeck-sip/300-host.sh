# ------------------------------------------------------------------------------
# HOST.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="$TAG-sip-host"
cd $MACHINES/$MACH

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_SIP_HOST" = true ]] && exit

echo
echo "-------------------------- $MACH --------------------------"

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

apt-get $APT_PROXY -y install uuid-runtime
apt-get $APT_PROXY -y install kmod alsa-utils
apt-get $APT_PROXY -y --install-recommends install v4l2loopback-dkms \
    v4l2loopback-utils

# ------------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# ------------------------------------------------------------------------------
# snd_aloop config
cp etc/modprobe.d/alsa-loopback.conf /etc/modprobe.d/
[[ -z "$(egrep '^snd_aloop' /etc/modules)" ]] && \
    cat etc/modules.custom.alsa >>/etc/modules

# load snd_aloop
rmmod -f snd_aloop || true
modprobe snd_aloop || true

# v4l2loopback config
cp etc/modprobe.d/v4l2loopback.conf /etc/modprobe.d/
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

This kernel ($(uname -r)) does not support snd_aloop module.

Please install the standard Linux kernel package and reboot it.
Probably it is "linux-image-$ARCH" for your case.

EOF

    if [[ "$IS_IN_LXC" = true ]]; then
        cat <<EOF
If this is a container, please load the snd_aloop module to the host
permanently.

EOF
    fi

    false
fi

if [[ "$DONT_CHECK_V4L2LOOPBACK" != true ]] && \
   [[ -z "$(grep v4l2loopback /proc/modules)" ]]; then
    cat <<EOF

This kernel ($(uname -r)) does not support v4l2loopback module.

Please install the standard Linux kernel package and reboot it.
Probably it is "linux-image-$ARCH" for your case.

EOF

    if [[ "$IS_IN_LXC" = true ]]; then
        cat <<EOF
If this is a container, please load the v4l2loopback module to the host
permanently.

EOF
    fi

    false
fi

# ------------------------------------------------------------------------------
# TOOLS
# ------------------------------------------------------------------------------
# sip-ephemeral-container service
cp usr/local/sbin/sip-ephemeral-start /usr/local/sbin/
chmod 744 /usr/local/sbin/sip-ephemeral-start
cp usr/local/sbin/sip-ephemeral-stop /usr/local/sbin/
chmod 744 /usr/local/sbin/sip-ephemeral-stop
cp etc/systemd/system/sip-ephemeral-container.service /etc/systemd/system/
