module top_module #(
    parameter WIDTH = 512
)(
    input logic cs,
    input logic spi_clk,
    input logic spi_pad_MOSI,
    input logic clk,rst,
    output logic rdy,
    output logic spi_pad_MISO
);

    logic [WIDTH:0] mid,add_out_1,add_out_2,add_out_3;
    logic [WIDTH-1:0] P0_x,P0_y,P0_z,P1_x,P1_y,P1_z,sum_x,sum_y,sum_z,dub_x,dub_y,dub_z,add_out;
    logic [WIDTH-1:0] a,mod,k,summed_x,summed_y,summed_z,dubbed_x,dubbed_y,dubbed_z, inv_in, inv_out, mult_a, mult_b, mult_out;
    logic [$clog2(WIDTH)+2:0] count_spi;
    logic [$clog2(WIDTH)-1:0] count;
    logic [3:0] state;
    logic req, alu_req, inv_req, alu_rdy, inv_rdy, first, mult_req, mult_rdy, start_sending=0, sent=0, alu_mult_only, did_it;

    always_ff @(posedge spi_clk) begin
        if(cs & !start_sending) begin
            count_spi<=count_spi+1;
            if(count_spi<WIDTH) begin
                P1_x<=P1_x>>1;
                P1_x[WIDTH-1]<=spi_pad_MOSI;
            end else if(count_spi<2*WIDTH) begin
                P1_y<=P1_y>>1;
                P1_y[WIDTH-1]<=spi_pad_MOSI;
            end else if(count_spi<3*WIDTH) begin
                a<=a>>1;
                a[WIDTH-1]<=spi_pad_MOSI;
            end else if(count_spi<4*WIDTH) begin
                mod<=mod>>1;
                mod[WIDTH-1]<=spi_pad_MOSI;
            end else if(count_spi<5*WIDTH) begin
                k<=k>>1;
                k[WIDTH-1]<=spi_pad_MOSI;
            end else if(count_spi==5*WIDTH) begin
                req<=1;
            end else begin
                req<=0;
            end
        end else begin
            count_spi<=0;
            req<=0;
        end
        if(rdy) begin
            count_spi<=count_spi+1;
            if(!start_sending) begin
                count_spi<=0;
                start_sending<=1;
            end else begin
                if(count_spi<512) P0_x<={P0_x[0],P0_x[WIDTH-1:1]};
                else if(count_spi<1024) P0_y<={P0_y[0],P0_y[WIDTH-1:1]};
                else rdy<=0;
            end

        end
    end

    localparam q = 512'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF27E69532F48D89116FF22B8D4E0560609B4B38ABFAD2B85DCACDB1411F10B275;

    always_comb begin
        first=0;
        sum_x=0;sum_y=0;sum_z=0;
        dub_x=0;dub_y=0;dub_z=0;
        inv_in=0;
        alu_mult_only=0;
        case(state)
            0: begin
                if(req) begin
                    mid=(k+q-{1'b1,{WIDTH{1'b0}}});
                    add_out = (mid[WIDTH]) ? (mid[WIDTH-1:0]+q) : mid[WIDTH-1:0];
                end
            end
            1: begin
                first=1;
                dub_x=P1_x; dub_y=P1_y; dub_z=P1_z;
                sum_x=P0_x; sum_y=P0_y; sum_z=P0_z;
            end
            2: begin
                if(k[count]) begin
                    dub_x=P1_x; dub_y=P1_y; dub_z=P1_z;
                    sum_x=P0_x; sum_y=P0_y; sum_z=P0_z;
                end else begin
                    dub_x=P0_x; dub_y=P0_y; dub_z=P0_z;
                    sum_x=P1_x; sum_y=P1_y; sum_z=P1_z;
                end
            end
            3: begin
                alu_mult_only=1;
                sum_x=P0_x;
            end
            4: begin
                alu_mult_only=1;
                sum_x=P0_y;
            end
            5: begin
                alu_mult_only=1;
                sum_x=P0_z;
            end
            6: begin
                inv_in=P1_z;
            end
            7: begin
                mult_a= P1_z; mult_b= P1_z;
            end
            8: begin
                mult_a= P0_x; mult_b= P0_z;
            end
            9: begin
                mult_a= P1_z; mult_b= P0_z;
            end
            10: begin
                mult_a= P0_y; mult_b= P0_z;
            end
        endcase


        //spi_miso drive
        if(rdy) begin
            if(count_spi<512)begin
                spi_pad_MISO=P0_x[0];
            end else begin
                spi_pad_MISO=P0_y[0];
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            P0_x<=0; P0_y<=0; P0_z<=569; P1_x<=0; P1_y<=0; P1_z<=569;
            a<=0; mod<=0; k<=0; count_spi<=0; rdy<=0; req<=0;
            state<=0; count<=0; sent<=0; start_sending<=0; did_it<=0;
        end
        inv_req<=0;
        mult_req<=0;
        alu_req<=0;
        case(state)
            0: begin
                if(req) begin
                    rdy<=0;
                    state<=1;
                    k<=add_out;
                end
            end
            1: begin
                if(!sent) alu_req<=1;
                sent<=1;
                req<=0;
                if(alu_rdy) begin
                    P0_x<=summed_x; P0_y<=summed_y; P0_z<=summed_z;
                    P1_x<=dubbed_x; P1_y<=dubbed_y; P1_z<=dubbed_z;
                    state<=2;
                    sent<=0;
                    count<=count-1;
                end
            end
            2: begin
                if(!sent) begin
                    alu_req<=1;
                end
                sent<=1;
                if(alu_rdy) begin
                    if(k[count]) begin
                        P0_x<=summed_x; P0_y<=summed_y; P0_z<=summed_z;
                        P1_x<=dubbed_x; P1_y<=dubbed_y; P1_z<=dubbed_z;
                    end else begin
                        P1_x<=summed_x; P1_y<=summed_y; P1_z<=summed_z;
                        P0_x<=dubbed_x; P0_y<=dubbed_y; P0_z<=dubbed_z;
                    end

                    sent<=0;
                    if(count==0 & did_it) begin
                        state<=3;
                    end else begin
                        count<=count-1;
                        did_it<=1;
                    end
                end
            end
            3: begin
                if(!sent) alu_req<=1;
                sent<=1;
                if(alu_rdy) begin
                    P0_x<=dubbed_x;
                    sent<=0;
                    state<=4;
                end
            end
            4: begin
                if(!sent) alu_req<=1;
                sent<=1;
                if(alu_rdy) begin
                    P0_y<=dubbed_x;
                    sent<=0;
                    state<=5;
                end
            end
            5: begin
                if(!sent) alu_req<=1;
                sent<=1;
                if(alu_rdy) begin
                    P1_z<=dubbed_x;
                    sent<=0;
                    state<=6;
                end
            end
            6: begin
                if(!sent) inv_req<=1;
                sent<=1;
                if(inv_rdy) begin
                    P1_z<=inv_out;
                    sent<=0;
                    state<=7;
                end
            end
            7: begin
                if(!sent) mult_req<=1;
                sent<=1;
                if(mult_rdy) begin
                    P0_z<=mult_out;
                    sent<=0;
                    state<=8;
                end
            end
            8: begin
                if(!sent) mult_req<=1;
                sent<=1;
                if(mult_rdy) begin
                    P0_x<=mult_out;
                    sent<=0;
                    state<=9;
                end
            end
            9: begin
                if(!sent) mult_req<=1;
                sent<=1;
                if(mult_rdy) begin
                    P0_z<=mult_out;
                    sent<=0;
                    state<=10;
                end
            end     
            10: begin
                if(!sent) mult_req<=1;
                sent<=1;
                if(mult_rdy) begin
                    P0_y<=mult_out;
                    sent<=0;
                    did_it<=0;
                    state<=0;
                    rdy<=1;
                end
            end        
        endcase
    end

point_alu #(.WIDTH(WIDTH)) alu (
    .clk(clk), .rst(rst), .req(alu_req), .first(first),
    .P1_x(dub_x), .P1_y(dub_y), .P1_z(dub_z),
    .P2_x(sum_x), .P2_y(sum_y), .P2_z(sum_z),
    .a(a), .mod(mod), .mult(alu_mult_only),
    .rdy(alu_rdy), .Psum_x(summed_x), .Psum_y(summed_y), .Psum_z(summed_z),
    .Pd_x(dubbed_x), .Pd_y(dubbed_y), .Pd_z(dubbed_z)
);

inverse #(.WIDTH(512)) inversion (
    .clk(clk), .rst(rst), .req(inv_req),
    .inv_in(inv_in), .mod(mod), .inv_out(inv_out), .rdy(inv_rdy)
); 

mod_mult #(.WIDTH(512)) mult (
    .clk(clk), .rst(rst), .req(mult_req),
    .mult_a(mult_a), .mult_b(mult_b), .mod(mod),
    .mult_out(mult_out), .rdy(mult_rdy)
);

endmodule