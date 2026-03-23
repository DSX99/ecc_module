module point_add #(
    parameter WIDTH = 512,
    parameter C =569
)(
    input logic clk,
    input logic rst,
    input logic req,
    input logic [WIDTH-1:0] P1_x,
    input logic [WIDTH-1:0] P1_y,
    input logic [WIDTH-1:0] P1_z,
    input logic [WIDTH-1:0] P2_x,
    input logic [WIDTH-1:0] P2_y,
    input logic [WIDTH-1:0] P2_z,
    output logic rdy,
    output logic [WIDTH-1:0] P3_x_norm,
    output logic [WIDTH-1:0] P3_y_norm,
    output logic [WIDTH-1:0] P3_z_norm,
    output logic [WIDTH-1:0] P3_x,
    output logic [WIDTH-1:0] P3_y,
    output logic [WIDTH-1:0] P3_z  
);

    logic [WIDTH-1:0] mult_0_a,mult_0_b,mult_0_out, mult_1_a,mult_1_b,mult_1_out, mult_2_a,mult_2_b,mult_2_out, mult_3_a,mult_3_b,mult_3_out;
    logic mult_0_rdy,mult_0_req, mult_1_rdy,mult_1_req, mult_2_rdy,mult_2_req, mult_3_rdy,mult_3_req;
    logic [WIDTH-1:0] u1, u2, s1, s2, r, h, g, v;

    modmul mult_0(
        .clk(clk),
        .rst(rst),
        .req(mult_0_req),
        .a(mult_0_a),
        .b(mult_0_b),
        .out(mult_0_out),
        .rdy(mult_0_rdy)
    );

    
    modmul mult_1(
        .clk(clk),
        .rst(rst),
        .req(mult_1_req),
        .a(mult_1_a),
        .b(mult_1_b),
        .out(mult_1_out),
        .rdy(mult_1_rdy)
    );
    
    modmul mult_2(
        .clk(clk),
        .rst(rst),
        .req(mult_2_req),
        .a(mult_2_a),
        .b(mult_2_b),
        .out(mult_2_out),
        .rdy(mult_2_rdy)
    );

    modmul mult_3(
        .clk(clk),
        .rst(rst),
        .req(mult_3_req),
        .a(mult_3_a),
        .b(mult_3_b),
        .out(mult_3_out),
        .rdy(mult_3_rdy)
    );

    logic inv_req;
    logic inv_rdy;
    logic [WIDTH-1:0] inv_in; 
    logic [WIDTH-1:0] inv_out; 

    pm_inverter inv_0(
        .clk(clk),
        .reset(rst),
        .start(inv_req),
        .z_in(inv_in),
        .inv_out(inv_out),
        .done(inv_rdy)
    );

    logic sent = 0;
    logic [3:0] count = 0;
    logic [3:0] rdy_count = 0;

    logic [WIDTH-1:0] mem [7:0];

    always_ff @(posedge clk) begin

        mult_0_req <= 0;
        mult_1_req <= 0;
        mult_2_req <= 0;
        mult_3_req <= 0;
        inv_req    <= 0;

        case(count) 
            0: begin
                rdy<=0;
                if(req) begin
                    mult_0_a <= P1_z;
                    mult_0_b <= P1_z;
                    mult_0_req <= 1;
                    mult_1_a <= P2_z;
                    mult_1_b <= P2_z;
                    mult_1_req <= 1;
                    mult_2_a <= P1_y;
                    mult_2_b <= P2_z;
                    mult_2_req <= 1;
                    mult_3_a <= P2_y;
                    mult_3_b <= P1_z;
                    mult_3_req <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[0]<=mult_0_out;
                end
                if(mult_1_rdy == 1) begin
                    rdy_count[1]<=1;
                    mem[1]<=mult_1_out;
                end
                if(mult_2_rdy == 1) begin 
                    rdy_count[2]<=1;
                    mem[2]<=mult_2_out;
                end
                if(mult_3_rdy == 1) begin
                    rdy_count[3]<=1;
                    mem[3]<=mult_3_out;
                end

                if(rdy_count == 15) begin
                    count<=1;
                    rdy_count<=0;
                end
            end

            1: begin // mem[0] =p1z^2 mem[1] = p2z^2 mem[2] =p1y*p2z mem[3] =p2yp1z
                if(~sent) begin
                    mult_0_a <= P1_x;
                    mult_0_b <= mem[1];
                    mult_0_req <= 1;
                    mult_1_a <= P2_x;
                    mult_1_b <= mem[0];
                    mult_1_req <= 1;
                    mult_2_a <= mem[0];
                    mult_2_b <= mem[3];
                    mult_2_req <= 1;
                    mult_3_a <= mem[1];
                    mult_3_b <= mem[2];
                    mult_3_req <= 1;
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[0]<=mult_0_out;
                end
                if(mult_1_rdy == 1) begin
                    rdy_count[1]<=1;
                    mem[1]<=mult_1_out;
                end
                if(mult_2_rdy == 1) begin 
                    rdy_count[2]<=1;
                    mem[2]<=mult_2_out;
                end
                if(mult_3_rdy == 1) begin
                    rdy_count[3]<=1;
                    mem[3]<=mult_3_out;
                end

                if(rdy_count == 15) begin
                    count<=2;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            2: begin // mem[0] =p1xp2z^2 mem[1] = p2xp1z^2 mem[2] =p2y*p1z^3 mem[3] =p1yp2z^3
                mem[1]<=connect_3;
                mem[2]<=connect_4;
                count<=3;

                u1<=mem[0];
                u2<=mem[1];
                s1<=mem[3];
                s2<=mem[2];
            end
            3: begin //mem[0] =u1 mem[1] =r mem[2] =h mem[3] =s1 need to find h**2,r**2,p1_z*p2_z, no use for 4th
                if(~sent) begin
                    mult_0_a <= mem[1]; 
                    mult_0_b <= mem[1];
                    mult_0_req <= 1; //
                    mult_1_a <= mem[2];
                    mult_1_b <= mem[2];
                    mult_1_req <= 1;
                    mult_2_a <= P1_z;
                    mult_2_b <= P2_z;
                    mult_2_req <= 1;
                    rdy_count[3] <=1;
                    sent <= 1;
                end

                u1<=mem[0];
                r<=mem[1];
                h<=mem[2];
                s1<=mem[3];


                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[4]<=mult_0_out;
                end
                if(mult_1_rdy == 1) begin
                    rdy_count[1]<=1;
                    mem[5]<=mult_1_out;
                end
                if(mult_2_rdy == 1) begin 
                    rdy_count[2]<=1;
                    mem[6]<=mult_2_out;
                end

                if(rdy_count == 15) begin
                    count<=4;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            4: begin //mem[0] =u1 mem[1] =r mem[2] =h mem[3] =s1 mem[4] =r**2 mem[5] =h**2 mem[6] =p1z*p2z need to find g,v,p3_z
                if(~sent) begin
                    mult_0_a <= mem[2]; 
                    mult_0_b <= mem[5];
                    mult_0_req <= 1; //
                    mult_1_a <= mem[0];
                    mult_1_b <= mem[5];
                    mult_1_req <= 1;
                    mult_2_a <= mem[6];
                    mult_2_b <= mem[2];
                    mult_2_req <= 1;
                    rdy_count[3] <=1;
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[2]<=mult_0_out;
                end
                if(mult_1_rdy == 1) begin
                    rdy_count[1]<=1;
                    mem[0]<=mult_1_out;
                end
                if(mult_2_rdy == 1) begin 
                    rdy_count[2]<=1;
                    mem[6]<=mult_2_out;
                end

                if(rdy_count == 15) begin
                    count<=5;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            5: begin //mem[0] =v mem[1] =r mem[2] =g mem[3] =s1 mem[4] =r**2 mem[5] =h**2 mem[6] =p3z need to find r**2 + g - 2*v (p3x)
                mem[5]<=connect_3;
                count<=6;
                v<=mem[0];
                g<=mem[2];
            end
            6: begin //mem[0] =v mem[1] =r mem[2] =g mem[3] =s1 mem[4] =r**2 mem[5] =p3x mem[6] =p3z need to find v-p3_x
                mem[0]<=connect_3;
                count<=7;
            end
            7: begin //mem[0] =v-p3x mem[1] =r mem[2] =g mem[3] =s1 mem[4] =r**2 mem[5] =p3x mem[6] =p3z need to find r*(v-p3_x), s1*g
                if(~sent) begin
                    mult_0_a <= mem[0]; 
                    mult_0_b <= mem[1];
                    mult_0_req <= 1; 
                    mult_1_a <= mem[2];
                    mult_1_b <= mem[3];
                    mult_1_req <= 1;
                    rdy_count[2] <=1;
                    rdy_count[3] <=1;
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[0]<=mult_0_out;
                end
                if(mult_1_rdy == 1) begin
                    rdy_count[1]<=1;
                    mem[1]<=mult_1_out;
                end

                if(rdy_count == 15) begin
                    count<=8;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            8: begin //mem[0] =r*(v-p3_x) mem[1] =s1*g mem[2] =g mem[3] =s1 mem[4] =r**2 mem[5] =p3x mem[6] =p3z need to find p3_y
                mem[0]<=connect_4;
                count<=9;
            end
            9: begin
                P3_x<= mem[5];
                P3_y<= mem[0];
                P3_z<= mem[6];
                // rdy<=1;
                count<=10;
            end
            10: begin
                if(~sent) begin
                    inv_in <= mem[6];
                    inv_req <= 1;
                    sent <= 1;
                end

                if(inv_rdy) begin
                    mem[6]<= inv_out;
                    P3_z_norm <= inv_out;
                    count<=11;
                    sent<=0;
                end
            end 
            11: begin
                if(~sent) begin
                    mult_0_a <= mem[6]; 
                    mult_0_b <= mem[6];
                    mult_0_req <= 1; 
                    rdy_count[1] <=1;
                    rdy_count[2] <=1;
                    rdy_count[3] <=1;
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[1]<=mult_0_out;
                end

                if(rdy_count == 15) begin
                    count<=12;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            12: begin
                if(~sent) begin
                    mult_0_a <= mem[1]; 
                    mult_0_b <= mem[6];
                    mult_0_req <= 1; 
                    rdy_count[1] <=1;
                    rdy_count[2] <=1;
                    rdy_count[3] <=1;
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[2]<=mult_0_out;
                end

                if(rdy_count == 15) begin
                    count<=13;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            13: begin
                if(~sent) begin
                    mult_0_a <= mem[0]; 
                    mult_0_b <= mem[2];
                    mult_0_req <= 1; 
                    mult_1_a <= mem[5];
                    mult_1_b <= mem[1];
                    mult_1_req <= 1;
                    rdy_count[2] <=1;
                    rdy_count[3] <=1;
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[0]<=mult_0_out;
                end
                if(mult_1_rdy == 1) begin
                    rdy_count[1]<=1;
                    mem[1]<=mult_1_out;
                end

                if(rdy_count == 15) begin
                    count<=14;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            14: begin
                P3_x_norm <= mem[1];
                P3_y_norm <= mem[0];
                rdy<=1;
                count<=0;
            end
        endcase
    end

    logic [WIDTH+1:0] connect_5, res_5,connect_6;
    logic [WIDTH:0] connect_1, connect_2, res_1, res_2;
    logic [WIDTH-1:0] connect_3, connect_4;

    always_comb begin 
        case(count)
            2:begin
                connect_1 = mem[3]-mem[2];
                connect_2 = mem[0]-mem[1];
                res_1 = connect_1 - C;
                res_2 = connect_2 - C;
                connect_3 = ~connect_1[WIDTH] ? connect_1[WIDTH-1:0] : res_1[WIDTH-1:0];
                connect_4 = ~connect_2[WIDTH] ? connect_2[WIDTH-1:0] : res_2[WIDTH-1:0];
            end
            5: begin
                connect_5 = mem[4] + mem[2] - mem[0] - mem[0] + 2*((1<<512) - C);
                connect_6 = connect_5[WIDTH-1:0] + connect_5[WIDTH+1:WIDTH]*C;
                res_5 = connect_6 + C;
                connect_3 = ~res_5[WIDTH] ? connect_6[WIDTH-1:0] : res_5[WIDTH-1:0];
            end
            6: begin
                connect_1 = mem[0]-mem[5];
                res_1 = connect_1 - C;
                connect_3 = ~connect_1[WIDTH] ? connect_1[WIDTH-1:0] : res_1[WIDTH-1:0];
            end
            8: begin
                connect_2 = mem[0]-mem[1];
                res_2 = connect_2 - C;
                connect_4 = ~connect_2[WIDTH] ? connect_2[WIDTH-1:0] : res_2[WIDTH-1:0];
            end
        endcase
    end

    // u1 = (p1_x*p2_z**2)%p
    // u2 = (p2_x*p1_z**2)%p
    // s1 = (p1_y*p2_z**3)%p
    // s2 = (p2_y*p1_z**3)%p
    // r = (s1 - s2)%p
    // h = (u1 -u2)%p
    // g = (h**3)%p
    // v = (u1*h**2)%p
    // p3_x = (r**2 + g - 2*v)%p
    // p3_y = (r*(v-p3_x) - s1*g)%p
    // p3_z = (p1_z*p2_z*h)%p
    
    // p3_x = (p3_x*inverse(p3_z**2,p))%p
    // p3_y = (p3_y*inverse(p3_z**3,p))%p
