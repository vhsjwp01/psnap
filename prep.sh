#!/bin/bash

# Install available needed things from default repo(s)
utilities="          \
    bc               \
    bridge-utils     \
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

apt update
apt install -y ${utilities}

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

for i in ${unwanted_services} ; do
    systemctl stop ${i}
    systemctl disable ${i}
done

# Turn off graphical login and boot
systemctl set-default multi-user
sed -i -e 's|\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)splash\(.*\)$|\1\2|g' /etc/default/grub
update-grub

# uninstall unneeded things
unneeded_services=" \
    openresolv      \
    dhcpcd5         \
    plymouth        \
    netplan.io"

for i in ${unneeded_services} ; do
    apt remove -y ${i}
    apt purge -y ${i}
done

# Delete unneeded things
unneeded_things="
    /usr/share/plymouth                       \
    /etc/dhcp/dhclient-enter-hooks.d/resolved \
    /etc/resolv*"

for i in ${unneeded_things} ; do
    eval "rm -rf ${i}"
done


