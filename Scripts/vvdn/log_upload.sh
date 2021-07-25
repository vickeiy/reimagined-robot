#!/bin/sh
trap "exit" INT
cnt=1
MAX_VAP="0 1 2 3 4 5 6 7"
mkdir -p /tmp/log/
err()
{
	if [ $1 != 0 ]; then
		exit
	fi
}
collect()
{
	cp -r /var/log/messa* /tmp/log/
	dmesg > /tmp/log/dmesg
	ps > /tmp/log/ps
	ping -W 1 -c 2 google.com > /tmp/log/ping
	err $?
	echo "" > /tmp/log/sta
	for i in $MAX_VAP
	do
        	echo "wifi0vap$i"  >> /tmp/log/sta
		/usr/local/bin/wlanconfig wifi0vap$i list sta >> /tmp/log/sta
		err $?
	done
	cp /var/pal.cfg  /tmp/log/pal.cfg
	err $?
	cp /etc/resolv.conf /tmp/log/resolv.conf
	err $?
	cp /var/config  /tmp/log/config
	err $?
	ifconfig > /tmp/log/ifconfig
	err $?
}
upload()
{
	cd /tmp/
	tar -cvf log$cnt.tar log
	err $?
	tftp -p 192.168.101.103 -l log$cnt.tar
	err $?
}
cleanup()
{
	rm -rf /tmp/log$cnt.tar
	rm -rf /tmp/log/*
	let "cnt++"
}
while [ 1 ]
do
        collect
	upload
	cleanup
        sleep 3
done


