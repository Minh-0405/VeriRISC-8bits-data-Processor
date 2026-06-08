module VeriRISC_CPU_tb;

logic clk;
logic rst;
logic HALT;

VeriRISC_CPU cpu(
    .clk(clk),
    .rst(rst),
    .HALT(HALT)
);

task automatic clock(input logic number);
    repeat (number) begin
        clk = 1'b1; #1;
        clk = 1'b0; #1;
    end
endtask

task automatic reset();
    rst = 1'b1; clock(1);
    rst = 1'b0;
endtask

task automatic expect_halt(input logic value);
    $display("At time %0t, expected halt = %0b, got halt = %0b", $time, value, HALT);
    if ( HALT !== value ) begin
        $display("cpu  FAILED");
        $display("At time %0t, expected halt = %0b, got halt = %0b, controlhalt = %0b",
                  $time, value, HALT, cpu.control_signal.halt);
    end
endtask

task automatic expect_acc(input int value);
    $display("At time %0t, expected acc_reg = %0b, got acc_reg = %0b",
                $time, value, cpu.accumulator.data_out);
    if ( cpu.accumulator.data_out !== value ) begin
        $display("cpu  FAILED");
    end
endtask

task automatic expect_Mem(input int value, input int i);
    $display("At time %0t, expected MemData[%0d] = %0b, got MemData[%0d] = %0b",
                $time, i, value, i, cpu.MemData.mem[i]);
    if ( cpu.MemData.mem[i] !== value ) begin
        $display("cpu  FAILED");
    end
endtask

// ✅ Task để in ra tất cả tín hiệu control
task automatic dump_control();
    $display("---- Control signals at %0t ----", $time);
    $display("pc_load=%0b pc_en=%0b halt=%0b jmp=%0b",
             cpu.control_signal.pc_load,
             cpu.control_signal.pc_en,
             cpu.control_signal.halt,
             cpu.control_signal.jmp);
    $display("acc_control=%0b acc_load=%0b",
             cpu.control_signal.accumulator_control,
             cpu.control_signal.accumulator_load);
    $display("memIns_en=%0b memDa_en=%0b memDa_we=%0b",
             cpu.control_signal.memIns_en,
             cpu.control_signal.memDa_en,
             cpu.control_signal.memDa_we);
    $display("---------------------------------");
endtask


task automatic dump_mem(input int depth = 8);
    $display("====== Dumping Instruction Memory ======");
    for (int i = 0; i < depth; i++) begin
        $display("Mem[%0d] = %b | opcode=%b (%0d) imm=%b (%0d)",
                 i,
                 cpu.MemIns.mem[i],              // full 8-bit instruction
                 cpu.MemIns.mem[i][7:5],        // opcode
                 cpu.MemIns.mem[i][7:5],        // opcode decimal
                 cpu.MemIns.mem[i][4:0],        // immediate
                 cpu.MemIns.mem[i][4:0]);       // immediate decimal
    end
    $display("========================================");
endtask

typedef enum logic [2:0] {
    HLT, SKZ , ADD, AND, XOR, LDA, STO, JMP
} opcode_t;

initial begin

    $display("Testing reset");
    cpu.MemIns.mem[0] = {HLT, 5'bxxxxx};
    reset;
    dump_mem(4);
    dump_control();   // ✅ in control sau reset
    expect_halt(1'b0);

    $display("Testing HLT instruction");
    cpu.MemIns.mem[0] = { HLT, 5'd0 };
    clock(1); dump_control();
    reset;
    dump_mem(4);
    dump_control();
    clock(1); dump_control();
    clock(1); dump_control();
    clock(1); dump_control();
    clock(1); dump_control(); expect_halt(1'b1);
    clock(1); dump_control();

    $display("Testing JMP instruction");
    cpu.MemIns.mem[0] = { JMP, 5'd2 };
    cpu.MemIns.mem[1] = { JMP, 5'd2};
    cpu.MemIns.mem[2] = { HLT, 5'd0 };
    reset;
    dump_mem(4);
    clock(1); dump_control();
    clock(1); dump_control();
    clock(1); dump_control();
    clock(1); dump_control();
    clock(1); dump_control();
    clock(1); dump_control();
    clock(1); dump_control(); expect_halt(1'b1);

    $display("Testing SKZ instruction");
    cpu.MemIns.mem[0] = { SKZ, 5'd2 };
    cpu.MemIns.mem[1] = { JMP, 5'd2 };
    cpu.MemIns.mem[2] = { HLT, 5'd0 };
    reset;
    dump_mem(4);
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1); dump_control(); expect_halt(1'b1);

    $display("Testing LDA instruction");
    cpu.MemIns.mem[0] = { LDA, 5'd5 };
    cpu.MemData.mem[5] = {20} ;
    reset;
    dump_mem(4);
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; expect_acc(20) ; $display("memDa_value = %b", cpu.MemData.mem[5]) ;

    $display("Testing STO instruction");
    cpu.MemData.mem[5] = {18} ;
    cpu.MemIns.mem[0] = { LDA, 5'd5 };
    cpu.MemIns.mem[1] = { STO, 5'd10 };
    reset;
    dump_mem(4);
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; dump_control();
    clock(1) ; expect_Mem(18, 10) ;

    $display("test FINISHED");
    $finish;
end
endmodule
