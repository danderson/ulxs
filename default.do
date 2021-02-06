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
		nextpnr-ecp5 --85k -l "$log" --json "$json" --lpf "$LAYOUT_CFG" --textcfg "$3"
		;;
	out/*/*.json)
		log="${1%.*}.yosys.log"
		main="${1%.*}.v"
		main="${main#*/}"
		make_parent "$3"
		find $(dirname "$1") -name "*.v" | xargs redo-ifchange
		yosys -l "$log" -v1 -Q -T -e ".*" -p "read_verilog $main" -p "synth_ecp5 -json $3"
		;;
	*)
		echo "don't know how to build $1"
		exit 1
esac
