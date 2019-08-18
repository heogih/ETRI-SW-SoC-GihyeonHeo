/*
 *  cnnip_ctrlr.sv -- CNN IP controller
 *  ETRI <SW-SoC AI Deep Learning HW Accelerator RTL Design> course material
 *
 *  first draft by Junyoung Park
 */
module cnnip_ctrlr #
(
  parameter DATA_WIDTH   = 32,
  parameter ADDR_WIDTH   = 12,
  parameter READ_LATENCY = 2
)
(
  // clock and reset signals from domain a
  input wire clk_a,
  input wire arstz_aq,

  // internal memories
  cnnip_mem_if.master to_input_mem,
  cnnip_mem_if.master to_weight_mem,
  cnnip_mem_if.master to_feature_mem,

  // configuration registers
  input wire         CMD_START,
  input wire   [7:0] MODE_KERNEL_SIZE,
  input wire   [7:0] MODE_KERNEL_NUMS,
  input wire   [1:0] MODE_STRIDE,
  input wire         MODE_PADDING,

  output wire        CMD_DONE,
  output wire        CMD_DONE_VALID

);

    localparam image = 5; 
	localparam bram0_iaddr = 12'h100;
	localparam bram1_iaddr = 12'h200;
	localparam bram2_iaddr = 12'h300;
    // sample FSM
    localparam IDLE = 0;
    localparam CONV = 1;
    localparam DONE = 2;
    
    reg [1:0] state_aq, state_next;
    
    // internal registers
    reg [DATA_WIDTH-1 : 0] x_data, w_data;
    //reg [DATA_WIDTH-1 : 0] y_data;
    reg [ADDR_WIDTH-1 : 0] x_addr, w_addr, y_addr;
    reg valid;
    reg d_valid;
    //reg y_valid;
    
    wire [DATA_WIDTH*2-1:0] multi;
    wire [DATA_WIDTH-1:0] sat_multi;
    wire [DATA_WIDTH-1:0] sat_sum;
    wire [7:0] result_size;
    reg [DATA_WIDTH:0] sum;
    reg [4:0] count;
    reg [4:0] valid_count;
    reg [7:0] xcount;
    reg [7:0] ycount;
    reg [7:0] result_count;
    reg [3:0] jcount;
    reg [3:0] icount;
    reg [1:0] latency_count;
    reg wait_done;
    reg en_latched;
    
    assign result_size = ((image - MODE_KERNEL_SIZE) >> (MODE_STRIDE - 1))+1;

    always@(posedge clk_a, negedge arstz_aq)
	begin
        if(!arstz_aq)
            state_aq <= IDLE;
        else state_aq <= state_next;
	end
		
    always @(*)
    begin
    state_next = state_aq;
    case (state_aq)
      IDLE:
        if (CMD_START) state_next = CONV;
    
      CONV:
        if (wait_done) state_next = DONE;
    
      DONE:
        state_next = IDLE;
    endcase
    end
    always@(posedge clk_a, negedge arstz_aq)
	begin
	if(!arstz_aq)
		wait_done<=0;
    else if((ycount==0)&&(xcount==0)&&(icount==0)
			&&(state_aq==CONV)&& (d_valid==1))	// y_addr>>2
		wait_done<=1;
	else wait_done<=0;
	end

//--------------------------DONE state-----------------------------

	assign CMD_DONE = (state_aq==DONE);
	assign CMD_DONE_VALID = (state_aq==DONE);

//--------------------------Address Generater----------------------------
    
    always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            latency_count <= 0;
        else if(latency_count == READ_LATENCY)
            latency_count <= 0;
        else
            latency_count <= latency_count + 1;
    end
    
    always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            ycount <= 0;
		else if((state_aq==IDLE)||(state_aq==DONE))
			ycount <= 0;
        else if( ycount == result_size-1
				&& xcount == result_size-1
				&& icount == MODE_KERNEL_SIZE-1 && jcount == MODE_KERNEL_SIZE-1  && latency_count == READ_LATENCY)
			ycount <= 0;
		else if(xcount == result_size-1
				&& icount == MODE_KERNEL_SIZE-1 && jcount == MODE_KERNEL_SIZE-1  && latency_count == READ_LATENCY)
			ycount <= ycount + 1;
        else ycount <= ycount;
    end
    
    always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            xcount <= 0;
		else if((state_aq==IDLE)||(state_aq==DONE))
			xcount <= 0;
		else if(xcount == result_size-1
				&& icount == MODE_KERNEL_SIZE-1 && jcount == MODE_KERNEL_SIZE-1  && latency_count == READ_LATENCY)
			xcount <= 0;
		else if(icount == MODE_KERNEL_SIZE-1 && jcount == MODE_KERNEL_SIZE-1  && latency_count == READ_LATENCY)
			xcount <= xcount + 1;
        else xcount <= xcount;
    end
    
    always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            icount <= 0;
		else if((state_aq==IDLE)||(state_aq==DONE))
			icount <= 0;
        else if(icount == MODE_KERNEL_SIZE-1 && jcount == MODE_KERNEL_SIZE-1 && latency_count == READ_LATENCY) 
			icount <= 0;
		else if(jcount == MODE_KERNEL_SIZE-1 && latency_count == READ_LATENCY)
			icount <= icount +1;
		else icount <= icount;
    end
    
    always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            jcount <= 0;
		else if((state_aq==IDLE)||(state_aq==DONE))
			jcount <= 0;
        else if (jcount == MODE_KERNEL_SIZE-1 && latency_count == READ_LATENCY)
			jcount <= 0;
		else if(latency_count == READ_LATENCY) jcount <= jcount + 1;
    end



