#!/bin/bash
# Exit on failure
set -euo pipefail
shopt -s inherit_errexit
# Set uniform timestamps while logging irrespective of the
# server timezone where this script runs
export TZ=GMT

echo "[$(date +%H:%M:%S)] Start of $0 Execution"
unset repo
unset topology
unset branch_name
unset version
unset build_id
unset mockserver_build_id
input_tags=""
input_exclude_tags=""
input_critical_tags=""
input_noncritical_tags=""
ap_hw_if_name=""
# Choose NSE start default timeout to be large enough to
# start one instance of NSE docker using the most heavy topology.
nse_start_default_timeout=600
nse_start_timeout=$nse_start_default_timeout
robot_test_default_timeout=3600
robot_test_timeout=$robot_test_default_timeout

# Set default tags for Tests
default_he_it_testTags="-i HE_IT"
default_ap_it_testTags="-i AP_IT"
default_ds_it_testTags="-i SW_IT"
default_hw_ap_it_testTags="-i HW_AP_IT"
default_hw_ap_it_pr_testTags="-i HW_AP_IT_PRECOMMIT"
default_mini_it_testTags="-i SMOKE"
default_mini_it_ap_pr_testTags="-i TOPO_AP_SMOKE"
default_mini_it_he_pr_testTags="-i TOPO_HE_SMOKE"
default_mini_it_ap_testTags="-i TOPO_AP"
default_mini_it_hwap_testTags="-i TOPO_HW_AP"
default_mini_it_he_testTags="-i TOPO_HE"
default_infra_he_it_testTags="-i HE_IT_SMOKE"
default_infra_ap_it_testTags="-i AP_IT_SMOKE"
preserve_failed_docker="false"
robot_exit_on_failure="true"
single_he_mode="false"
mixed_rel=""
extra_options=""

print_usage()
{
    echo "Usage:  $0 -r <he|ap|ds|nilebot|nse|mockserver> -t <he-it|ap-it|x86ap-it|two_he-sw|mini-it> -b <branch_name> \
         -v <version> -i <build_id> -k <tags> -T <nse_start_timeout_in_secs> -R <robot_test_timeout_in_secs> -p \
         [-a <ap-version>] [-h <he-version>] [-s <switch-version>] [-n <nse-version>] [-N <nilebot-verson] [-m <mockserver-verson] [-e <exclude_tags>] \
         [-c <critical_tag>] [-C <noncritical_tag>]"
    echo "        -r: repo (required)"
    echo "        -t: topology (required)"
    echo "        -b: branch_name (required)"
    echo "        -v: version (required)"
    echo "        -i: build_id (required for legacy, not used in newer builds)"
    echo "        -k: tags or keywords (default: for a repo) "
    echo "            input as -k HE_IT_NTM -k HE_IT_SMOKE for selecting multiple tags"
    echo "            he: $default_he_it_testTags, ap: $default_ap_it_testTags, ds: $default_ds_it_testTags"
    echo "            nilebot: $default_he_it_testTags -or- $default_ap_it_testTags -or- $default_mini_it_testTags -or- $default_hw_ap_it_testTags based on topology"
    echo "            nile-nse -or- mock-server: $default_infra_he_it_testTags -or- $default_infra_ap_it_testTags based on topology"
    echo "        -e: exclude tags or keywords "
    echo "            input as -e AP_IT_HOSTAPD -e AP_IT_NCFG for specifying multiple tags for exclusion"
    echo "        -c: Tests having the given tag are considered critical"
    echo "        -C: Tests having the given tag are considered noncritical"
    echo "        -T: nse_start_timeout_in_secs(default: $nse_start_default_timeout)"
    echo "        -R: robot_test_timeout_in_secs(default: $robot_test_default_timeout)"
    echo "        -p: preserve NSE docker on failure(default: false)"
    echo "        -x: robot exit of failure (default: true)"
    echo "        -a: AP software version (default = GOLDEN)"
    echo "        -h: Headend software version (default = GOLDEN)"
    echo "        -s: Switch software version (default = GOLDEN)"
    echo "        -S: Sensor software version (default = GOLDEN)"
    echo "        -n: NSE version (default = latest)"
    echo "        -N: Nilebot version (default = master)"
    echo "        -m: Mockserver version (default = mockserver:latest)"
    echo "        -1: single HE mode"
    echo "        -X: mixed release version (e.g. 21.1. default = none)"

    exit "$1"
}

