# ------------------------------------------------------------------------------
# SIP.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="$TAG-sip-template"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_SIP" = true ]] && exit

echo
echo "-------------------------- $MACH --------------------------"

# ------------------------------------------------------------------------------
# CONTAINER SETUP
# ------------------------------------------------------------------------------
# stop the template container if it's running
set +e
lxc-stop -n $TAG-bookworm
lxc-wait -n $TAG-bookworm -s STOPPED
set -e

# remove the old container if exists
set +e
systemctl stop sip-ephemeral-container.service

lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-destroy -n $MACH
rm -rf /var/lib/lxc/$MACH
sleep 1
set -e

# create the new one
lxc-copy -n $TAG-bookworm -N $MACH -p /var/lib/lxc/

# the shared directories
mkdir -p $SHARED/cache

# the container config
rm -rf $ROOTFS/var/cache/apt/archives
mkdir -p $ROOTFS/var/cache/apt/archives

cat >> /var/lib/lxc/$MACH/config <<EOF

# Devices
lxc.cgroup2.devices.allow = c 116:* rwm
lxc.cgroup2.devices.allow = c 81:* rwm
lxc.mount.entry = /dev/snd dev/snd none bind,optional,create=dir

# Start options
lxc.start.auto = 1
lxc.start.order = 301
lxc.start.delay = 2
lxc.group = $TAG-group
lxc.group = $TAG-sip
EOF

# start the container
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING

# wait for the network to be up
for i in $(seq 0 9); do
    lxc-attach -n $MACH -- ping -c1 host.loc && break || true
    sleep 1
done

# ------------------------------------------------------------------------------
# HOSTNAME
# ------------------------------------------------------------------------------
lxc-attach -n $MACH -- zsh <<EOS
set -e
echo $MACH > /etc/hostname
sed -i 's/\(127.0.1.1\s*\).*$/\1$MACH/' /etc/hosts
hostname $MACH
EOS

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
# fake install
lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get $APT_PROXY -dy reinstall hostname
EOS

# update
lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get $APT_PROXY update
apt-get $APT_PROXY -y dist-upgrade
EOS

# packages
lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get $APT_PROXY -y install jq
apt-get $APT_PROXY -y install gnupg unzip unclutter
apt-get $APT_PROXY -y install libnss3-tools
apt-get $APT_PROXY -y install va-driver-all vdpau-driver-all
apt-get $APT_PROXY -y install openjdk-17-jre-headless
apt-get $APT_PROXY -y --install-recommends install ffmpeg
apt-get $APT_PROXY -y install x11vnc
apt-get $APT_PROXY -y install sudo
EOS

# google chrome
cp etc/apt/sources.list.d/google-chrome.list $ROOTFS/etc/apt/sources.list.d/
lxc-attach -n $MACH -- zsh <<EOS
set -e
wget -T 30 -qO /tmp/google-chrome.gpg.key \
    https://dl.google.com/linux/linux_signing_key.pub
cat /tmp/google-chrome.gpg.key | gpg --dearmor \
    >/usr/share/keyrings/google-chrome.gpg
apt-get $APT_PROXY update
EOS

lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get $APT_PROXY -y --install-recommends install google-chrome-stable
apt-mark hold google-chrome-stable
EOS

# fix overwritten google-chrome sources list by recopying it
# google tries to add its key as a globally trusted one, limit its permissions
cp etc/apt/sources.list.d/google-chrome.list $ROOTFS/etc/apt/sources.list.d/

lxc-attach -n $MACH -- zsh <<EOS
set -e
rm -f /etc/apt/trusted.gpg.d/google-chrome.*
apt-get $APT_PROXY update
EOS

# chromedriver
lxc-attach -n $MACH -- zsh <<EOS
set -e
CHROME_VER=\$(dpkg -s google-chrome-stable | egrep "^Version" | \
    cut -d " " -f2 | cut -d. -f1-3)
CHROMELAB_LINK="https://googlechromelabs.github.io/chrome-for-testing"
CHROMEDRIVER_LINK=\$(curl -s \
    \$CHROMELAB_LINK/known-good-versions-with-downloads.json | \
    jq -r ".versions[].downloads.chromedriver | select(. != null) | .[].url" | \
    grep linux64 | grep "\$CHROME_VER" | tail -1)
