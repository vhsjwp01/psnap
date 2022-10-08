#!/bin/bash
#set -x

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
TERM="vt100"
export TERM PATH

# Install available needed things from default repo(s)
utilities="          \
    bc               \
    bridge-utils     \
    coreutils        \
    curl             \
    ethtool          \
    git              \
    gnupg            \
    gnupg1           \
    gnupg2           \
    hostapd          \
    htop             \
    iftop            \
    ifupdown         \
    iotop            \
    iptables         \
    isc-dhcp-server  \
    iw               \
    jq               \
    lsb-release      \
    net-tools        \
    ntp              \
    ntpdate          \
    openssh-server   \
    rsync            \
    screen           \
    sudo             \
    uuid-runtime     \
    vim              \
    wget             \
    wireless-tools"

echo "Updating apt source manifests"
apt update -qq > /dev/null 2>&1

echo "Installing needed packages"
apt install -y ${utilities} > /dev/null 2>&1

# Turn off unwanted services
unwanted_services="
    systemd-networkd.socket
    systemd-networkd
    networkd-dispatcher
    systemd-networkd-wait-online \
    systemd-resolved
    network-manager
    networking
    wpa_supplicant
    hostapd"

echo "Turning off unwanted services"

for i in ${unwanted_services} ; do
    systemctl stop ${i} > /dev/null 2>&1
    systemctl disable ${i} > /dev/null 2>&1
done

# Turn off graphical login and boot
echo "Disabling graphical boot"
systemctl set-default multi-user > /dev/null 2>&1
sed -i -e 's|\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)splash\(.*\)$|\1\2|g' /etc/default/grub > /dev/null 2>&1
update-grub > /dev/null 2>&1

# uninstall unneeded things
unneeded_services=" \
    openresolv      \
    dhcpcd5         \
    plymouth        \
    netplan.io"

echo "Uninstalling unneeded resources"

for i in ${unneeded_services} ; do
    apt remove -y ${i} > /dev/null 2>&1
    apt purge -y ${i} > /dev/null 2>&1
done

# Delete unneeded things
unneeded_things="
    /usr/share/plymouth                       \
    /etc/dhcp/dhclient-enter-hooks.d/resolved \
    /etc/resolv*"

echo "Deleting unneeded resources"

for i in ${unneeded_things} ; do
    eval "rm -rf ${i}" > /dev/null 2>&1
done

exit 0
