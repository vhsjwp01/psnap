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
    let counter=0

    for nic in ${nics[*]} ; do
        echo "    ${counter}: ${nic}"
        let counter+=1
    done

    echo
    read -p "Select the Uplink Network Interface: " uplink_nic_index
    uplink_nic_index=$(echo "${uplink_nic_index=}" | sed -e 's|[^0-9]||g')

    if [ -n "${uplink_nic_index}" ]; then

        if [ 0 -le ${uplink_nic_index} -a ${uplink_nic_index} -le ${#nics[*]} ]; then
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
                ap_channel="0"
                ap_hw_mode="g"
                ap_passphrase=$(echo -ne "${wifi_pass_phrase}" | base64)
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
                                ;;

                                2)
                                    ap_hw_mode="a"
                                    frequency="5.0"
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

                radio_vif="radio${iw_device_index}-${frequency}"
                ap_bridge="$(hostname | awk -F'.' '{print $1}')-bridge"

                # <physical_radio_device>:<radio_vif>:<ap_bridge>:<ap_ssid>:<ap_hw_mode>:<ap_channel>:<ap_passphrase base64 encoded>
                copy_command="cp '${overlay_file}' '${target_path}/${target_file}' && echo '${physical_radio_device}:${radio_vif}:${ap_bridge}:${ap_ssid}:${ap_hw_mode}:${ap_channel}:${ap_passphrase}' >> '${target_path}/${target_file}'"
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

if [ -e /lib/systemd/system/rc-local-psnap.service ]; then
    echo "  Enabling rc.local PSNAP edition"
    systemctl enable rc-local-psnap


    echo
    echo "Please reboot this node for the WiFi to start up properly"
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
