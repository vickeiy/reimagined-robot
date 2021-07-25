#!/bin/bash
set -x
set -o pipefail
#STAMP=`date +%d_%m_%Y`
STAMP=`date +%d_%m_%Y`
TOP_DIR=`pwd`
MAX_CONCURRENT_BUILD=1
directory=workspace_$STAMP
qsdk_branch=master
nile_branch=master
recompile=false
verbose=""
multithread="-j8"
mirror=false
is_docker=false
incrbuild=false
waiting=1
clean=true
BUILD_VARIENT="apbuild sensorbuild x86qemubuild x86qemuglibcbuild"
exit_if_err()
{
    if [ $1 != 0 ]; then 
        cd $2; echo "failed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
        exit 2
    fi
}

echo_with_date()
{
	echo "`date +%H_%M_%S_%d_%m_%Y` $1"
}

print_usage()
{
    echo "$0 -r (recompile) -d <directory> -q <QSDK branch> -n <nile repo branch> -p <project to build> -v (verbose build) -j <Num thread , Multi thread build>"
}

if [ $# -ne 0 ]; then
    while getopts "cw:d:q:p:n:?hmrvj:" opt; 
    do
        echo $opt
        case $opt in
	    c)
		clean=true
		;;
            d)
                directory=$OPTARG
                ;;
            q)
                qsdk_branch=$OPTARG
                ;;
            p)
                repo=$OPTARG
                ;;
            n)
                nile_branch=$OPTARG
                ;;
            v)
                verbose="V=s"
                ;;
            j)
                multithread="-j$OPTARG"
                ;;
            r)
                recompile=true
                ;;
            m)
                mirror=true
                ;;
	    w)
		waiting=$OPTARG
		;;
            h|?|:)
                print_usage
                exit 0
                ;;
        esac
    done
    if [ $((OPTIND -1)) -eq 0 ]; then
        print_usage
        exit 1
    fi
    shift $((OPTIND -1))
fi
if [ ! -z "$repo" ]; then
	BUILD="$repo"
	match=0
	for ID in $BUILD_VARIENT
	do
		if [ "$ID" == "$BUILD" ]; then
			match=1
			break;
		fi
	done
	if [ "$match" -ne "1" ]; then
		echo_with_date "Please provide valid platform build"
		exit -1
	fi
else
	BUILD=$BUILD_VARIENT
fi
echo_with_date "These are the builds gone compile $BUILD"
echo_with_date "DIR: $directory QSDK: $qsdk_branch REPO: $repo NILE: $nile_branch"
DIR=${directory}
if [ $recompile = false ]; then
    mkdir -p $DIR/Logs
fi
cd $DIR
CURDIR="$PWD"
#update local mirroed repo before syncing code
MIRROR_REPO=$HOME/work/mirror-repo
echo "Started at `date +%H_%M_%S_%d_%m_%Y`" > stamp
echo 0 > /dev/shm/buildcount

if [ -f /.dockerenv ]; then
    echo_with_date "I'm inside docker container";
    is_docker=true
else
    echo_with_date "I'm living in real world!!";
    is_docker=false
fi

if [ ! -d "/tools/dl" ]; then
	echo_with_date "package dl doesn't exist"
	exit 2
fi