wget -T 30 -qO /tmp/chromedriver-linux64.zip \$CHROMEDRIVER_LINK
unzip -o /tmp/chromedriver-linux64.zip -d /tmp
mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/
chmod 755 /usr/local/bin/chromedriver
EOS

# pjsua related
lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get $APT_PROXY -y install libv4l-0
EOS

# jibri
cp etc/apt/sources.list.d/jitsi-stable.list $ROOTFS/etc/apt/sources.list.d/
lxc-attach -n $MACH -- zsh <<EOS
set -e
wget -T 30 -qO /tmp/jitsi.gpg.key https://download.jitsi.org/jitsi-key.gpg.key
cat /tmp/jitsi.gpg.key | gpg --dearmor >/usr/share/keyrings/jitsi.gpg
apt-get $APT_PROXY update
EOS

lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive

[[ -z "$JIBRI_VERSION" ]] && \
    apt-get $APT_PROXY -y install jibri || \
    apt-get $APT_PROXY -y install jibri=$JIBRI_VERSION

apt-mark hold jibri
EOS

# removed packages
lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get -y purge upower
EOS

# ------------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# ------------------------------------------------------------------------------
# disable ssh service
lxc-attach -n $MACH -- zsh <<EOS
set -e
systemctl stop ssh.service
systemctl disable ssh.service
EOS

# google chrome managed policies
mkdir -p $ROOTFS/etc/opt/chrome/policies/managed
cp etc/opt/chrome/policies/managed/$TAG-policies.json \
    $ROOTFS/etc/opt/chrome/policies/managed/

# sudo
cp etc/sudoers.d/jibri $ROOTFS/etc/sudoers.d/
chmod 440 $ROOTFS/etc/sudoers.d/jibri

# ------------------------------------------------------------------------------
# JIBRI
# ------------------------------------------------------------------------------
cp $ROOTFS/etc/jitsi/jibri/xorg-video-dummy.conf \
    $ROOTFS/etc/jitsi/jibri/xorg-video-dummy.conf.org
cp $ROOTFS/etc/jitsi/jibri/pjsua.config $ROOTFS/etc/jitsi/jibri/pjsua.config.org
cp $ROOTFS/opt/jitsi/jibri/pjsua.sh $ROOTFS/opt/jitsi/jibri/pjsua.sh.org
cp $ROOTFS/opt/jitsi/jibri/finalize_sip.sh \
    $ROOTFS/opt/jitsi/jibri/finalize_sip.sh.org
cp $ROOTFS/home/jibri/.asoundrc $ROOTFS/home/jibri/.asoundrc.org

# resolution 1280x720
lxc-attach -n $MACH -- zsh <<EOS
set -e
sed -ri 's/^(\s*)Modes "1920/\1#Modes "1920/' \
    /etc/jitsi/jibri/xorg-video-dummy.conf
sed -ri 's/^(\s*)#Modes "1280/\1Modes "1280/' \
    /etc/jitsi/jibri/xorg-video-dummy.conf
EOS

# xorg DISPLAY :1
cp etc/systemd/system/sip-xorg.service \
    $ROOTFS/etc/systemd/system/sip-xorg.service
lxc-attach -n $MACH -- zsh <<EOS
set -e
systemctl daemon-reload
systemctl enable sip-xorg.service
EOS

# icewm DISPLAY :1
cp etc/systemd/system/sip-icewm.service \
    $ROOTFS/etc/systemd/system/sip-icewm.service
lxc-attach -n $MACH -- zsh <<EOS
set -e
systemctl daemon-reload
systemctl enable sip-icewm.service
EOS

# jibri groups
lxc-attach -n $MACH -- zsh <<EOS
set -e
chsh -s /usr/bin/bash jibri
usermod -aG adm,audio,video,plugdev jibri
chown jibri:jibri /home/jibri
EOS

# jibri, icewm
mkdir -p $ROOTFS/home/jibri/.icewm
cp home/jibri/.icewm/theme $ROOTFS/home/jibri/.icewm/
cp home/jibri/.icewm/prefoverride $ROOTFS/home/jibri/.icewm/
cp home/jibri/.icewm/startup $ROOTFS/home/jibri/.icewm/
chmod 755 $ROOTFS/home/jibri/.icewm/startup

# pki
if [[ -f /root/.ssh/jms-CA.crt ]]; then
    cp /root/.ssh/jms-CA.crt $ROOTFS/usr/local/share/ca-certificates/
fi

lxc-attach -n $MACH -- zsh <<EOS
set -e
update-ca-certificates

