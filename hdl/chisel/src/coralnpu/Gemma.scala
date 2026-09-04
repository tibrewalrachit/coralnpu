// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package coralnpu

import chisel3._
import chisel3.util._

import common._

// Wide read port between the weight TCM and the matrix-vector engine. A
// request presented while `ready` is high returns a full WTCM row on `rdata`
// in the following cycle.
class WeightMemWideIO(rowAddrBits: Int, rowBits: Int) extends Bundle {
  val req = Input(Valid(UInt(rowAddrBits.W)))
  val ready = Output(Bool())
  val rdata = Output(Valid(UInt(rowBits.W)))
}

// Weight TCM ("WTCM"): a large SRAM sized to hold an entire quantized LLM
// (weights, per-channel scales and the KV cache). It exposes:
//  * a 128-bit fabric port, used by the scalar/vector core (dbus) and the
//    AXI slave to load weights and to read/write the KV cache, and
//  * a row-wide (rowBits) read port feeding the matrix-vector engine at
//    rowBytes bytes per cycle.
// The fabric port has priority; the wide port is stalled on a conflict.
//
// The storage is described behaviourally with a single SyncReadMem. A
// silicon implementation replaces this with an array of banked SRAM macros
// (see doc/gemma.md); the row-wide read is then a same-row read across all
// banks of one macro group.
class WeightMem(p: Parameters, sizeBytes: Long, rowBits: Int = 2048) extends Module {
  val rowBytes = rowBits / 8
  require(sizeBytes % rowBytes == 0)
  val rowCount = (sizeBytes / rowBytes).toInt
  val rowAddrBits = log2Ceil(rowCount)
  val fabricBytes = p.axi2DataBits / 8
  val lanesPerRow = rowBytes / fabricBytes
  val laneBits = log2Ceil(lanesPerRow)

  val io = IO(new Bundle {
    val fabric = Flipped(new FabricIO(p))
    val wide = new WeightMemWideIO(rowAddrBits, rowBits)
  })

  val mem = SyncReadMem(rowCount, Vec(rowBytes, UInt(8.W)))

  // Fabric port decode. Addresses arrive as full bus addresses; the region
  // base is aligned to at least the WTCM size so the low bits index the
  // array directly (same convention as the SRAM fabric wrapper).
  val fabricRead = io.fabric.readDataAddr.valid
  val fabricWrite = io.fabric.writeDataAddr.valid
  val fabricOp = fabricRead || fabricWrite
  val fabricAddr = Mux(fabricWrite, io.fabric.writeDataAddr.bits,
                                    io.fabric.readDataAddr.bits)
  val fabricRow = fabricAddr(rowAddrBits + log2Ceil(rowBytes) - 1, log2Ceil(rowBytes))
  val fabricLane = fabricAddr(log2Ceil(rowBytes) - 1, log2Ceil(fabricBytes))

  // Shared read address: fabric has priority over the wide port.
  val wideAccept = io.wide.req.valid && !fabricOp
  val readEnable = fabricRead || wideAccept
  val readRow = Mux(fabricRead, fabricRow, io.wide.req.bits)
  val readData = mem.read(readRow, readEnable)
  val readDataBits = Cat(readData.reverse)  // byte k of the row at bits [8k+7:8k]

  when (fabricWrite) {
    val wbytes = UIntToVec(io.fabric.writeDataBits, 8)
    val wdata = Wire(Vec(rowBytes, UInt(8.W)))
    val wmask = Wire(Vec(rowBytes, Bool()))
    for (i <- 0 until rowBytes) {
      val lane = i / fabricBytes
      val byteInLane = i % fabricBytes
      wdata(i) := wbytes(byteInLane)
      wmask(i) := (fabricLane === lane.U) && io.fabric.writeDataStrb(byteInLane)
    }
    mem.write(fabricRow, wdata, wmask)
  }
  io.fabric.writeResp := true.B

  // Fabric read data: select the 128-bit lane a cycle after the address.
  val fabricReadValid = RegNext(fabricRead, false.B)
  val fabricLaneReg = RegNext(fabricLane)
  val lanes = VecInit((0 until lanesPerRow).map(
      i => readDataBits((i + 1) * p.axi2DataBits - 1, i * p.axi2DataBits)))
  io.fabric.readData.valid := fabricReadValid
  io.fabric.readData.bits := Mux(fabricReadValid, lanes(fabricLaneReg), 0.U)