clone_repo ()
{
    repo=$1
    branch=$2
    if [ "$3" ]; then
        dir=$3
    else
        dir=$repo
    fi
    if [ -d $dir ]; then
	sh -c "cd $dir && git fetch origin && git stash && git checkout $branch"
	localbranch=$(cd $dir && git branch | sed -n -e 's/^\* \(.*\)/\1/p')
	if [ $localbranch != "master" ]; then
		sh -c "cd $dir && git rebase origin/master"
	else
		sh -c "cd $dir && git pull"
	fi
	sh -c "cd $dir && git stash apply"
	incrbuild=true
	return
    fi
    if [ $mirror = true ]; then
	sh -c "cd $MIRROR_REPO/nileglobalsw && ./update_mirror.sh $repo"
        git clone $MIRROR_REPO/nileglobalsw/$repo.git -b $branch $dir
	exit_if_err $? $PWD
    else
        git clone git@bitbucket.org:nileglobalsw/$repo.git -b $branch $dir
	exit_if_err $? $PWD
    fi
    sh -c "cd $dir && git remote set-url origin git@bitbucket.org:nileglobalsw/$repo.git"
    if [ ! -d "$dir" ]; then
	echo_with_date "repo download failed"
	exit_if_err 255 $PWD
    fi
    #if [ "$branch" != "master" ]; then
    #	sh -c "cd $dir && git rebase origin/master"
    #	exit_if_err $? $PWD
    #fi
    #for f in $TOP_DIR/patches/$repo/*.patch
    #do
    #    echo "Patching file $f"
    #    sh -c "cd $dir && patch -p1 < $f"
    #done
}

apbuild ()
{
    while true
    do
	if [ $incrbuild == true ]; then
		break
	fi
        if [[ $(</dev/shm/buildcount) -lt $MAX_CONCURRENT_BUILD ]]; then
            echo_with_date "Thread is available to execute build"
            break
        else
            echo_with_date "Waiting for thread to get free"
        fi
        sleep 100
    done
    echo $(($(</dev/shm/buildcount)+1)) >/dev/shm/buildcount
    echo_with_date "Started thread  at $(</dev/shm/buildcount)"
    ID=$1
    CURDIR=$2
    rebuild=$3
    unset GOBIN; unset GOPATH; unset GOROOT
    if [ "$rebuild" = "true" ]; then
        echo_with_date "reCompiling $ID"
        if [ -d "$CURDIR/$ID/nile-ap-sw/qca-networking-x_qca_oem/qsdk" ]; then
            cd $CURDIR/$ID/nile-ap-sw/qca-networking-x_qca_oem/qsdk
            make $verbose $multithread JENKINS=1 TARGET_ONLY=1  2>&1 | tee rebuild.log
    	    exit_if_err $? $CURDIR/$ID
	    cd ../IPQ8074.ILQ.10.0/
	    sh -c "./cmd_fit_64_P.sh &> packaging_output.txt"
    	    exit_if_err $? $CURDIR/$ID
        fi
        return
    fi
    echo_with_date "Compiling $ID"
    #AP software build
    cd $CURDIR
    if [ $clean = true ]; then
	rm -rf $ID
    fi
    mkdir -p $ID; cd $ID
    STAMP_DIR="$PWD"; echo "Started at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    clone_repo nile-ap-sw $qsdk_branch
    clone_repo nile-pkgs $nile_branch
    if [ $incrbuild == true ]; then
	apbuild $ID $CURDIR "true"
    	cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
	exit
    fi
    cd nile-ap-sw
    ln -sf ../nile-pkgs .
    cd qca-networking-x_qca_oem/qsdk
    sleep $waiting
    make $verbose $multithread -f nile_tools/Makefile all JENKINS=1 TOOLCHAIN=/tools/nile-ap 2>&1 | tee output.loed
    exit_if_err $? $STAMP_DIR
    cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
}

