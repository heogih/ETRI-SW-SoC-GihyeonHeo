
`timescale 1 ns / 1 ps

module bram_wrapper #( 
        parameter READ_LATENCY = 2,
        parameter ADDR_WIDTH = 16,
        parameter DATA_WIDTH = 32 )
    (
        input wire clk,
        input wire rst,
        input wire we,
        input wire ena,
        input wire [ADDR_WIDTH-1:0] waddr,
        input wire [DATA_WIDTH-1:0] din,
        input wire enb,
        input wire [ADDR_WIDTH-1:0] raddr,
        output wire [DATA_WIDTH-1:0] dout,
        output wire valid
    );
    wire en;
    reg [1:0] wait_counter;
    reg [1:0] wait_counter_next;
    reg en_bram;
    reg valid_slv;
    
    enum { IDLE, LCTL, READ } cstate, nstate;
    
    always@(posedge clk, negedge rst) begin
        if (rst == 1'b0)
            cstate <= IDLE;
        else
            cstate <= nstate;
    end
    
    always@(*) begin
    nstate = cstate;
        case (cstate)     
            IDLE : begin
                if(enb == 1'b1 && we == 1'b0) begin
                    if (READ_LATENCY == 1)
                        nstate = READ;
                    else
                        nstate = LCTL;
                end
            end     
            LCTL : begin
                if(wait_counter == READ_LATENCY-1)
                    nstate = READ;
            end   
            READ : begin
                nstate = IDLE;
            end
        endcase
    end
    
    always@(*) begin
        en_bram = enb;
        valid_slv = 0;
        case (cstate)
            IDLE : begin
                en_bram = enb;
                valid_slv = 0;
            end            
            LCTL : begin
                en_bram = 1;
                valid_slv = 0;
            end       
            READ : begin
                en_bram = 0;
                valid_slv = 1;
            end
        endcase
    end
    
    assign en = en_bram;
    assign valid = valid_slv;
    
    always @(posedge clk, negedge rst) begin
        if(rst == 1'b0)
            wait_counter <= 0;
        else
            wait_counter <= wait_counter_next;
    end
        
    always@(*) begin
        wait_counter_next = wait_counter;
        case (cstate)
            IDLE : wait_counter_next = 2'b1;
            LCTL : wait_counter_next = wait_counter + 1'b1;
            default : wait_counter_next = 0;
        endcase
    end
    
    blk_mem_gen_0 dual_bram0 (
      .clka(clk),    // input wire clka
      .ena(ena),      // input wire ena
      .wea(we),      // input wire [0 : 0] wea
      .addra(waddr),  // input wire [15 : 0] addra
      .dina(din),    // input wire [31 : 0] dina
      .clkb(clk),    // input wire clkb
      .enb(en),      // input wire enb
      .addrb(raddr),  // input wire [15 : 0] addrb
      .doutb(dout)  // output wire [31 : 0] doutb
    );

endmodule