check_args()
{
    while getopts ':a:c:C:h:s:S:n:N:m:r:t:T:R:b:v:i:k:e:X:px1?H' o; do
        case "${o}" in
            r)
                repo=${OPTARG}
                ;;
            t)
                topology=${OPTARG}
                ;;
            b)
                branch_name=${OPTARG}
                ;;
            v)
                version=${OPTARG}
                ;;
            i)
                build_id=${OPTARG}
                ;;
            k)
                if [[ "${input_tags}" == "" ]]; then
                    input_tags="-i ${OPTARG}"
                else
                    input_tags="${input_tags} -i ${OPTARG}"
                fi
                ;;
            e)
                if [[ "${input_exclude_tags}" == "" ]]; then
                    input_exclude_tags="-e ${OPTARG}"
                else
                    input_exclude_tags="${input_exclude_tags} -e ${OPTARG}"
                fi
                ;;
            c)
                if [[ "${input_critical_tags}" == "" ]]; then
                    input_critical_tags="-c ${OPTARG}"
                else
                    input_critical_tags="${input_critical_tags} -c ${OPTARG}"
                fi
                ;;
            C)
                if [[ "${input_noncritical_tags}" == "" ]]; then
                    input_noncritical_tags="-n ${OPTARG}"
                else
                    input_noncritical_tags="${input_noncritical_tags} -n ${OPTARG}"
                fi
                ;;
            T)
                nse_start_timeout=${OPTARG}
                ;;
            R)
                robot_test_timeout=${OPTARG}
                ;;
            p)
                preserve_failed_docker="true"
                ;;
            x)
                robot_exit_on_failure="false"
                ;;
            a)
                ap_version=${OPTARG}
                ;;
            h)
                he_version=${OPTARG}
                ;;
            s)
                ds_version=${OPTARG}
                ;;
            S)
                sen_version=${OPTARG}
                ;;
            n)
                nse_version=${OPTARG}
                ;;
            N)
                nilebot_version=${OPTARG}
                ;;
            m)
                mockserver_build_id=${OPTARG}
                mockserver_version="mock-servers:$mockserver_build_id"
                ;;
            1)
                single_he_mode="true"
		;;
            X)
                mixed_rel=${OPTARG}
                ;;
            H)
                print_usage 0
                ;;
            \?)
                print_usage 1
                ;;
        esac
    done
    shift "$((OPTIND-1))"
    if [[ ! ${repo+x} ]] || [[ ! ${topology+x} ]] || \
       [[ ! ${branch_name+x} ]] || [[ ! ${version+x} ]]; then
        echo "Error: Mandatory Parameter Missing"
    print_usage 1
    fi

    if [[ "$mixed_rel" != "" && "$topology" != "mini-2ap" ]]; then
        echo "ERROR: Mixed image support only on mini-2ap topo for now"
        exit 1
    fi
}

# Set default version for all Repos
he_version="GOLDEN"
ap_version="GOLDEN"
ds_version="GOLDEN"
sen_version="GOLDEN"
nilebot_version="origin/master"
default_nse_version="latest"
nse_version="${default_nse_version}"
default_mockserver_version="mock-servers:latest"
mockserver_version="${default_mockserver_version}"

# Parse the command line arguments and validate
check_args $*

# Get the HwIntf into ap_hw_if_name for the applicable topos upfront
# irrespective of the repos for which AP HW is used for IT.
if [ "$topology" = "hw_ap-it" ]; then
   ap_hw_if_name=`sed -n 's/^\s*HwIntf\s*:\s*\(.*\)$/\1/p' /etc/testbed/topo_hw-it.yaml`
elif [ "$topology" = "mini-hwap-it" ]; then
   ap_hw_if_name=`sed -n 's/^\s*hwintf\s*:\s*\(.*\)$/\1/p' /etc/testbed/topo-mini-hwap-it.yaml`
fi

