#!/bin/sh
REPOS="nile-ble memtrace nile-ap-fw environment-systems-latest freeradius-docker nile-nse environment-production pre-staging-hit apbuild grpc-proxy log-client mock-servers ndp-client nile-ap-sw nile-pkgs nilebot nmp-client oc-models openwrt shared-pkgs"

for repo in $REPOS
do
        if [ ! -z "$1" ]; then
                if [ $1 != $repo ]; then
                        continue
                fi
        fi
        echo "Deleting repo $repo"
        rm -rf $repo.git
        echo "Cloning repo $repo"
        git clone --mirror --quiet git@bitbucket.org:nileglobalsw/$repo.git
        if [ $? -eq 0 ];
        then
                echo "Repo $repo downloaded successfully"
        else
                echo "Repo $repo download failed"
                exit 1
        fi
done
