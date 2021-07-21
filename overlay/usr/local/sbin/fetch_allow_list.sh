#!/bin/bash
#set -x

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
TERM="vt100"
export TERM PATH

conf_file="/etc/mac_allow_list/mac_allow_list.conf"

temp_config="/tmp/mac_addresses.allow.$$"
mac_address_allow="/etc/hostapd/mac_addresses.allow"

radio_vif_config="/etc/default/radio_vifs"
radio_vifs=$(egrep -v "^#" "${radio_vif_config}" | awk -F':' '{print $2}')

if [ -e "${conf_file}" ]; then
    . "${conf_file}"
fi

if [ "${1}" = "debug" ]; then
    debug="echo"
fi

if [ ! -z "${db_connection_string}" ]; then
    sleep $(echo "${RANDOM}%30" | bc)
    encoded_db_uri=$(echo -n "${db_connection_string}" | base64 -w 0)
    encoded_query=$(echo -n "${db_query}" | base64 -w 0)

    mac_addresses=$(echo -ne "${encoded_db_uri}\n${encoded_query}\n" | nc ${db_host} ${db_port} 2> /dev/null)

    if [ "${1}" = "showlist" -o "${2}" = "showlist" ]; then
        echo "MAC Addresses Allowed:"

        for mac_address in ${mac_addresses} ; do
            echo "${mac_address}"
        done

    else

        if [ ! -z "${mac_addresses}" ]; then
            rm -f "${temp_config}" > /dev/null 2>&1
    
            for mac_address in ${mac_addresses} ; do
                echo "${mac_address}" | tr '[A-Z]' '[a-z]' >> "${temp_config}"
            done
    
            let mac_list_count=$(egrep -c "^[0-9a-f]*:[0-9a-f]*:[0-9a-f]*:[0-9a-f]*:[0-9a-f]*:[0-9a-f]*$" "${temp_config}" 2> /dev/null || echo "0")
    
            if [ -s "${temp_config}" -a ${mac_list_count} -gt 0 ]; then
                diff -iq "${temp_config}" "${mac_address_allow}" > /dev/null 2>&1
    
                if [ ${?} -ne 0 ]; then
                    ${debug} mv "${temp_config}" "${mac_address_allow}"

                    for radio_vif in ${radio_vifs} ; do
                        hostapd_service=$(echo "${radio_vif}" | sed -e 's|\.||g')
                        ${debug} systemctl restart hostapd-${hostapd_service}
                    done

                    echo "Changes detected"
                fi
    
            fi
    
        fi

    fi

fi

if [ -e "${temp_config}" ]; then
    ${debug} rm -f "${temp_config}" > /dev/null 2>&1
fi

exit 0