actual_tag="${input_tags} ${input_exclude_tags} ${input_critical_tags} ${input_noncritical_tags}"
case "${repo}" in
    "he")
        # Set right Build Version
        if [[ $version == M\.* ]]; then
            if [ "${branch_name}" == "master" ]; then
                he_version="$version-$build_id"
            else
                he_version="$version-$build_id-$branch_name"
            fi
        fi

        build_version=$he_version

        # Set the right Test Tags
        if [ "${input_tags}" == "" ]; then
            if [ "$topology" = "he-it" ]; then
                # Topology is he-it; use he-it tags
                actual_tag="${default_he_it_testTags}"
            elif [ "$topology" = "two_he-sw" ] || [ "$topology" = "mini-it" ]; then
                if [ "${branch_name}" == "master" ]; then
                    actual_tag="${default_mini_it_he_testTags}"
                else
                    actual_tag="${default_mini_it_he_pr_testTags}"
                fi
            else
                echo "Error: Unsupported Topology"
                print_usage 1
            fi
        fi
        ;;
    "ap")

        if [[ $version == M\.* ]]; then
            # Set the legacy build Version
            if [ "${branch_name}" == "master" ]; then
                ap_version="${version}.${build_id}"
                sen_version="${version}.${build_id}"
            else
                ap_version="${version}.${build_id}-$branch_name"
                sen_version="${version}.${build_id}-$branch_name"
            fi
        fi

        build_version=$ap_version
        # Set the right Test Tags
        if [ "${input_tags}" == "" ]; then
            if [ "$topology" = "ap-it" ] || [ "$topology" = "x86ap-it" ]; then
                # Topology is ap-it; use ap-it tags
                actual_tag="${default_ap_it_testTags}"
            elif [ "$topology" = "two_he-sw" ] || [ "$topology" = "mini-it" ]; then
                if [ "${branch_name}" == "master" ]; then
                    actual_tag="${default_mini_it_ap_testTags}"
                else
                    actual_tag="${default_mini_it_ap_pr_testTags}"
                fi
            elif [ "$topology" = "hw_ap-it" ]; then
                if [ "${branch_name}" == "master" ]; then
                    actual_tag="${default_hw_ap_it_testTags}"
                else
                    actual_tag="${default_hw_ap_it_pr_testTags}"
                fi
            elif [ "$topology" = "mini-hwap-it" ]; then
               actual_tag="${default_mini_it_hwap_testTags}"
            else
                echo "Error: Unsupported Topology"
                print_usage 1
            fi
        fi
        ;;
    "ds")
        if [[ $version == M\.* ]]; then
            # Set the legacy Build Version
            if [ "${branch_name}" == "master" ]; then
                ds_version="$version-$build_id"
            else
                ds_version="$version-$build_id-$branch_name"
            fi
        fi

        build_version=$ds_version

        # Set the right Test Tags
        if [ "${input_tags}" == "" ]; then
            # Use default tags
            actual_tag="${default_ds_it_testTags}"
        fi
        ;;
    "nilebot")
        if [[ $version == M\.* || $version == 0.0* ]]; then
            # $version and $build_id are not applicable for nilebot repo since
            # the $branch_name refers to a git branch
            nilebot_version="$branch_name"
        fi

        build_version=$nilebot_version

        # Set the right Test Tags
        if [ "${input_tags}" == "" ]; then
            # Use default tags
            if [ "$topology" = "he-it" ]; then
                # Topology is he-it; use he-it tags
                actual_tag="${default_he_it_testTags}"
            elif [ "$topology" = "ap-it" ] || [ "$topology" = "x86ap-it" ]; then
                # Topology is ap-it; use ap-it tags
                actual_tag="${default_ap_it_testTags}"
            elif [ "$topology" = "two_he-sw" ] || [ "$topology" = "mini-it" ]; then
                actual_tag="${default_mini_it_testTags}"
            else
                echo "Error: Unsupported Topology"
                print_usage 1
            fi
        fi
        ;;
    "nse")
        if [[ $version == M\.* || $version == 0.0* ]]; then
            # Set the legacy Build Version
            if [ "${branch_name}" != "master" ]; then
                nse_version=$version-$build_id
            fi
        fi

        build_version=$nse_version

        # Set the right Test Tags
        if [ "${input_tags}" == "" ]; then
            # Use default tags
            if [ "$topology" = "he-it" ]; then
                # Topology is he-it; use he-it tags
                actual_tag="${default_infra_he_it_testTags}"
            elif [ "$topology" = "ap-it" ] || [ "$topology" = "x86ap-it" ]; then
                # Topology is ap-it; use ap-it tags
                actual_tag="${default_infra_ap_it_testTags}"
            elif [ "$topology" = "two_he-sw" ] || [ "$topology" = "mini-it" ]; then
                actual_tag="${default_mini_it_testTags}"
            else
                echo "Error: Unsupported Topology"
                print_usage 1
            fi
        fi
        ;;
    "mockserver")
        if [[ $version == M\.* || $version == 0.0* ]]; then
            # Set the legacy Build Version
            if [ "${branch_name}" != "master" ]; then
                mockserver_version="$branch_name:$version-$build_id"
                build_version="$version-$build_id"
            else
                build_version=$version
            fi
        else
            mockserver_version="mock-servers:$mockserver_build_id"
            build_version=$mockserver_build_id
        fi


        # Set the right Test Tags
        if [ "${input_tags}" == "" ]; then
            # Use default tags
            if [ "$topology" = "he-it" ]; then
                # Topology is he-it; use he-it tags
                actual_tag="${default_infra_he_it_testTags}"
            elif [ "$topology" = "ap-it" ] || [ "$topology" = "x86ap-it" ]; then
                # Topology is ap-it; use ap-it tags
                actual_tag="${default_infra_ap_it_testTags}"
            elif [ "$topology" = "two_he-sw" ] || [ "$topology" = "mini-it" ]; then
                actual_tag="${default_mini_it_testTags}"
            else
                echo "Error: Unsupported Topology"
                print_usage 1
            fi
        fi
        ;;
    *)
        echo "Error: Repo name is wrong"
        print_usage 1
        ;;
