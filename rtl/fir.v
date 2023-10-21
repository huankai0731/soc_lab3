 module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
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


reg [31:0]axi_data;
reg [11:0]axi_addr;
reg write_tapdata=0,read_tapdata=0,write_datalength=0;
reg write_done=0;


///////////////////////
/////axil-write////////
///////////////////////
always @(posedge axis_clk)begin 
if(tap_ram_init_done)begin 
    if(awvalid==1&&write_done==0&&wr==0) begin
        wr<=0;awr<=0;
        axi_addr<=awaddr;
        axi_data<=wdata;
        if((awaddr>>4)==0) write_ap(wdata);
        if((awaddr>>4)==1) write_datalength<=1;
        if((awaddr>>4)>1) write_tapdata<=1;
    end
    if(write_done==1)begin
        wr<=1;awr<=1;
        write_done<=0;
        tap_ram_we<=0;
    end
    if(wr==1) wr<=0;
end
end

//write coef into tap ram
always @(posedge axis_clk)begin 
if(write_tapdata==1)begin 
    tap_ram_we<=1;
    tap_ram_addr<=axi_addr-32;
    tap_ram_data<=axi_data;
    write_done<=1;
    write_tapdata<=0;
end
end

//wrwite datalength
always @(posedge axis_clk)begin 
if(write_datalength==1)
begin 
datalength<=wdata;
write_done<=1;
write_datalength<=0;
end
end

//check ap_ctrl
task write_ap;
input [31:0]data;
begin 
if(data==1)ap_start<=1;
write_done<=1;
end
endtask 
////////////////////////////////////////////
////////////////////////////////////////////

//////////////////////
//////axil-read///////
//////////////////////
always @(posedge axis_clk)begin 
if(tap_ram_init_done)begin 
    //if((araddr>>4)==1)
    if((araddr>>4)>1) begin
    read_tapdata<=1;
    end
end
end

///delay register
reg rvd1=0,rvd2=0,rvd3=0;

//read coef from tap ram//
always @(posedge axis_clk)begin 
if(rv==1)begin 
 rv<=0;rvd1<=0;rvd2<=0;rvd3<=0;read_tapdata<=0;
 end
if(read_tapdata==1&&!rv)
begin 
tap_ram_addr<=araddr-32;
dataout<=tap_Do;
rvd1<=1;rvd2<=rvd1;rvd3<=rvd2;rv<=rvd3;
arr<=1;
end
end
////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////



assign awready = awr && awvalid;
assign  wready = wr;
reg wr,awr; 

assign arready= arr && arvalid;
assign rvalid= rv;
assign rdata= dataout;
reg rv,arr;
reg [31:0]dataout;

assign tap_WE[3:0]={4{tap_ram_we}};
assign tap_EN=1;
assign tap_A=tap_ram_addr;
assign tap_Di=tap_ram_data;
reg [31:0]tap_ram_data;
reg [11:0] tap_ram_addr;
reg  tap_ram_we;

assign data_WE[3:0]={4{data_ram_we}};
assign data_EN=1;
assign data_A=data_ram_addr;
assign data_Di=data_ram_data;
reg data_ram_we=1;
reg [11:0] data_ram_addr;
reg [31:0] data_ram_data;

assign ss_tready=ssr;
assign sm_tvalid=smv;
assign sm_tdata=result;
assign sm_tlast=sml;
reg ssr,smv,sml;

//state control
reg tap_ram_init_done;
reg data_ram_init_done;
//

reg [11:0]waddr;

reg [11:0]counter=0;

reg ap_start=0;
reg ap_idle=1;
reg [11:0]datalength=0;


initial begin
    rv=0;arr=0;
    ssr=0;
    smv=0;
    sml=0;
    wr=0;awr=0;
    tap_ram_init_done=0;
    data_ram_init_done=0;
end
integer  x=0,y=0,write_data_cycle=0;




