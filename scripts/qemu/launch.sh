#!/usr/bin/env bash

set -E -e -u -o pipefail
# QEMU 的 -pidfile 在 QEMU 被 pkill 的时候自动删除的，但是如果 QEMU 是 segv 之类的就不会
pidfile=/tmp/martins3-alpine/qemu-pid

function close_qemu() {
	if [[ -f $pidfile ]]; then
		qemu=$(cat $pidfile)
		if ps -p "$qemu" >/dev/null; then
			gum confirm "Kill the machine?" && kill -9 "$qemu"
		fi
	fi
}

function debug_kernel() {
	set -x
	close_qemu
        # 不要给 -- 后面的增加双引号
	zellij run --close-on-exit -- /home/martins3/core/vn/docs/qemu/sh/alpine.sh -s
	/home/martins3/core/vn/docs/qemu/sh/alpine.sh -k
	close_qemu
}

function login() {
	close_qemu
	zellij run --close-on-exit -- /home/martins3/core/vn/docs/qemu/sh/alpine.sh
	ssh -o '3' -p5556 root@localhost
	close_qemu
}

while getopts "dk" opt; do
	case $opt in
		d)
			debug_kernel
			exit 0
			;;
		k)
			close_qemu
			exit 0
			;;
		*)
			cat /home/martins3/.dotfiles/scripts/qemu/luanch.sh
			exit 0
			;;
	esac
done

login