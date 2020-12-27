#!/bin/bash
OUTPUT="junk"
cnt=0



protocol_checklist()
{
	PROTOCOL=$(whiptail --title "Test Checklist Dialog" --checklist \
		"Choose preferred protocol must allowed" 15 60 6 \
		"dhcp" "DHCP protocol" ON \
		"icmp" "ICMP protocol" OFF \
		"dns" "DNS protocol" OFF \
		"tcp" "TCP protocol" OFF \
		"udp" "TCP protocol" OFF \
		"http" "HTTP protocol" OFF \
		"https" "HTTPS protocol" OFF \
		"ntp" "NTP protocol" OFF 3>&1 1>&2 2>&3)
 
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
	    echo "Your favorite distros are:" $PROTOCOL
	else
	    echo "You chose Cancel."
	fi
	OUTPUT=$PROTOCOL
	for i in $OUTPUT
	do
		let "cnt++"
	done
}
install()
{
	inc=100/$cnt
	{    
	for ((i = 0 ; i <= 100 ; i+=$inc)); do
        	sleep 1
	        echo $i
    	done
	} | whiptail --gauge "Please wait while installing" 6 60 0
	echo "100" | whiptail --gauge "Please wait while installing" 6 60 0
}

protocol_checklist
echo "Installing configuration"
install
