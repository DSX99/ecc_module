module top_module #(
    parameter WIDTH = 256
)(
    input logic cs,
    input logic spi_clk,
    input logic spi_pad_MOSI,
    input logic clk,rst,
    output logic rdy,
    output logic spi_pad_MISO
);

    logic [WIDTH-1:0] mem [8:0];
    logic [WIDTH+1:0] extmem[1:0];
    logic [WIDTH-1:0] mod;
    logic [$clog2(WIDTH)+4:0] count_spi;
    logic start_sending, prev_spi_clk;
    logic [1:0] mem_set;
    logic [4:0] state, return_state;
    logic [3:0] roll;
    logic req, save_a, save_b;

    always_comb begin 
        spi_pad_MISO=0;
        if(rdy) begin
            if(count_spi<WIDTH) spi_pad_MISO=mem[0][0];
            else if(count_spi<2*WIDTH) spi_pad_MISO=mem[1][0];
            else if(count_spi<3*WIDTH) spi_pad_MISO=mem[2][0];
            else if(count_spi<4*WIDTH) spi_pad_MISO=mem[3][0];
            else if(count_spi<5*WIDTH) spi_pad_MISO=mem[4][0];
            else if(count_spi<6*WIDTH) spi_pad_MISO=mem[5][0];
            else if(count_spi<7*WIDTH) spi_pad_MISO=mem[6][0];
            else if(count_spi<8*WIDTH) spi_pad_MISO=mem[7][0];
            else if(count_spi<9*WIDTH) spi_pad_MISO=mem[8][0];
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            mem[0]<=0;mem[1]<=0;mem[2]<=0;mem[3]<=0;mem[4]<=0;mem[5]<=0;mem[6]<=0;mem[7]<=0;mem[8]<=0;extmem[1]<=0;extmem[0]<=0;
            mod<=0; count_spi<=0; start_sending<=0; prev_spi_clk<=0; rdy<=0;
            mem_set<=0; return_state<=0; req<=0; roll<=0;
            save_a<=0; save_b<=0; state<=0;
        end else begin
            if(state!=1 & state!=0) begin
                case(mem_set)
                    0: begin
                        save_a<=1;
                        save_b<=0;
                        state<=1;
                        mem_set<=1;
                    end
                    1: begin
                        save_a<=0;
                        save_b<=1;
                        state<=1;
                        mem_set<=2;
                    end
                    2: begin
                        save_a<=0;
                        save_b<=0;
                        state<=1;
                        mem_set<=3;
                    end
                    3: begin
                        return_state<=state+1;
                    end
                endcase
            end

            case(state)
                0:begin
                    if(req) begin
                        rdy<=0;
                        state<=2;
                    end
                end
                1:begin //state to rotate mems
                    if(roll==0) begin
                        if(save_a) extmem[0]<=mem[0];
                        if(save_b) extmem[1]<=mem[0];
                        state<=return_state;
                    end else begin
                        roll<=roll-1;
                        mem[1]<=mem[0];
                        mem[2]<=mem[1];
                        mem[3]<=mem[2];
                        mem[4]<=mem[3];
                        mem[5]<=mem[4];
                        mem[6]<=mem[5];
                        mem[7]<=mem[6];
                        mem[8]<=mem[7];
                        mem[0]<=mem[8];
                    end
                end
                2:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=1;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=2;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=5;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                3:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=4;
                            mem_set<=1;
                            add_ctrl<=0;
                        end
                        1: begin
                            roll<=0;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=0;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=5;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                4:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=3;
                            mem_set<=1;
                            add_ctrl<=0;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=0;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=5;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                5:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=1;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=4;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=4;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                6:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=4;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=3;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                7:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=5;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=0;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=2;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=2;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                8:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=1;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=6;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=1;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                9:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=4;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=0;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=5;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=0;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                10:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=2;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=4;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=4;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=8;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                11:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=3;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=3;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=5;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=7;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                12:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=2;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=5;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=4;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=7;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                12:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=2;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=5;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=4;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=7;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                13:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=0;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=2;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=6;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                14:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=1;
                            mem_set<=1;
                            add_ctrl<=0;
                        end
                        1: begin
                            roll<=2;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=2;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=4;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                15:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=8;
                            mem_set<=1;
                            add_ctrl<=1;
                        end
                        1: begin
                            roll<=4;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=4;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=2;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                16:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=1;
                        end
                        1: begin
                            roll<=5;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=3;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                17:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=8;
                            mem_set<=1;
                            add_ctrl<=1;
                        end
                        1: begin
                            roll<=0;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=5;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=5;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                18:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=2;
                            mem_set<=1;
                            add_ctrl<=0;
                        end
                        1: begin
                            roll<=2;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=4;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                19:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=1;
                        end
                        1: begin
                            roll<=2;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=2;
                            mem_set<=3;
                        end
                        3: begin
                            mult_req<=1;
                            if(mult_rdy) begin
                                mem[0]<=extmem[0];
                                roll<=5;
                                state<=1;
                                mem_set<=0;
                                mult_req<=0;
                            end
                        end
                    endcase
                end
                20:begin
                    rdy<=1;
                    state<=0;
                end
            endcase

            if(spi_clk | !spi_clk) prev_spi_clk<=spi_clk;

            if(spi_clk & spi_clk!=prev_spi_clk) begin
                if(cs & !start_sending) begin
                    count_spi<=count_spi+1;
                    if(count_spi<WIDTH) begin
                        mem[0]<=mem[0]>>1;
                        mem[0][WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<2*WIDTH) begin
                        mem[1]<=mem[1]>>1;
                        mem[1][WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<3*WIDTH) begin
                        mem[2]<=mem[2]>>1;
                        mem[2][WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<4*WIDTH) begin
                        mem[3]<=mem[3]>>1;
                        mem[3][WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<5*WIDTH) begin
                        mem[4]<=mem[4]>>1;
                        mem[4][WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<6*WIDTH) begin
                        mem[5]<=mem[5]>>1;
                        mem[5][WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<7*WIDTH) begin
                        mem[6]<=mem[6]>>1;
                        mem[6][WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<8*WIDTH) begin
                        mem[7]<=mem[7]>>1;
                        mem[7][WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<9*WIDTH) begin
                        mem[8]<=mem[8]>>1;
                        mem[8][WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<10*WIDTH) begin
                        mod<=mod>>1;
                        mod[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi==10*WIDTH) begin
                        req<=1;
                    end else begin
                        req<=0;
                    end
                end else begin
                    count_spi<=0;
                end
                if(rdy) begin
                    count_spi<=count_spi+1;
                    if(!start_sending) begin
                        count_spi<=0;
                        start_sending<=1;
                    end else begin
                        if(count_spi<WIDTH) mem[0]<={mem[0][0],mem[0][WIDTH-1:1]};
                        else if(count_spi<2*WIDTH) mem[1]<={mem[1][0],mem[1][WIDTH-1:1]};
                        else if(count_spi<3*WIDTH) mem[2]<={mem[2][0],mem[2][WIDTH-1:1]};
                        else if(count_spi<4*WIDTH) mem[3]<={mem[3][0],mem[3][WIDTH-1:1]};
                        else if(count_spi<5*WIDTH) mem[4]<={mem[4][0],mem[4][WIDTH-1:1]};
                        else if(count_spi<6*WIDTH) mem[5]<={mem[5][0],mem[5][WIDTH-1:1]};
                        else if(count_spi<7*WIDTH) mem[6]<={mem[6][0],mem[6][WIDTH-1:1]};
                        else if(count_spi<8*WIDTH) mem[7]<={mem[7][0],mem[7][WIDTH-1:1]};
                        else if(count_spi<9*WIDTH) mem[8]<={mem[8][0],mem[8][WIDTH-1:1]};
                        else rdy<=0;
                    end
                end
            end
        end
    end


    // modmul stuff

    logic [2:0]            state_mul;
    logic [WIDTH-1:0]      mult_mem_a, mult_mem_b;
    logic [$clog2(WIDTH):0] count;
    logic prev_req, mult_req, mult_rdy;

    logic [WIDTH+1:0] add_a,add_b,add_out, add_mod;
    logic add_ctrl;

    always_comb begin
        add_mod=mod;
        case(state_mul)
            2: begin
                add_mod = '1;
            end
            4: begin
                add_mod = '1;
            end
            6: begin
                add_mod = {1'b0,mod};
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            add_ctrl<=0;
            mult_req<=0;
            prev_req<=0;
            state_mul    <= 0;
            count    <= 0;
            mult_rdy      <= 0;
            mult_mem_a<=0;
            mult_mem_b<=0;
        end else begin
            case (state_mul)
                0: begin
                    prev_req<=mult_req;
                    mult_rdy<=0;
                    if (mult_req & ~prev_req) begin
                        mult_mem_a<=extmem[0];
                        mult_mem_b<=extmem[1];
                        extmem[0]<=0;
                        count <= 0;
                        state_mul <= 1;
                        add_ctrl = 0;
                    end
                end
                1: begin
                    extmem[1] = mult_mem_b[0] ? {1'b0,mult_mem_a} : 0;
                    mult_mem_b<=mult_mem_b>>1;
                    state_mul<=2;
                end
                2: begin
                    extmem[0] <= add_out;
                    count<=count+1;
                    state_mul<=3;
                end
                3: begin
                    extmem[1] = extmem[0] ? {1'b0,mod} : 0;
                    state_mul<=4;
                end
                4: begin
                    extmem[0]<= add_out>>1;
                    if(count[$clog2(WIDTH)]) state_mul<=5;
                    else state_mul<=1;
                end
                5: begin
                    extmem[1]<=0;
                    state_mul<=6;
                end
                6: begin
                    extmem[0]<=add_out[WIDTH-1:0];
                    mult_rdy<=1;
                    state_mul<=0;
                    prev_req<=req;
                end
            endcase
        end
    end

    //modadd

    logic [WIDTH+2:0] val_1;
    logic [WIDTH+2:0] val_2;

    always_comb begin
        if(add_ctrl) begin
            val_1 = {1'b0,extmem[0]} - {1'b0,extmem[1]};
            val_2 = val_1[WIDTH-1:0] + add_mod;
            add_out = (extmem[1]>=extmem[0]) ? val_2[WIDTH-1:0] : val_1[WIDTH-1:0];
        end else begin
            val_1 = {1'b0,extmem[0]} + {1'b0,extmem[1]};
            val_2 = val_1[WIDTH-1:0] - add_mod;
            add_out = (val_1>={1'b0,add_mod}) ? val_2[WIDTH-1:0] : val_1[WIDTH-1:0];
        end
    end


endmodule
