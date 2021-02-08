// pulse_gen produces 1-cycle pulses at a configurable frequency, by
// dividing the input clock. It can produce frequencies which aren't a
// clean factor of the input clock, by using an accumulator to remain
// within a set margin of error from the desired output frequency.
//
// The module parameters acc_width and acc_incr set the desired output
// frequency. Use ../tools/pulse_gen.py to calculate these parameters
// based on the input frequency and desired output frequency.
module pulse_gen(input clk, output pulse);
   // Default parameters generate a pulse for every clock pulse.
   parameter acc_width=1, acc_incr=2;

   reg [acc_width:0] cnt;
   always @(posedge clk) cnt <= cnt[acc_width-1:0] + acc_incr;

   assign pulse = cnt[acc_width];
endmodule