apbuild_host ()
{
    while true
    do
	if [ $incrbuild == true ]; then
		break
	fi
        if [[ $(</dev/shm/buildcount) -lt $MAX_CONCURRENT_BUILD ]]; then
            echo_with_date "Thread is available to execute build"
            break
        else
            echo_with_date "Waiting for thread to get free"
        fi
        sleep 100
    done
    echo $(($(</dev/shm/buildcount)+1)) >/dev/shm/buildcount
    echo_with_date "Started thread  at $(</dev/shm/buildcount)"
    ID=$1
    CURDIR=$2
    rebuild=$3
    unset GOBIN; unset GOPATH; unset GOROOT
    if [ "$rebuild" = "true" ]; then
        echo_with_date "reCompiling $ID"
        if [ -d "$CURDIR/$ID/nile-ap-sw/qca-networking-x_qca_oem/qsdk" ]; then
            cd $CURDIR/$ID/nile-ap-sw/qca-networking-x_qca_oem/qsdk
            #make $verbose $multithread 2>&1 | tee rebuild.log
    	    exit_if_err $? $CURDIR/$ID
	    path=`realpath -s --relative-to=$HOME ..`
            docker exec -w /root/$path/IPQ8074.ILQ.10.0 apbuild "./cmd_fit_64_P.sh"
        fi
        return
    fi
    echo_with_date "Compiling $ID"
    #AP software build
    cd $CURDIR
    if [ $clean = true ]; then
	rm -rf $ID
    fi
    mkdir -p $ID; cd $ID
    STAMP_DIR="$PWD"; echo "Started at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    clone_repo nile-ap-sw $qsdk_branch
    clone_repo nile-pkgs $nile_branch
    if [ $incrbuild == true ]; then
	apbuild_host $ID $CURDIR "true"
    	cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
	exit
    fi
    cd nile-ap-sw/qca-networking-x_qca_oem/qsdk
    mkdir feeds
    sh -c "cd feeds && ln -sf ../../../../nile-pkgs nile"
    sh -c "./scripts/feeds update -a && ./scripts/feeds install -f -a"
    sh -c "cp -r /tools/dl/* dl/"
    sh -c "cp ipq807x-premium-config .config && make defconfig"
    sleep $waiting
    make $verbose $multithread | tee output.loed
    exit_if_err $? $STAMP_DIR
    path=`realpath -s --relative-to=$HOME ..`
    docker exec -w /root/$path/IPQ8074.ILQ.10.0 apbuild "./cmd_fit_64_P.sh"
    cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
}

sensorbuild()
{
    while true
    do
	if [ $incrbuild == true ]; then
		break
	fi
        if [[ $(</dev/shm/buildcount) -lt $MAX_CONCURRENT_BUILD ]]; then
            echo_with_date "Thread is available to execute build"
            break
        else
            echo_with_date "Waiting for thread to get free"
        fi
        sleep 100
    done
    echo $(($(</dev/shm/buildcount)+1)) >/dev/shm/buildcount
    echo_with_date "Started thread  at $(</dev/shm/buildcount)"
    ID=$1
    CURDIR=$2
    rebuild=$3
    if [ "$rebuild" = "true" ]; then
        echo_with_date "reCompiling $ID"
        if [ -d "$CURDIR/$ID/nile-sensor-sw/qca-networking-x_qca_oem/qsdk" ]; then
            cd $CURDIR/$ID/nile-sensor-sw/qca-networking-x_qca_oem/qsdk
            make $verbose $multithread JENKINS=1 TARGET_ONLY=1 2>&1 | tee rebuild.log
    	    exit_if_err $? $CURDIR/$ID
	    cd ../IPQ4019.ILQ.10.0/
	    sh -c "./cmd_fit.sh qsdk &> packaging_output.txt"
    	    exit_if_err $? $CURDIR/$ID
        fi
        return
    fi
    echo_with_date "Compiling $ID"
    #Sensor software build
    cd $CURDIR
    if [ $clean = true ]; then
	rm -rf $ID
    fi
    mkdir -p $ID; cd $ID
    STAMP_DIR="$PWD"; echo "Started at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    clone_repo nile-ap-sw $qsdk_branch nile-sensor-sw
    clone_repo nile-pkgs $nile_branch
    if [ $incrbuild == true ]; then
	sensorbuild $ID $CURDIR "true"
    	cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
	exit
    fi
    cd nile-sensor-sw
    ln -sf ../nile-pkgs .
    cd qca-networking-x_qca_oem/qsdk
    sleep $waiting
    make $verbose $multithread -f nile_tools/Makefile.4019 all JENKINS=1 TOOLCHAIN=/tools/nile-ap 2>&1 | tee output.log
    exit_if_err $? $STAMP_DIR
    cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
}

