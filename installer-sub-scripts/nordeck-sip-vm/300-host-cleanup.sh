# ------------------------------------------------------------------------------
# HOST-CLEANUP.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_HOST_CLEANUP" = true ]] && exit

echo
echo "------------------------ CLEAN UP -------------------------"

# ------------------------------------------------------------------------------
# CLEAN UP
# ------------------------------------------------------------------------------
systemctl stop virtual-camera-0.service || true
systemctl stop virtual-camera-1.service || true
systemctl stop jitsi-component-sidecar.service || true
systemctl stop jitsi-component-sidecar-config.service || true
systemctl stop sip-xorg.service || true
systemctl stop jibri-xorg.service || true

apt-mark unhold jibri || true
apt-mark unhold 'jitsi-*' || true
apt-mark unhold google-chrome-stable || true

apt-get -y purge jibri || true
apt-get -y purge 'jitsi-*' || true
apt-get -y purge 'openjdk-*' || true
apt-get -y purge redis || true
apt-get -y purge nodejs || true
apt-get -y purge google-chrome-stable || true
apt-get -y purge va-driver-all vdpau-driver-all || true
apt-get -y autoremove --purge

deluser jibri || true
delgroup jibri || true

rm -rf /home/jibri
rm -rf /etc/jitsi
rm -rf /etc/opt/chrome
rm -rf /etc/systemd/system/jibri*
rm -rf /etc/systemd/system/jitsi-*
rm -rf /etc/systemd/system/sip-*
rm -rf /etc/systemd/system/virtual-camera-*
rm -rf /opt/jitsi
rm -rf /var/log/jitsi
rm -f  /etc/apt/sources.list.d/jitsi-stable.list
rm -f  /etc/apt/sources.list.d/google-chrome.list
rm -f  /etc/apt/sources.list.d/nodesource.list
rm -f  /etc/sudoers.d/jibri
rm -f  /usr/local/bin/chromedriver
rm -f  /usr/local/bin/google-chrome
rm -f  /usr/local/bin/pjsua
rm -f  /usr/local/sbin/component-sidecar-config
rm -f  /usr/local/sbin/sip-ephemeral-config
rm -f  /usr/share/keyrings/google-chrome.gpg
rm -f  /usr/share/keyrings/jitsi.gpg
rm -f  /usr/share/keyrings/nodesource.gpg

rm -f /lib/modules/$(uname -r)/kernel/drivers/video/v4l2loopback.ko
depmod
