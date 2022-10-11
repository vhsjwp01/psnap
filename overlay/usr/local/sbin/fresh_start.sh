#!/bin/bash
#set -x

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
TERM="vt100"
export TERM PATH

# 1: Stop all hostapd instances
echo "Stopping all currently running hostapd instances"
hostapd_services=$(systemctl list-unit-files | egrep "hostapd-radio*enabled" | awk '{print $1}')

for hostapd_service in ${hostapd_services} ; do
    systemctl stop ${hostapd_service} > /dev/null 2>&1
done

# 2. Remove custom hostapd service files from /lib/systemd/system
echo "Removing custom hostapd service files"
rm -f /lib/systemd/system/hostapd-radio* > /dev/null 2>&1

# 3. Remove custom hostapd configuration files from /etc/hostapd
echo "Removing custom hostapd configuration files"
rm /etc/hostapd/hostapd-radio* > /dev/null 2>&1

# 4. Blank /etc/default/radio_vifs
echo "Purging virtual radio mappings"
sed -i /^phy[0-9].*$/d /etc/default/radio_vifs > /dev/null 2>&1

# 5. Remove the bridge
my_bridges=$(brctl show | egrep "^[a-z0-9]" | egrep -v "^bridge name" | awk '{print $1}' | sort -u)

for bridge in ${my_bridges} ; do
    bridge_members=$(brctl show ${bridge} | egrep -v "^bridge name" | awk '{print $NF}' | sort -u)

    for bridge_member in ${bridge_members} ; do
        brctl delif ${bridge} ${bridge_member} > /dev/null 2>&1
    done

    ifconfig ${bridge} down > /dev/null 2>&1
    brctl delbr ${bridge} > /dev/null 2>&1
done

# 6. Tear down all wifi related network devices
all_interfaces=$(ifconfig -a | egrep "^[a-z0-9]*:" | awk -F':' '{print $1}' | sort -u)
all_wifi_interfaces=""
all_bridge_interfaces=""

# tear down wifi aliases first
for interface in ${all_interfaces} ; do
    let is_wifi=$(iw ${interface} info 2> /dev/null | egrep -c "\bwiphy\b")

    if [ ${is_wifi} -gt 0 ]; then
        all_wifi_interfaces+="${interface} "
    fi

done

for wifi_interface in ${all_wifi_interfaces} ; do
    iw dev ${wifi_interface} delete > /dev/null 2>&1
done

# 7. Re-scan the usb buses
usb_sys_tree="/sys/bus/usb/drivers/usb"
my_usb_buses=$(ls -al ${usb_sys_tree}/usb* | awk -F '->' '{print $NF}' | awk -F'/' '{print $7}' | sort -u)

for usb_bus in ${my_usb_buses} ; do
    echo -n "${usb_bus}" > ${usb_sys_tree}/unbind > /dev/null 2>&1
    sleep 1
    echo -n "${usb_bus}" > ${usb_sys_tree}/bind > /dev/null 2>&1
done

# 8. Re-Run the setup
echo "Re-running WIFI setup"
echo

my_nics=$(ifconfig -a | awk -F':' '/^[a-z]/ {print $1}' | sort -u)

nics=(${my_nics})

