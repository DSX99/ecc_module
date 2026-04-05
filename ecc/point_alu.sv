module point_alu #(
    parameter WIDTH = 512
)(
    input  logic              clk,
    input  logic              rst,
    input  logic              req,
    input  logic              first, 
    input  logic              mult,
    input  logic [WIDTH-1:0]  P1_x, P1_y, P1_z,
    input  logic [WIDTH-1:0]  P2_x, P2_y, P2_z,
    input  logic [WIDTH-1:0] a, mod,
    output logic              rdy,
    output logic [WIDTH-1:0]  Psum_x, Psum_y, Psum_z,
    output logic [WIDTH-1:0]  Pd_x, Pd_y, Pd_z,
    output logic [WIDTH-1:0] mem_out0,
    output logic [WIDTH-1:0] mem_out1,
    output logic [WIDTH-1:0] mem_out2,
    output logic [WIDTH-1:0] mem_out3,
    output logic [WIDTH-1:0] mem_out4,
    output logic [WIDTH-1:0] mem_out5,
    output logic [WIDTH-1:0] mem_out6,
    output logic [WIDTH-1:0] mem_out7,
    output logic [WIDTH-1:0] mem_out8,
    output logic [WIDTH-1:0] mem_out9,
    output logic [WIDTH-1:0] mem_out10
);

    assign mem_out0  = mem[0];
    assign mem_out1  = mem[1];
    assign mem_out2  = mem[2];
    assign mem_out3  = mem[3];
    assign mem_out4  = mem[4];
    assign mem_out5  = mem[5];
    assign mem_out6  = mem[6];
    assign mem_out7  = mem[7];
    assign mem_out8  = mem[8];
    assign mem_out9  = mem[9];
    assign mem_out10 = mem[10];

    logic [WIDTH-1:0] mult_a [2], mult_b [2], mult_out [2];
    logic             mult_req [2], mult_rdy [2];

    logic [WIDTH-1:0] add_a [2], add_b [2], add_out [2];
    logic             add_ctrl [2];

    logic [WIDTH-1:0] mem [0:10];
    logic [1:0] done_flags;
    logic [1:0] sent=0;

    logic [4:0] state=0;

    always_comb begin    
        
        if(rdy) begin
            Pd_x = mem[2]; Pd_y = mem[3]; Pd_z = mem[4];
            if(!first)begin
                Psum_x = mem[10]; Psum_y = mem[1]; Psum_z = mem[5];
            end else begin
                Psum_x = P1_x;  Psum_y = P1_y; Psum_z = P1_z;
            end
        end

        mult_req[0] = 0; mult_a[0] = '0; mult_b[0] = '0;
        mult_req[1] = 0; mult_a[1] = '0; mult_b[1] = '0;

        mult_a[0] = 0;   mult_b[0] = 0;   mult_req[0] = 0;
        mult_a[1] = 0;   mult_b[1] = 0;   mult_req[1] = 0;
        add_a[0]  = 0; add_b[0] = 0;
        add_a[1]  = 0; add_b[1] = 0;

        case(state)
            0: begin
                if(mult) begin
                    mult_a[0] = P2_x; mult_b[0] = 1; mult_req[0] = !sent[0];
                end
            end
            1: begin
                mult_a[0] = P1_z;   mult_b[0] = P1_z;   mult_req[0] = !sent[0];
                mult_a[1] = P2_z;   mult_b[1] = P2_z;   mult_req[1] = !sent[1];
            end
            2: begin
                mult_a[0] = mem[0];   mult_b[0] = P1_z;   mult_req[0] = !sent[0];
                mult_a[1] = mem[1];   mult_b[1] = P2_z;   mult_req[1] = !sent[1];
            end
            3: begin
                mult_a[0] = P1_y;   mult_b[0] = mem[3];   mult_req[0] = !sent[0];
                mult_a[1] = P2_y;   mult_b[1] = mem[2];   mult_req[1] = !sent[1];
            end
            4: begin
                mult_a[0] = P1_x;   mult_b[0] = mem[1];   mult_req[0] = !sent[0];
                mult_a[1] = P2_x;   mult_b[1] = mem[0];   mult_req[1] = !sent[1];
            end
            5: begin
                mult_a[0] = P1_x;   mult_b[0] = P1_x;   mult_req[0] = !sent[0];
                mult_a[1] = P1_y;   mult_b[1] = P1_z;   mult_req[1] = !sent[1];
                add_a[0]  = mem[1]; add_b[0] = mem[4]; add_ctrl[0] = 1;
                add_a[1]  = mem[2]; add_b[1] = mem[3]; add_ctrl[1] = 1;
            end
            6: begin
                mult_a[0] = mem[0];   mult_b[0] = mem[0];   mult_req[0] = !sent[0];
                mult_a[1] = mem[5];   mult_b[1] = mem[5];   mult_req[1] = !sent[1];
                add_a[0]  = mem[3]; add_b[0] = mem[3]; add_ctrl[0] = 0;
                add_a[1]  = mem[4]; add_b[1] = mem[4]; add_ctrl[1] = 0;
            end
            7: begin
                mult_a[0] = mem[1];   mult_b[0] = mem[7];   mult_req[0] = !sent[0];
                mult_a[1] = mem[5];   mult_b[1] = mem[7];   mult_req[1] = !sent[1];
                add_a[0]  = mem[3]; add_b[0] = mem[8]; add_ctrl[0] = 0;
            end
            8: begin
                mult_a[0] = mem[6];   mult_b[0] = mem[6];   mult_req[0] = !sent[0];
            end
            9: begin
                mult_a[0] = a;   mult_b[0] = mem[0];   mult_req[0] = !sent[0];
                mult_a[1] = P1_y;   mult_b[1] = P1_y;   mult_req[1] = !sent[1];
                add_a[0]  = mem[9]; add_b[0] = mem[7]; add_ctrl[0] = 0;
                add_a[1]  = mem[1]; add_b[1] = mem[1]; add_ctrl[1] = 0;
            end
            10: begin
                mult_a[0] = P1_x;   mult_b[0] = mem[8];   mult_req[0] = !sent[0];
                mult_a[1] = mem[2];   mult_b[1] = mem[7];   mult_req[1] = !sent[1];
                add_a[0]  = mem[9]; add_b[0] = mem[10]; add_ctrl[0] = 1;
                add_a[1]  = mem[0]; add_b[1] = mem[3]; add_ctrl[1] = 0;
            end
            11: begin
                mult_a[0] = mem[8];   mult_b[0] = mem[8];   mult_req[0] = !sent[0];
                mult_a[1] = P1_z;   mult_b[1] = P2_z;   mult_req[1] = !sent[1];
                add_a[0]  = mem[1]; add_b[0] = mem[10]; add_ctrl[0] = 1;
                add_a[1]  = mem[9]; add_b[1] = mem[9]; add_ctrl[1] = 0;
            end
            12: begin
                mult_a[0] = mem[1];   mult_b[0] = mem[6];   mult_req[0] = !sent[0];
                mult_a[1] = mem[5];   mult_b[1] = mem[7];   mult_req[1] = !sent[1];
                add_a[0]  = mem[3]; add_b[0] = mem[3]; add_ctrl[0] = 0;
                add_a[1]  = mem[9]; add_b[1] = mem[9]; add_ctrl[1] = 0;
            end
            13: begin
                mult_a[0] = mem[0];   mult_b[0] = mem[0];   mult_req[0] = !sent[0];
                add_a[0]  = mem[1]; add_b[0] = mem[2]; add_ctrl[0] = 1;
                add_a[1]  = mem[9]; add_b[1] = mem[9]; add_ctrl[1] = 0;
            end
            14: begin
                add_a[0]  = mem[2]; add_b[0] = mem[6]; add_ctrl[0] = 1;
                add_a[1]  = mem[3]; add_b[1] = mem[3]; add_ctrl[1] = 0;
            end
            15: begin
                add_a[0]  = mem[9]; add_b[0] = mem[2]; add_ctrl[0] = 1;
                add_a[1]  = mem[3]; add_b[1] = mem[3]; add_ctrl[1] = 0;
            end
            16: begin
                mult_a[0] = mem[0];   mult_b[0] = mem[6];   mult_req[0] = !sent[0];
            end
            17: begin
                add_a[0]  = mem[6]; add_b[0] = mem[3]; add_ctrl[0] = 1;
            end
            19 : begin
                mult_a[0] = P2_x; mult_b[0] = 1; mult_req[0] = !sent[0];
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 0;
            rdy <= 0;
            done_flags <= 2'b00;
            sent<=0;
        end else begin
            case (state)
                0: begin
                    sent<=0;
                    rdy <= 0;
                    if (req) begin
                        state <= 1;
                        if(mult) state<=19;
                    end
                end

                // Multiplier States (Wait for both to finish)
                1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17: begin

                    sent<=3;

                    if (mult_rdy[0]) begin done_flags[0] <= 1; end
                    if (mult_rdy[1]) begin done_flags[1] <= 1; end

                    if ((done_flags[0] || mult_rdy[0]) && (done_flags[1] || mult_rdy[1])) begin
                        done_flags <= 0;

                        case(state)
                            1:   begin mem[0] <= mult_out[0]; mem[1] <= mult_out[1];end  
                            2:   begin mem[2] <= mult_out[0]; mem[3] <= mult_out[1];end  
                            3:   begin mem[2] <= mult_out[0]; mem[3] <= mult_out[1];end  
                            4:   begin mem[1] <= mult_out[0]; mem[4] <= mult_out[1];end  
                            5:   begin mem[3] <= mult_out[0]; mem[4] <= mult_out[1]; mem[5] <= add_out[0]; mem[6] <= add_out[1];end  
                            6:   begin mem[0] <= mult_out[0]; mem[7] <= mult_out[1]; mem[8] <= add_out[0]; mem[4] <= add_out[1];end  
                            7:   begin mem[1] <= mult_out[0]; mem[7] <= mult_out[1]; mem[3] <= add_out[0];end  
                            9:   begin mem[0] <= mult_out[0]; mem[8] <= mult_out[1]; mem[9] <= add_out[0]; mem[10] <= add_out[1];end  
                            10:   begin mem[9] <= mult_out[0]; mem[2] <= mult_out[1]; mem[10] <= add_out[0]; mem[0] <= add_out[1];end  
                            11:   begin mem[3] <= mult_out[0]; mem[7] <= mult_out[1]; mem[1] <= add_out[0]; mem[9] <= add_out[1];end  
                            12:   begin mem[1] <= mult_out[0]; mem[5] <= mult_out[1]; mem[3] <= add_out[0]; mem[9] <= add_out[1];end  
                            endcase
                        sent<=0;
                        state <= state+1;
                    end
                    
                    if((state == 8) && (done_flags[0] || mult_rdy[0])) begin
                        mem[9]<=mult_out[0];
                        sent<=0;
                        state <= state+1;
                    end

                    if(state>12) begin
                        case(state)
                            14: begin
                                mem[2] <= add_out[0]; mem[3] <= add_out[1];
                                sent<=0;
                                state <= state+1;
                            end
                            15: begin
                                mem[6] <= add_out[0]; mem[3] <= add_out[1];
                                sent<=0;
                                state <= state+1;
                            end
                            17: begin
                                mem[3] <= add_out[0];
                                sent<=0;
                                state <= state+1;
                            end
                            default: ;
                        endcase
                        if(state == 13) sent<=3;

                        if((state == 13) && (done_flags[0] || mult_rdy[0])) begin
                            mem[2] <= mult_out[0]; mem[1] <= add_out[0]; mem[6] <= add_out[1];
                            sent<=0;
                            state <= state+1;
                            done_flags <= 0;
                        end

                        if(state == 16) sent<=3;

                        if((state == 16) && (done_flags[0] || mult_rdy[0])) begin
                            mem[6] <= mult_out[0];
                            sent<=0;
                            state <= state+1;
                            done_flags <= 0;
                        end
                    end
                end

                18: begin
                    rdy   <= 1;
                    state <= 0;
                end

                19: begin
                    sent[0]<=1;
                    if(mult_rdy[0]) begin
                        mem[2]<=mult_out[0];
                        rdy<=1;
                        state<=0;
                    end
                end
            endcase
        end
    end

    // --- Hardware Instantiations ---
    modmul #(.WIDTH(WIDTH)) mult0 (.clk(clk), .rst(rst), .req(mult_req[0]), .a(mult_a[0]), .b(mult_b[0]), .mod(mod), .result(mult_out[0]), .rdy(mult_rdy[0]));
    modmul #(.WIDTH(WIDTH)) mult1 (.clk(clk), .rst(rst), .req(mult_req[1]), .a(mult_a[1]), .b(mult_b[1]), .mod(mod), .result(mult_out[1]), .rdy(mult_rdy[1]));

    modadd #(.WIDTH(WIDTH)) add0  (.ctrl(add_ctrl[0]), .a(add_a[0]), .b(add_b[0]), .mod(mod), .result(add_out[0]));
    modadd #(.WIDTH(WIDTH)) add1  (.ctrl(add_ctrl[1]), .a(add_a[1]), .b(add_b[1]), .mod(mod), .result(add_out[1]));

endmodule