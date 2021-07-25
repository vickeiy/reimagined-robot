#!/bin/sh
REPOS="memtrace nile-ap-fw environment-systems-latest freeradius-docker nile-nse environment-production pre-staging-hit apbuild grpc-proxy log-client mock-servers ndp-client nile-ap-sw nile-pkgs nilebot nmp-client oc-models openwrt shared-pkgs"

for repo in $REPOS
do
        if [ ! -z "$1" ]; then
                if [ $1 != $repo ]; then
                        continue
                fi
        fi
        echo "Deleting repo $repo"
        rm -rf $repo
        echo "Cloning repo $repo"
	    sh -c "cd ~/work/mirror-repo/nileglobalsw && ./update_mirror.sh $repo"
        git clone ~/work/mirror-repo/nileglobalsw/$repo.git
        if [ $? -eq 0 ]; 
        then
                echo "Repo $repo downloaded successfully"
        	sh -c "cd $repo && git remote set-url origin git@bitbucket.org:nileglobalsw/$repo.git"
	else
                echo "Repo $repo download failed"
                exit 1
        fi
done
