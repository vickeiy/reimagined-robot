#!/bin/sh


if [ $# != 4 ]; then
	echo "Usage: netgear_firmware_upgrade.sh <Host> <Password of Host> <firmware filename> <TFTP server IP>"
	exit 0
else
	sshpass -p "$2" ssh root@$1 "/usr/local/bin/firmware-upgrade-tftp $3 $4"
fi
