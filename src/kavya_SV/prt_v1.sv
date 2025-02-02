`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/05/2024 08:58:55 AM
// Design Name: 
// Module Name: prt
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// Table_Size = 2; //make present 

parameter int Index_Size = 1;
parameter int Table_Size = 2;
parameter int DATA_SIZE = 8;
parameter int DATA_ADDR_SIZE = 16;
parameter int FrameSize = 1518;


typedef struct { 
        BOOL valid;														   
	    logic [0:7] [0 : FrameSize-1] frame;	//only frame needs to be stored in correct order others are just count so no problem                                
	    logic [15:0] bytes_sent_req;											
	    logic [15:0] bytes_sent_res;											
	    logic [15:0] bytes_rcvd;												
	    BOOL       is_frame_fully_rcvd;
}PRTEntry;

typedef union tagged {
    void Invalid;
    int Valid; //integer used
} VInt;

typedef struct  {
	    logic [7:0] data_byte;
    	logic 	is_last_byte;
} PRTReadOutput ;

module prt(input logic clk , 
            input logic reset, 
            output logic is_prt_slot_free);
           //declare
            PRTEntry prt_table[0 : Table_Size]; 
            VInt write_slot =tagged Valid(0); 
            VInt read_slot= tagged Invalid;
            int temp_write_slot;
            BOOL using_write_slot ;
            BOOL is_write_slot_available; 
            PRTReadOutput out_prt;
           
           //block
            always_ff @ (posedge clk)begin 
                    if (reset) begin 
                        for (int i = 0; i <Table_Size; i = i +1) begin 
                            prt_table[i].valid <= FALSE; 
                            prt_table[i].frame <= 0;
                            prt_table[i].bytes_sent_req <= 0;
                            prt_table[i].bytes_sent_res <= 0;
                            prt_table[i].bytes_rcvd <=0; 
                            prt_table[i].is_frame_fully_rcvd <= FALSE;
                            using_write_slot <= FALSE;
                            is_write_slot_available <= FALSE;
                        end
                    end else begin 
                            if((!using_write_slot) && !isValid(write_slot)) begin //&& (!conflict_tag)
                                is_write_slot_available <= FALSE;
                                temp_write_slot <= 0;
                                for ( int j = 0; j < Table_Size ; j = j+1) begin
                                    if (!prt_table[j].valid) begin
                                       is_write_slot_available <= TRUE;
                                       temp_write_slot <= j ;
                                    end
                                end
                                if(is_write_slot_available) begin 
                                    write_slot <= tagged Valid(temp_write_slot);
                                end 
                                else begin
			                         write_slot <= tagged Invalid;
                                end 
                            end
                    end 
             end //always ff block end           
             
             //func 1
               function int  start_writing_prt_entry ;  // [Index_Size:0] return int 
                    if ((!using_write_slot) && 
		                 (!prt_table[write_slot.Valid].valid) && !isValid(write_slot)) begin  
		                          automatic int slot = write_slot.Valid;
		                          prt_table[slot].valid = TRUE;
		                          prt_table[slot].bytes_rcvd = 0;
		                          prt_table[slot].bytes_sent_req = 1;
		                          prt_table[slot].bytes_sent_res = 0;
		                          prt_table[slot].is_frame_fully_rcvd = FALSE;
		                          using_write_slot = TRUE; 
		                          return slot;
                    end 
               endfunction   
               
               //func 2   
               function void write_prt_entry ;
                    input logic [7:0] data;
                    if((using_write_slot) && (!prt_table[write_slot.Valid].is_frame_fully_rcvd)) begin 
                        		automatic int slot = write_slot.Valid; 
                        		prt_table[slot].frame = data;
                        		prt_table[slot].bytes_rcvd = prt_table[slot].bytes_rcvd + 1;
                    end 
               endfunction
               
               //func 3
               function void finish_writing_prt_entry ;
                    if((using_write_slot) && (!prt_table[write_slot.Valid].is_frame_fully_rcvd)) begin 
                        automatic int slot = write_slot.Valid;
                        using_write_slot = FALSE;
                        write_slot = tagged Invalid ;
                        prt_table[slot].is_frame_fully_rcvd = TRUE;
                    end
                endfunction
                
                
                //func4 
                function void invalidate_prt_entry ;
                    input int slot; 
                    //conflict_tag<= 1;
                    if ((write_slot.Valid == slot) && (using_write_slot)) begin 
                        using_write_slot = FALSE;
                        write_slot = tagged Invalid;
                    end 
                    if(prt_table[slot].valid) prt_table[slot].valid <= FALSE;
                 endfunction 
                 
                 //func5
                 function void start_reading_prt_entry ;
                    input int slot ;
                    if(prt_table[slot].valid) begin 
                        	read_slot = tagged Valid(slot);  //satrt from the bram address 
                    end 
                 endfunction 
                 
                 //func6 
                 function PRTReadOutput read_prt_entry ;
                    if ((prt_table[read_slot.Valid].valid) && (((prt_table[read_slot.Valid].bytes_sent_res < prt_table[read_slot.Valid].bytes_sent_req) && (prt_table[read_slot.Valid].bytes_sent_req < prt_table[read_slot.Valid].bytes_rcvd)) ||
		 ((prt_table[read_slot.Valid].bytes_sent_res < prt_table[read_slot.Valid].bytes_sent_req) && (prt_table[read_slot.Valid].bytes_sent_req == prt_table[read_slot.Valid].bytes_rcvd) && (prt_table[read_slot.Valid].is_frame_fully_rcvd)))
           ) begin 
                    automatic int slot = read_slot.Valid;
                    logic [0 : FrameSize] data; 
                    data <= prt_table[slot].frame;
		            prt_table[slot].bytes_sent_res = prt_table[slot].bytes_sent_res + 1;
                    
                    if (prt_table[slot].bytes_sent_req < prt_table[slot].bytes_rcvd) begin
                         prt_table[slot].bytes_sent_req = prt_table[slot].bytes_sent_req + 1;
                    end     
                    
                    if ((prt_table[slot].bytes_sent_res + 1 == prt_table[slot].bytes_rcvd) && (prt_table[slot].is_frame_fully_rcvd)) begin
			             read_slot = tagged Invalid;	
			             prt_table[slot].valid = FALSE;
			             out_prt.data_byte <= data ;
			             out_prt.is_last_byte = TRUE;
			             //
			             //conflict_tag <= 1;
			             return out_prt;
			        end 
			        else begin 
			             out_prt.data_byte = data;
			             out_prt.is_last_byte = FALSE;
			             return out_prt;
			        end 
			      end 
			  endfunction 	
	               
	          assign  is_prt_slot_free = ((isValid(write_slot)) && (!using_write_slot));  
	            	              
	           function bit isValid( input VInt write_slot) ;
                    if ( write_slot.Valid) begin 
                         return 1;
                    end else begin 
                         return 0;
                    end 
                endfunction 
endmodule
