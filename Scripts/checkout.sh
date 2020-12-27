#!/bin/sh
err()
{
        if [ $1 != 0 ]; then
                exit 0
        fi
}

echo "Downloading firmware"
sshpass -p "selva" scp -r svelmuruga@10.120.161.179:/home/svelmuruga/vgit/sw/releases/wnd930/rc/sdk/build/images/CAPRICORN/wnd930_firmware.tar /tftpboot/
err $?
echo "Upgrading firmware in 192.168.100.145"
sh /home/vchn076/script/netgear_firmware_upgrade.sh 192.168.100.145 password wnd930_firmware.tar 192.168.101.103
echo "Upgrading firmware in 192.168.100.193"
sh /home/vchn076/script/netgear_firmware_upgrade.sh 192.168.100.193 password wnd930_firmware.tar 192.168.101.103

