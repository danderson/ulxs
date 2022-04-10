package CPU_Test;

import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import Testing::*;

import CPU::*;
import ISA::*;
import Mem::*;

module mkTB();
   let cycles <- mkTestCycleCounter(10);

   let imem <- mkIMem("cpu_test_mem.hex");
   let dmem <- mkDMem();
   FIFO#(Bit#(8)) into_cpu <- mkFIFO();
   FIFO#(Bit#(8)) from_cpu <- mkFIFO();
   let iomem <- mkIOOverlay(dmem, toGet(into_cpu), toPut(from_cpu));
   let cpu <- mkCPU(iomem, imem);

   mkTest("CPU", seq
      into_cpu.enq(32);
      await (from_cpu.first() == 42);
   endseq);
endmodule

endpackage