sensorbuild_host()
{
    while true
    do
	if [ $incrbuild == true ]; then
		break
	fi
        if [[ $(</dev/shm/buildcount) -lt $MAX_CONCURRENT_BUILD ]]; then
            echo_with_date "Thread is available to execute build"
            break
        else
            echo_with_date "Waiting for thread to get free"
        fi
        sleep 100
    done
    echo $(($(</dev/shm/buildcount)+1)) >/dev/shm/buildcount
    echo_with_date "Started thread  at $(</dev/shm/buildcount)"
    ID=$1
    CURDIR=$2
    rebuild=$3
    if [ "$rebuild" = "true" ]; then
        echo_with_date "reCompiling $ID"
        if [ -d "$CURDIR/$ID/nile-sensor-sw/qca-networking-x_qca_oem/qsdk" ]; then
            cd $CURDIR/$ID/nile-sensor-sw/qca-networking-x_qca_oem/qsdk
            make $verbose $multithread 2>&1 | tee rebuild.log
    	    exit_if_err $? $CURDIR/$ID
	    path=`realpath -s --relative-to=$HOME ..`
            docker exec -w /root/$path/IPQ4019.ILQ.10.0 apbuild "./cmd_fit.sh"
        fi
        return
    fi
    echo_with_date "Compiling $ID"
    #Sensor software build
    cd $CURDIR
    if [ $clean = true ]; then
	rm -rf $ID
    fi
    mkdir -p $ID; cd $ID
    STAMP_DIR="$PWD"; echo "Started at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    clone_repo nile-ap-sw $qsdk_branch nile-sensor-sw
    clone_repo nile-pkgs $nile_branch
    if [ $incrbuild == true ]; then
	sensorbuild_host $ID $CURDIR "true"
    	cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
	exit
    fi
    cd nile-sensor-sw/qca-networking-x_qca_oem/qsdk
    mkdir feeds
    sh -c "cd feeds && ln -sf ../../../../nile-pkgs nile"
    sh -c "./scripts/feeds update -a && ./scripts/feeds install -f -a"
    sh -c "cp -r /tools/dl/* dl/"
    sh -c "cp ipq4019_premium.config .config && make defconfig"
    sleep $waiting
    make $verbose $multithread | tee output.loed
    exit_if_err $? $STAMP_DIR
    path=`realpath -s --relative-to=$HOME ..`
    docker exec -w /root/$path/IPQ4019.ILQ.10.0 apbuild "./cmd_fit.sh"
    cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
}

qemubuild()
{
    while true
    do
	if [ $incrbuild == true ]; then
		break
	fi
        if [[ $(</dev/shm/buildcount) -lt $MAX_CONCURRENT_BUILD ]]; then
            echo_with_date "Thread is available to execute build"
            break
        else
            echo_with_date "Waiting for thread to get free"
        fi
        sleep 100
    done
    echo $(($(</dev/shm/buildcount)+1)) >/dev/shm/buildcount
    echo_with_date "Started thread  at $(</dev/shm/buildcount)"
    ID=$1
    CURDIR=$2
    rebuild=$3
    if [ "$rebuild" = "true" ]; then
        echo_with_date "reCompiling $ID"
        if [ -d "$CURDIR/$ID/openwrt" ]; then
            cd $CURDIR/$ID/openwrt
            make $verbose $multithread JENKINS=1 TARGET_ONLY=1 QEMU=1 2>&1 | tee rebuild.log
    	    exit_if_err $? $CURDIR/$ID
	    make -f nile_tools/Makefile qemu_pkg
    	    exit_if_err $? $CURDIR/$ID
        fi
        return
    fi
    echo_with_date "Compiling $ID"
    #qemu based build
    cd $CURDIR
    if [ $clean = true ]; then
	rm -rf $ID
    fi
    mkdir -p $ID; cd $ID
    STAMP_DIR="$PWD"; echo "Started at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    clone_repo openwrt $qsdk_branch
    clone_repo nile-pkgs $nile_branch
    if [ $incrbuild == true ]; then
	qemubuild $ID $CURDIR "true"
    	cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
	exit
    fi
    cd openwrt
    sleep $waiting
    make $verbose $multithread -f nile_tools/Makefile qemu JENKINS=1 TOOLCHAIN=/tools/openwrt 2>&1 | tee output.log
    exit_if_err $? $STAMP_DIR
    cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
}

