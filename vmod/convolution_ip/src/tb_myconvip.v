`timescale 1ns / 1ps


module tb_conv();

//Declaration of Variables
reg clk;
reg rstn;
reg [15:0] awaddr=0;
reg [2:0] awprot =0;
reg awvalid=0;
wire awready;

reg [31:0] wdata=32'h00000000;
reg [(32/8)-1:0] wstrb=4'b1111;
reg wvalid=0;
wire wready;

wire [1:0] bresp;
wire bvalid;
reg bready;

reg [15:0] araddr=0;
reg [2:0] arprot =0;
reg arvalid=0;
wire arready;

wire [31:0] rdata;
wire [1:0] rresp;
wire rvalid;
reg rready=0;



//Instantiation
cnnip_v1_0  #(
.C_S00_AXI_DATA_WIDTH(32),
.C_S00_AXI_ADDR_WIDTH(16)
)dut_myconv_ip
(
.s00_axi_aclk(clk),
.s00_axi_aresetn(rstn),
.s00_axi_awaddr(awaddr),
.s00_axi_awprot(awprot),
.s00_axi_awvalid(awvalid),
.s00_axi_awready(awready),
.s00_axi_wdata(wdata),
.s00_axi_wstrb(wstrb),
.s00_axi_wvalid(wvalid),
.s00_axi_wready(wready),
.s00_axi_bresp(bresp),
.s00_axi_bvalid(bvalid),
.s00_axi_bready(bready),
.s00_axi_araddr(araddr),
.s00_axi_arprot(arprot),
.s00_axi_arvalid(arvalid),
.s00_axi_arready(arready),
.s00_axi_rdata(rdata),
.s00_axi_rresp(rresp),
.s00_axi_rvalid(rvalid),
.s00_axi_rready(rready)
);

integer i,j;
always #5 clk = ~clk;

initial begin
clk = 0;
rstn =0;
@(posedge clk) #1 rstn =1;
repeat(5)@(posedge clk);
@(posedge clk) #1 begin awvalid =1'b1;wvalid= 1'b1; bready=1'b1;end
@(posedge clk) #1 begin awaddr = 16'h0008; awvalid =1'b1;wvalid= 1'b1; wdata = 32'h00030001; end
@(posedge clk);
@(posedge clk) #1 begin awvalid =1'b1;wvalid= 1'b1; bready=1'b1;end // 1clk 미뤄주어야 값이 정확히 들어감 
@(posedge clk);
@(posedge clk) #1 begin awvalid =1'b1;wvalid= 1'b1; bready=1'b1;end
@(posedge clk) #1 begin awaddr = 16'h000c; awvalid =1'b1;wvalid= 1'b1; wdata = 32'h00000001; end
@(posedge clk);
@(posedge clk) #1 begin awvalid =1'b1;wvalid= 1'b1; bready=1'b1;end
@(posedge clk);



for(i=0;i<25;i=i+1)
begin
@(posedge clk) #1 begin awvalid =1'b1;wvalid= 1'b1; bready=1'b1;end
@(posedge clk) #1 begin awaddr = 16'h0100+4*i; awvalid =1'b1;wvalid= 1'b1; wdata = i+1; end
@(posedge clk);
end


for(j=0;j<9;j=j+1)
begin
@(posedge clk) #1 begin awvalid =1'b1;wvalid= 1'b1; bready=1'b1;end
@(posedge clk) #1 begin awaddr = 16'h0200+4*j; awvalid =1'b1;wvalid= 1'b1; wdata = 1; end
@(posedge clk);
end

@(posedge clk) #1 begin awvalid =1'b1;wvalid= 1'b1; bready=1'b1;end
@(posedge clk) #1 begin awaddr = 16'h0000; awvalid =1'b1;wvalid= 1'b1; wdata = 32'hffffffff; end
@(posedge clk);


repeat(500)@(posedge clk);

$finish;
end



endmodule