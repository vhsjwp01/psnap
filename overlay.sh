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

wifi_creds="/etc/default/wifi_creds"
echo "${wifi_pass_phrase}" > "${wifi_creds}"
chmod 400 "${wifi_creds}"

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
                ap_channel=""
                ap_hw_mode="g"
                ap_passphrase=$(awk '{print $0}' "${wifi_creds}" | base64)
                frequency="2.4"
                iw_device_index=$(iw ${raw_wifi_nic} info | awk '/wiphy/ {print $NF}')
                physical_radio_device="phy${iw_device_index}"
                my_channels=$(iw phy ${physical_radio_device} info | egrep "* 2[0-9]* .* \[[0-9]*\]" | awk '{if ($NF != "detection)" && $NF != "(disabled)") print $4}' | sed -e 's|[^0-9]||g')

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
                                    my_channels=$(iw phy ${physical_radio_device} info | egrep "* (4|5)[0-9]* .* \[[0-9]*\]" | awk '{if ($NF != "detection)" && $NF != "(disabled)") print $4}' | sed -e 's|[^0-9]||g')
                                ;;

                                *)
                                    frequency_index=""
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
                copy_command="cp '${overlay_file}' '${target_path}/${target_file}' && echo '${physical_radio_device}:${radio_vif}:${ap_bridge}:${ap_ssid}:${ap_hw_mode}:${ap_channel}:${ap_passphrase}' >> '${target_path}/${target_file}'"

                # Put useful things in /etc/motd
                echo "WIFI Access Point ${hostname}"     >  /etc/motd
                echo "              SSID: ${ap_ssid}"    >> /etc/motd
                echo "         Frequency: ${frequency}"  >> /etc/motd
                echo "           Channel: ${ap_channel}" >> /etc/motd
                echo "    Hard Ware Mode: ${ap_hw_mode}" >> /etc/motd
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
    echo
    echo "Enabling rc.local PSNAP edition"
    systemctl enable rc-local-psnap > /dev/null 2>&1

    echo
    echo "Settings things up"
    /etc/rc.local

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