//write data into data ram
always @(posedge axis_clk)begin 
if(ap_start==1&&fir_operation==0)
begin 
if(ssr==1)ssr<=0;
if(smv==1)smv<=0;
if(write_data_cycle<2)begin
    data_ram_we<=1;
    data_ram_addr<=dadd_shift;
    data_ram_data<=ss_tdata;
    write_data_cycle=write_data_cycle+1;
    end
    else begin
    write_data_cycle=0;
    fir_operation<=1;
    result<=0;
    end
end
end


///////////////////////////////////////////////////////
reg fir_operation=0;
reg [11:0]dadd_shift=0;
reg finish_operation=0;
reg read_addr_reuest=1;
reg signed [31:0]tap=0;
reg signed [31:0]result;
reg signed [31:0]coef;
reg [31:0]data;

always @(posedge axis_clk) begin
//when ap_start=1,start block
if(ap_start==1&&fir_operation==1)begin 
data_ram_we<=0;
    if(read_addr_reuest==0)begin
        read_addr_reuest<=1;
        tap=coef*data;
        result=result+tap;
        if(i==11)begin
            dadd_shift=dadd_shift+4;
            if(dadd_shift==44) dadd_shift=0;
            j=j+1;
            if(j==11) j=0;
            z<=j;
            fir_operation<=0;
            ssr<=1;smv<=1;
            i=0;            
            counter=counter+1;
            if(counter==datalength) begin
                finish_operation<=1;
                ap_start<=0;
                sml<=1;
            end
        end
    end

end
end
integer finish_delay=0;
////finish
always @(posedge axis_clk) begin
if(ap_start==1) begin
dataout<=0;
rv<=1;
end
if(finish_operation==1)begin
dataout<=6;
rv<=1;
tap_ram_init_done<=0;
data_ram_init_done<=0;
smv<=0;ssr<=0;sml<=0;counter<=0;
finish_delay=finish_delay+1;
end
if(finish_delay==5)begin
    finish_delay<=0;
    finish_operation<=0;
end
end

integer z=0,i=0,j=0,cycle=0;


//fir generator
always @(posedge axis_clk) begin
if(read_addr_reuest==1&&fir_operation==1)begin
    if(i<Tape_Num)begin
        if(cycle<3)begin
            tap_ram_addr<=i<<2;
            data_ram_addr<=(z-i)<<2;
            coef<=tap_Do;
            data<=data_Do; 
            cycle=cycle+1;
            end
        else begin
            cycle=0;
            read_addr_reuest=0;
            if((z-i)==0) z=11+j;
            i=i+1;
            end
        end
    end
end
    
integer clk=0;



reg tap_init_addr=0;
reg data_init_addr=0;     

always @(posedge axis_clk) begin
if(tap_ram_init_done==0&&tap_init_addr<=1) begin
tap_ram_we<=1;
    if(y<11)begin
        tap_ram_addr<=tap_ram_addr+4;
        tap_ram_data<=0;
        y<=y+1;
    end
    else begin
        y<=0;
        tap_ram_init_done<=1;
        tap_ram_we<=0;
        tap_ram_addr<=0;
        tap_init_addr<=0;
    end

end
if(tap_init_addr==0&&tap_ram_init_done==0)begin
    tap_ram_addr<=0;tap_init_addr<=1;tap_ram_data<=0;tap_ram_we<=1;
end
end
    
    
always @(posedge axis_clk) begin
if(data_ram_init_done==0&&data_init_addr<=1) begin
data_ram_we<=1;
    if(x<11)begin
        data_ram_addr<=data_ram_addr+4;
        data_ram_data<=0;
        x<=x+1;
    end
    else begin
        x<=0;
        data_ram_init_done<=1;
        data_ram_we<=0;
        data_ram_addr<=0;
        data_init_addr<=0;
    end

end
if(data_init_addr==0&&data_ram_init_done==0)begin
    data_ram_addr<=0;data_init_addr<=1;data_ram_data<=0;data_ram_we<=1;
end
end


endmodule