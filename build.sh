#!/bin/sh

set -eu

project="$1"
action="${2:-}"

blueroot="$(bsc --help | grep "Bluespec directory: " | awk '{print $3}')"
bluelib="$blueroot/Libraries"
bluev="$blueroot/Verilog"
libpath="lib:$bluelib"
buildout="out/${project}"

function phase() {
	echo
	echo "****************************************"
	echo "**** $1"
	echo "****************************************"
	echo
}

mkdir -p "$buildout"

buildout=$(readlink -f "$buildout")

##################
# Generate Verilog from BSV
##################
phase "Bluespec to Verilog"
bsc -check-assert -u -verilog -vdir "$buildout" -bdir "$buildout" -g "mkTop" -p "lib:$bluelib" "$project/Top.bsv"

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
cp ${project}/*.hex "$buildout"
(
	cd "$buildout"
	yosys -l "$buildout/yosys.log" -v0 -Q -T "$buildout/synth.ys"
)

if [ "$action" != "" ]; then
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
