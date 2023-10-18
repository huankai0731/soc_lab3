 module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
        output wire [5:0] e,

    output  wire                     awready,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     awvalid,
    output  wire                     arready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     wready,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    input   wire                     rready,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata, 
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
    

);

assign awready = awr && awvalid;
assign  wready = wr && wvalid;
reg wr,awr; 

assign arready= arr && arvalid;
assign rvalid= rv && rready;
assign rdata= dataout;
reg rv,arr;
reg [(pDATA_WIDTH-1):0]dataout;

assign tap_WE[3:0]={4{wvalid&&twe}};
assign tap_EN=1;
assign tap_A=tadd;
assign tap_Di=wdata;
reg [11:0] tadd;
reg  twe;

assign data_WE[3:0]={4{dwe}};
assign data_EN=1;
assign data_A=dadd;
assign data_Di=ddata;
reg dwe=1;
reg [11:0] dadd;
reg [31:0] ddata;

assign ss_tready=ssr;
assign sm_tvalid=smv;
assign sm_tdata=result;
reg ssr,smv;

initial begin
    rv<=0;arr<=0;
    ssr<=0;
    dadd=0;
    smv=0;
end

//data_ram initialize
initial begin
dwe<=1;ddata<=0;
@(posedge axis_clk);
for(integer x=0;x<11;x=x+1) begin
@(posedge axis_clk);
dadd=dadd+4;ddata<=0;end
dadd<=0;
dwe<=0;
end




reg signed [31:0]tap=0;
reg signed [31:0]result;
reg signed [31:0]coef;
reg [31:0]data;
reg [11:0]waddr;
reg [11:0]dadd_shift=0;
reg [11:0]counter=0;
integer z=0,i=0,j=0;

always @(posedge axis_clk) begin
//when ap_start=1,start block
while (!ap_start)begin 
 @(posedge axis_clk); 
 end


writedata(dadd_shift ,ss_tdata);
result=0;
dwe<=0;
z=j;
    for(i=0;i<Tape_Num;i=i+1) begin       
        tadd=i<<2;
        dadd=(z-i)<<2;
        @(posedge axis_clk);
        @(posedge axis_clk);
        coef<=tap_Do;
        data<=data_Do;        
        @(posedge axis_clk);
        
	if((z-i)==0) z=11+j;
        tap=coef*data;
        result=result+tap;
    end
    j=j+1;
    smv<=1;
    if(j==11) j=0;
    dadd_shift=dadd_shift+4;
    if(dadd_shift==44) dadd_shift=0;
    dadd<=dadd_shift;
    ssr<=1;
    @(posedge axis_clk);
    ssr<=0; smv<=0;
    counter=counter+1;
    if(counter==600) dataout<=6;ap_start<=0;
end

task writedata;
input [11:0]addr;
input [31:0]data;
begin
@(posedge axis_clk);
ddata<=data;
dwe<=1;
@(posedge axis_clk);
end
endtask

task read_coef_data;
input [11:0]caddr;
input [11:0]daddr;
output [31:0]coefdata;
output [31:0]data;
begin 
@(posedge axis_clk);
coefdata<=tap_Do;
data<=data_Do;
end
endtask 

reg ap_start=0;
reg ap_idle=1;
reg datalength;
integer x=0;
always @(posedge axis_clk) begin
    wr<=0;awr<=0;twe<=0;rv<=0;
    
    if((awaddr>>4)==0) begin
     rv<=1;
     if(wdata==1) ap_start<=1;
     @(posedge axis_clk);
     end
     
    if((awaddr>>4)==1)begin
     wr<=1;awr<=1;
     datalength<=wdata;
     $display("datal",datalength);
     end
    
    //tap address
    if((awaddr>>4)>1) begin
        //write
        if(wvalid) begin
            twe<=1;
            tadd<=awaddr-32;
            wr<=1;awr<=1; end
        //read
        if(arvalid) begin
            tadd<=araddr-32;
            rdataout;
            rv<=0;end       
    end
end



task rdataout; begin           
    @(posedge axis_clk);
    arr<=1; 
    @(posedge axis_clk);
    dataout<=tap_Do;
    rv<=1;
    @(posedge axis_clk);end
endtask
    

endmodule