qemubuild_host()
{
    while true
    do
	if [ $incrbuild == true ]; then
		break
	fi
        if [[ $(</dev/shm/buildcount) -lt $MAX_CONCURRENT_BUILD ]]; then
            echo_with_date "Thread is available to execute build"
            break
        else
            echo_with_date "Waiting for thread to get free"
        fi
        sleep 100
    done
    echo $(($(</dev/shm/buildcount)+1)) >/dev/shm/buildcount
    echo_with_date "Started thread  at $(</dev/shm/buildcount)"
    ID=$1
    CURDIR=$2
    rebuild=$3
    echo_with_date "Compiling $ID"
    if [ "$rebuild" = "true" ]; then
        echo_with_date "reCompiling $ID"
        if [ -d "$CURDIR/$ID/openwrt" ]; then
            cd $CURDIR/$ID/openwrt
            make $verbose $multithread QEMU=1 2>&1 | tee rebuild.log
    	    exit_if_err $? $CURDIR/$ID
        fi
        return
    fi
    #qemu based build
    cd $CURDIR
    if [ $clean = true ]; then
	rm -rf $ID
    fi
    mkdir -p $ID; cd $ID
    STAMP_DIR="$PWD"; echo "Started at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    clone_repo openwrt $qsdk_branch
    clone_repo nile-pkgs $nile_branch
    if [ $incrbuild == true ]; then
	qemubuild_host $ID $CURDIR "true"
    	cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
	exit
    fi
    cd openwrt
    sh -c "mkdir feeds && cd feeds && ln -sf ../../nile-pkgs nile"
    sh -c "cp /tools/dl/* dl/"
    sh -c "./scripts/feeds update -a && ./scripts/feeds install -a -f"
    sh -c "cp qemu-config .config && make defconfig"
    sleep $waiting
    make $verbose $multithread QEMU=1 2>&1 | tee output.log
    exit_if_err $? $STAMP_DIR
    cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
}    

x86qemubuild()
{
    while true
    do
	if [ $incrbuild == true ]; then
		break
	fi
        if [[ $(</dev/shm/buildcount) -lt $MAX_CONCURRENT_BUILD ]]; then
            echo_with_date "Thread is available to execute build"
            break
        else
            echo_with_date "Waiting for thread to get free"
        fi
        sleep 100
    done
    echo $(($(</dev/shm/buildcount)+1)) >/dev/shm/buildcount
    echo_with_date "Started thread  at $(</dev/shm/buildcount)"
    ID=$1
    CURDIR=$2
    rebuild=$3
    echo_with_date "Compiling $ID"
    if [ "$rebuild" = "true" ]; then
        echo_with_date "reCompiling $ID"
        if [ -d "$CURDIR/$ID/openwrt" ]; then
            cd $CURDIR/$ID/openwrt
            make $verbose $multithread JENKINS=1 TARGET_ONLY=1 QEMU=1 2>&1 | tee rebuild.log
    	    exit_if_err $? $CURDIR/$ID
	    make -f nile_tools/Makefile x86qemu_pkg
    	    exit_if_err $? $CURDIR/$ID
        fi
        return
    fi
    #qemu based build
    cd $CURDIR
    if [ $clean = true ]; then
	rm -rf $ID
    fi
    mkdir -p $ID; cd $ID
    STAMP_DIR="$PWD"; echo "Started at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    clone_repo openwrt $qsdk_branch
    clone_repo nile-pkgs $nile_branch
    if [ $incrbuild == true ]; then
	x86qemubuild $ID $CURDIR "true"
    	cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
	exit
    fi
    cd openwrt
    sleep $waiting
    make $verbose $multithread -f nile_tools/Makefile x86qemu JENKINS=1 TOOLCHAIN=/tools/openwrt-x86 2>&1 | tee output.log
    exit_if_err $? $STAMP_DIR
    cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
}    