endmodule

module mult_mod #(
    parameter WIDTH = 512
)(
    input logic clk,
    input logic req,
    input logic [WIDTH-1:0] a,
    input logic [WIDTH-1:0] b,
    output logic rdy,
    output logic [2*WIDTH-1:0] out
);

    logic delay;
    always_ff @(posedge clk) begin
        rdy <= delay;
        delay <= req;
        out <= a*b;
    end
endmodule

module modmul #(
    parameter WIDTH = 512,
    parameter C     = 569
)(
    input  logic clk,
    input  logic rst,
    input  logic req,
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] out,
    output logic rdy
);

    localparam [WIDTH:0] MODULUS_VAL = (1'b1 << WIDTH) - C;

    logic [1:0] count = 0;

    logic [WIDTH*2-1:0] mult_out;
    logic               mult_rdy;

    logic [WIDTH+15:0]  sum; // Extra bits to handle H*C carry

    mult_mod #(WIDTH) mult (
        .clk(clk),
        .req(req),
        .a(a),
        .b(b),
        .out(mult_out),
        .rdy(mult_rdy)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            count <= 0; 
            rdy <= 0;
            out <= 0;
        end else begin
            case (count)
                0: begin
                    rdy<=0;
                    if (req) begin
                        count<=1;
                    end
                end

                1: begin
                    if (mult_rdy) begin
                        sum   <= mult_out[WIDTH-1:0] + (mult_out[WIDTH*2-1:WIDTH] * C);
                        count <= 2;
                    end
                end

                2: begin
                    if (sum >= MODULUS_VAL) begin
                        sum <= sum - MODULUS_VAL;
                    end else begin
                        sum <= sum[WIDTH-1:0];
                    end
                    if(sum<MODULUS_VAL) begin
                        rdy<=1;
                        count <=0;
                        out<=sum;
                    end
                end
            endcase
        end
    end
endmodule

module pm_inverter #(
    parameter WIDTH = 512,
    parameter [WIDTH-1:0] C = 569
)(
    input  logic              clk,
    input  logic              reset,
    input  logic              start,
    input  logic [WIDTH-1:0]  z_in,
    output logic [WIDTH-1:0]  inv_out,
    output logic              done
);

    typedef enum logic [2:0] {IDLE, SQUARE_START, SQUARE_WAIT, MUL_START, MUL_WAIT, NEXT_BIT, FINISH} state_t;
    state_t state;

    logic [WIDTH-1:0] res_reg, z_reg;
    logic [9:0]       bit_ptr;
    
    // Explicit 512-bit exponent (p-2)
    localparam [WIDTH-1:0] P_VAL = -C; 
    localparam [WIDTH-1:0] EXPONENT = P_VAL - 2;

    logic [WIDTH-1:0] mm_a, mm_b, mm_out;
    logic mm_req, mm_rdy;

    modmul #(.WIDTH(WIDTH), .C(C)) mm_inst (
        .clk(clk), .rst(reset), .req(mm_req),
        .a(mm_a), .b(mm_b), .out(mm_out), .rdy(mm_rdy)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            bit_ptr <= 511;
        end else begin
            mm_req <= 0;
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        z_reg <= z_in;
                        res_reg <= 512'd1;
                        bit_ptr <= 511;
                        state <= SQUARE_START;
                    end
                end

                SQUARE_START: begin
                    mm_a <= res_reg;
                    mm_b <= res_reg;
                    mm_req <= 1;
                    state <= SQUARE_WAIT;
                end

                SQUARE_WAIT: begin
                    if (mm_rdy) begin
                        res_reg <= mm_out;
                        if (EXPONENT[bit_ptr]) begin
                            state <= MUL_START; // Bit is 1, do multiply phase
                        end else begin
                            state <= NEXT_BIT;  // Bit is 0, move to next bit
                        end
                    end
                end

                MUL_START: begin
                    mm_a <= res_reg;
                    mm_b <= z_reg;
                    mm_req <= 1;
                    state <= MUL_WAIT;
                end

                MUL_WAIT: begin
                    if (mm_rdy) begin
                        res_reg <= mm_out;
                        state <= NEXT_BIT;
                    end
                end

                NEXT_BIT: begin
                    if (bit_ptr == 0) begin
                        state <= FINISH;
                    end else begin
                        bit_ptr <= bit_ptr - 1;
                        state <= SQUARE_START;
                    end
                end

                FINISH: begin
                    inv_out <= res_reg;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule