# ------------------------------------------------------------------------------
# JITSI-CUSTOMIZATION.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="$TAG-jitsi-host"
cd $MACHINES/$MACH

JITSI_ROOTFS="/var/lib/lxc/$TAG-jitsi/rootfs"
CONFIG_JS="$JITSI_ROOTFS/etc/jitsi/meet/$JITSI_FQDN-config.js"

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_JITSI_CUSTOMIZATION" = true ]] && exit

echo
echo "------------------- JITSI CUSTOMIZATION -------------------"

# ------------------------------------------------------------------------------
# CONFIG.JS
# ------------------------------------------------------------------------------
# recording
cat $MACHINES/$TAG-jitsi/etc/jitsi/meet/config.recording.js >> $CONFIG_JS

# livestreaming
cat $MACHINES/$TAG-jitsi/etc/jitsi/meet/config.livestreaming.js >> $CONFIG_JS

# hidden domain
cat $MACHINES/$TAG-jitsi/etc/jitsi/meet/config.hiddendomain.js >> $CONFIG_JS

# whiteboard
cat $MACHINES/$TAG-jitsi/etc/jitsi/meet/config.whiteboard.js >> $CONFIG_JS

# prefer bosh
cat $MACHINES/$TAG-jitsi/etc/jitsi/meet/config.preferbosh.js >> $CONFIG_JS

# UI customizations
cat $MACHINES/$TAG-jitsi/etc/jitsi/meet/config.ui.js >> $CONFIG_JS

# Dynamic branding
cat $MACHINES/$TAG-jitsi/etc/jitsi/meet/config.branding.js >> $CONFIG_JS
cp $MACHINES/$TAG-jitsi/usr/share/jitsi-meet/static/branding.json \
    $JITSI_ROOTFS/usr/share/jitsi-meet/static/

# guest domain
cat $MACHINES/$TAG-jitsi/etc/jitsi/meet/config.guest.js >> $CONFIG_JS

# dialplan
if [[ "$DONT_RUN_DIALPLAN" != true ]]; then
    cat $MACHINES/$TAG-jitsi/etc/jitsi/meet/config.dialplan.js >> $CONFIG_JS
fi

# substitutions
sed -i "s/___JITSI_FQDN___/$JITSI_FQDN/" $CONFIG_JS

# ------------------------------------------------------------------------------
# CUSTOMIZATION FOLDER & TOOLS
# ------------------------------------------------------------------------------
FOLDER="/root/jitsi-customization"

# is there an old customization folder?
if [[ -d "/root/jitsi-customization" ]]; then
    FOLDER="/root/jitsi-customization-new"
    rm -rf $FOLDER

    echo "There is already an old customization folder."
    echo "A new folder will be created as $FOLDER"
fi

cp -arp root/jitsi-customization $FOLDER

sed -i "s/___TURN_FQDN___/$TURN_FQDN/g" $FOLDER/README.md
sed -i "s/___JITSI_FQDN___/$JITSI_FQDN/g" $FOLDER/README.md
sed -i "s/___TURN_FQDN___/$TURN_FQDN/g" $FOLDER/customize.sh
sed -i "s/___JITSI_FQDN___/$JITSI_FQDN/g" $FOLDER/customize.sh

mkdir -p $FOLDER/files
cp $CONFIG_JS $FOLDER/files/
cp $JITSI_ROOTFS//usr/share/jitsi-meet/interface_config.js $FOLDER/files/
cp $JITSI_ROOTFS/usr/share/jitsi-meet/images/favicon.svg $FOLDER/files/
cp $JITSI_ROOTFS/usr/share/jitsi-meet/images/watermark.svg $FOLDER/files/
