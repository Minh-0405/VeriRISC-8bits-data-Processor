module VeriRISC_CPU (
        input logic clk, rst,
        output logic HALT
);
    logic pc_load, pc_en, jmp_control ;
    logic [4:0] pc_addr, addr_in, skz_addr ;
    logic accumulator_control, accumulator_load ;
    logic memIns_en, memDa_en, memDa_we, zero ;
    logic [7:0] acc_in, acc_out, alu_out, memDa_out, ins;

    PC counter (.clk(clk), .rst(rst), .load(pc_load), .en(pc_en),
                    .data_in(addr_in), .pc_count(pc_addr)) ;

    MEM MemIns (.clk(clk), .en(memIns_en), .we('0), .addr(pc_addr),
                    .din('0), .dout(ins)) ;

    CONTROL control_signal (.opcode(ins[7:5]), .clk(clk), .rst(rst), .is_zero(zero),
                    .pc_load(pc_load), .pc_en(pc_en), .halt(HALT), .jmp(jmp_control),
                    .accumulator_load(accumulator_load), .accumulator_control(accumulator_control),
                    .memIns_en(memIns_en), .memDa_en(memDa_en), .memDa_we(memDa_we)) ;

    MEM MemData (.clk(clk), .en(memDa_en), .we(memDa_we),
                .addr(ins[4:0]), .din(acc_out), .dout(memDa_out)) ;

    ALU alu (.rs1(acc_out), .rs2(memDa_out), .rd(alu_out), .opcode(ins[7:5]), .is_zero(zero)) ;

    mux_parameter #(.WIDTH(8)) muxData (.d0(alu_out), .d1(memDa_out),
                                        .control(accumulator_control), .y(acc_in)) ;

    RST accumulator (.clk(clk), .rst(rst), .load(accumulator_load),
                            .data_in(acc_in), .data_out(acc_out)) ;

    assign skz_addr = pc_addr + 2 ;

    mux_parameter #(.WIDTH(5)) muxAddr (.d0(skz_addr), .d1(ins[4:0]),
                                        .control(jmp_control), .y(addr_in)) ;
endmodule


module CONTROL (
        input logic [2:0] opcode,
        input logic clk, rst,
        input logic is_zero,
        output logic pc_load, pc_en, halt,
        output logic accumulator_load, accumulator_control,
        output logic memIns_en, memDa_en, memDa_we,
        output logic jmp
);
    typedef enum logic [3:0] {
        s0 = 4'b0000,
        s1 = 4'b0001, // fetch
        s2 = 4'b0010, // decode
        s3 = 4'b0100, // execute
        s4 = 4'b1000  // writeback
    } statetype_e;

    statetype_e state, nextstate;

    always_comb begin
    if (!halt) begin
        case (state)
            s0: nextstate = s1;
            s1: nextstate = s2;
            s2: nextstate = s3;
            s3: nextstate = s4;
            s4: nextstate = s1;
            default: nextstate = s0;
        endcase
    end else begin
        nextstate = state; // giữ nguyên khi halt
    end
end

    logic ACC_LOAD, ACC_MEM, STO, HALT, JMP, SKZ ;
    always_comb
    begin
        ACC_LOAD = (opcode == 2 | opcode == 3 | opcode == 4 | opcode == 5) ;
        ACC_MEM = (opcode == 5) ;
        STO = (opcode == 6) ;
        HALT = (opcode == 0) ;
        JMP = (opcode == 7) ;
        SKZ = (opcode == 1) ;
    end

    always_ff @(posedge clk or posedge rst) begin
    if (rst)
        state <= s0;      // reset về FETCH
    else
        state <= nextstate;
    end

    always_comb begin
    if (rst) begin
        pc_load = 0; pc_en = 0; halt = 0; jmp = 0;
        accumulator_control = 0; accumulator_load = 0;
        memIns_en = 0; memDa_en = 0; memDa_we = 0;
    end else begin
        case (state)
            s1: begin // FETCH
                pc_load = 0; pc_en = 0; halt = 0; jmp = JMP;
                accumulator_control = 0; accumulator_load = 0;
                memIns_en = 1; memDa_en = 0; memDa_we = 0;
            end
            s2: begin // DECODE
                pc_load = 0; pc_en = 0; halt = 0; jmp = JMP;
                accumulator_control = 0; accumulator_load = 0;
                memIns_en = 0; memDa_en = 1; memDa_we = 0;
            end
            s3: begin // EXECUTE
                pc_load = 0; pc_en = 0; halt = HALT; jmp = JMP;
                accumulator_control = 0; accumulator_load = 0;
                memIns_en = 0; memDa_en = 0; memDa_we = 0;
            end
            s4: begin // WRITEBACK
                pc_load = JMP | (SKZ & is_zero); pc_en = 1; halt = HALT; jmp = JMP;
                accumulator_control = ACC_MEM;
                accumulator_load = ACC_LOAD;
                memIns_en = 0; memDa_en = 1; memDa_we = STO;
            end
            default: begin
                pc_load = 0; pc_en = 0; halt = 0; jmp = 0;
                accumulator_control = 0; accumulator_load = 0;
                memIns_en = 0; memDa_en = 0; memDa_we = 0;
            end
        endcase
    end
end
endmodule


module ALU (
    input logic [7:0] rs1, rs2,
    input logic [2:0] opcode,
    output logic [7:0] rd,
    output logic is_zero
);
    logic [7:0] lut [8];
    always_comb begin
        begin
            begin
                is_zero = !(|rs1) ;
                lut[0] = rs1;
                lut[1] = rs1;
                lut[2] = rs1 + rs2; // 010
                lut[3] = rs1 & rs2; //011
                lut[4] = rs1 ^ rs2; //100
                lut[5] = rs2;//101
                lut[6] = rs1;
                lut[7] = rs1;
                rd = lut[opcode];
            end
        end
    end
endmodule


module MEM (
    input  logic       clk,
    input  logic       en,
    input  logic       we,
    input  logic [4:0] addr,
    input  logic [7:0] din,
    output logic [7:0] dout
);


    logic [7:0] mem [32];

    always_ff @(posedge clk) begin
        if (en) begin
            if (we) begin
                mem[addr] <= din;
            end else begin
                dout <= mem[addr];
            end
        end
    end

endmodule

module mux_parameter
            #(parameter int WIDTH = 5)
            (
              input logic [WIDTH-1:0] d0, d1,
              input logic control,
              output logic [WIDTH-1:0] y
            );
    assign y = control ? d1 : d0 ;
endmodule


module PC (
        input logic clk, rst, load, en,
        input logic [4:0] data_in,
        output logic [4:0] pc_count
);
    always_ff @(posedge clk, posedge rst)
    begin
        if(rst) pc_count <= 5'b0 ;
        else
        begin
            if(en)
                begin
                        if(load) pc_count <= data_in ;
                        else pc_count <= pc_count + 1 ;
                end
        end
    end
endmodule



module RST (
        input logic clk, rst,
        input logic [7:0] data_in,
        input logic load,
        output logic [7:0] data_out
);
        always_ff @(posedge clk)begin
                if (rst)
                data_out <= 8'b0;
                else if(load)
                data_out <= data_in;
        end
endmodule
