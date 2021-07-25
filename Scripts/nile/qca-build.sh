#!/bin/bash

set -e

if [ $# -ne 1 ]; then
    exit
fi
if [ "$1" != "32" ] && [ "$1" != "64" ]; then
    exit
fi
echo "Building $1"

CURDIR=$PWD
mkdir -p $CURDIR/$1
cd $CURDIR/$1

cp -rvf $HOME/work/qualcomm/chipcode/SPF-11-3/qca-networking-2020-spf-11-3_qca_oem/. $CURDIR/$1/

git checkout r11.3_00006.1
rm -rf BOOT.AK.1.0 BOOT.BF.3.1.1 IPQ4019.ILQ.11.* IPQ8064.ILQ.11.* RPM.AK.* TZ.AK.* TZ.BF.2.7 WIGIG.TLN* IPQ6018.ILQ.11.* TZ.WNS.5.1 BOOT.XF.0.3 BOOT.BF.3.3.1.1 TZ.WNS.4.0 IPQ5018.ILQ.11.* BTFW.MAPLE.1.0.0
cp -rf */* .

#repo init
cp -r $CURDIR/repo/. .
repo init -u git://codeaurora.org/quic/qsdk/releases/manifest/qstak -b release -m caf_AU_LINUX_QSDK_NHSS.QSDK.11.3_TARGET_ALL.12.0.5871.00.6204.xml
repo sync -j8 --no-tags -qc
mkdir -p qsdk/dl
cp -rf apss_proc/out/proprietary/Wifi/qsdk-ieee1905-security/* qsdk
cp -rf apss_proc/out/proprietary/Wifi/qsdk-qca-art/* qsdk
cp -rf apss_proc/out/proprietary/Wifi/qsdk-qca-wifi/* qsdk
cp -rf apss_proc/out/proprietary/Wifi/qsdk-qca-wlan/* qsdk
cp -rf wlan_proc/src/components/QCA8074_v2.0/qca-wifi-fw-src-component-cmn-WLAN.HK.* qsdk/dl/
cp -rf wlan_proc/pkg/wlan_proc/bin/QCA8074_v1.0/qca-wifi-fw-QCA8074_v1.0-WLAN.HK.*.tar.bz2 qsdk/dl/
cp -rf wlan_proc/pkg/wlan_proc/bin/QCA8074_v2.0/qca-wifi-fw-QCA8074_v2.0-WLAN.HK.*.tar.bz2 qsdk/dl/
tar xvf cnss_proc/src/components/qca-wifi-fw-src-component-cmn-WLAN.BL.*.tgz -C qsdk/dl
tar xvf cnss_proc/src/components/qca-wifi-fw-src-component-halphy_tools-WLAN.BL.*.tgz -C qsdk/dl
cp -rf cnss_proc/src/components/* qsdk/dl
cp -rf cnss_proc/bin/QCA9888/hw.2/* qsdk/dl
cp -rf cnss_proc/bin/AR900B/hw.2/* qsdk/dl
cp -rf cnss_proc/bin/QCA9984/hw.1/* qsdk/dl
cp -rf cnss_proc/bin/IPQ4019/hw.1/* qsdk/dl
cp -rf qca-wifi-fw-AR988* qsdk/dl
cp -rf apss_proc/out/proprietary/QSDK-Base/meta-tools/ .
cp -rf apss_proc/out/proprietary/QSDK-Base/common-tools/* qsdk/
cp -rf apss_proc/out/proprietary/QSDK-Base/qsdk-qca-nss/* qsdk/
cp -rf apss_proc/out/proprietary/QSDK-Base/qca-lib/* qsdk/
cp -rf apss_proc/out/proprietary/BLUETOPIA/qca-bluetopia/* qsdk
cp -rf apss_proc/out/proprietary/QSDK-Base/qca-mcs-apps/* qsdk
cp -rf apss_proc/out/proprietary/QSDK-Base/qca-nss-userspace/* qsdk
cp -rf apss_proc/out/proprietary/QSDK-Base/qca-time-services/* qsdk 
cp -rf apss_proc/out/proprietary/QSDK-Base/qca-qmi-framework/* qsdk
cp -rf apss_proc/out/proprietary/QSDK-Base/gpio-debug/* qsdk
cp -rf apss_proc/out/proprietary/QSDK-Base/qca-diag/* qsdk
cp -rf apss_proc/out/proprietary/QSDK-Base/qca-cnss-daemon/* qsdk
cp -rf apss_proc/out/proprietary/QSDK-Base/athtestcmd/* qsdk
cp -rf apss_proc/out/proprietary/QSDK-Base/fw-qca-stats/* qsdk
cp -rf apss_proc/out/proprietary/QSDK-Base/btdaemon/* qsdk
cp -rf apss_proc/out/proprietary/QSDK-Base/minidump/* qsdk
tar xjvf apss_proc/out/proprietary/QSDK-Base/qca-IOT/qca-IOT.tar.bz2 -C qsdk
sed -i '/QCAHKSWPL_SILICONZ/c\PKG_VERSION:=WLAN.HK.2.4-02142-QCAHKSWPL_SILICONZ-1' qsdk/qca/feeds/qca_hk/net/qca-hk/Makefile
cp apss_proc/out/proprietary/QSDK-Base/qca-nss-fw-eip-hk/BIN-EIP*.HK.* qsdk/dl/


cp apss_proc/out/proprietary/RBIN-NSS-RETAIL/BIN-NSS.HK* qsdk/dl/

cp -rf apss_proc/out/proprietary/Hyfi/hyfi/* qsdk
cp -rf apss_proc/out/proprietary/Wifi/qsdk-whc/* qsdk
mkdir qsdk/qca/feeds/qca-son-mem-debug/qca-son-mem-debug
mv qsdk/qca/feeds/qca-son-mem-debug/Makefile qsdk/qca/feeds/qca-son-mem-debug/Config.in qsdk/qca/feeds/qca-son-mem-debug/qca-son-mem-debug
cp -rf apss_proc/out/proprietary/Wifi/qsdk-whcpy/* qsdk


cd qsdk
./scripts/feeds update -a
./scripts/feeds install -a -f

if [ "$1" == "32" ]; then
    cp qca/configs/qsdk/ipq_premium.config .config
    sed -i "s/TARGET_ipq_ipq806x/TARGET_ipq_ipq807x/g" .config
    mv prebuilt/ipq807x/ipq_premium/* prebuilt/ipq807x/
elif [ "$1" == "64" ]; then
    cp qca/configs/qsdk/ipq_premium.config .config
    sed -i "s/TARGET_ipq_ipq806x/TARGET_ipq_ipq807x_64/g" .config
    mv prebuilt/ipq807x_64/ipq_premium/* prebuilt/ipq807x_64/
fi

echo "CONFIG_PACKAGE_whc-mesh=y" >> .config
echo "CONFIG_PACKAGE_hyfi-mesh=y" >> .config

make defconfig
make V=s


mkdir -p $CURDIR/uboot

if [ "$1" == "32" ]; then
    cp -r bin/ipq/openwrt-ipq807x-u-boot*.elf $CURDIR/uboot/
    cp -r bin/ipq/openwrt-ipq807x-lkboot*.elf $CURDIR/uboot/
    cp -r bin/ipq/openwrt-ipq807x_tiny-u-boot*.elf $CURDIR/uboot/
fi

cd $CURDIR/$1

if [ "$1" == "32" ]; then
    mkdir -p common/build/ipq
    mkdir -p apss_proc/out/meta-scripts
    cp qsdk/qca/src/u-boot-2016/tools/pack.py apss_proc/out/meta-scripts/pack_hk.py
    sed -i 's#</linux_root_path>#/</linux_root_path>#' contents.xml
    sed -i 's#</windows_root_path>#\\</windows_root_path>#' contents.xml
    sed -i 's/WLAN.BL.3.14//g' contents.xml
    sed -i 's/CNSS.PS.3.14//g' contents.xml
    cp qsdk/bin/ipq/openwrt* common/build/ipq
    cp -r apss_proc/out/proprietary/QSDK-Base/meta-tools apss_proc/out/
    cp -rf qsdk/bin/ipq/dtbs/* common/build/ipq/
    cp -rf skales/* common/build/ipq/
    cp qsdk/staging_dir/host/bin/ubinize common/build/ipq/
    cd common/build
    sed -i "s/os.chdir(ipq_dir)//" update_common_info.py
    sed "s/'''$/\n\n'''/g" -i update_common_info.py
    sed '/debug/d;/packages/d;/"ipq807x_64"/d;/t32/d;/ret_prep_64image/d;/Required/d;/skales/d; /lk/d;/os.system(cmd)/d;/os.chdir(ipq_dir)/d' -i update_common_info.py
    sed -i -e '/ret_pack_64image==0/,+7d' update_common_info.py
    sed -i -e '/prepareSingleImage.py and pack command for P\/E 64 bit/,+1d' update_common_info.py
    export BLD_ENV_BUILD_ID=P
    python update_common_info.py
elif [ "$1" == "64" ]; then
    mkdir -p common/build/ipq_x64
    mkdir -p apss_proc/out/meta-scripts
    cp qsdk/qca/src/u-boot-2016/tools/pack.py apss_proc/out/meta-scripts/pack_hk.py
    sed -i 's#</linux_root_path>#/</linux_root_path>#' contents.xml
    sed -i 's#</windows_root_path>#\\</windows_root_path>#' contents.xml
    sed -i 's/WLAN.BL.3.14//g' contents.xml
    sed -i 's/CNSS.PS.3.14//g' contents.xml
    cp qsdk/bin/ipq/openwrt* common/build/ipq_x64
    cp -rf $CURDIR/uboot/* common/build/ipq_x64/
    cp -r apss_proc/out/proprietary/QSDK-Base/meta-tools apss_proc/out/
    cp -rf qsdk/bin/ipq/dtbs/* common/build/ipq_x64/
    cp -rf skales/* common/build/ipq_x64/
    cp qsdk/staging_dir/host/bin/ubinize common/build/ipq_x64/
    cd common/build
    sed -i "s/os.chdir(ipq_dir)//" update_common_info.py
    sed "s/'''$/\n\n'''/g" -i update_common_info.py
    sed '/debug/d;/packages/d;/"ipq807x"/d;/t32/d;/ret_prep_32image/d;/Required/d;/lk/d;/os.system(cmd)/d;/skales/d;/os.chdir(ipq_dir)/d' -i update_common_info.py
    sed -i 's/\.\/ipq/\.\/ipq_x64/g' update_common_info.py
    sed -i 's/\.\/ipq_x64_x64/\.\/ipq_x64/g' update_common_info.py
    sed -i -e '/ret_pack_32image==0/,+7d' update_common_info.py
    sed -i -e '/prepareSingleImage.py and pack command for 32 bit/,+2d' update_common_info.py
    export BLD_ENV_BUILD_ID=P
    python update_common_info.py
fi 