x86qemubuild_host()
{

    exit 0
    while true
    do
	if [ $incrbuild == true ]; then
		break
	fi
        if [[ $(</dev/shm/buildcount) -lt $MAX_CONCURRENT_BUILD ]]; then
            echo_with_date "Thread is available to execute build"
            break
        else
            echo_with_date "Waiting for thread to get free"
        fi
        sleep 100
    done
    echo $(($(</dev/shm/buildcount)+1)) >/dev/shm/buildcount
    echo_with_date "Started thread  at $(</dev/shm/buildcount)"
    ID=$1
    CURDIR=$2
    rebuild=$3
    echo_with_date "Compiling $ID"
    if [ "$rebuild" = "true" ]; then
        echo_with_date "reCompiling $ID"
        if [ -d "$CURDIR/$ID/openwrt" ]; then
            cd $CURDIR/$ID/openwrt
            make $verbose $multithread QEMU=1 2>&1 | tee rebuild.log
    	    exit_if_err $? $CURDIR/$ID
        fi
        return
    fi
    #qemu based build
    cd $CURDIR
    if [ $clean = true ]; then
	rm -rf $ID
    fi
    mkdir -p $ID; cd $ID
    STAMP_DIR="$PWD"; echo "Started at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    clone_repo openwrt $qsdk_branch
    clone_repo nile-pkgs $nile_branch
    if [ $incrbuild == true ]; then
	x86qemubuild_host $ID $CURDIR "true"
    	cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
	exit
    fi
    cd openwrt
    sh -c "mkdir feeds && cd feeds && ln -sf ../../nile-pkgs nile"
    sh -c "cp /tools/dl/* dl/"
    sh -c "./scripts/feeds update -a && ./scripts/feeds install -a -f"
    sh -c "cp x86-config .config && make defconfig"
    sleep $waiting
    make $verbose $multithread QEMU=1 2>&1 | tee output.log
    exit_if_err $? $STAMP_DIR
    cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
}    

x86qemuglibcbuild()
{
    while true
    do
	if [ $incrbuild == true ]; then
		break
	fi
        if [[ $(</dev/shm/buildcount) -lt $MAX_CONCURRENT_BUILD ]]; then
            echo_with_date "Thread is available to execute build"
            break
        else
            echo_with_date "Waiting for thread to get free"
        fi
        sleep 100
    done
    echo $(($(</dev/shm/buildcount)+1)) >/dev/shm/buildcount
    echo_with_date "Started thread  at $(</dev/shm/buildcount)"
    ID=$1
    CURDIR=$2
    rebuild=$3
    echo_with_date "Compiling $ID"
    if [ "$rebuild" = "true" ]; then
        echo_with_date "reCompiling $ID"
        if [ -d "$CURDIR/$ID/openwrt" ]; then
            cd $CURDIR/$ID/openwrt
            make $verbose $multithread JENKINS=1 TARGET_ONLY=1 QEMU=1 2>&1 | tee rebuild.log
    	    exit_if_err $? $CURDIR/$ID
	    make -f nile_tools/Makefile x86qemu_pkg
    	    exit_if_err $? $CURDIR/$ID
        fi
        return
    fi
    #qemu based build
    cd $CURDIR
    if [ $clean = true ]; then
	rm -rf $ID
    fi
    mkdir -p $ID; cd $ID
    STAMP_DIR="$PWD"; echo "Started at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    clone_repo openwrt $qsdk_branch
    clone_repo nile-pkgs $nile_branch
    if [ $incrbuild == true ]; then
	x86qemubuild $ID $CURDIR "true"
    	cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
	exit
    fi
    cd openwrt
    sleep $waiting
    make $verbose $multithread -f nile_tools/Makefile x86glibcqemu JENKINS=1 TOOLCHAIN=/tools/openwrt-x86-glibc 2>&1 | tee output.log
    exit_if_err $? $STAMP_DIR
    cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
}    

