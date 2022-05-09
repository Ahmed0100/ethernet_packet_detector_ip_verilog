`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Mentor Graphics/ Egypt
// Engineer: Ahmed Mustafa 
// Create Date:    10:31:30 03/03/2017 
// Design Name:  Ethernet Packet Detector
// Module Name:  Ethernet_Packet_Detector 
// Project Name: Ethernet Packet Detector

/* Description: 
Ethernet Packet Detector that parses the incoming stream in search for an
Ethernet packet having specific fields values.

Input Name : Description
------------------------
clock  : Reference clock
reset : Synchronous reset signal (active high)
data[7:0] : Incoming stream (1 byte per clock cycle). It can contain packet data or IFG.
( Ethernet Packet data: data[7:0] = any value & control = 1
  IFG: data[7:0] = 0x00 & control = 0 )
control : A bit that indicates whether data[7:0] represents IFGs or Packet data
 (Ethernet Packet data: control = 1
  IFG: control = 0 ) 

Output Name : Description
-------------------------
preamble_valid : Asserted to 1 after receiving the correct preamble value and is asserted for one clock cycle only.
src_addr_valid : Asserted to 1 after receiving the correct source address value and is asserted for one clock cycle only.
dst_addr_valid : Asserted to 1 after receiving the correct destination address value and is asserted for one clock cycle.
type_length_valid : Asserted to 1 after receiving the correct type/length value and is asserted for one clock cycle only.
packet_size_valid : Asserted to 1 after receiving a packet with size =
72 bytes and is asserted for one clock cycle only.
valid_packet_counter [3:0] : Hold the count of valid packets.
 */
////////////////-//////////////////////////////////////////////////////////////////
module Ethernet_Packet_Detector(
/*Inputs*/
clk,
reset,
data,
control,
/*Outputs*/
preamble_valid,
dst_addr_valid,
src_addr_valid,
type_length_valid,
packet_size_valid,
valid_packet_counter);

input clk,reset,control;
input [7:0] data;

output reg preamble_valid,src_addr_valid,dst_addr_valid,type_length_valid,packet_size_valid;
output wire [3:0] valid_packet_counter;
//Registers to hold the states and next states 
reg [3:0] state,next_state;
//The design is implemented with an algorithm state machine that has 13 states
parameter IFG=0;
parameter Preamble0=1;
parameter Preamble1=2;
parameter Dst0=3;
parameter Dst1=4;
parameter Dst2=5;
parameter Src0=6;
parameter Src1=7;
parameter Type_length0=8;
parameter Type_length1=9;
parameter Payload_CRC0=10;
parameter Payload_CRC1=11;
parameter Done=12;

// The design uses one counter for multiple purposes (multi_purpose_counter) :
/*At the beginning of the packet detection while sniffing for the starting byte from the PREAMBLE field,
 the (count) register is loaded with (0) (using signal counter_load0)  and when the detection process starts
 the (count) value is incremented
 (using signal counter_en_up) to count the predefined number of the PREAMBLE field bytes
 (which is for this design is 7 bytes 0x55 and 1 byte 0xd5)  and then the (count) register is loaded with (1)
 (using signal counter_load1) to be compared with the first byte received from the DST ADDR field (which is here 0x01)
 and then the (count) value is incremented
 (using signal counter_en_up) to be compared with the remaining received bytes from the DST ADDR field (0x02 to 0x06)
 and then the (count) register is loaded with (0xff) (using signal counter_load255) to be compared with
 the first byte received from the SRC ADDR field (which is 0xff) and then the (count)value is decremented
 (using signal counter_en_down) to be compared with the remaining received bytes from the
 SRC ADDR field (0xfe to 0xfa) and then the (count) register is loaded with (0) (using signal counter_load0)
 to be used in counting the received PAYLOAD/CRC field (which is here 50 bytes) 
 and finally it increments (using signal packet_counter_en) the (valid_packet_counter) after receiving the whole packet.
*/ 

reg counter_en_up , counter_en_down , counter_load0 , counter_load1 , counter_load255;
reg packet_counter_en;
/*Declaration of the output signal (count) that is used for the multiple purposes above except the last one
(8 bits are used taking into account the case of loading 0xff
 into the counter and counting down till 0xfa while detecting the SRC_ADD field */
wire [7:0] count;
//Instantiation of the multi-purpose counter
counter multi_purpose_counter(clk,
reset,
packet_counter_en,
counter_en_up,
counter_en_down,
counter_load0,
counter_load1,
counter_load255,
valid_packet_counter,
count);


// Next state logic
always @*
case(state)
/*1- IFG (Inter Frame Gap) state: It's the initial state and in that state the detector sniffs for a valid starting byte
 (0x55) from the PREAMBLE header and also if any unexpected byte was received the state machine returns to that state.
 (In that state we load (0) in the(count)register using signal counter_load0 to be used later in the detection process).
*/
	IFG:
		if(control && (data==8'h55))
			next_state=Preamble0;
		else
			next_state=IFG;
/*2- Preamble0 state: In that state we already have received the first byte (0x55) from the PREAMBLE field
  and there remain(7) bytes (6 bytes 0x55 and 1 byte 0xd5) to be received. 
  In that state we detect the remaining 6 bytes (0x55) using
  the (count) value as a loop termination variable when it reaches 5.          
  (In that state the detector increments the (count) register using the signal counter_en_up).

 */
	Preamble0: 
		if(control && (data==8'h55))
			if(count<5)
				next_state=Preamble0;
			else
				next_state=Preamble1;
		else
			next_state=IFG;
/*3- Preamble1 state: In that state the detector sniffs for the last byte from the PREAMBLE field (0xd5).
    (In that state the detector loads the (count) register with (1) to be used in the next detection stage). 
*/
	Preamble1:
		if(control &&(data==8'hd5))
			next_state=Dst0;
		else
			next_state=IFG;
/*4- Dst0 state: In that state the detector sniffs for the starting byte from the DST ADDR field (0x01)
 using the value in the (count) register to be compared with the received byte .  
 (In that state the preamble_valid flag is asserted to indicate the successful receipt of the PREAMBLE field 
 and also the value of the (count) register is incremented using the signal counter_en_up).
*/
	Dst0:
		if(control &&(data==count))
			next_state=Dst1;
		else
			next_state=IFG;
/*5- Dst1 state: In that state the detector has already received the first byte from the DST ADDR field
 and there remain (5) bytes to be received (0x02 to 0x06). In that state the detector receives
 only (4) bytes (0x02 to 0x05) using the (count) value to be compared with the received bytes. 
 The last byte is detected in a different state for the reason that with the last byte 
 the detector loads the (count) register with (0xff) to be used in the next detection stage.           
 (The reason why the first byte from the DST ADDR field was received in a different state
 is that in that state we will assert the Preamble_valid flag and it must be asserted for only one clock cycle).
 (In that state the (count) value is incremented using the signal counter_en_up).
*/
	Dst1:
		if(control &&(data==count))
			if(count<5)
				next_state=Dst1;
			else
				next_state=Dst2;
		else
			next_state=IFG;
/*6- Dst2 state: In that state the detector sniffs for the last byte from the DST ADDR field (0x06).
 (In that state the detector loads the (count) register with 0xff using the signal counter_load255 
 to be used in the next detection stage).
*/
	Dst2: 
		if(control &&(data==count))
			next_state=Src0;
		else
			next_state=IFG;
/*7- Src0 state: In that state the detector sniffs for the starting byte from the SRC ADDR field (0xff)
 using the (count) value to be compared with received byte.
 (In that state the detectors asserts the dst_addr_valid flag to indicate the successful receipt of the DST ADDR field
 and also it decrements the (count) value using the signal counter_en_down).
*/
	Src0: 
		if(control && (data==count))
			next_state=Src1;
		else
			next_state=IFG;
/*8- Src1 state: In that state the detector has already received the first byte (0xff) from the SRC ADDR field 
 and there remain(5) bytes (0xfe to 0xfa) to be received using the (count) value to be compared with the received bytes. 
 (In that state the detector decrements the (count) register using counter_en_down).
*/
	Src1:
		if(control && (data==count))
			if(count>8'hfa)
				next_state=Src1;
			else
				next_state=Type_length0;
		else
			next_state=IFG;	
/*9- Type_length0 state: In that state the detector sniffs for the starting byte from the TYPE/LENGTH field (0x08).
 (In that state the detector asserts the src_addr_valid flag to indicate the successful receipt of the SRC ADDR field).
*/		
	Type_length0:
		if(control && (data==8'h08))
			next_state=Type_length1;
		else
			next_state=IFG;
/*10- Type_length1: In that state the detector sniffs for the last byte from the TYPE/LENGTH field (0x00).
      (In that state the detector loads the (count) register with (0)
	   using signal counter_load0 to be used in the detection of the next field).
*/	
	Type_length1:
		if(control && (data==8'h00))
			next_state=Payload_CRC0;
		else
			next_state=IFG;
/*11- Payload_CRC0 state: In that state the detector receives the starting byte from the PAYLOAD field.
      (In that state the detector asserts the type_length_valid flag to indicate
	   the successful receipt of the TYPE/LENGTH field 
	   and also it increments the (count) value using signal counter_en_up).
*/
	Payload_CRC0: 
		if(control)
			next_state=Payload_CRC1;
		else
			next_state=IFG;
/*12-Payload_CRC1: In that state the detector receives the last 49 bytes from the PAYLOAD/CRC field.
     (In that state the detector increments the (count) value using signal counter_en_up).
*/
	Payload_CRC1:
		if(control)
			if(count<49)
				next_state=Payload_CRC1;
			else
				next_state=Done;
		else
			next_state=IFG;
/*13-Done state: In that state the detector finished receiving the Ethernet Packet and expects one or more IFG packets.
     (In that state the detector asserts the packet_size_valid flag 
	  and also increments the (valid_packet_counter) using signal packet_counter_en).

*/
	Done:
		next_state=IFG;	
	default:
		next_state=IFG;
endcase
//sequential logic
always @(posedge clk)
	if(reset)
		state=IFG;
	else
		state=next_state;
//output logic
always @*
begin
//outputs initialization
	preamble_valid=0; src_addr_valid=0; dst_addr_valid=0; type_length_valid=0; packet_size_valid=0;
	counter_en_up=0; counter_en_down=0; counter_load0=0; counter_load1=0; counter_load255=0;
	packet_counter_en=0;
	case(state)
		IFG: counter_load0=1; 
		Preamble0: counter_en_up=1; //enables count up of the multi purpose counter to count up the remaining 6 0x55 bytes. 
		Preamble1: counter_load1=1;//loads the multi purpose counter with 1 on the next positive edge . 
		Dst0: begin  preamble_valid=1; counter_en_up=1; end /*asserts the PREAMBLE_VALID flag and enables
		the multi purpose counter to count up the values to be compared with received DST ADDR field bytes.*/
		Dst1: counter_en_up=1; /*enables the multi purpose counter to count up the values to be compared with 
		the received DST ADDR field bytes.*/
		Dst2: counter_load255=1;//loads the multi purpose counter with 0xff on the next positive edge.
		Src0: begin dst_addr_valid=1; counter_en_down=1; end/*asserts the DST_ADDR_VALID flag and enables
		the multi purpose counter to count down the values to be compared with the received SRC ADDR field bytes */
		Src1: counter_en_down=1;/*enables the multi purpose counter to count down the values to be compared with
		the received SRC ADDR field bytes */
		Type_length0: src_addr_valid=1;//asserts the SRC_ADDR_VALID flag
		Type_length1: counter_load0=1;//loads the counter with 0 on the next positive edge
		Payload_CRC0: begin type_length_valid=1; counter_en_up=1; end
		Payload_CRC1: counter_en_up=1;//enables the mutli purpose counter to count up the number of recieved PAYLOAD bytes
		Done: begin packet_size_valid=1; packet_counter_en=1;  end/*asserts the PACKET_SIZE_VALID flag and increments
		the VALID_PACKET_COUNTER output of the multi purpose counter*/
	endcase
end

endmodule

