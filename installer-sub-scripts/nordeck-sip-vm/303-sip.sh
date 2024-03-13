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

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_SIP" = true ]] && exit

echo
echo "-------------------------- $MACH --------------------------"

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

# update
apt-get $APT_PROXY update
apt-get $APT_PROXY -y dist-upgrade

# packages
apt-get $APT_PROXY -y install curl jq
apt-get $APT_PROXY -y install gnupg unzip unclutter
apt-get $APT_PROXY -y install libnss3-tools
apt-get $APT_PROXY -y install va-driver-all vdpau-driver-all
apt-get $APT_PROXY -y install openjdk-17-jre-headless
apt-get $APT_PROXY -y --install-recommends install ffmpeg
apt-get $APT_PROXY -y install x11vnc
apt-get $APT_PROXY -y install sudo

# google chrome
cp etc/apt/sources.list.d/google-chrome.list /etc/apt/sources.list.d/
wget -T 30 -qO /tmp/google-chrome.gpg.key \
    https://dl.google.com/linux/linux_signing_key.pub
cat /tmp/google-chrome.gpg.key | gpg --dearmor \
    >/usr/share/keyrings/google-chrome.gpg

apt-get $APT_PROXY update
apt-get $APT_PROXY -y --install-recommends install google-chrome-stable
apt-mark hold google-chrome-stable

# fix overwritten google-chrome sources list by recopying it
# google tries to add its key as a globally trusted one, limit its permissions
cp etc/apt/sources.list.d/google-chrome.list /etc/apt/sources.list.d/
rm -f /etc/apt/trusted.gpg.d/google-chrome.*
apt-get $APT_PROXY update

# chromedriver
CHROME_VER=$(dpkg -s google-chrome-stable | egrep "^Version" | \
    cut -d " " -f2 | cut -d "-" -f1)
CHROME_STORE="https://storage.googleapis.com/chrome-for-testing-public"
CHROMEDRIVER="$CHROME_STORE/${CHROME_VER}/linux64/chromedriver-linux64.zip"
wget -T 30 -qO /tmp/chromedriver-linux64.zip $CHROMEDRIVER

rm -rf /tmp/chromedriver-linux64
unzip -o /tmp/chromedriver-linux64.zip -d /tmp
mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/
chmod 755 /usr/local/bin/chromedriver

# pjsua related
apt-get $APT_PROXY -y install libv4l-0

# jibri
cp etc/apt/sources.list.d/jitsi-stable.list /etc/apt/sources.list.d/
wget -T 30 -qO /tmp/jitsi.gpg.key https://download.jitsi.org/jitsi-key.gpg.key
cat /tmp/jitsi.gpg.key | gpg --dearmor >/usr/share/keyrings/jitsi.gpg
apt-get $APT_PROXY update

[[ -z "$JIBRI_VERSION" ]] && \
    apt-get $APT_PROXY -y install jibri || \
    apt-get $APT_PROXY -y install jibri=$JIBRI_VERSION

apt-mark hold jibri

# removed packages
apt-get -y purge upower

# ------------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# ------------------------------------------------------------------------------
# google chrome managed policies
mkdir -p /etc/opt/chrome/policies/managed
cp etc/opt/chrome/policies/managed/$TAG-policies.json \
    /etc/opt/chrome/policies/managed/

# sudo
cp etc/sudoers.d/jibri.vm /etc/sudoers.d/jibri
chmod 440 /etc/sudoers.d/jibri

# ------------------------------------------------------------------------------
# JIBRI
# ------------------------------------------------------------------------------
cp /etc/jitsi/jibri/xorg-video-dummy.conf \
    /etc/jitsi/jibri/xorg-video-dummy.conf.org
cp /etc/jitsi/jibri/pjsua.config /etc/jitsi/jibri/pjsua.config.org
cp /opt/jitsi/jibri/pjsua.sh /opt/jitsi/jibri/pjsua.sh.org
cp /opt/jitsi/jibri/finalize_sip.sh /opt/jitsi/jibri/finalize_sip.sh.org
cp /home/jibri/.asoundrc /home/jibri/.asoundrc.org

# resolution 1280x720
sed -ri 's/^(\s*)Modes "1920/\1#Modes "1920/' \
    /etc/jitsi/jibri/xorg-video-dummy.conf
sed -ri 's/^(\s*)#Modes "1280/\1Modes "1280/' \
    /etc/jitsi/jibri/xorg-video-dummy.conf