esac

echo " ---------- Run Parameters ---------- "
echo " DS Version         : $ds_version"
echo " HE Version         : $he_version"
echo " AP Version         : $ap_version"
echo " Sensor Version     : $sen_version"
echo " Nilebot Version    : $nilebot_version"
echo " Nile-NSE Version   : $nse_version"
echo " Mock-Server Version: $mockserver_version"
echo " Topology to test   : $topology"
echo " Repo to Test       : $repo"
echo " Robot Test Tags    : $actual_tag"
echo " Single HE Mode     : $single_he_mode"
echo " ------------------------------------ "

# Choose a unique name for the NSE Docker container
# PID is suffixed so that we can run parallel NSE containers
# locally with the same branch,version,buildId combo.
# $branch_name can contain forward slash in case of a git branch.
# So, convert forward slash if any to underscore.
nsedocker_name="nsedocker-${branch_name//\//_}-${build_version//\//_}-$$"

# Trap handler function which is called when this script exits
cleanup()
{
    exit_code=$?
    # We don't want to exit partially from here.
    # Do a best effort of cleanup.
    set +euo pipefail
    shopt -u inherit_errexit

    echo "[$(date +%H:%M:%S)] $0 - Finished with exit code of $exit_code"
    docker exec "$nsedocker_name" cp -r /root/src/nilebot/Logs /root/robotResults
    echo "[$(date +%H:%M:%S)] $0 - Copied Logs into robotResults directory"
    if [ "$exit_code" = "124" ]; then
        echo "[$(date +%H:%M:%S)] $0 - likely exited due to robot test timeout of $robot_test_timeout"
    fi
    if [ "$exit_code" = "100" ] || [ "$exit_code" = "101" ]; then
        echo "[$(date +%H:%M:%S)] $0 - nse_start.sh likely exited due flock failure with exit_code=${exit_code}. Dumping all the locks -"
        lslocks
    fi
    if [ "$exit_code" != "0" ]; then
        docker exec "$nsedocker_name" bash -c 'echo -e "NSE Logs:\n$(tail -n +1 /var/log/nse/*.log)\n"'
        echo "[$(date +%H:%M:%S)] Preserve Failed Docker image of ${nsedocker_name} - ${preserve_failed_docker}"
        if [ "$preserve_failed_docker" = "true" ]; then
            # Copy the bind mounted data in the nse run folder into the docker.
            docker exec "$nsedocker_name" cp -r /opt/nile/apps/nse/run /tmp
            docker exec "$nsedocker_name" umount -f /opt/nile/apps/nse/run
            docker exec "$nsedocker_name" cp -r /tmp/run /opt/nile/apps/nse
            docker exec "$nsedocker_name" rm -fr /tmp/run
            # Commit the docker image and export it to ECR in the us-west-2 region
            eval "$(aws ecr get-login --region us-west-2 --no-include-email)"
            nsedocker_tag="${us_east_ecr_url}/nile-nse:${nsedocker_name}-${repo}-${topology}"
            echo "[$(date +%H:%M:%S)] Committing and pushing the docker image as $nsedocker_tag"
            docker commit "$nsedocker_name" "$nsedocker_tag"
            docker push --quiet "$nsedocker_tag"
            echo "[$(date +%H:%M:%S)] The image retention policy is set to - "
            echo "$(aws ecr get-lifecycle-policy --region us-west-2 --repository-name nileglobalsw/nile-nse)"
            docker image rmi "$nsedocker_tag"
            echo "[$(date +%H:%M:%S)] For details on using the preserved docker image $nsedocker_tag please go through -"
            echo "https://nile-global.atlassian.net/wiki/spaces/TAF/pages/422281433/Using+the+NSE+docker+preserved+on+failure"
        fi
    fi

    echo "[$(date +%H:%M:%S)] Deleting the NSE docker container - $nsedocker_name"
    # Destroy the NSE docker and the associated directories which were bind mounted.
    docker rm -f "$nsedocker_name"

    # Cleanup the docker images
    if [ "${nse_version}" != "${default_nse_version}" ]; then
      nsedocker_image_name="${us_east_ecr_url}/nile-nse:${nse_version}"
      echo "[$(date +%H:%M:%S)] Deleting the NSE docker image - ${nsedocker_image_name}"
      sudo docker image rm -f "${nsedocker_image_name}"
    fi
    if [ "${mockserver_version}" != "${default_mockserver_version}" ]; then
      mockserver_docker_image_name="${us_east_ecr_url}/${mockserver_version}"
      echo "[$(date +%H:%M:%S)] Deleting the mockserver docker image - ${mockserver_docker_image_name}"
      sudo docker image rm -f "${mockserver_docker_image_name}"
      echo "[$(date +%H:%M:%S)] Deleting the mockserver docker image - localhost:${local_ecr_port}/${mockserver_version}"
      sudo docker image rm -f localhost:${local_ecr_port}/"${mockserver_version}"
    fi
    # Remove all stopped containers, unused networks, dangling images, build cache
    docker system prune --volumes -f
    rm -fr /srv/"$nsedocker_name"
    exit $exit_code
}

