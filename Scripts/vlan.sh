#modprobe 8021q
#vconfig add eth0 100
ifconfig eth0 10.42.0.1 netmask 255.255.255.224 up
#ifconfig eth0.100 10.5.5.1 netmask 255.255.255.224 up
killall dhcpd
dhcpd eth0 #eth0.100
