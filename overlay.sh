#!/bin/bash
#set -x

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
TERM="vt100"
export TERM PATH

# VARIABLE REPLACEMENT
echo

ifconfig -a | awk -F':' '/^[a-z]/ {print $1}'

while [ -z "${uplink_nic}" ]; do
    read -p "Enter the Uplink NIC name: " uplink_nic
done

echo

while [ -z "${raw_wifi_nic}" ]; do
    read -p "Enter the RAW WIFI NIC name: " raw_wifi_nic
done

echo

# Find all files
this_dir=$(realpath -L $(dirname "${0}"))

if [ -d "${this_dir}/overlay" ]; then
    overlay_files=$(find "${this_dir}/overlay" -depth -type f 2> /dev/null)

    for overlay_file in ${overlay_files} ; do
        copy_command=""
        target_file=$(basename "${overlay_file}")
	target_path=$(dirname "${overlay_file}" | sed -e "s|^${this_dir}/overlay||g")

        if [ ! -e "${target_path}" ]; then
            mkdir -p "${target_path}"
        fi

        # Perform any variable substitution in line
        case ${target_file} in

            relevant_nics)
                copy_command="sed -e 's|::UPLINK_NIC::|${uplink_nic}|g' -e 's|::RAW_WIFI_NIC::|${raw_wifi_nic}|g' '${overlay_file}' > '${target_path}/${target_file}'"
            ;;

            *)
                copy_command="cp '${overlay_file}' '${target_path}/${target_file}'"
            ;;

        esac

        if [ -n "${copy_command}" ]; then
            eval "${copy_command}"
        fi

    done

fi


## NOTES
#
## This get executed as-is ... no replacement needed
#./overlay/etc/rc.local
#
## These are templates ... no replacement needed
#./overlay/etc/default/hostapd-systemd.template
#./overlay/etc/default/hostapd.template
#
## Needs to be replaced with values
#./overlay/etc/default/wifi_ap_config:bridge_ifname="::BRIDGE_IFNAME::"
#./overlay/etc/default/wifi_ap_config:bridge_ip="::BRIDGE_IP::"
#./overlay/etc/default/wifi_ap_config:bridge_gateway="::BRIDGE_GATEWAY::"
#./overlay/etc/default/wifi_ap_config:bridge_subnet="::BRIDGE_SUBNET::"
#
## Needs to be replaced with values
#./overlay/etc/mac_allow_list/mac_allow_list.conf:db="::MAC_ALLOW_DB::"
#./overlay/etc/mac_allow_list/mac_allow_list.conf:db_host="::DB_HOST::"
#./overlay/etc/mac_allow_list/mac_allow_list.conf:db_port="::DB_PORT::"
#./overlay/etc/mac_allow_list/mac_allow_list.conf:db_user="::DB_USER::"
#./overlay/etc/mac_allow_list/mac_allow_list.conf:db_password="::DB_PASSWORD::"
