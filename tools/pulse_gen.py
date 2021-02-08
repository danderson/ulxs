#!/usr/bin/env python
#
# A helper to generate clocking parameters for lib/pulse_gen.v.

import argparse

def frequency(s):
    l = s.lower()
    if l.endswith('mhz'):
        mult = 1000000
        l = l[:len(l)-3]
    elif l.endswith('khz'):
        mult = 1000
        l = l[:len(l)-3]
    elif l.endswith('hz'):
        mult = 1
        l = l[:len(l)-2]
    else:
        raise ValueError('unknown suffix on value "{}", must be MHz, KHz or Hz'.format(s))
    return int(l)*mult

def main():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('--in_freq', type=frequency, required=True, metavar='F', help='input clock frequency (e.g. "25MHz")')
    parser.add_argument('--out_freq', type=frequency, required=True, metavar='F', help='output pulse frequency (e.g. "25MHz")')
    parser.add_argument('--oversample', type=int, default=1, metavar='N', help='desired oversampling rate')
    parser.add_argument('--error_pct', type=float, default=0.5, metavar='PCT', help='allowable deviation from target frequency')

    args = parser.parse_args()

    target_freq = args.out_freq*args.oversample
    target_ratio = args.in_freq / target_freq

    for width in range(1, 64):
        scaled_in_freq = 1<<width
        incr = int(round(scaled_in_freq * target_freq / args.in_freq))
        if incr == 0:
            continue
        actual_ratio = scaled_in_freq / incr
        error_pct = abs(actual_ratio-target_ratio) / target_ratio * 100
        if error_pct < args.error_pct:
            print("// input {}Hz, output {}Hz, {}x oversample, error {:.2}%\nacc_width={},\nacc_incr={}".format(args.in_freq, args.out_freq, args.oversample, error_pct, width, incr))
            break

if __name__ == '__main__':
    main()
