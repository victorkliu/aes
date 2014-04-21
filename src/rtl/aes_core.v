//======================================================================
//
// aes.core.v
// ----------
// The AES core. This core supports key size of 128, 192 and 256 bits.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2013, 2014, Secworks Sweden AB
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or 
// without modification, are permitted provided that the following 
// conditions are met: 
// 
// 1. Redistributions of source code must retain the above copyright 
//    notice, this list of conditions and the following disclaimer. 
// 
// 2. Redistributions in binary form must reproduce the above copyright 
//    notice, this list of conditions and the following disclaimer in 
//    the documentation and/or other materials provided with the 
//    distribution. 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module aes_core(
                input wire            clk,
                input wire            reset_n,
                   
                input wire            encdec,
                input wire            init,
                input wire            next,
                output wire           ready,
                
                input wire [255 : 0]  key,
                input wire [1 : 0]    keylen,
                   
                input wire [127 : 0]  block,
                output wire [127 : 0] result,
                output wire           result_valid
               );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter AES_128_BIT_KEY = 0;
  parameter AES_192_BIT_KEY = 1;
  parameter AES_256_BIT_KEY = 2;

  parameter AES128_ROUNDS = 10;
  parameter AES192_ROUNDS = 12;
  parameter AES256_ROUNDS = 14;
  
  parameter CTRL_IDLE   = 0;
  parameter CTRL_INIT   = 1;
  parameter CTRL_ROUNDS = 2;
  parameter CTRL_DONE   = 3;

 
  //----------------------------------------------------------------
  // Functions.
  //----------------------------------------------------------------
  // Galois Multiplication by two.
  function [7 : 0] gmul2(input [7 : 0] op);
    begin
      gmul2 = {s00_0[6 : 0], 1'b0} ^ (8'h1b & {8{b[7]}});
    end
  endfunction // gmul2

  // Galois Multiplication by three.
  function [7 : 0] gmul3(input [7 : 0] op);
    begin
      gmul3 = gmul2(op) ^ op;
    end
  endfunction // gmul2
  
  
  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [255 : 0] key_reg;
  reg [1 : 0]   keylen_reg;
  reg           encdec_reg;
  reg           init_we;

  reg [7 : 0]   s00_reg;
  reg [7 : 0]   s00_new;
  reg [7 : 0]   s01_reg;
  reg [7 : 0]   s01_new;
  reg [7 : 0]   s02_reg;
  reg [7 : 0]   s02_new;
  reg [7 : 0]   s03_reg;
  reg [7 : 0]   s03_new;

  reg [7 : 0]   s10_reg;
  reg [7 : 0]   s10_new;
  reg [7 : 0]   s11_reg;
  reg [7 : 0]   s11_new;
  reg [7 : 0]   s12_reg;
  reg [7 : 0]   s12_new;
  reg [7 : 0]   s13_reg;
  reg [7 : 0]   s13_new;

  reg [7 : 0]   s20_reg;
  reg [7 : 0]   s20_new;
  reg [7 : 0]   s21_reg;
  reg [7 : 0]   s21_new;
  reg [7 : 0]   s22_reg;
  reg [7 : 0]   s22_new;
  reg [7 : 0]   s23_reg;
  reg [7 : 0]   s23_new;

  reg [7 : 0]   s30_reg;
  reg [7 : 0]   s30_new;
  reg [7 : 0]   s31_reg;
  reg [7 : 0]   s31_new;
  reg [7 : 0]   s32_reg;
  reg [7 : 0]   s32_new;
  reg [7 : 0]   s33_reg;
  reg [7 : 0]   s33_new;
  
  reg           s_we;
  
  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;

  reg           result_valid_reg;
  reg           result_valid_new;
  reg           result_valid_we;

  reg [3 : 0]   num_rounds;

  reg [3 : 0]   round_ctr_reg;
  reg [3 : 0]   round_ctr_new;
  reg           round_ctr_we;
  reg           round_ctr_rst;
  reg           round_ctr_inc;
  
  reg [2 : 0]   aes_ctrl_reg;
  reg [2 : 0]   aes_ctrl_new;
  reg           aes_ctrl_we;
  
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [7 : 0] tmp_data;

  reg init_state;
  reg update_state;

  wire [7 : 0] sbox00_data;
  wire [7 : 0] sbox01_data;
  wire [7 : 0] sbox02_data;
  wire [7 : 0] sbox03_data;
  wire [7 : 0] sbox10_data;
  wire [7 : 0] sbox11_data;
  wire [7 : 0] sbox12_data;
  wire [7 : 0] sbox13_data;
  wire [7 : 0] sbox20_data;
  wire [7 : 0] sbox21_data;
  wire [7 : 0] sbox22_data;
  wire [7 : 0] sbox23_data;
  wire [7 : 0] sbox30_data;
  wire [7 : 0] sbox31_data;
  wire [7 : 0] sbox32_data;
  wire [7 : 0] sbox33_data;

  wire [7 : 0] inv_sbox00_data;
  wire [7 : 0] inv_sbox01_data;
  wire [7 : 0] inv_sbox02_data;
  wire [7 : 0] inv_sbox03_data;
  wire [7 : 0] inv_sbox10_data;
  wire [7 : 0] inv_sbox11_data;
  wire [7 : 0] inv_sbox12_data;
  wire [7 : 0] inv_sbox13_data;
  wire [7 : 0] inv_sbox20_data;
  wire [7 : 0] inv_sbox21_data;
  wire [7 : 0] inv_sbox22_data;
  wire [7 : 0] inv_sbox23_data;
  wire [7 : 0] inv_sbox30_data;
  wire [7 : 0] inv_sbox31_data;
  wire [7 : 0] inv_sbox32_data;
  wire [7 : 0] inv_sbox33_data;

  
  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  aes_sbox sbox00(.addr(sbox00_reg), .data(sbox00_data));
  aes_sbox sbox01(.addr(sbox01_reg), .data(sbox01_data));
  aes_sbox sbox02(.addr(sbox02_reg), .data(sbox02_data));
  aes_sbox sbox03(.addr(sbox03_reg), .data(sbox03_data));
  aes_sbox sbox10(.addr(sbox10_reg), .data(sbox10_data));
  aes_sbox sbox11(.addr(sbox11_reg), .data(sbox11_data));
  aes_sbox sbox12(.addr(sbox12_reg), .data(sbox12_data));
  aes_sbox sbox13(.addr(sbox13_reg), .data(sbox13_data));
  aes_sbox sbox20(.addr(sbox20_reg), .data(sbox20_data));
  aes_sbox sbox21(.addr(sbox21_reg), .data(sbox21_data));
  aes_sbox sbox22(.addr(sbox22_reg), .data(sbox22_data));
  aes_sbox sbox23(.addr(sbox23_reg), .data(sbox23_data));
  aes_sbox sbox30(.addr(sbox30_reg), .data(sbox30_data));
  aes_sbox sbox31(.addr(sbox31_reg), .data(sbox31_data));
  aes_sbox sbox32(.addr(sbox32_reg), .data(sbox32_data));
  aes_sbox sbox33(.addr(sbox33_reg), .data(sbox33_data));

  aes_inv_sbox inv_sbox00(.addr(sbox00_reg), .data(inv_sbox00_data));
  aes_inv_sbox inv_sbox01(.addr(sbox01_reg), .data(inv_sbox01_data));
  aes_inv_sbox inv_sbox02(.addr(sbox02_reg), .data(inv_sbox02_data));
  aes_inv_sbox inv_sbox03(.addr(sbox03_reg), .data(inv_sbox03_data));
  aes_inv_sbox inv_sbox10(.addr(sbox10_reg), .data(inv_sbox10_data));
  aes_inv_sbox inv_sbox11(.addr(sbox11_reg), .data(inv_sbox11_data));
  aes_inv_sbox inv_sbox12(.addr(sbox12_reg), .data(inv_sbox12_data));
  aes_inv_sbox inv_sbox13(.addr(sbox13_reg), .data(inv_sbox13_data));
  aes_inv_sbox inv_sbox20(.addr(sbox20_reg), .data(inv_sbox20_data));
  aes_inv_sbox inv_sbox21(.addr(sbox21_reg), .data(inv_sbox21_data));
  aes_inv_sbox inv_sbox22(.addr(sbox22_reg), .data(inv_sbox22_data));
  aes_inv_sbox inv_sbox23(.addr(sbox23_reg), .data(inv_sbox23_data));
  aes_inv_sbox inv_sbox30(.addr(sbox30_reg), .data(inv_sbox30_data));
  aes_inv_sbox inv_sbox31(.addr(sbox31_reg), .data(inv_sbox31_data));
  aes_inv_sbox inv_sbox32(.addr(sbox32_reg), .data(inv_sbox32_data));
  aes_inv_sbox inv_sbox33(.addr(sbox33_reg), .data(inv_sbox33_data));

  aes_keygen keygen(
                    .clk(clk),
                    .reset_n(reset_n),
                    .key(key),
                    .keylen(keylen),
                    .encdec(encdec),
                    .init(init),
                    .addr(key_number),

                    .round_key(round_key),
                    .ready(key_ready)
                   );


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready        = ready_reg;
  assign result       = block_reg;
  assign result_valid = result_valid_reg;
  
  
  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with synchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin: reg_update
      if (!reset_n)
        begin
          ready_reg        <= 1'b0;
          result_valid_reg <= 1'b0;
          key_reg          <= 128'h00000000000000000000000000000000;
          keylen_reg       <= 2'h0;
          encdec_reg       <= 1'b0;
          s00_reg          <= 8'h00;
          s01_reg          <= 8'h00;
          s02_reg          <= 8'h00;
          s03_reg          <= 8'h00;
          s10_reg          <= 8'h00;
          s11_reg          <= 8'h00;
          s12_reg          <= 8'h00;
          s13_reg          <= 8'h00;
          s20_reg          <= 8'h00;
          s21_reg          <= 8'h00;
          s22_reg          <= 8'h00;
          s23_reg          <= 8'h00;
          s30_reg          <= 8'h00;
          s31_reg          <= 8'h00;
          s32_reg          <= 8'h00;
          s33_reg          <= 8'h00;

          round_ctr_reg    <= 4'h0;
          
          aes_ctrl_reg     <= CTRL_IDLE;
        end
      else
        begin
          if (ready_we)
            begin
              ready_reg <= ready_new;
            end

          if (result_valid_we)
            begin
              result_valid_reg <= result_valid_new;
            end
          
          if (init_we)
            begin
              key_reg    <= key;
              keylen_reg <= keylen;
              encdec_reg <= encdec;
            end

          if (s_we)
            begin
              s00_reg <= s00_new;
              s01_reg <= s01_new;
              s02_reg <= s02_new;
              s03_reg <= s03_new;

              s10_reg <= s10_new;
              s11_reg <= s11_new;
              s12_reg <= s12_new;
              s13_reg <= s13_new;

              s20_reg <= s20_new;
              s21_reg <= s21_new;
              s22_reg <= s22_new;
              s23_reg <= s23_new;

              s30_reg <= s30_new;
              s31_reg <= s31_new;
              s32_reg <= s32_new;
              s33_reg <= s33_new;
            end

          if (round_ctr_we)
            begin
              round_ctr_reg <= round_ctr_new;
            end
          
          if (aes_ctrl_we)
            begin
              aes_ctrl_reg <= aes_ctrl_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // rounds_select
  //
  // Simple logic that selects number of rounds based on the given
  // key length.
  //----------------------------------------------------------------
  always @*
    begin : rounds_select
      case (keylen_reg)
        AES_128_BIT_KEY: num_rounds = AES128_ROUNDS;
        AES_192_BIT_KEY: num_rounds = AES192_ROUNDS;
        AES_256_BIT_KEY: num_rounds = AES256_ROUNDS;
        default:         num_rounds = 4'h0;
      endcase // case (keylen_reg)
    end // rounds_select


  //----------------------------------------------------------------
  // state_logic
  //
  // The logic needed to initalize as well as update the internal
  // state during round processing.
  //----------------------------------------------------------------
  always @*
    begin : state_update_logic
      // Wires for internal intermediate values.
      reg [7 : 0] s00_0, s00_1;
      reg [7 : 0] s01_0, s01_1;
      reg [7 : 0] s02_0, s02_1;
      reg [7 : 0] s03_0, s03_1;
      reg [7 : 0] s10_0, s10_1;
      reg [7 : 0] s11_0, s11_1;
      reg [7 : 0] s12_0, s12_1;
      reg [7 : 0] s13_0, s13_1;
      reg [7 : 0] s20_0, s20_1;
      reg [7 : 0] s21_0, s21_1;
      reg [7 : 0] s22_0, s22_1;
      reg [7 : 0] s23_0, s23_1;
      reg [7 : 0] s30_0, s30_1;
      reg [7 : 0] s31_0, s31_1;
      reg [7 : 0] s32_0, s32_1;
      reg [7 : 0] s33_0, s33_1;

      // Default assignments.
      s00_new = 8'h00;
      s01_new = 8'h00;
      s02_new = 8'h00;
      s03_new = 8'h00;
      s10_new = 8'h00;
      s11_new = 8'h00;
      s12_new = 8'h00;
      s13_new = 8'h00;
      s20_new = 8'h00;
      s21_new = 8'h00;
      s22_new = 8'h00;
      s23_new = 8'h00;
      s30_new = 8'h00;
      s31_new = 8'h00;
      s32_new = 8'h00;
      s33_new = 8'h00;
      s_we    = 0;
      
      if (init_state)
        begin
          // We tranfer the given block into state and do initial
          // AddRoundKey. This assumes that all keys start at
          // key[255] and extend downwards for 128, 192 or 256 bits.
          sa00_new = block[127 : 120] ^ round_key[255 : 248];
          sa10_new = block[119 : 112] ^ round_key[247 : 240];
          sa20_new = block[111 : 104] ^ round_key[239 : 232];
          sa30_new = block[103 : 096] ^ round_key[231 : 224];
          sa01_new = block[095 : 088] ^ round_key[223 : 216];
          sa11_new = block[087 : 080] ^ round_key[215 : 208];
          sa21_new = block[079 : 072] ^ round_key[207 : 200];
          sa31_new = block[071 : 064] ^ round_key[199 : 192];
          sa02_new = block[063 : 056] ^ round_key[191 : 184];
          sa12_new = block[055 : 048] ^ round_key[183 : 176];
          sa22_new = block[047 : 040] ^ round_key[175 : 168];
          sa32_new = block[039 : 032] ^ round_key[167 : 160];
          sa03_new = block[031 : 024] ^ round_key[159 : 152];
          sa13_new = block[023 : 016] ^ round_key[151 : 144];
          sa23_new = block[015 : 008] ^ round_key[143 : 136];
          sa33_new = block[007 : 000] ^ round_key[135 : 128];
          swe = 1;
        end
      else if (update_state)
        begin
          // SubBytes - Done through connectivity of sbox instances.
          // sbox_data wires contains the substitute values.
          
          // Shiftrows
          s00_0 = sbox00_data;
          s01_0 = sbox01_data;
          s02_0 = sbox02_data;
          s03_0 = sbox03_data;
          s10_0 = sbox11_data;
          s11_0 = sbox12_data;
          s12_0 = sbox13_data;
          s13_0 = sbox10_data;
          s20_0 = sbox22_data;
          s21_0 = sbox23_data;
          s22_0 = sbox20_data;
          s23_0 = sbox21_data;
          s30_0 = sbox33_data;
          s31_0 = sbox30_data;
          s32_0 = sbox31_data;
          s33_0 = sbox32_data;

          // MixColumns
          s00_1 = gm2(s00_0) ^ gm3(s10_0) ^ s20_0      ^ s30_0;
          s10_1 = s00_0      ^ gm2(s10_0) ^ gm3(s20_0) ^ s30_0;
          s20_1 = s00_0      ^ s10_0      ^ gm2(s20_0) ^ gm3(s30_0);
          s30_1 = gm3(s00_0) ^ s10_0      ^ s20_0      ^ gm2(s30_0);

          s01_1 = gm2(s01_0) ^ gm3(s11_0) ^ s21_0      ^ s31_0;
          s11_1 = s01_0      ^ gm2(s11_0) ^ gm3(s21_0) ^ s31_0;
          s21_1 = s01_0      ^ s11_0      ^ gm2(s21_0) ^ gm3(s31_0);
          s31_1 = gm3(s01_0) ^ s11_0      ^ s21_1      ^ gm2(s31_0);

          s02_1 = gm2(s02_0) ^ gm3(s12_0) ^ s22_0      ^ s32_0;
          s12_1 = s02_0      ^ gm2(s12_0) ^ gm3(s22_0) ^ s32_0;
          s22_1 = s02_0      ^ s12_0      ^ gm2(s22_0) ^ gm3(s32_0);
          s32_1 = gm3(s02_0) ^ s12_0      ^ s22_1      ^ gm2(s32_0);

          s03_1 = gm2(s03_0) ^ gm3(s13_0) ^ s23_0      ^ s33_0;
          s13_1 = s03_0      ^ gm2(s13_0) ^ gm3(s23_0) ^ s33_0;
          s23_1 = s03_0      ^ s13_0      ^ gm2(s23_0) ^ gm3(s33_0);
          s33_1 = gm3(s03_0) ^ s13_0      ^ s23_1      ^ gm2(s33_0);
          
          // AddRoundKey
          // TODO: Add correct round_key indices.
          s00_new = s00_1 ^ round_key[127 : 120];
          s01_new = s01_1 ^ round_key[119 : 112];
          s02_new = s02_1 ^ round_key[111 : 104];
          s03_new = s03_1 ^ round_key[103 :  96];
          s10_new = s10_1 ^ round_key[95  :  88];
          s11_new = s11_1 ^ round_key[87  :  80];
          s12_new = s12_1 ^ round_key[79  :  72];
          s13_new = s13_1 ^ round_key[71  :  64];
          s20_new = s20_1 ^ round_key[63  :  56];
          s21_new = s21_1 ^ round_key[55  :  48];
          s22_new = s22_1 ^ round_key[47  :  40];
          s23_new = s23_1 ^ round_key[39  :  32];
          s30_new = s30_1 ^ round_key[31  :  24];
          s31_new = s31_1 ^ round_key[23  :  16];
          s32_new = s32_1 ^ round_key[15  :   8];
          s33_new = s33_1 ^ round_key[7   :   0];
          swe = 1;
        end
    end // state_logic


  //----------------------------------------------------------------
  // round_ctr
  //
  // The round counter with reset and increase logic.
  //----------------------------------------------------------------
  always @*
    begin : round_ctr
      round_ctr_new = 4'h0;
      round_ctr_we  = 1'b0;

      if (round_ctr_rst)
        begin
          round_ctr_we  = 1'b1;
        end
      elsif (round_ctr_inc)
        begin
          round_ctr_new = round_ctr_reg + 1'b1;
          round_ctr_we  = 1'b0;
        end
    end // round_ctr

  
  //----------------------------------------------------------------
  // aes_ctrl_fsm
  //
  // The control FSM that runs the core.
  //----------------------------------------------------------------
  always @*
    begin : aes_ctrl_fsm
      ready_new        = 0;
      ready_we         = 0;
      result_valid_new = 0;
      result_valid_we  = 0;
      init_we          = 0;
      init_state       = 0;
      round_ctr_rst    = 0;
      round_ctr_inc    = 0;
      update_state     = 0;
      aes_ctrl_new     = CTRL_IDLE;
      aes_ctrl_we      = 0;
      
      case (aes_ctrl_reg)
        CTRL_IDLE:
          begin
            if (init)
              begin
                init_we      = 1;
                aes_ctrl_new = CTRL_INIT;
                aes_ctrl_we  = 1;
              end
          end

        CTRL_INIT:
          begin
            aes_ctrl_new = CTRL_ROUNDS;
            aes_ctrl_we  = 1;
          end

        CTRL_ROUNDS:
          begin
            aes_ctrl_new = CTRL_DONE;
            aes_ctrl_we  = 1;
          end
          

        CTRL_DONE:
          begin
            aes_ctrl_new = CTRL_IDLE;
            aes_ctrl_we  = 1;
          end

        
        default:
          begin

          end
      endcase // case (aes_ctrl_reg)
    end // aes_ctrl_fsm
    
endmodule // aes_core

//======================================================================
// EOF aes_core.v
//======================================================================
