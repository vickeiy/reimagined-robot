#!/bin/sh
config_wds()
{
	if [ $2 = "wpa2psk" ]; then
		ENC="aes"
	elif [ $2 = "wpapsk" ]; then
		ENC='tkip'
	else
		ENC=""
	fi
	echo "$ENC"
	ret=`/usr/sbin/cli config/interface/wlan/5GHz/channel 149`
	echo $ret
	ret=`/usr/sbin/cli config/interface/wlan/5GHz/operation-mode p2p-ap`
	echo $ret
	ret=`/usr/sbin/cli config/interface/wlan/5GHz/wireless-bridge/security-profile/1/remote-mac $3`
	echo $ret
	ret=`/usr/sbin/cli config/interface/wlan/5GHz/wireless-bridge/security-profile/1/authentication $2`
	echo $ret
	ret=`/usr/sbin/cli config/interface/wlan/5GHz/wireless-bridge/security-profile/1/encryption $ENC`
	echo $ret
	ret=`/usr/sbin/cli config/interface/wlan/5GHz/wireless-bridge/security-profile/1/presharedkey 12345678`
	echo $ret
	ret=`/usr/sbin/cli config/interface/wlan/5GHz/wireless-bridge/security-profile/1/status enable`	
	echo $ret
}
if [ $1 = "CAPRICORN" ];
then
	config_wds $1 $2 $3
elif [ $1 = "WNDAP350" ];
then
	config_wds $1 $2 $3
else
	echo "sorry"
fi
