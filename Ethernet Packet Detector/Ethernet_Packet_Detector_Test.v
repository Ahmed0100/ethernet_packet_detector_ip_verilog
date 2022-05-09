`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Design Name:   Ethernet_Packet_Detector_Test
////////////////////////////////////////////////////////////////////////////////

module Ethernet_Packet_Detector_Test;
	//Declare the clock period in nano seconds
	parameter CLOCK_PERIOD=10;
	// Inputs
	reg clk;
	reg reset;
	reg [7:0] data;
	reg control;

	// Outputs
	wire preamble_valid;
	wire src_addr_valid;
	wire dst_addr_valid;
	wire type_length_valid;
	wire packet_size_valid;
	wire [3:0] valid_packet_counter;
	//
	reg [13:0] vectors [0:1000]; //holds the test vectors loaded from an external text file.
	integer f, //variable used in opening an external file to write the results to. 
	vector_num,//variable used to hold the index of the test vector currently used in the test bench.
	errors;//variable to hold the number of errors detected.
	reg [4:0] expected_outputs;//holds the expected correct outputs to be compared with the generated outputs
	wire [4:0] outputs={preamble_valid,dst_addr_valid,src_addr_valid,type_length_valid,packet_size_valid};
	
	//Instantiation of the UUT(Unit Under Test) 
	Ethernet_Packet_Detector uut (
		.clk(clk), 
		.reset(reset), 
		.data(data), 
		.control(control), 
		.preamble_valid(preamble_valid),  
		.dst_addr_valid(dst_addr_valid), 
		.src_addr_valid(src_addr_valid),
		.type_length_valid(type_length_valid), 
		.packet_size_valid(packet_size_valid), 
		.valid_packet_counter(valid_packet_counter)
	);

	initial 
	begin
		// Initialize Inputs
		clk = 0;
		$readmemb("vectors.tv",vectors); //loading the test vectors from an external text file to (vectors).
		f=$fopen("outputs.txt","w");  //opening an external text file to write the results to .
		vector_num=0; //initializing the vectors index with 0.
		errors=0; // initializing the errors with 0.
		// Wait 100 ns for global reset to finish
		reset=1; #100 reset=0;
	end
	
	always //generating clock with period 10ns.  
	begin
		#(CLOCK_PERIOD/2) clk<=!clk;
	end
	
	always @(posedge clk)
	begin
		if(!reset)
		begin
	
			{control,data,expected_outputs}=vectors[vector_num];//loading the stimulus values into the UUT inputs.
			#1; //waiting 1ns for the outputs to be generated.
			if(expected_outputs==5'b11111)//Just a case used to indicate the end of the test when loaded from the test file.
			begin
				$display("Total number of valid packets = %d",valid_packet_counter);//To be sent to the terminal.
				$fwrite(f,"Total number of valid packets = %d \n",valid_packet_counter);//To be written to the outputs file.
				$display("Test Finished with %d Errors ... See logs above for more details ",errors);
				$fwrite(f,"Test Finished with %d Errors ... See logs above for more details \n ",errors);
				$fclose(f);//closing the file before exit.
				$finish;//finishing the test session.
			end
			//Message to be displayed in the terminal.
			$display("Time =%d ns -- Control bit = %b -- Data_in = %h -- ",$realtime,control,data,
			"Outputs[preamble_valid,dst_addr_valid,src_addr_valid,type_length_valid,packet_size_valid]",
			"= %b -- ",outputs,
			"Expected outputs = %b -- Valid packet counter= %d ",expected_outputs,valid_packet_counter);
			//Message to be written to the outputs text file.
			$fwrite(f,"Time =%d ns -- Control bit = %b -- Data_in = %h -- ",$realtime,control,data,
			"Outputs[preamble_valid,dst_addr_valid,src_addr_valid,type_length_valid,packet_size_valid]",
			"= %b -- ",outputs,
			"Expected outputs = %b -- Valid packet counter=%d \n \n",expected_outputs,valid_packet_counter);
			if(outputs!=expected_outputs)//Detecting error case.
			begin
				//Message to be displayed in the terminal.
				$display("WRONG RESULTS !!! --Time =%d ns -- Control bit = %b -- Data_in = %h -- ",$realtime,control,data,
				"Outputs[preamble_valid,dst_addr_valid,src_addr_valid,type_length_valid,packet_size_valid] = %b -- ",outputs, 
				"Expected outputs = %b",expected_outputs);
				//Message to be written to the outputs text file.
				$fwrite(f,"WRONG RESULTS !!! --Time =%d ns -- Control bit = %b -- Data_in = %h -- ",$realtime,control,data,				"Outputs[preamble_valid,dst_addr_valid,src_addr_valid,type_length_valid,packet_size_valid] = %b -- ",outputs,
				"expected outputs = %b \n",expected_outputs);
				errors=errors+1;//incrementing the number of detected errors.
			end
			vector_num=vector_num+1;//incrementing the test vectors index.
		end
	end
	
	
      
endmodule

