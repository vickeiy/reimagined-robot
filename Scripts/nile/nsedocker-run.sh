#!/bin/bash
declare -A dirs_to_create_and_mount=(
	["/srv/${nsedocker_name}/artifacts"]='/opt/nile/apps/nse/artifacts'
	["/srv/${nsedocker_name}/run"]='/opt/nile/apps/nse/run'
	["/srv/${nsedocker_name}/tmp"]='/tmp'
	['/opt/qemu-ap']='/opt/qemu-ap'
	['/opt/qemu-headend']='/opt/qemu-headend'
	['/opt/qemu-switch']='/opt/qemu-switch'
	["${HOME}/src"]='/root/src'
	['/var/cache/git/reference']='/var/cache/git/reference'
)

declare -A dirs_to_mount=(
	["${HOME}/.aws"]='/root/.aws'
	["${HOME}/.ssh"]='/root/.ssh'
	['/lib/modules']='/lib/modules'
)


if [ "$1" != "mini-it" ] && [ "$1" != "x86ap-it" ]; then
    dirs_to_mount["/etc/testbed"]='/etc/testbed'
    dirs_to_mount["/opt/hw-ap"]='/opt/hw-ap'
    dirs_to_mount["/opt/hw-sensor"]='/opt/hw-sensor'
fi
dirs_to_mount["${HOME}/work"]='/mnt/workspace'
dirs_to_mount["${HOME}/.bashrc"]='/root/.bashrc'

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

docker run -it --rm --name $1 -h $1 --privileged --security-opt apparmor=unconfined -d ${bind_mount_str} 374188005532.dkr.ecr.us-east-1.amazonaws.com/nileglobalsw/nile-nse:$2
