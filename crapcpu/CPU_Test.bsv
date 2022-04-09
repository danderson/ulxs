package CPU_Test;

import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import Testing::*;

import CPU::*;
import ISA::*;
import Mem::*;

module mkTB();
   let cycles <- mkTestCycleCounter(1000);

   let imem <- mkIMem("cpu_test_mem.hex");
   let dmem <- mkDMem();
   FIFO#(Bit#(8)) serial_in <- mkFIFO();
   FIFO#(Bit#(8)) serial_out <- mkFIFO();
   let iomem <- mkIOOverlay(dmem, toGet(serial_in), toPut(serial_out));
   let cpu <- mkCPU(iomem, imem);

   mkTest("CPU", seq
      serial_in.enq(32);
      await (serial_out.first() == 42);
   endseq);
endmodule

endpackage
