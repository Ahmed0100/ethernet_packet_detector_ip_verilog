module counter(clk,reset,en,en_up,en_down,load0,load1,load255,count0,count);
input clk,reset,en,en_up,en_down,load0,load1,load255;
output reg [3:0] count0;
output reg [7:0] count;
always @(posedge clk)
begin
	if(reset)
		begin count0<=4'b0; count<=8'd0; end
	else if(load0)
		count<=8'b0;
	else if(load1)
		count<=8'd1;
	else if(load255)
		count<=8'd255;
	else if(en)
		count0<=count0+1;
	else if(en_up)
		count<=count+1;
	else if(en_down)
		count<=count-1;
end
endmodule 
