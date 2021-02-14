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
hierarchy -check -top mkTop
scratchpad -set abc9.D 20000
scratchpad -copy abc9.script.flow3 abc9.script
synth_ecp5 -abc9 -top mkTop -json $odir/mkTop.json
EOF
		yosys -l "$odir/mkTop.yosys.log" -v1 -Q -T "$odir/mkTop.ys"
		nextpnr-ecp5 --85k -q -l "$odir/mkTop.pnr.log" --json "$odir/mkTop.json" --lpf "ulx3s.lpf" --package CABGA381 --textcfg "$odir/mkTop.pnr"
		ecppack "$odir/mkTop.pnr" "$odir/mkTop.bit"
		openFPGALoader -b ulx3s "$odir/mkTop.bit"
	)
}

do_draw() {
	mkdir -p "$OUT"
	(
		odir="../$OUT"
		cd "$DIR"
		bsc -verilog -vdir "$odir" -simdir "$odir" -info-dir "$odir" -bdir "$odir" -g mkTop -u "Top.bsv"
		cat >"$odir/mkTop_draw.ys" <<EOF
read_verilog -sv $odir/mkTop.v
hierarchy -check -top mkTop
proc
opt
wreduce
clean -purge
show -format svg -width -signed -notitle -colors 1 -prefix $odir/mkTop
EOF
		yosys -l "$odir/mkTop.draw.log" -v1 -Q -T "$odir/mkTop_draw.ys"
		convert "$odir/mkTop.svg" "$odir/mkTop.jpg"
	)
}

case "$MODE" in
	sim)
		do_sim
		;;
	prog)
		do_prog
		;;
	draw)
		do_draw
		;;
	*)
		usage
		;;
esac