# xorg DISPLAY :1
cp etc/systemd/system/sip-xorg.service /etc/systemd/system/sip-xorg.service
systemctl daemon-reload
systemctl enable sip-xorg.service

# icewm DISPLAY :1
cp etc/systemd/system/sip-icewm.service /etc/systemd/system/sip-icewm.service
systemctl daemon-reload
systemctl enable sip-icewm.service

# jibri groups
chsh -s /usr/bin/bash jibri
usermod -aG adm,audio,video,plugdev jibri
chown jibri:jibri /home/jibri

# jibri, icewm
mkdir -p /home/jibri/.icewm
cp home/jibri/.icewm/ringing.png /home/jibri/.icewm/
cp home/jibri/.icewm/theme /home/jibri/.icewm/
cp home/jibri/.icewm/prefoverride /home/jibri/.icewm/
cp home/jibri/.icewm/startup /home/jibri/.icewm/
chmod 755 /home/jibri/.icewm/startup

# pki
if [[ -f /root/.ssh/jms-CA.crt ]]; then
    cp /root/.ssh/jms-CA.crt /usr/local/share/ca-certificates/
fi

update-ca-certificates

mkdir -p /home/jibri/.pki/nssdb
chmod 700 /home/jibri/.pki
chmod 700 /home/jibri/.pki/nssdb

if [[ -f "/usr/local/share/ca-certificates/jms-CA.crt" ]]; then
    certutil -A -n 'jitsi' -i /usr/local/share/ca-certificates/jms-CA.crt \
        -t 'TCu,Cu,Tu' -d sql:/home/jibri/.pki/nssdb/
fi

chown jibri:jibri /home/jibri/.pki -R

# jibri config
cp etc/jitsi/jibri/jibri.conf /etc/jitsi/jibri/
sed -i "s/___JITSI_FQDN___/$JITSI_FQDN/" /etc/jitsi/jibri/jibri.conf
sed -i "s/___JIBRI_PASSWD___/$JIBRI_PASSWD/" /etc/jitsi/jibri/jibri.conf
sed -i "s/___JIBRI_SIP_PASSWD___/$JIBRI_SIP_PASSWD/" /etc/jitsi/jibri/jibri.conf

# asoundrc
cp home/jibri/.asoundrc /home/jibri/

# sip ephemeral config service
cp usr/local/sbin/sip-ephemeral-config.vm /usr/local/sbin/sip-ephemeral-config
chmod 744 /usr/local/sbin/sip-ephemeral-config
cp etc/systemd/system/sip-ephemeral-config.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable sip-ephemeral-config.service

# jibri service
systemctl enable jibri.service
systemctl start jibri.service

# jibri, vnc
mkdir -p /home/jibri/.vnc
x11vnc -storepasswd jibri /home/jibri/.vnc/passwd
chown jibri:jibri /home/jibri/.vnc -R

# jibri, Xdefaults
cp home/jibri/.Xdefaults /home/jibri/
chown jibri:jibri /home/jibri/.Xdefaults

# ------------------------------------------------------------------------------
# VIRTUAL CAMERAS
# ------------------------------------------------------------------------------
cp etc/systemd/system/virtual-camera-0.service.vm \
    /etc/systemd/system/virtual-camera-0.service
cp etc/systemd/system/virtual-camera-1.service.vm \
    /etc/systemd/system/virtual-camera-1.service
systemctl daemon-reload

# ------------------------------------------------------------------------------
# PJSUA
# ------------------------------------------------------------------------------
cp /root/meta/pjsua /usr/local/bin/pjsua
chmod 755 /usr/local/bin/pjsua

# pjsua config
if [[ -f "/root/meta/pjsua.config" ]]; then
    cp /root/meta/pjsua.config /etc/jitsi/jibri/
else
    cp etc/jitsi/jibri/pjsua.config /etc/jitsi/jibri/
fi

# pjsua scripts
cp opt/jitsi/jibri/pjsua.sh /opt/jitsi/jibri/pjsua.sh
cp opt/jitsi/jibri/finalize_sip.sh.vm /opt/jitsi/jibri/finalize_sip.sh

# fake google-chrome
cp usr/local/bin/google-chrome /usr/local/bin/
chmod 755 /usr/local/bin/google-chrome

# ------------------------------------------------------------------------------
# SERVICES
# ------------------------------------------------------------------------------
systemctl stop sip-xorg.service
systemctl stop jibri-xorg.service

find /var/log/jitsi -type f -delete

systemctl start sip-ephemeral-config.service
systemctl start jibri.service