# Use a local AWS ECR docker registry to house the mock-servers,  wired-client, freeradius docker image locally.
# This helps in avoiding the need to pull mock-servers, wired-client, freeradius docker image from the AWS ECR
# each time a new NSE Docker container instance is spawned.
nile_ecr_docker="nile-ecr"
nile_local_ecr_name="nile.ecr"
local_ecr_port="5000"
echo "[$(date +%H:%M:%S)] Getting ${nile_ecr_docker} local container registry IP. The registry docker is started if not running"
$(sudo docker ps -f "name=^${nile_ecr_docker}$"  | grep ${nile_ecr_docker} &> /dev/null) || \
  docker run -d -p ${local_ecr_port}:${local_ecr_port} --restart=always \
  --name ${nile_ecr_docker} -v /srv/registry:/var/lib/registry registry:latest
local_registry_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${nile_ecr_docker})
eval "$(aws ecr get-login --region us-east-1 --no-include-email)"

# Helper function to cache the docker image version passed as an argument
# into a local container registry
# $1 -> remote ECR base URL
# $2 -> image version
local_docker_registry_cache() {
  docker_ecr_url="$1"
  docker_image_version="$2"
  echo "[$(date +%H:%M:%S)] Getting docker instance: ${docker_ecr_url}/${docker_image_version}"
  docker pull --quiet ${docker_ecr_url}/${docker_image_version}
  docker tag ${docker_ecr_url}/${docker_image_version} localhost:${local_ecr_port}/${docker_image_version}
  docker push --quiet localhost:${local_ecr_port}/${docker_image_version}
}

us_east_ecr_url="374188005532.dkr.ecr.us-east-1.amazonaws.com/nileglobalsw"
local_docker_registry_cache "${us_east_ecr_url}" "${mockserver_version}"
wired_client_apps_version="wired-client-apps:latest"
freeradius_docker_version="freeradius-docker:latest"

if [ "$topology" = "mini-it" ]; then
  # For wired-client-apps and freeradius we only need latest version,
  # since there is no active development there.
  local_docker_registry_cache "${us_east_ecr_url}" "${wired_client_apps_version}"
  local_docker_registry_cache "${us_east_ecr_url}" "${freeradius_docker_version}"
fi

# Register the cleanup trap handler to cleanup before exit.
trap "cleanup" EXIT

# Best effort pull of nile-nse and mock-servers docker golden images
# corresponding to the version passed. Ideally, we don't need to get the golden
# docker image of nile-nse OR mock-servers in case of the repo being tested is
# either nile-nse or mock-servers respectively. But, keeping it simple and
# pulling golden image always. This will mostly be a no-op until the golden tag
# is revised on a image, in which case the previously golden tagged image will
# be regarded as a dangling image and removed on a docker system prune.
# This will help in local caching of nile-nse and mock-servers docker images.

# Strip the last field out of the version and make it explicitly 0 for the
# nile-nse and mock-server golden docker image version tag.
# For example, if version is 20.1.3 use 20.1.0 for nile-nse and mock-server
# version since the last field in the version is not used for the infra repos.
golden_version="${version%.*}.0"
golden_tag="${golden_version}_golden"
echo "[$(date +%H:%M:%S)] Getting nile-nse and mock-servers ${golden_tag} image"
docker pull --quiet ${us_east_ecr_url}/nile-nse:"${golden_tag}" || \
  echo "[$(date +%H:%M:%S)] Pulling nile-nse ${golden_tag} image failed"
docker pull --quiet ${us_east_ecr_url}/mock-servers:"${golden_tag}" || \
  echo "[$(date +%H:%M:%S)] Pulling mock-servers ${golden_tag} image failed"

