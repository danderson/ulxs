LAYOUT_CFG="ulx3s_v20.lpf"

exec >&2

odir="${1%/*}"
ofile="${1##*/}"
ostem="${ofile%.*}"
sdir="${odir#*/}"
sstem="${sdir}/${ostem}"
blueroot="$(bsc --help | grep "Bluespec directory: " | awk '{print $3}')"
bluelib="$blueroot/Libraries"
bluev="$blueroot/Verilog"

make_parent() {
	mkdir -p "${1%/*}"
}

case "$1" in
	*/compile)
		redo-always
		redo-ifchange "out/$odir/mkTop.json"
		;;
	*/bit)
		redo-always
		redo-ifchange "out/$odir/mkTop.bit"
		;;
	*/prog)
		redo-always
		redo-ifchange "out/$odir/mkTop.bit"
		openFPGALoader -b ulx3s "out/$odir/mkTop.bit"
		;;
	*/test)
		redo-always
		redo-ifchange "out/$odir/mkTB.sim"
		"./out/$odir/mkTB.sim"
		;;

	out/*/*.bo)
		mkdir -p "$1.tmp"
		./deps.py --extra-lib-dir=lib --build-dir=out "$sstem.bsv" | xargs redo-ifchange
		bsc -p "$odir:lib:$bluelib" -bdir "$1.tmp" "$sstem.bsv"
		mv -f "$1.tmp/$ofile" "$3"
		rm -rf "$1.tmp"
		;;
	out/*/*.v)
		mkdir -p "$1.tmp"
		module="${ostem:2}"
		./deps.py --extra-lib-dir=lib --build-dir=out "$sdir/$module.bsv" | xargs redo-ifchange
		bsc -verilog -p "$odir:lib:$bluelib" -vdir "$1.tmp" -bdir "$1.tmp" -g "$ostem" "$sdir/$module.bsv"
		mv -f "$1.tmp/$ofile" "$3"
		rm -rf "$1.tmp"
		;;
	out/*/*.vlibs)
		mkdir -p "$odir"
		src="$sstem.vlibs"
		if [ -f "$src" ]; then
			redo-ifchange "$src"
			echo -n "" >$3
			cat "$src" | while read f; do
				p="$bluev/$f.v"
				if [ ! -f "$p" ]; then
					echo "Missing verilog library $f"
					exit 1
				fi
				echo -n "$p " >>$3
			done
		else
			redo-ifcreate "$src"
			echo -n "" >$3
		fi
		;;
	out/*/*.json)
		mkdir -p "$1.tmp"
		redo-ifchange "$odir/$ostem.v" "$odir/$ostem.vlibs"
		cat >"$1.tmp/synth.ys" <<EOF
read_verilog -sv $(cat $odir/$ostem.vlibs) $odir/$ostem.v
hierarchy -top $ostem
scratchpad -set abc9.D 20000
scratchpad -copy abc9.script.flow3 abc9.script
synth_ecp5 -abc9 -top $ostem -json $3
EOF
		yosys -l "$1.yosys.log" -v0 -Q -T "$1.tmp/synth.ys"
		rm -rf "$1.tmp"
		;;
	out/*/*.pnr)
		mkdir -p "$odir"
		redo-ifchange "$odir/$ostem.json" "$sdir/ulx3s.lpf"
		nextpnr-ecp5 --85k -q -l "$1.pnr.log" --json "$odir/$ostem.json" --lpf "$sdir/ulx3s.lpf" --package CABGA381 --textcfg "$3"
		;;
	out/*/*.bit)
		mkdir -p "$odir"
		redo-ifchange "$odir/$ostem.pnr"
		ecppack "$odir/$ostem.pnr" "$3"
		;;

	out/*/*.ba)
		mkdir -p "$1.tmp"
		module="${ostem:2}"
		./deps.py --extra-lib-dir=lib --build-dir=out "$sdir/$module.bsv" | xargs redo-ifchange
		bsc -p "$odir:lib:$bluelib" -bdir "$1.tmp" -sim -g "$ostem" "$sdir/$module.bsv"
		mv -f "$1.tmp/$ofile" "$3"
		rm -rf "$1.tmp"
		;;
	out/*/*.sim)
		mkdir -p "$1.tmp"
		redo-ifchange "$odir/$ostem.ba"
		bsc -sim -bdir "$odir" -simdir "$1.tmp" -e "$ostem" -o "$3"
		rm -rf "$1.tmp"
		mv -f "$3.so" "$1.so"
		;;

	clean)
		redo-always
		rm -rf out .redo
		;;
	*)
		echo "don't know how to build $1"
		exit 1
esac