  // Wide read data.
  io.wide.ready := !fabricOp
  io.wide.rdata.valid := RegNext(wideAccept, false.B)
  io.wide.rdata.bits := readDataBits
}

object MatVecCsr {
  val CTRL = 0        // W: bit0 = start
  val STATUS = 1      // R: bit0 = busy, bit1 = done
  val W_BASE = 2      // W: weight base byte address (row aligned) in WTCM
  val IN_BASE = 3     // W: input vector base byte address (16B aligned) in DTCM
  val OUT_BASE = 4    // W: output base byte address (16B aligned) in DTCM
  val ROWS = 5        // W: number of output rows (1 .. 2^22)
  val COLS = 6        // W: input length in elements (1 .. maxCols)
  val ROW_STRIDE = 7  // W: row pitch in WTCM rows; 0 selects ceil(cols/rowBytes)
  val MODE = 8        // W: bit0 = argmax mode (no output writes)
  val ARGMAX_IDX = 9  // R: row index of the maximum accumulator
  val ARGMAX_VAL = 10 // R: maximum accumulator value (int32)
  val CYCLES = 11     // R: busy cycles of the most recent operation
}

// Matrix-vector engine. Streams int8 weight rows out of the weight TCM at a
// full row (rowBytes MACs) per cycle against an int8 input vector held in a
// local buffer, and either writes int32 accumulators back to the DTCM or
// tracks a running argmax (used for greedy decoding over the whole
// vocabulary without materializing logits).
//
// The engine is programmed over its 128-bit fabric CSR port (mapped into the
// core's data address space) and is a fabric master on the DTCM for input
// vector reads and result writes.
class MatVecUnit(p: Parameters, wtcmRowCount: Int, rowBits: Int = 2048,
                 maxCols: Int = 2048) extends Module {
  val rowBytes = rowBits / 8
  val rowAddrBits = log2Ceil(wtcmRowCount)
  val fabricBytes = p.axi2DataBits / 8       // 16
  val wordsPerChunk = rowBytes / fabricBytes // 16
  val maxWords = maxCols / fabricBytes
  val maxChunks = maxCols / rowBytes
  val rowsBits = 22                          // up to 4M rows (vocab is 256K)

  val io = IO(new Bundle {
    val csr = Flipped(new FabricIO(p))
    val dtcm = new FabricIO(p)
    val dtcmBusy = Input(Bool())
    val wide = Flipped(new WeightMemWideIO(rowAddrBits, rowBits))
    val busy = Output(Bool())
  })

  // ==========================================================================
  // Configuration registers
  val wBase = RegInit(0.U(32.W))
  val inBase = RegInit(0.U(32.W))
  val outBase = RegInit(0.U(32.W))
  val rowsCfg = RegInit(0.U(rowsBits.W))
  val colsCfg = RegInit(0.U(log2Ceil(maxCols + 1).W))
  val strideCfg = RegInit(0.U(16.W))
  val modeCfg = RegInit(0.U(2.W))
  val busyReg = RegInit(false.B)
  val doneReg = RegInit(false.B)
  val cyclesReg = RegInit(0.U(32.W))
  val argmaxIdx = RegInit(0.U(rowsBits.W))
  val argmaxVal = RegInit(0.S(32.W))

  val modeArgmax = modeCfg(0)

  // ==========================================================================
  // CSR port: word-registers accessed through 128-bit fabric lines.
  val csrWrite = io.csr.writeDataAddr.valid
  val csrRead = io.csr.readDataAddr.valid
  val csrAddr = Mux(csrWrite, io.csr.writeDataAddr.bits, io.csr.readDataAddr.bits)
  val csrLine = csrAddr(5, 4)
  val csrWords = UIntToVec(io.csr.writeDataBits, 32)
  val csrStrb = io.csr.writeDataStrb

  val start = WireInit(false.B)
  when (csrWrite) {
    for (w <- 0 until 4) {
      val wordStrb = csrStrb((w + 1) * 4 - 1, w * 4).andR
      when (wordStrb) {
        val regIdx = Cat(csrLine, w.U(2.W))
        val wdata = csrWords(w)
        switch (regIdx) {
          is (MatVecCsr.CTRL.U) { start := wdata(0) && !busyReg }
          is (MatVecCsr.W_BASE.U) { wBase := wdata }
          is (MatVecCsr.IN_BASE.U) { inBase := wdata }
          is (MatVecCsr.OUT_BASE.U) { outBase := wdata }
          is (MatVecCsr.ROWS.U) { rowsCfg := wdata(rowsBits - 1, 0) }
          is (MatVecCsr.COLS.U) {
            val cols = wdata(colsCfg.getWidth - 1, 0)
            colsCfg := Mux(cols > maxCols.U, maxCols.U, cols)
          }
          is (MatVecCsr.ROW_STRIDE.U) { strideCfg := wdata(15, 0) }
          is (MatVecCsr.MODE.U) { modeCfg := wdata(1, 0) }
        }
      }
    }
  }
  io.csr.writeResp := true.B

  val statusVal = Cat(doneReg, busyReg)
  val csrRegs = VecInit(Seq(
    0.U(32.W), statusVal.pad(32), wBase, inBase,
    outBase, rowsCfg.pad(32), colsCfg.pad(32), strideCfg.pad(32),
    modeCfg.pad(32), argmaxIdx.pad(32), argmaxVal.asUInt, cyclesReg,
  ))
  val csrReadValid = RegNext(csrRead && !csrWrite, false.B)
  val csrLineReg = RegNext(csrLine)
  val csrLines = VecInit((0 until 3).map(l =>
      Cat((0 until 4).reverse.map(w => csrRegs(l * 4 + w)))))
  io.csr.readData.valid := csrReadValid
  io.csr.readData.bits := Mux(csrReadValid,
      Mux(csrLineReg < 3.U, csrLines(csrLineReg(1, 0)), 0.U), 0.U)

  // ==========================================================================
  // Derived working state, latched on start.
  // sSetup gives configuration writes that land in the same fabric line as
  // the start bit a cycle to settle before derived values are computed.
  object State extends ChiselEnum {
    val sIdle, sSetup, sLoad, sTailClear, sCompute = Value
  }
  import State._
  val state = RegInit(sIdle)

  val wordBits = log2Ceil(maxWords + 1)
  val chunkBits = log2Ceil(maxChunks + 1)
  val wordsToLoad = RegInit(0.U(wordBits.W))
  val chunksPerRow = RegInit(0.U(chunkBits.W))
  val tailWords = RegInit(0.U(wordBits.W))
  val rowStrideRows = RegInit(0.U(16.W))
  val wBaseRow = RegInit(0.U(rowAddrBits.W))

  val colsPlusWord = colsCfg +& (fabricBytes - 1).U
  val colsPlusChunk = colsCfg +& (rowBytes - 1).U
  val nWords = (colsPlusWord >> log2Ceil(fabricBytes))(wordBits - 1, 0)
  val nChunks = (colsPlusChunk >> log2Ceil(rowBytes))(chunkBits - 1, 0)

  when (start) {
    busyReg := true.B
    doneReg := false.B
    cyclesReg := 0.U
    argmaxIdx := 0.U
    argmaxVal := (BigInt(-1) << 31).S(32.W)
    state := sSetup
  }
  when (state === sSetup) {
    wordsToLoad := nWords
    chunksPerRow := nChunks
    tailWords := ((nChunks << log2Ceil(wordsPerChunk)) - nWords)(wordBits - 1, 0)
    rowStrideRows := Mux(strideCfg === 0.U, nChunks.pad(16), strideCfg)
    wBaseRow := wBase(rowAddrBits + log2Ceil(rowBytes) - 1, log2Ceil(rowBytes))
    state := sLoad
  }
  when (busyReg) { cyclesReg := cyclesReg + 1.U }
  io.busy := busyReg

  // ==========================================================================
  // Input vector buffer: maxCols int8 elements as 128-bit words.
  val xbuf = Reg(Vec(maxWords, UInt(p.axi2DataBits.W)))

  // Load: stream ceil(cols/16) words from the DTCM. Requests are accepted
  // when the DTCM arbiter grants this port; data returns the cycle after a
  // grant. Bytes at/after `cols` in the final word are zeroed.
  val loadIssue = RegInit(0.U(log2Ceil(maxWords + 1).W))
  val loadRecv = RegInit(0.U(log2Ceil(maxWords + 1).W))

  val loadReqValid = (state === sLoad) && (loadIssue < wordsToLoad)
  val loadAccept = loadReqValid && !io.dtcmBusy
  when (loadAccept) { loadIssue := loadIssue + 1.U }

  val loadDataValid = RegNext(loadAccept, false.B)
  when (loadDataValid) {
    val bytesIn = UIntToVec(io.dtcm.readData.bits, 8)
    val masked = Wire(Vec(fabricBytes, UInt(8.W)))
    for (i <- 0 until fabricBytes) {
      val elemIdx = Cat(loadRecv, i.U(log2Ceil(fabricBytes).W))
      masked(i) := Mux(elemIdx < colsCfg, bytesIn(i), 0.U)
    }
    xbuf(loadRecv(log2Ceil(maxWords) - 1, 0)) := Cat(masked.reverse)
    loadRecv := loadRecv + 1.U
    when (loadRecv === wordsToLoad - 1.U) {
      state := Mux(tailWords === 0.U, sCompute, sTailClear)
    }
  }

  // Zero the trailing words of the last chunk so partial-chunk columns
  // contribute nothing to the dot products.
  val tailPtr = RegInit(0.U(log2Ceil(maxWords + 1).W))
  when (state === sTailClear) {
    val w = wordsToLoad + tailPtr
    xbuf(w(log2Ceil(maxWords) - 1, 0)) := 0.U
    tailPtr := tailPtr + 1.U
    when (tailPtr === tailWords - 1.U) {
      tailPtr := 0.U
      state := sCompute
    }
  }
  when (start) { loadIssue := 0.U; loadRecv := 0.U; tailPtr := 0.U }

  // ==========================================================================
  // Result queue and writeback (decoupled from the MAC pipeline).
  class MvResult extends Bundle {
    val value = SInt(32.W)
    val lastRow = Bool()
  }
  val resultQueue = Module(new Queue(new MvResult, 8))

  // ==========================================================================
  // Weight row issue.
  val issueRow = RegInit(0.U(rowsBits.W))
  val issueChunk = RegInit(0.U(log2Ceil(maxChunks + 1).W))
  val issueRowAddr = RegInit(0.U(rowAddrBits.W))
  val issueDone = RegInit(false.B)
  when (start) {
    issueRow := 0.U; issueChunk := 0.U; issueDone := false.B
  }
  when (state === sTailClear || (state === sLoad)) { issueRowAddr := wBaseRow }

  // Two pipeline stages can hold un-enqueued results; leave headroom so the
  // queue can never overflow.
  val canIssue = (state === sCompute) && !issueDone &&
                 (resultQueue.io.count <= 4.U)
  io.wide.req.valid := canIssue
  io.wide.req.bits := issueRowAddr + issueChunk
  val issueAccept = canIssue && io.wide.ready
  val issueLastChunk = issueChunk === chunksPerRow - 1.U
  val issueLastRow = issueRow === rowsCfg - 1.U
  when (issueAccept) {
    when (issueLastChunk) {
      issueChunk := 0.U
      issueRow := issueRow + 1.U
      issueRowAddr := (issueRowAddr + rowStrideRows)(rowAddrBits - 1, 0)
      when (issueLastRow) { issueDone := true.B }
    } .otherwise {
      issueChunk := issueChunk + 1.U
    }
  }

  // ==========================================================================
  // MAC pipeline.
  // Stage 0 (issue)   : row read request accepted by the WTCM.
  // Stage 1 (data)    : row data returns; 256 int8xint8 products are reduced
  //                     to 16 partial sums, registered with their tags.
  // Stage 2 (acc)     : partial sums reduce to one total and accumulate; on
  //                     the last chunk of a row the result is enqueued.
  class ChunkTag extends Bundle {
    val chunk = UInt(log2Ceil(maxChunks + 1).W)
    val firstChunk = Bool()
    val lastChunk = Bool()
    val lastRow = Bool()
  }
  val dataTag = RegInit(MakeInvalid(new ChunkTag))
  val t = Wire(new ChunkTag)
  t.chunk := issueChunk
  t.firstChunk := issueChunk === 0.U
  t.lastChunk := issueLastChunk
  t.lastRow := issueLastRow && issueLastChunk
  dataTag := MakeValid(issueAccept, t)

  // Stage 1: products and first-level reduction.
  val xChunk = Wire(Vec(rowBytes, SInt(8.W)))
  for (i <- 0 until rowBytes) {
    val word = i / fabricBytes
    val byteInWord = i % fabricBytes
    val wordIdx = Cat(dataTag.bits.chunk, word.U(log2Ceil(wordsPerChunk).W))
    val xword = xbuf(wordIdx(log2Ceil(maxWords) - 1, 0))
    xChunk(i) := xword((byteInWord + 1) * 8 - 1, byteInWord * 8).asSInt
  }
  val lanesPerPartial = 16
  val nPartials = rowBytes / lanesPerPartial
  val partialBits = 8 + 8 + log2Ceil(lanesPerPartial)  // 20
  val partials = Wire(Vec(nPartials, SInt(partialBits.W)))
  for (pi <- 0 until nPartials) {
    val prods = (0 until lanesPerPartial).map { j =>
      val k = pi * lanesPerPartial + j
      val w = io.wide.rdata.bits((k + 1) * 8 - 1, k * 8).asSInt
      w * xChunk(k)
    }
    partials(pi) := prods.map(_.pad(partialBits)).reduce(_ + _)
  }
  assert(!dataTag.valid || io.wide.rdata.valid,
         "MatVecUnit: WTCM data expected but not valid")

  val partialsReg = Reg(Vec(nPartials, SInt(partialBits.W)))
  val accTag = RegInit(MakeInvalid(new ChunkTag))
  when (dataTag.valid) { partialsReg := partials }
  accTag := dataTag

  // Stage 2: accumulate.
  val acc = RegInit(0.S(32.W))
  val chunkTotal = partialsReg.map(_.pad(32)).reduce(_ + _)
  val rowSum = Mux(accTag.bits.firstChunk, chunkTotal, acc + chunkTotal)
  when (accTag.valid) { acc := rowSum }

  resultQueue.io.enq.valid := accTag.valid && accTag.bits.lastChunk
  resultQueue.io.enq.bits.value := rowSum
  resultQueue.io.enq.bits.lastRow := accTag.bits.lastRow
  assert(!resultQueue.io.enq.valid || resultQueue.io.enq.ready,
         "MatVecUnit: result queue overflow")

  // ==========================================================================
  // Result drain: DTCM writeback (mode 0) or argmax tracking (mode 1).
  val lineBuf = Reg(Vec(4, UInt(32.W)))
  val lineCount = RegInit(0.U(2.W))
  val outLine = RegInit(0.U(28.W))
  val writePending = RegInit(false.B)
  val writeBytes = RegInit(0.U(3.W))  // words in the pending line
  val drainRow = RegInit(0.U(rowsBits.W))
  val sawLastResult = RegInit(false.B)
  when (start) {
    lineCount := 0.U; outLine := 0.U; writePending := false.B
    drainRow := 0.U; sawLastResult := false.B
  }

  val deq = resultQueue.io.deq
  deq.ready := Mux(modeArgmax, true.B, !writePending)
  when (deq.fire) {
    when (deq.bits.lastRow) { sawLastResult := true.B }
    when (modeArgmax) {
      when (deq.bits.value > argmaxVal) {
        argmaxVal := deq.bits.value
        argmaxIdx := drainRow
      }
      drainRow := drainRow + 1.U
    } .otherwise {
      lineBuf(lineCount) := deq.bits.value.asUInt
      when (lineCount === 3.U || deq.bits.lastRow) {
        writePending := true.B
        writeBytes := lineCount +& 1.U
      } .otherwise {
        lineCount := lineCount + 1.U
      }
    }
  }

  val writeAccept = writePending && !io.dtcmBusy
  when (writeAccept) {
    writePending := false.B
    lineCount := 0.U
    outLine := outLine + 1.U
  }

  // ==========================================================================
  // DTCM fabric master port.
  io.dtcm.readDataAddr := MakeValid(loadReqValid,
      inBase + Cat(loadIssue, 0.U(log2Ceil(fabricBytes).W)))
  io.dtcm.writeDataAddr := MakeValid(writePending,
      outBase + Cat(outLine, 0.U(log2Ceil(fabricBytes).W)))
  io.dtcm.writeDataBits := Cat(lineBuf.reverse)
  val strbWords = VecInit((0 until 4).map(w => Fill(4, w.U < writeBytes)))
  io.dtcm.writeDataStrb := Cat(strbWords.reverse)
  assert(!(io.dtcm.readDataAddr.valid && io.dtcm.writeDataAddr.valid))

  // ==========================================================================
  // Completion.
  val pipelineEmpty = !dataTag.valid && !accTag.valid
  val drainDone = sawLastResult && !resultQueue.io.deq.valid && !writePending
  when (state === sCompute && issueDone && pipelineEmpty && drainDone) {
    state := sIdle
    busyReg := false.B
    doneReg := true.B
  }
}