# Pull the NSE Docker image and start a container instance from it.
# Bind mount directories which expect to see huge I/O in a partition
# different from the place where docker would do the I/O( i.e /var/lib/docker/... )
# This is to prevent docker from stalling for the disk I/O while it does umount() etc..
# when a container is started.
# Note: Use Bind mount instead of the volume mount option -v so that the source
# directory does not get created on the host of it does not exist leading to issues
# seen with https://nile-global.atlassian.net/browse/SW-13763
echo "[$(date +%H:%M:%S)] Getting nile-nse docker instance ${us_east_ecr_url}/nile-nse:$nse_version"
docker pull --quiet ${us_east_ecr_url}/nile-nse:"$nse_version"

# Create the directories to be bind mounted if not existing already. Other directories
# bind mounted are expected to be present. Use bash associate array key=value, where key
# is source and value is target of bind mount.
declare -A dirs_to_create_and_mount=(
    ["/srv/${nsedocker_name}/artifacts"]='/opt/nile/apps/nse/artifacts'
    ["/srv/${nsedocker_name}/run"]='/opt/nile/apps/nse/run'
    ["/srv/${nsedocker_name}/tmp"]='/tmp'
    ['/opt/qemu-ap']='/opt/qemu-ap'
    ['/opt/qemu-headend']='/opt/qemu-headend'
    ['/opt/qemu-switch']='/opt/qemu-switch'
    ['/var/cache/git/reference']='/var/cache/git/reference'
)

declare -A dirs_to_mount=(
    ["${HOME}/.aws"]='/root/.aws'
    ["${HOME}/.ssh"]='/root/.ssh'
    [$(pwd)]='/root/robotResults'
    ['/lib/modules']='/lib/modules'
)
if [ -n "${ap_hw_if_name}" ]; then
    dirs_to_create_and_mount['/opt/hw-ap']='/opt/hw-ap'
    dirs_to_create_and_mount['/opt/hw-sensor']='/opt/hw-sensor'
    dirs_to_mount['/etc/testbed']='/etc/testbed'
fi

bind_mount_str=''
echo "[$(date +%H:%M:%S)] Creating directories to be bind mounted inside docker:" "${!dirs_to_create_and_mount[@]}"
for d in "${!dirs_to_create_and_mount[@]}"; do
    mkdir -p "${d}"
    bind_mount_str="${bind_mount_str} --mount type=bind,source=${d},target=${dirs_to_create_and_mount[${d}]}"
done

echo "[$(date +%H:%M:%S)] Existing directories to be bind mounted inside docker:" "${!dirs_to_mount[@]}"
for d in "${!dirs_to_mount[@]}"; do
    bind_mount_str="${bind_mount_str} --mount type=bind,source=${d},target=${dirs_to_mount[${d}]}"
done

# Ensure that the iptables NAT MASQUERADE rules are sane for docker by stopping
# any existing nile-nse runs on the host and restarting docker daemon
if [ ! -z "$ap_hw_if_name" ]; then
  echo -n "[$(date +%H:%M:%S)] AP_HW_IT: Stopping nile-nse service and restarting docker daemon on the host..."
  service nilense stop
  service docker restart
  echo "[$(date +%H:%M:%S)] Done"
fi

docker run --rm --name "${nsedocker_name}" --privileged --security-opt apparmor=unconfined -d ${bind_mount_str} ${us_east_ecr_url}/nile-nse:"${nse_version}"

# Add the Local ECR docker registry DNS mapping within the NSE Docker container.
docker exec "$nsedocker_name" bash -c "echo \"$local_registry_ip ${nile_local_ecr_name}\" >> /etc/hosts"

echo -e "[$(date +%H:%M:%S)] Waiting for docker to be setup within nsedocker-$$ ..."
setup_timeout=120
count=0
until docker exec "$nsedocker_name" bash -c "systemctl is-active docker && ping -c 1 -q ${nile_local_ecr_name}"; do
    sleep 1
    count=$((count+1))
    if [ "$count" = "$setup_timeout" ]; then
        echo "Giving up after $setup_timeout seconds."
        exit 1
    fi
done
echo "[$(date +%H:%M:%S)] Done"

# Helper function to pull the docker image version from local ecr and tag it
# appropriately into the NSE docker
# $1 -> remote ECR base URL
# $2 -> image version
# $3 -> local ECR name
local_docker_registry_pull() {
  docker_ecr_url="$1"
  docker_image_version="$2"
  local_ecr_name="$3"
  echo "[$(date +%H:%M:%S)] Pulling docker image: ${local_ecr_name}:${local_ecr_port}/${docker_image_version}"
  docker exec "$nsedocker_name" docker pull --quiet "${local_ecr_name}:${local_ecr_port}/${docker_image_version}"
  docker exec "$nsedocker_name" docker tag "${local_ecr_name}:${local_ecr_port}/${docker_image_version}" \
    "${docker_ecr_url}/${docker_image_version}"
}