x86qemuglibcbuild_host()
{

    exit 0
    while true
    do
	if [ $incrbuild == true ]; then
		break
	fi
        if [[ $(</dev/shm/buildcount) -lt $MAX_CONCURRENT_BUILD ]]; then
            echo_with_date "Thread is available to execute build"
            break
        else
            echo_with_date "Waiting for thread to get free"
        fi
        sleep 100
    done
    echo $(($(</dev/shm/buildcount)+1)) >/dev/shm/buildcount
    echo_with_date "Started thread  at $(</dev/shm/buildcount)"
    ID=$1
    CURDIR=$2
    rebuild=$3
    echo_with_date "Compiling $ID"
    if [ "$rebuild" = "true" ]; then
        echo_with_date "reCompiling $ID"
        if [ -d "$CURDIR/$ID/openwrt" ]; then
            cd $CURDIR/$ID/openwrt
            make $verbose $multithread QEMU=1 2>&1 | tee rebuild.log
    	    exit_if_err $? $CURDIR/$ID
        fi
        return
    fi
    #qemu based build
    cd $CURDIR
    if [ $clean = true ]; then
	rm -rf $ID
    fi
    mkdir -p $ID; cd $ID
    STAMP_DIR="$PWD"; echo "Started at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    clone_repo openwrt $qsdk_branch
    clone_repo nile-pkgs $nile_branch
    if [ $incrbuild == true ]; then
	x86qemubuild_host $ID $CURDIR "true"
    	cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    	echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
    	echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
	exit
    fi
    cd openwrt
    sh -c "mkdir feeds && cd feeds && ln -sf ../../nile-pkgs nile"
    sh -c "cp /tools/dl/* dl/"
    sh -c "./scripts/feeds update -a && ./scripts/feeds install -a -f"
    sh -c "cp x86-config .config && make defconfig"
    sleep $waiting
    make $verbose $multithread QEMU=1 2>&1 | tee output.log
    exit_if_err $? $STAMP_DIR
    cd $STAMP_DIR; echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
    echo_with_date "Completed thread  at $(</dev/shm/buildcount)"
    echo $(($(</dev/shm/buildcount)-1)) >/dev/shm/buildcount
}    

for ID in $BUILD
do
    sleep 1
    case $ID in
        "apbuild")
            rm -rf Logs/$ID.log
	    if [ $is_docker == true ]; then
            	apbuild $ID $CURDIR $recompile > Logs/$ID.log 2>&1 &
	    else
            	apbuild_host $ID $CURDIR $recompile > Logs/$ID.log 2>&1 &
            fi
            ;;
        "qemubuild")
            rm -rf Logs/$ID.log
	    if [ $is_docker == true ]; then
            	qemubuild $ID $CURDIR $recompile > Logs/$ID.log 2>&1 &
	    else
            	qemubuild_host $ID $CURDIR $recompile > Logs/$ID.log 2>&1 &
            fi
            ;;
        "sensorbuild")
            rm -rf Logs/$ID.log
	    if [ $is_docker == true ]; then
            	sensorbuild $ID $CURDIR $recompile > Logs/$ID.log 2>&1 &
	    else
            	sensorbuild_host $ID $CURDIR $recompile > Logs/$ID.log 2>&1 &
            fi
            ;;
        "x86qemubuild")
            rm -rf Logs/$ID.log
	    if [ $is_docker == true ]; then
            	x86qemubuild $ID $CURDIR $recompile > Logs/$ID.log 2>&1 &
	    else
            	x86qemubuild_host $ID $CURDIR $recompile > Logs/$ID.log 2>&1 &
            fi
            ;;
        "x86qemuglibcbuild")
            rm -rf Logs/$ID.log
	    if [ $is_docker == true ]; then
            	x86qemuglibcbuild $ID $CURDIR $recompile > Logs/$ID.log 2>&1 &
	    else
            	x86qemuglibcbuild_host $ID $CURDIR $recompile > Logs/$ID.log 2>&1 &
            fi
            ;;
        *)
            ;;
    esac
done
wait
cd $CURDIR
echo "Completed at `date +%H_%M_%S_%d_%m_%Y`" >> stamp
