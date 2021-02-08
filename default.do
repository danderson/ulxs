LAYOUT_CFG="ulx3s_v20.lpf"

exec >&2

make_parent() {
	mkdir -p "${1%/*}"
}

case "$1" in
	*/prog)
		redo-always
		base="$(basename ${1%/*})"
		bitstream="out/$base/$base.bit"
		redo-ifchange "$bitstream"
		fujprog "$bitstream"
		;;
	*/build)
		redo-always
		base="$(basename ${1%/*})"
		bitstream="out/$base/$base.bit"
		redo-ifchange "$bitstream"
		;;
	out/*/*.bit)
		pnr="${1%.*}.pnr"
		make_parent "$3"
		redo-ifchange "$pnr"
		ecppack "$pnr" "$3"
		;;
	out/*/*.pnr)
		json="${1%.*}.json"
		log="${1%.*}.nextpnr.log"
		make_parent "$3"
		redo-ifchange "$json" "$LAYOUT_CFG"
		nextpnr-ecp5 --85k -q -l "$log" --json "$json" --lpf "$LAYOUT_CFG" --package CABGA381 --textcfg "$3"
		;;
	out/*/*.json)
		pfx="${1%.*}"
		log="$pfx.yosys.log"
		deps="$pfx.deps"
		srcdir="${1%/*}"
		srcdir="${srcdir#*/}"
		make_parent "$3"
		find "$srcdir" -name "*.v" -print0 | xargs -0 redo-ifchange
		srcs=$(find "$srcdir" -name "*.v" | tr '\n' ' ')
		cat >"$pfx.ys" <<EOF
read_verilog -sv $srcs
hierarchy -top ${pfx##*/}
synth_ecp5 -json $3
EOF
		verilator --lint-only -Wall $srcs
		yosys -l "$log" -E "$deps" -v1 -Q -T -e ".*" "$pfx.ys"
		cut -f2- -d: | xargs redo-ifchange
		;;
	clean)
		rm -rf out
		;;
	*)
		echo "don't know how to build $1"
		exit 1
esac