# Pull the mock-servers, wired-client-apps, freeradius docker image upfront from the Local ECR docker registry
# and tag it with the AWS ECR docker name to avoid pulling this image from the remote AWS ECR.
local_docker_registry_pull "${us_east_ecr_url}" "${mockserver_version}" "${nile_local_ecr_name}"

if [ "$topology" = "mini-it" ]; then
  local_docker_registry_pull "${us_east_ecr_url}" "${wired_client_apps_version}" "${nile_local_ecr_name}"
  local_docker_registry_pull "${us_east_ecr_url}" "${freeradius_docker_version}" "${nile_local_ecr_name}"
fi

echo "[$(date +%H:%M:%S)] Run nse_start.sh to create nse topology"
if [ "${mixed_rel}" != "" ]; then
   extra_options="-x ${mixed_rel}"
fi
if [ "$single_he_mode" = "true" ]; then
   extra_options="${extra_options} -1"
fi

# Start the NSE within the docker using the NSE start script with the appropriate arguments.
if [ -z "$ap_hw_if_name" ]; then
   if [ "${extra_options}" != "" ]; then
       dockerExecCmd=(docker exec "$nsedocker_name" /root/nse_start.sh -t "${topology}" -a "$ap_version"\
       -h "$he_version" -s "$ds_version" -S "$sen_version" -r -T "$nse_start_timeout" ${extra_options} -e -n -I -m "${mockserver_version#'mock-servers:'}"\
       -B "${nilebot_version}" -v "$version" -P)
   else
       dockerExecCmd=(docker exec "$nsedocker_name" /root/nse_start.sh -t "${topology}" -a "$ap_version"\
       -h "$he_version" -s "$ds_version" -S "$sen_version" -r -T "$nse_start_timeout" -e -n -I -m "${mockserver_version#'mock-servers:'}"\
       -B "${nilebot_version}" -v "$version" -P)
   fi
else
   ap_hw_if_netns_move_cmd="ip link set ${ap_hw_if_name} netns $(docker inspect -f '{{.State.Pid}}' ${nsedocker_name})"
   if ! ${ap_hw_if_netns_move_cmd}; then
     echo "[$(date +%H:%M:%S)] Failed to move interface: ${ap_hw_if_name} into netns of NSE docker: ${nsedocker_name}"
     # Attempt to recover the interface back into the default net namespace and retry movement into NSE docker net namespace(netns)
     lsns -t net -o PID -n | xargs -i nsenter -at {} ip link set ${ap_hw_if_name} netns 0 2>/dev/null
     if ! ${ap_hw_if_netns_move_cmd}; then
       echo "[$(date +%H:%M:%S)] Failed to move interface: ${ap_hw_if_name} into netns of NSE docker: ${nsedocker_name} even after attempting to getting it back to default ns"
       lsns -t net -o PID -n | xargs -i sudo bash -c "ps -fp {}; nsenter -at {} ip link show ${ap_hw_if_name} 2>/dev/null"
       exit 1
     fi
   fi
   docker exec $nsedocker_name ip link set $ap_hw_if_name up
   dockerExecCmd=(docker exec "$nsedocker_name" /root/nse_start.sh -t "${topology}" -a "$ap_version"\
    -h "$he_version" -s "$ds_version" -S "$sen_version" -r -T "$nse_start_timeout" -e -n -I -m "${mockserver_version#'mock-servers:'}"\
    -B "${nilebot_version}" -v "$version" -i $ap_hw_if_name -P)
fi
echo "[$(date +%H:%M:%S)] Running Command:" "${dockerExecCmd[@]}"
"${dockerExecCmd[@]}"

echo "[$(date +%H:%M:%S)] Completed nse_start.sh"

test_list=test_list.json
if [ -f "$test_list" ]
then
    docker cp $test_list "$nsedocker_name":/root/src/nilebot
    echo "[$(date +%H:%M:%S)] $0 - Copied $test_list into nilebot directory"
fi

# Generate the common robot run command line
robotRunCmd="python3 -m robot -d /root/robotResults --prerunmodifier SetTags.py"
# Set loglevel default to DEBUG but filtered to Trace, Timestamped result file
robotRunCmd="${robotRunCmd} --loglevel=TRACE:DEBUG --timestampoutputs"
# Set Exit on Failure (default)
if [ "$robot_exit_on_failure" = "true" ]; then
    robotRunCmd="${robotRunCmd} --exitonfailure"
fi
robotRunCmd="${robotRunCmd} -l log-${topology} -o output-${topology} -r report-${topology}"
robotRunCmd="${robotRunCmd} --listener Lib/Common/Utility/NileBotListener.py"
robotRunCmd="${robotRunCmd} ${actual_tag}"

