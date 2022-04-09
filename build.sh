#!/bin/sh

set -eu

project="$1"
action="${2:-}"

blueroot="$(bsc --help | grep "Bluespec directory: " | awk '{print $3}')"
bluelib="$blueroot/Libraries"
bluev="$blueroot/Verilog"
libpath="lib:$bluelib"
buildout="out/${project}"

function prepare_hex() {
	outdir="$1"
	has_asm=$(ls -1 ${project} | grep '.asm' | wc -l)
	if [ "$has_asm" != "0" ]; then
		for f in ${project}/*.asm; do
			go run ${project}/asm.go $f out/${f%.asm}.hex
		done
	fi
	has_hex=$(ls -1 ${project} | grep '.hex' | wc -l)
	if [ "$has_hex" != "0" ]; then
		cp -f ${project}/*.hex "$outdir"
	fi

}

function phase() {
	echo
	echo "****************************************"
	echo "**** $1"
	echo "****************************************"
	echo
}

mkdir -p "$buildout"

buildout=$(readlink -f "$buildout")

synth() {
	##################
	# Generate Verilog from BSV
	##################
	phase "Bluespec to Verilog"
	bsc -check-assert -u -verilog -vdir "$buildout" -bdir "$buildout" -g "mkTop" -p "lib:${project}:${bluelib}" "$project/Top.bsv"

	##################
	# Synthesize Verilog
	##################
	phase "Synthesis"

	function getLibfiles() {
		find "$bluev" -name '*.v' | while read f; do
			case "${f##*/}" in
				main.v)
				;;
				InoutConnect.v)
				;;
				ProbeHook.v)
				;;
				*)
					echo -n "$f "
					;;
			esac
		done
		echo
	}
	libFiles=$(getLibfiles)
	cat >"$buildout/synth.ys" <<EOF
read_verilog -defer -sv $libFiles $buildout/mkTop.v
hierarchy -top mkTop
scratchpad -set abd9.D 20000
scratchpad -copy abc9.script.flow3 abc9.script
EOF
	if [ "$action" = "shell" ]; then
		echo "shell" >>"$buildout/synth.ys"
	else
		echo "synth_ecp5 -abc9 -top mkTop -json $buildout/Top.json" >>"$buildout/synth.ys"
	fi
	prepare_hex "$buildout"
	(
		cd "$buildout"
		yosys -l "$buildout/yosys.log" -v0 -Q -T "$buildout/synth.ys"
	)

	if [ "$action" = "shell" ]; then
		exit 0
	fi

	##################
	# Place and Route
	##################
	phase "Place & Route"
	nextpnr-ecp5 --85k --detailed-timing-report -q -l "$buildout/pnr.log" --json "$buildout/Top.json" --lpf "$project/ulx3s.lpf" --package CABGA381 --textcfg "$buildout/Top.pnr"
	cat >"$buildout/filter.awk" <<EOF
BEGIN { want = 0 }

/Info: Logic utilisation/ { want = 1 }
/Info: Device utilisation/ { want = 1 }
/Info: Max frequency/ { want = 1 }
/^\$/ {
    if (want == 1) { print }
	want = 0
}
{ if (want == 1) { print } }
EOF
	awk -f "$buildout/filter.awk" "$buildout/pnr.log"

	##################
	# Pack bitstream
	##################
	phase "Pack"
	ecppack "$buildout/Top.pnr" "$buildout/Top.bit"

	##################
	# Flash board
	##################
	if [ "$action" = "flash" ]; then
		phase "Flash"
		openFPGALoader -b ulx3s "$buildout/Top.bit"
	fi
}

function runTest() {
	infile="$1"

	testout="$buildout/test/${infile%%_*}"
	mkdir -p "$testout"
	prepare_hex "$testout"
	bsc -check-assert -u -sim -simdir "$testout" -bdir "$testout" -g "mkTB" -p "lib:${project}:${bluelib}" "$project/$infile"
	(
		set -eu
		cd "$testout"
		bsc -sim -e mkTB -o TB
		echo
		./TB
	) || exit 1
}

if [ "$action" = "test" ]; then
	specifictest="${3:-}"
	if [ "$specifictest" == "" ]; then
		find "$project" -name "*_Test.bsv" | while read testfile; do
			runTest "${testfile##*/}"
		done
	else
		runTest "${specifictest}_Test.bsv"
	fi
else
	synth
fi
