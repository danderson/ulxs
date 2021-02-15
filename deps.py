#!/usr/bin/env python

import argparse
import subprocess
import shutil
import os.path

def main():
    parser = argparse.ArgumentParser(description='Figure out the dependencies of a BSV file.')
    parser.add_argument('file', type=str, help='File for which to find dependencies')
    parser.add_argument('--verilog', action='store_const', const=True, default=False,
                        help='Find Verilog library dependencies')
    parser.add_argument('--build-dir', type=str,
                        help='Build directory in which bsv dependencies will be built')
    parser.add_argument('--extra-lib-dir', type=str,
                        help='Extra library path to search between . and AzureIP')
    args = parser.parse_args()

    libdir = os.path.dirname(shutil.which('bsc'))
    if args.verilog:
        libdir = os.path.join(libdir, "../lib/Verilog")
    else:
        libdir = os.path.join(libdir, "../lib/Libraries")
    libdir = os.path.abspath(libdir)

    search_paths = [os.path.dirname(args.file)]
    if args.extra_lib_dir:
        search_paths.append(args.extra_lib_dir)
    search_paths.append(libdir)

    imports = get_imports(args.file)
    files = find_imports(imports, search_paths, args.verilog, args.build_dir)
    print(args.file)
    for f in files:
        print(f)

exts = {
    True: set(['.v']),
    False: set(['.bsv', '.bo']),
}

def find_imports(imports, search, verilog, build_dir):
    ret = set()
    for imp in imports:
        ret.add(find_import(imp, search, verilog, build_dir))
    return ret

def find_import(name, search, verilog, build_dir):
    for ext in exts[verilog]:
        fname = name+ext
        for s in search:
            path = os.path.join(s, fname)
            if os.path.isfile(path):
                if path.endswith('.bsv') and build_dir:
                    return os.path.join(build_dir, path[:-3]+'bo')
                else:
                    return path
    return None

def get_imports(filename):
    imports = set()

    if filename.endswith('.bsv'):
        with open(filename) as f:
            bs = f.read()
    elif filename.endswith('.bo'):
        bs = subprocess.run(["dumpbo", "-bi", filename], capture_output=True, check=True, text=True).stdout

    for line in bs.splitlines():
        line = line.strip()
        if not line.startswith('import '):
            continue
        f = line.split()[1]
        # bsv has trailing ::, bo has trailing ;
        f = (f.split(':')[0]).split(';')[0]
        imports.add(f)
    return list(imports)

if __name__ == '__main__':
    main()