while [ -z "${uplink_nic_index}" ]; do
    let counter=0

    for nic in ${nics[*]} ; do
        echo "    ${counter}: ${nic}"
        let counter+=1
    done

    echo
    read -p "Select the Uplink Network Interface: " uplink_nic_index
    uplink_nic_index=$(echo "${uplink_nic_index=}" | sed -e 's|[^0-9]||g')

    if [ -n "${uplink_nic_index}" ]; then

        if [ 0 -le ${uplink_nic_index} -a ${uplink_nic_index} -lt ${#nics[*]} ]; then
            true
        else
            uplink_nic_index=""
            echo "    invalid choice ... please choose again"
            echo
        fi

    else
        echo "    Uplink interface choice cannot be blank ... please choose again"
    fi

done

uplink_nic="${nics[$uplink_nic_index]}"

echo

while [ -z "${wifi_nic_index}" ]; do
    let counter=0

    for nic in ${nics[*]} ; do
        echo "    ${counter}: ${nic}"
        let counter+=1
    done

    echo
    read -p "Select the WIFI Network Interface: " wifi_nic_index
    wifi_nic_index=$(echo "${wifi_nic_index=}" | sed -e 's|[^0-9]||g')

    if [ -n "${wifi_nic_index}" ]; then

        if [ "${wifi_nic_index}" = "${uplink_nic_address}" ]; then
            wifi_nic_index=""
            echo "    Upload and WIFI interfaces cannot be the same"
            echo
        elif [ 0 -le ${uplink_nic_index} -a ${uplink_nic_index} -le ${#nics[*]} ]; then
            true
        else
            wifi_nic_index=""
            echo "    invalid choice ... please choose again"
            echo
        fi

    else
        echo "    WIFI interface choice cannot be blank ... please choose again"
    fi

done

raw_wifi_nic="${nics[$wifi_nic_index]}"

echo

while [ -z "${ap_ssid}" ]; do
    read -p "What SSID name would you like: " ap_ssid
done

echo

while [ -z "${wifi_pass_phrase}" ]; do
    read -p "Enter the WI-FI passphrase you want to use: " wifi_pass_phrase
done

# save the wifi creds to a rescue file
wifi_creds="/etc/default/wifi_creds"
echo "${wifi_pass_phrase}" > "${wifi_creds}"
chmod 400 "${wifi_creds}"

echo

# setup relevant nics
sed -e 's|^\(uplink_nic\)=.*$|\1=${uplink_nic}|g' -e 's|^\(raw_wifi_nic\)=.*$|\1=${raw_wifi_nic}|g' /etc/default/relevant_nics

ap_channel=""
ap_hw_mode="g"
ap_passphrase=$(awk '{print $0}' "${wifi_creds}" | base64)
frequency="2.4"
iw_device_index=$(iw ${raw_wifi_nic} info | awk '/wiphy/ {print $NF}')
physical_radio_device="phy${iw_device_index}"

let supports_5GHz=$(iw ${physical_radio_device} info | egrep -c "* 5[0-9]* .* \[[0-9]*\]")

if [ ${supports_5GHz} -gt 0 ]; then
    echo
    echo "This radio '${raw_wifi_nic}' supports both 2.4 GHz and 5.0 GHz operation"

    while [ -z "${frequency_index}" ]; do
        echo
        echo "    1: 2.4 GHz"
        echo "    2: 5.0 GHz"
        echo
        read -p "Select the operating band: " frequency_index
        frequency_index=$(echo "${frequency_index}" | sed -e 's|[^0-9]||g')

        if [ -n "${frequency_index}" ]; then

            case ${frequency_index} in

                1)
                    true
                    my_channels=$(iw phy phy0 info | egrep "* 2[0-9]* .* \[[0-9]*\]" | awk '{if ($NF != "detection)" && $NF != "(disabled)") print $4}' | sed -e 's|[^0-9]||g')
                ;;

                2)
                    ap_hw_mode="a"
                    frequency="5.0"
                    my_channels=$(iw phy phy0 info | egrep "* (4|5)[0-9]* .* \[[0-9]*\]" | awk '{if ($NF != "detection)" && $NF != "(disabled)") print $4}' | sed -e 's|[^0-9]||g')
                ;;

                *)
                    frequency_index==""
                    echo "    invalid choice ... please choose again"
                    echo
                ;;

            esac

        else
            echo "    Uplink interface choice cannot be blank ... please choose again"
        fi

    done

fi

channels=(${my_channels})

while [ -z "${ap_channel_index}" ]; do
    let counter=0
    echo

    for channel in ${channels[*]} ; do
        echo "    ${counter}: Channel ${channel}"
        let counter+=1
    done

    echo
    read -p "Select the operating band: " ap_channel_index
    ap_channel_index=$(echo "${ap_channel_index}" | sed -e 's|[^0-9]||g')

    if [ -n "${ap_channel_index}" ]; then

        if [ 0 -le ${ap_channel_index} -a ${ap_channel_index} -lt ${#channels[*]} ]; then
            true
        else
            ap_channel_index=""
            echo "    invalid choice ... please choose again"
            echo
        fi

    else
        echo "    AP channel selection cannot be blank ... please choose again"
    fi

done

ap_channel="${channels[$ap_channel_index]}"
radio_vif="radio${iw_device_index}-${frequency}"
short_hostname=$(hostname -s | tr '[A-Z]' '[a-z]')
ap_bridge="$(echo "${short_hostname}" | sed -e 's|[^a-z0-9]||g' | cut -c-8)-br"

# <physical_radio_device>:<radio_vif>:<ap_bridge>:<ap_ssid>:<ap_hw_mode>:<ap_channel>:<ap_passphrase base64 encoded>
echo '${physical_radio_device}:${radio_vif}:${ap_bridge}:${ap_ssid}:${ap_hw_mode}:${ap_channel}:${ap_passphrase}' >> /etc/default/radio_vifs

# Put useful things in /etc/motd
echo "WIFI Access Point ${hostname}"     >  /etc/motd
echo "              SSID: ${ap_ssid}"    >> /etc/motd
echo "         Frequency: ${frequency}"  >> /etc/motd
echo "           Channel: ${ap_channel}" >> /etc/motd
echo "    Hard Ware Mode: ${ap_hw_mode}" >> /etc/motd

exit 0

