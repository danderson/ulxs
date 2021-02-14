#!/usr/bin/env bash

set -euo pipefail

usage() {
	exec >&2
	cat <<EOF
Usage: $0 dir mode
Modes: sim prog
EOF
	exit 1
}

if [[ $# != 2 ]]; then
	usage
fi

DIR=$1
MODE=$2
OUT="out/$DIR"

do_sim() {
	mkdir -p "$OUT"
	(
		odir="../$OUT"
		cd "$DIR"
		bsc -sim -simdir "$odir" -info-dir "$odir" -bdir "$odir" -g mkTB -u "TB.bsv"
		bsc -sim -simdir "$odir" -info-dir "$odir" -bdir "$odir" -e mkTB -o "$odir/$DIR.sim"
		echo "==================="
		$odir/$DIR.sim
	)
}

do_prog() {
	mkdir -p "$OUT"
	(
		odir="../$OUT"
		cd "$DIR"
		bsc -verilog -vdir "$odir" -simdir "$odir" -info-dir "$odir" -bdir "$odir" -g mkTop -u "Top.bsv"
		cat >"$odir/mkTop.ys" <<EOF
read_verilog -sv $odir/mkTop.v
hierarchy -top mkTop
synth_ecp5 -json $odir/mkTop.json
EOF
		yosys -l "$odir/mkTop.yosys.log" -v1 -Q -T "$odir/mkTop.ys"
		nextpnr-ecp5 --85k -q -l "$odir/mkTop.pnr.log" --json "$odir/mkTop.json" --lpf "ulx3s.lpf" --package CABGA381 --textcfg "$odir/mkTop.pnr"
		ecppack "$odir/mkTop.pnr" "$odir/mkTop.bit"
		openFPGALoader -b ulx3s "$odir/mkTop.bit"
	)
}

case "$MODE" in
	sim)
		do_sim
		;;
	prog)
		do_prog
		;;
	*)
		usage
		;;
esac
