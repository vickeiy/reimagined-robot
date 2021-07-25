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
	[ ! -d "$repo.git" ] && ./clone_mirror.sh $repo
        sh -c "cd  $repo.git && git fetch --tag --prune --all" 
        if [ $? -eq 0 ]; 
        then
		echo "$repo updated successfully"
                echo "Repo $repo updated successfully"
        else
		echo "$repo failed to update"
                echo "Repo $repo update failed"
        fi
done
