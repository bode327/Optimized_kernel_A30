#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2018-2019 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.

set -e
exec 9> "$1"
shift
dtboimg="$1"
shift

TMPDIR="$(mktemp -d -t)"
trap 'rm -rf "$TMPDIR"' INT TERM EXIT

echo '/* WARNING: DO NOT EDIT - This file was generated by arch/arm64/boot/overlay.sh */' >&9
echo '#include <linux/kernel.h>' >&9

total=0
while [[ $# -gt 1 && $1 != FORCE ]]; do
	extract_dtb "$1" "$TMPDIR/soc.dtb"
	shift
	python2 $(which mkdtboimg.py) dump "$dtboimg" -b "$TMPDIR/overlay-$total.dtbo" > "$TMPDIR/dtbo-$total.info"
	for overlay in "$TMPDIR"/overlay-$total.dtbo*; do
		ufdt_apply_overlay "$TMPDIR/soc.dtb" "$overlay" "$TMPDIR/combined-$total.dtb"
		overlay_txt="$(dtc-aosp -q -O dts -o - "$overlay")"
		model="$(sed -n '/^\s*model\s*=\(.*\)$/{s//\1/p;q}' <<<"$overlay_txt")"
		compatible="$(sed -n '/^\s*compatible\s*=\(.*\)$/{s//\1/p;q}' <<<"$overlay_txt")"
		board_id="$(sed -n '/^\s*qcom,board-id\s*=\(.*\)$/{s//\1/p;q}' <<<"$overlay_txt")"
		dtc-aosp -q -O dts -o "$TMPDIR/combined-$total.dts" "$TMPDIR/combined-$total.dtb"
		sed -i "0,/^\\s*model\\s*=.*/s//model = $model/" "$TMPDIR/combined-$total.dts"
		sed -i "0,/^\\s*compatible\\s*=.*/s//compatible = $compatible/" "$TMPDIR/combined-$total.dts"
		sed -i "0,/^\\s*qcom,board-id\\s*=.*/s//qcom,board-id = $board_id/" "$TMPDIR/combined-$total.dts"
		sed -i 's/^\s*phandle = \(.*\)/\0\nlinux,phandle = \1/' "$TMPDIR/combined-$total.dts"
		dtc-aosp -q -O dtb -H both -o "$TMPDIR/combined-$total.dtb" "$TMPDIR/combined-$total.dts"
		echo "static u8 dtb_embedded_$((total + 1))[] __initdata = {" >&9
		xxd -i < "$TMPDIR/combined-$total.dtb" >&9
		echo "};" >&9
		((++total))
	done
done

printf 'u8 *const dtb_embedded[] __initconst = { ' >&9
[[ $total -eq 0 ]] || printf 'dtb_embedded_%s, ' $(seq 1 $total) >&9
printf 'NULL };\n' >&9