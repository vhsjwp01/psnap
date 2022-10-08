#!/bin/bash
#set -x

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
TERM="vt100"
export TERM PATH

# VARIABLE REPLACEMENT
echo

my_nics=$(ifconfig -a | awk -F':' '/^[a-z]/ {print $1}')

nics=(${my_nics})

while [ -z "${uplink_nic_index}" ]; do
    read -p "Select the Uplink Network Interface: " uplink_nic_index

    if [ -z "${nics[$uplink_nic_index]}" ]; then
        uplink_nic_index=""
        echo "    invalid choice ... please choose again"
        echo
    fi

done

uplink_nic="${nics[$uplink_nic_index]}"

echo

while [ -z "${wifi_nic_index}" ]; do
    read -p "Select the WIFI Network Interface: " wifi_nic_index

    if [ -z "${nics[$wifi_nic_index]}" ]; then
        wifi_nic_index=""
        echo "    invalid choice ... please choose again"
        echo
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

            radio_vifs)
                ap_hw_mode="g"
                ap_passphrase=$(echo -ne "${wifi_pass_phrase}" | base64)
                frequency="2.4"
                iw_device_index=$(iw ${raw_wifi_nic} info | awk '/wiphy/ {print $NF}')
                physical_radio_device="phy${iw_device_index}"

                let supports_5GHz=$(iw ${iw_phy_device} info | egrep -c "* 5[0-9]* .* \[[0-9]*\]")

                if [ ${supports_5GHz=} -gt 0 ]; then
                    ap_hw_mode="a"
                    frequency="5.0"
                fi

                radio_vif="radio${iw_device_infex}-${frequency}"
                ap_bridge="$(echo "${ap_ssid}" | tr '[A-Z]' '[a-z]' | sed -e 's|[_-]| |g' -e 's|  *| |g' -e 's|\([a-z]\)[a-z]\?$|\1|g' -e 's|\([a-z]\)[a-z]* |\1|g')-bridge"

                # <physical_radio_device>:<radio_vif>:<ap_bridge>:<ap_ssid>:<ap_hw_mode>:<ap_channel>:<ap_passphrase base64 encoded>
                copy_command="cp '${overlay_file}' '${target_path}/${target_file}' && echo '${physical_radio_device}:${radio_vif}:${ap_bridge}:${ap_ssid}:0:${ap_passphrase}' >> '${target_path}/${target_file}'"
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

exit 0


## NOTES
#
## This gets executed as-is ... no replacement needed
#./overlay/etc/rc.local
#
## These are templates ... no replacement needed
#./overlay/etc/default/hostapd-systemd.template
#./overlay/etc/default/hostapd.x.x.template
