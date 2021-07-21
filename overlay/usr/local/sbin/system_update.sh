#!/bin/bash
#set -x

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
TERM="vt100"
export TERM PATH

let sleep_time=${RANDOM}%60
sleep ${sleep_time}

this_os=$(uname -s | tr '[A-Z]' '[a-z]')
this_distro=$(lsb_release -is | tr '[A-Z]' '[a-z]')
this_model=$(egrep "^Model" /proc/cpuinfo | awk -F':' '{print $NF}' | awk '{print $1}' | tr '[A-Z]' '[a-z]')

case ${this_os} in 

    linux)

        case ${this_distro} in

            arch)
                pacman-key --init                  > /dev/null 2>&1 &&
                pacman-key --populate archlinuxarm > /dev/null 2>&1 &&
                pacman -Syu --noconfirm            > /dev/null 2>&1
            ;;

            debian|raspbian|ubuntu)
                export DEBIAN_FRONTEND="noninteractive"

                apt-get clean           > /dev/null 2>&1 &&
                apt-get update          > /dev/null 2>&1 &&
                apt-get upgrade -y      > /dev/null 2>&1 &&
                apt-get dist-upgrade -y > /dev/null 2>&1
            ;;

            *)
                echo "Unsupported OS distro: '${this_os}' - '${this_distro}'"
                /bin/false
            ;;

        esac

        if [ ${?} -eq 0 -a "${this_model}" = "raspberry" ]; then
            rpi-update <<<"y" > /dev/null 2>&1
        fi

        #reboot > /dev/null 2>&1
    ;;

    *)
        echo "Unsupported OS: '${this_os}'"
        /bin/false
    ;;

esac

exit ${?}

