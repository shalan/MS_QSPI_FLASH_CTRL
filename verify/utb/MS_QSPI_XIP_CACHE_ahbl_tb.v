/*
	Copyright 2020 Mohamed Shalan (mshalan@aucegypt.edu)
	
	Licensed under the Apache License, Version 2.0 (the "License"); 
	you may not use this file except in compliance with the License. 
	You may obtain a copy of the License at:
	http://www.apache.org/licenses/LICENSE-2.0
	Unless required by applicable law or agreed to in writing, software 
	distributed under the License is distributed on an "AS IS" BASIS, 
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
	See the License for the specific language governing permissions and 
	limitations under the License.
*/

`timescale          1ns/1ps
`default_nettype    none

module MS_QSPI_XIP_CACHE_ahbl_tb;
    wire        sck;
    wire        ce_n;
    wire [3:0]  din;
    wire [3:0]  dout;
    wire [3:0]  douten;    
    reg         HSEL;
    reg         HCLK;
    reg         HRESETn;
    reg [31:0]  HADDR;
    reg [1:0]   HTRANS;
    reg [31:0]  HWDATA;
    reg         HWRITE;
    wire        HREADY;

    wire        HREADYOUT;
    wire [31:0] HRDATA;

    MS_QSPI_XIP_CACHE_ahbl DUV (
        // AHB-Lite Slave Interface
        .HSEL(HSEL),
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HADDR(HADDR),
        .HTRANS(HTRANS),
        //.HWDATA(HWDATA),
        .HWRITE(HWRITE),
        .HREADY(HREADY),
        .HREADYOUT(HREADYOUT),
        .HRDATA(HRDATA),

        // External Interface to Quad I/O
        .sck(sck),
        .ce_n(ce_n),
        .din(din),
        .dout(dout),
        .douten(douten)   
    );    
    
    wire [3:0] SIO = (douten==4'b1111) ? dout : 4'bzzzz;
    
    assign din = SIO;

    sst26wf080b FLASH (
            .SCK(sck),
            .SIO(SIO),
            .CEb(ce_n)
        );

    initial begin
        $dumpfile("MS_QSPI_XIP_CACHE_ahbl_tb.vcd");
        $dumpvars;
        // Initializa flash memory ( the hex file inits first 10 bytes)
        #1 $readmemh("./vip/init.hex", FLASH.I0.memory);
    end

    // resetting and clocking
    event rst_trig, rst_done;
    always #5 HCLK = ~HCLK;
    initial begin
        forever begin
            @(rst_trig);
            @(posedge HCLK);
            HRESETn = 0;
            #75;
            @(posedge HCLK);
            HRESETn = 1;
            -> rst_done;
        end
    end

    assign HREADY = HREADYOUT;

    task ahbl_w_read;
        input [31:0] addr;
        begin
            //@(posedge HCLK);
            wait (HREADY == 1'b1);
            @(posedge HCLK);
            #1;
            HSEL = 1'b1;
            HTRANS = 2'b10;
            // First Phase
            HADDR = addr;
            @(posedge HCLK);
            HSEL = 1'b0;
            HTRANS = 2'b00;
            #2;
            wait (HREADY == 1'b1);
            @(posedge HCLK) 
                #1 $display("Read 0x%8x from 0x%8x", HRDATA, addr);
        end
    endtask

    task check;
        input [31:0] expected;
        begin
            if (expected == HRDATA)
                #1 $display("Passed");
            else
                #1 $display("RFailed! read 0x%8x expected 0x%8x", HRDATA, expected);
        end
    endtask

    initial begin
        HCLK = 0;
        HSEL = 0;
        HCLK = 0;
        HRESETn = 0;
        HADDR = 0;
        HTRANS = 0;
        HWDATA = 0;
        HWRITE = 0;

        // Reset Operation
        #39;
        -> rst_trig;
        @(rst_done);

        // perform some transactions
        #100;
        ahbl_w_read(0);
        check(32'h07060504);

        ahbl_w_read(4);
        check(32'h07060504);

        ahbl_w_read(8);
        check(32'h0b0a0908);

        ahbl_w_read(12);
        check(32'h0f0e0d0c);

        ahbl_w_read(32);
        check(32'h23222120);

        ahbl_w_read(36);
        check(32'h27262524);
        
        ahbl_w_read(40);
        check(32'h2b2a2928);

        ahbl_w_read(44);
        check(32'h2f2e2d2c);
        
        #2000;
        $finish;
    end


endmodule