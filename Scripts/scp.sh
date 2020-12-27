#!/bin/sh
APLIST="660 360 350 320 210"

typeset -A APDIRS
APDIRS=(
    [210]=TAURUS
    [320]=LYRA
    [350]=WNDAP350
    [360]=WNDAP360
    [660]=WNDAP660
)
typeset -A APPATH
APPATH=(
    [210]=WNAP210v2
    [320]=WNAP320
    [350]=WNDAP350
    [360]=WNDAP360
    [660]=WNDAP660
)
typeset -A APFILELIST
APFILELIST=(
    [210]="wnap210_firmware.tar art.ko mdk_client.out"
    [320]="wnap320_firmware.tar art.ko mdk_client.out"
    [350]="wndap350_firmware.tar art.ko mdk_client.out"
    [360]="wndap360_firmware.tar art.ko mdk_client.out"
    [660]="WNDAP660_firmware.tar"
)
typeset -A APMIBFILELIST
APMIBFILELIST=(
    [210]="documents/TAURUS/MIBS/WNAP210V2.mib"
    [320]="documents/LYRA/MIBS/WNAP320.mib"
    [350]="documents/LIBRA/MIBS/wndap350.mib"
    [360]="documents/LYNX/MIBS/WNDAP360.mib"
    [660]="documents/WNDAP660/MIB/WNDAP660.mib"
)
password=$1
username=$2
ipaddress=$3
forwardpath=$4
for APNUM in $APLIST; do
  APDIR=${APDIRS[$APNUM]}
  AP=${APFILELIST[$APNUM]}
  AP_PATH=${APPATH[$APNUM]}
  MIB_PATH=${APMIBFILELIST[$APNUM]}
  mkdir -p ./$AP_PATH/
  for file in $AP; do
	URL="$username@$ipaddress:$forwardpath/sdk/build/images/$APDIR/$file"
	sshpass -p "$password" scp -r $URL ./$AP_PATH/
        if [ $1 = 0 ]; then
                echo "$file download failed" 
        else
		echo "$file download successfull"
	fi
  done
  URL="$username@$ipaddress:$forwardpath/$MIB_PATH"
  sshpass -p "$password" scp -r $URL ./$AP_PATH/
  if [ $1 = 0 ]; then
	echo "$MIB_PATH download failed" 
  else
	echo "$MIB_PATH download successfull"
  fi
done