mkdir -p /home/jibri/.pki/nssdb
chmod 700 /home/jibri/.pki
chmod 700 /home/jibri/.pki/nssdb

if [[ -f "/usr/local/share/ca-certificates/jms-CA.crt" ]]; then
    certutil -A -n 'jitsi' -i /usr/local/share/ca-certificates/jms-CA.crt \
        -t 'TCu,Cu,Tu' -d sql:/home/jibri/.pki/nssdb/
fi

chown jibri:jibri /home/jibri/.pki -R
EOS

# jibri config
cp etc/jitsi/jibri/jibri.conf $ROOTFS/etc/jitsi/jibri/
sed -i "s/___JITSI_FQDN___/$JITSI_FQDN/" $ROOTFS/etc/jitsi/jibri/jibri.conf
sed -i "s/___JIBRI_PASSWD___/$JIBRI_PASSWD/" $ROOTFS/etc/jitsi/jibri/jibri.conf
sed -i "s/___JIBRI_SIP_PASSWD___/$JIBRI_SIP_PASSWD/" \
    $ROOTFS/etc/jitsi/jibri/jibri.conf

# asoundrc
cp home/jibri/.asoundrc $ROOTFS/home/jibri/

# sip ephemeral config service
cp usr/local/sbin/sip-ephemeral-config $ROOTFS/usr/local/sbin/
chmod 744 $ROOTFS/usr/local/sbin/sip-ephemeral-config
cp etc/systemd/system/sip-ephemeral-config.service \
    $ROOTFS/etc/systemd/system/

lxc-attach -n $MACH -- zsh <<EOS
set -e
systemctl daemon-reload
systemctl enable sip-ephemeral-config.service
EOS

# jibri service
lxc-attach -n $MACH -- zsh <<EOS
set -e
systemctl enable jibri.service
systemctl start jibri.service
EOS

# jibri, vnc
lxc-attach -n $MACH -- zsh <<EOS
set -e
mkdir -p /home/jibri/.vnc
x11vnc -storepasswd jibri /home/jibri/.vnc/passwd
chown jibri:jibri /home/jibri/.vnc -R
EOS

# jibri, Xdefaults
cp home/jibri/.Xdefaults $ROOTFS/home/jibri/
lxc-attach -n $MACH -- zsh <<EOS
set -e
chown jibri:jibri /home/jibri/.Xdefaults
EOS

# ------------------------------------------------------------------------------
# VIRTUAL CAMERAS
# ------------------------------------------------------------------------------
cp etc/systemd/system/virtual-camera-0.service $ROOTFS/etc/systemd/system/
cp etc/systemd/system/virtual-camera-1.service $ROOTFS/etc/systemd/system/
lxc-attach -n $MACH -- systemctl daemon-reload

# ------------------------------------------------------------------------------
# PJSUA
# ------------------------------------------------------------------------------
mv /root/pjsua $ROOTFS/usr/local/bin/pjsua
chmod 755 $ROOTFS/usr/local/bin/pjsua

# pjsua config
if [[ -f "/root/pjsua.config" ]]; then
    cp /root/pjsua.config $ROOTFS/etc/jitsi/jibri/
else
    cp etc/jitsi/jibri/pjsua.config $ROOTFS/etc/jitsi/jibri/
fi

# pjsua scripts
cp opt/jitsi/jibri/pjsua.sh $ROOTFS/opt/jitsi/jibri/pjsua.sh
cp opt/jitsi/jibri/finalize_sip.sh $ROOTFS/opt/jitsi/jibri/finalize_sip.sh

# fake google-chrome
cp usr/local/bin/google-chrome $ROOTFS/usr/local/bin/
chmod 755 $ROOTFS/usr/local/bin/google-chrome

# ------------------------------------------------------------------------------
# CONTAINER SERVICES
# ------------------------------------------------------------------------------
lxc-attach -n $MACH -- systemctl stop jibri-xorg.service
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED

# ------------------------------------------------------------------------------
# CLEAN UP
# ------------------------------------------------------------------------------
find $ROOTFS/var/log/jitsi -type f -delete

# ------------------------------------------------------------------------------
# ON HOST
# ------------------------------------------------------------------------------
systemctl daemon-reload
systemctl enable sip-ephemeral-container.service

[[ "$DONT_RUN_COMPONENT_SIDECAR" = true ]] && \
    systemctl start sip-ephemeral-container.service || \
    true