//--------------------------Address-------------------------------


    always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            x_addr <= bram0_iaddr;
		else if((state_aq==IDLE)||(state_aq==DONE))
			x_addr <= bram0_iaddr;
		else if(to_input_mem.valid)
			x_addr <= bram0_iaddr + 4*(((xcount*MODE_STRIDE)+jcount) + image*((ycount*MODE_STRIDE)+icount));
    end

    always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            w_addr <= bram1_iaddr;
		else if((state_aq==IDLE)||(state_aq==DONE))
			w_addr <= bram1_iaddr;
        else if(to_weight_mem.valid)
			w_addr <= bram1_iaddr +4*count;
    end

    always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            y_addr <= bram2_iaddr;
		else if((state_aq==IDLE)||(state_aq==DONE))
			y_addr <= bram2_iaddr;
        else if(valid == 1)
			y_addr <= bram2_iaddr + 4*result_count;
    end

//--------------------------read BRAM data-------------------------------

  always @(posedge clk_a, negedge arstz_aq) begin
    if (arstz_aq == 1'b0)
        x_data <= 'b0;
    else if((state_aq==IDLE)||(state_aq==DONE))
        x_data <= 'b0;
    else if(to_input_mem.valid)
        x_data <= to_input_mem.dout;
    else
        x_data <= 'b0;
  end
  
  always @(posedge clk_a, negedge arstz_aq) begin
    if (arstz_aq == 1'b0)
        w_data <= 'b0;
    else if((state_aq==IDLE)||(state_aq==DONE))
        w_data <= 'b0;
    else if(to_weight_mem.valid)
        w_data <= to_weight_mem.dout;
    else
        w_data <= 'b0;
  end
  
//--------------------------Calculation-------------------------------

	assign multi = x_data * w_data;
	assign sat_multi = multi[DATA_WIDTH-1:0];

	always@(posedge clk_a, negedge arstz_aq)
	begin
		if(!arstz_aq)
			sum <= 0;
		else if((state_aq==IDLE)||(state_aq==DONE))
			sum <= 0;
		else if(d_valid)
			sum<= sat_multi;
		else if(valid_count < MODE_KERNEL_SIZE * MODE_KERNEL_SIZE)
			sum <= sat_sum + sat_multi;
		else
			sum <= 0;
	end

	assign sat_sum[DATA_WIDTH-1:0] = sum[DATA_WIDTH-1:0];
   

//--------------------------y_valid signal-------------------------------
	
	always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            count <= 0;
		else if((state_aq==IDLE)||(state_aq==DONE))
			count <= 0;
        else if (count == (MODE_KERNEL_SIZE*MODE_KERNEL_SIZE)-1 && latency_count == READ_LATENCY)
			count <= 0;
		else if(latency_count == READ_LATENCY) count <= count + 1;
    end
    
    always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            result_count <= 0;
		else if(d_valid && result_count == result_size*result_size -1)
			result_count <= 0;
        else if(d_valid)
			result_count <= result_count + 1;
    end
    
    always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            valid_count <= 0;
		else if(latency_count == READ_LATENCY)
			valid_count <= count;
    end
    
	always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            valid <= 0;
        else if (en_latched && valid_count == (MODE_KERNEL_SIZE*MODE_KERNEL_SIZE)-1 && latency_count == READ_LATENCY)
			valid <= 1;
		else valid <= 0;
    end
    
	always@(posedge clk_a, negedge arstz_aq)
    begin
        if(!arstz_aq)
            d_valid <= 0;
		else if((state_aq==IDLE)||(state_aq==DONE))
			d_valid <= 0;
        else
			d_valid <= valid;
	end
	
//	always@(posedge clk_a, negedge arstz_aq)
//    begin
//        if(!arstz_aq)
//            y_valid <= 0;
//		else if((state_aq==IDLE)||(state_aq==DONE))
//			y_valid <= 0;
//        else
//			y_valid <= d_valid;
//	end


//--------------------------y_data-------------------------------
	

//	always@(posedge clk_a, negedge arstz_aq)
//	begin
//		if(!arstz_aq)
//			y_data <= 0;
//		else if((state_aq==IDLE)||(state_aq==DONE))
//			y_data <= 0;
//		else if(d_valid)
//			y_data <= sat_sum;
//	end
	
//--------------------------connection-------------------------------	
	always@(posedge clk_a, negedge arstz_aq)
	begin
		if(!arstz_aq)
			en_latched <= 0;
		else if(state_aq == CONV)
			en_latched <= 1;
	    else
	        en_latched <= 0;
	end
	
  assign to_input_mem.en   = (en_latched)? 1: 0;
  assign to_input_mem.we   = (en_latched)? 'b0: 'b1;
  assign to_input_mem.addr = x_addr;
  
  assign to_weight_mem.en   = (en_latched)? 1: 0;
  assign to_weight_mem.we   = (en_latched)? 'b0: 'b1;
  assign to_weight_mem.addr = w_addr;
  
  assign to_feature_mem.en   = (d_valid && en_latched)? 1: 0;
  assign to_feature_mem.we   = (en_latched)? 'b1: 'b0;
  assign to_feature_mem.addr = y_addr;
  assign to_feature_mem.din  = (d_valid)? sat_sum: 0;
  
endmodule// cnnip_ctrlr
