#!/bin/bash
#set -x

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
TERM="vt100"
export TERM PATH

let cpu_count=$(egrep -c "^processor.*:" /proc/cpuinfo)
let high_cpu=${cpu_count}+1

first_check="/tmp/uptime.first_check"
second_check="/tmp/uptime.second_check"
third_check="/tmp/uptime.third_check"

radio_vif_config="/etc/default/radio_vifs"
radio_vifs=$(egrep -v "^#" "${radio_vif_config}" | awk -F':' '{print $2}')

# Start the watchdog loop
while [ true ] ;do 
    let check_index=0
    this_uptime=$(uptime | awk -F':' '{print $NF}' | sed -e 's|,||g' | awk '{print $1}')

    # First off, let's make sure we have all of our uptime timestamped check files
    if [ ! -s "${first_check}" -a ${check_index} -eq 0 ]; then
        echo "$(date +%s):${this_uptime}" > "${first_check}"
        let check_index=${check_index}+1
    fi
    
    if [ ! -s "${second_check}" -a ${check_index} -eq 0 ]; then
        echo "$(date +%s):${this_uptime}" > "${second_check}"
        let check_index=${check_index}+1
    fi
    
    if [ ! -s "${third_check}" -a ${check_index} -eq 0 ]; then
        echo "$(date +%s):${this_uptime}" > "${third_check}"
        let check_index=${check_index}+1
    fi
    
    # Now let's figure out what to do this round
    if [ ${check_index} -eq 0 ]; then # All previous check files exist, time to weigh what to do
        sum_array=""
    
        # Average the last 3 uptimes with this one
        for i in /tmp/uptime.*_check ; do
    
            if [ -z "${sum_array}" ]; then
                sum_array="$(awk -F':' '{print $NF}' "${i}")"
            else
                sum_array="${sum_array} $(awk -F':' '{print $NF}' "${i}")"
            fi
    
        done
    
        let result=$(echo "scale=2;((${sum_array} ${this_uptime})/4)>${high_cpu}" | sed 's| |+|g' | bc)
    
        if [ ${result} -eq 1 ]; then
            echo "$(date) - stopping hostapd - current 1 minute uptime is ${this_uptime}" >> /var/log/hostapd_watchdog.log
            dmesg -c                                                                       > /var/log/dmesg.hostapd.restart.$(date +Y%m%d-%H%M%S).log

            for radio_vif in ${radio_vifs} ; do
                hostapd_service=$(echo "${radio_vif}" | sed -e 's|\.||g')
                hostapd_status=$(systemctl status hostapd-${hostapd_service} | egrep -i "^ *Active:" | awk '{print $2}')

                if [ "${hostapd_status}" != "active" ]; then
                    systemctl stop hostapd-${hostapd_service} > /dev/null 2>&1
                    sleep 2
                    echo "$(date) - restarting hostapd-${hostapd_service}" >> /var/log/hostapd_watchdog.log
                    systemctl start hostapd-${hostapd_service} > /dev/null 2>&1
                fi

            done

        fi
    
        # Reset all values
        mv "${second_check}" "${first_check}"
        mv "${third_check}" "${second_check}"
        echo "$(date +%s):${this_uptime}" > "${third_check}"
    fi

    sleep 60
done

exit 0
