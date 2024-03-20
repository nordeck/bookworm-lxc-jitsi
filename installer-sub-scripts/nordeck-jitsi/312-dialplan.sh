# ------------------------------------------------------------------------------
# DIALPLAN.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="$TAG-dialplan"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/$TAG-jitsi | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30$(printf %03d ${IP##*.})"
echo DIALPLAN="$IP" >> $INSTALLER/000-source

# ------------------------------------------------------------------------------
# NFTABLES RULES
# ------------------------------------------------------------------------------
# the public ssh
nft delete element $TAG-nat tcp2ip { $SSH_PORT } 2>/dev/null || true
nft add element $TAG-nat tcp2ip { $SSH_PORT : $IP }
nft delete element $TAG-nat tcp2port { $SSH_PORT } 2>/dev/null || true
nft add element $TAG-nat tcp2port { $SSH_PORT : 22 }

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_DIALPLAN" = true ]] && exit

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

# Start options
lxc.start.auto = 1
lxc.start.order = 312
lxc.start.delay = 2
lxc.group = $TAG-group
lxc.group = onboot
EOF

# container network
cp $MACHINE_COMMON/etc/systemd/network/eth0.network $ROOTFS/etc/systemd/network/
sed -i "s/___IP___/$IP/" $ROOTFS/etc/systemd/network/eth0.network
sed -i "s/___GATEWAY___/$HOST/" $ROOTFS/etc/systemd/network/eth0.network

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
apt-get $APT_PROXY -y install unzip git
EOS

# ------------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# ------------------------------------------------------------------------------
# deno
lxc-attach -n $MACH -- zsh <<EOS
set -e
cd /tmp
wget -T 30 -O deno.zip \
    https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip
unzip -o deno.zip
cp /tmp/deno /usr/local/bin/
deno --version
EOS

# ------------------------------------------------------------------------------
# DIALPLAN
# ------------------------------------------------------------------------------
# dialplan user
lxc-attach -n $MACH -- zsh <<EOS
set -e
adduser dialplan --system --group --disabled-password --shell /bin/zsh \
    --home /home/dialplan
EOS

cp $MACHINE_COMMON/home/user/.tmux.conf $ROOTFS/home/dialplan/
cp $MACHINE_COMMON/home/user/.zshrc $ROOTFS/home/dialplan/
cp $MACHINE_COMMON/home/user/.vimrc $ROOTFS/home/dialplan/

lxc-attach -n $MACH -- zsh <<EOS
set -e
chown dialplan:dialplan /home/dialplan/.tmux.conf
chown dialplan:dialplan /home/dialplan/.vimrc
chown dialplan:dialplan /home/dialplan/.zshrc
EOS

# application
lxc-attach -n $MACH -- zsh <<EOS
set -e
su -l dialplan <<EOSS
    set -e
    git clone https://github.com/jitsi-contrib/sip-dial-plan.git app
EOSS
EOS

sed -i "/HOSTNAME/ s~\".*\"~\"0.0.0.0\"~" \
    $ROOTFS/home/dialplan/app/config.ts
sed -i "/TOKEN_SECRET/ s~\".*\"~\"$APP_SECRET\"~" \
    $ROOTFS/home/dialplan/app/config.ts

# systemd
cp etc/systemd/system/dialplan.service $ROOTFS/etc/systemd/system/

lxc-attach -n $MACH -- zsh <<EOS
set -e
systemctl daemon-reload
systemctl enable dialplan.service
systemctl start dialplan.service
EOS

# ------------------------------------------------------------------------------
# CONTAINER SERVICES
# ------------------------------------------------------------------------------
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING

# wait for the network to be up
for i in $(seq 0 9); do
    lxc-attach -n $MACH -- ping -c1 host.loc && break || true
    sleep 1
done
