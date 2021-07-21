#!/bin/bash
#set -x

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
TERM="vt100"
export TERM PATH

my_disks=$(fdisk -l | egrep "^Disk \/" | awk -F':' '{print $1}' | awk -F'/' '{print $NF}')

for my_disk in ${my_disks} ; do
    is_rotational=$(lsblk -d -o name,rota | egrep "^\b${my_disk}\b" | awk '{print $NF}' | sed -e 's|^0$|no|g' -e 's|^1$|yes|g')
    scheduler_command=""
    scheduler_target="/sys/block/${my_disk}/queue/scheduler"

    scheduler_choices=$(cat "${scheduler_target}" | sed -e 's|\[||g' -e 's|\]||g')

    rotational_mode=$(for i in ${scheduler_choices} ; do echo "${i}" ; done | egrep "deadline")
    solid_state_mode=$(for i in ${scheduler_choices} ; do echo "${i}" ; done | egrep "none|noop")

    case "${is_rotational}" in

        yes)
            scheduler_type="${rotational_mode}"
        ;;

        no)
            scheduler_type="${solid_state_mode}"
        ;;

    esac

    if [ ! -z "${scheduler_type}" ]; then
        echo "${scheduler_type}" > "${scheduler_target}"
    fi

    done

exit 0