if [ "$topology" = "hw_ap-it" ]; then
   robotRunCmd="${robotRunCmd} --variable upgrade:True -v version:${ap_version} -v ap_image:/opt/hw-ap/${ap_version}/norplusnand-ipq807x_64-single.img"
fi

if [ "$topology" = "he-it" ]; then
    listenerRunCmd=(python3 listener_pre.py -t he-it -l /root/devicelog/ -s s3://nilesw-us-west-2/${topology}-log/${repo}/${branch_name//\//_}_${build_version} -n .)
    echo "[$(date +%H:%M:%S)] Listener Precondition Set:" "${listenerRunCmd[@]}"
    docker exec -w /root/src/nilebot "$nsedocker_name" "${listenerRunCmd[@]}"
    robotRunCmdHE=(${robotRunCmd} TestSuit/HE/He_Test.robot)
    echo "[$(date +%H:%M:%S)] Starting Robot:" "${robotRunCmdHE[@]}"
    docker exec -w /root/src/nilebot "$nsedocker_name" timeout "$robot_test_timeout" "${robotRunCmdHE[@]}"
elif [ "$topology" = "ap-it" ] || [ "$topology" = "x86ap-it" ] || [ "$topology" = "hw_ap-it" ]; then
    listenerRunCmd=(python3 listener_pre.py -t ap-it -l /root/devicelog/ -s s3://nilesw-us-west-2/${topology}-log/${repo}/${branch_name//\//_}_${build_version} -n .)
    echo "[$(date +%H:%M:%S)] Listener Precondition Set:" "${listenerRunCmd[@]}"
    docker exec -w /root/src/nilebot "$nsedocker_name" "${listenerRunCmd[@]}"
    robotRunCmdAP=(${robotRunCmd} TestSuit/AP/)
    echo "[$(date +%H:%M:%S)] Starting Robot:" "${robotRunCmdAP[@]}"
    docker exec -w /root/src/nilebot "$nsedocker_name" timeout "$robot_test_timeout" "${robotRunCmdAP[@]}"
elif [ "$topology" = "two_he-sw" ] || [ "$topology" = "mini-it" ] || [ "$topology" = "mini-2ap" ] || [[ "$topology" =~ ap-scale.* ]]; then
    listenerRunCmd=(python3 listener_pre.py -t mini-topo -l /root/devicelog/ -s s3://nilesw-us-west-2/${topology}-log/${repo}/${branch_name//\//_}_${build_version} -n . -e 1 -N 1)
    echo "[$(date +%H:%M:%S)] Listener Precondition Set:" "${listenerRunCmd[@]}"
    docker exec -w /root/src/nilebot "$nsedocker_name" "${listenerRunCmd[@]}"
    robotRunCmdMini=(${robotRunCmd} TestSuit/Topology/)
    echo "[$(date +%H:%M:%S)] Starting Robot:" "${robotRunCmdMini[@]}"
    docker exec -w /root/src/nilebot "$nsedocker_name" timeout "$robot_test_timeout" "${robotRunCmdMini[@]}"
elif [ "$topology" = "mini-hwap-it" ]; then
    ap_vsensor=`sed -n 's/^\s*AP_VSENSOR\s*:\s*\(.*\)$/\1/p' /etc/testbed/mini-topo.yaml`
    if [ "${ap_vsensor}" = "True" ]; then
        echo "[$(date +%H:%M:%S)] Virtual Sensor Enabled in topo file" "${ap_vsensor}"
        robotRunCmd="${robotRunCmd} -i TOPO_HW_AP_IT_VSENS"
    fi
    listenerRunCmd=(python3 listener_pre.py -t hit -l /root/devicelog/ -s s3://nilesw-us-west-2/${topology}-log/${repo}/${branch_name//\//_}_${build_version} -n .)
    echo "[$(date +%H:%M:%S)] Listener Precondition Set:" "${listenerRunCmd[@]}"
    docker exec -w /root/src/nilebot "$nsedocker_name" "${listenerRunCmd[@]}"
    robotRunCmdMini=(${robotRunCmd} TestSuit/Topology/)
    echo "[$(date +%H:%M:%S)] Starting Robot:" "${robotRunCmdMini[@]}"
    docker exec -w /root/src/nilebot "$nsedocker_name" timeout "$robot_test_timeout" "${robotRunCmdMini[@]}"
else
    echo "$topology topology is not supported. Only he-it, ap-it, x86ap-it and two_he-sw topology are supported."
    exit 1
fi
echo "[$(date +%H:%M:%S)] Completed Robot run Execution"
