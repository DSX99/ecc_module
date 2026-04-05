module top_module_old #(
    parameter WIDTH = 512
)(
    input logic clk,
    input logic rst,
    input logic req,
    input logic [WIDTH-1:0] G_x,
    input logic [WIDTH-1:0] G_y,
    input logic [WIDTH-1:0] a,
    output logic rdy,
    output logic [WIDTH-1:0] P_x,
    output logic [WIDTH-1:0] P_y,
    output logic [WIDTH-1:0] P_z
);

    logic [WIDTH-1:0] buff_x, buff_y, buff_z, sum_x=0, sum_y=0, sum_z=1, add_x, add_y, add_z, dub_x, dub_y, dub_z, rec_x, rec_y, rec_z;
    logic [WIDTH-1:0] conn [2:0], conn_inv [2:0], P_x_to_inv, P_y_to_inv, P_z_to_inv, P_x_out, P_y_out;
    logic [8:0] count;
    logic [1:0] rdy_count=0;
    logic op_req, add_rdy, dub_rdy, sent=0, check, reqed=0, reqed_2=0, reqed_inv=0, inv_req, inv_rdy;

    point_add add_mod(
        .clk(clk),
        .rst(rst),
        .req(op_req),
        .P1_x(sum_x),
        .P1_y(sum_y),
        .P1_z(sum_z),
        .P2_x(buff_x),
        .P2_y(buff_y),
        .P2_z(buff_z),
        .rdy(add_rdy),
        .P3_x(add_x),
        .P3_y(add_y),
        .P3_z(add_z),
        .do_inv(do_inv)
    );

    point_double double_mod(
        .clk(clk),
        .rst(rst),
        .req(op_req),
        .P1_x(buff_x),
        .P1_y(buff_y),
        .P1_z(buff_z),
        .rdy(dub_rdy),
        .P3_x(dub_x),
        .P3_y(dub_y),
        .P3_z(dub_z)
    );

    full_inversion inversion(
        .clk(clk),
        .rst(rst),
        .req(inv_req),
        .P_x(P_x_to_inv),
        .P_y(P_y_to_inv),
        .P_z(P_z_to_inv),
        .P_x_out(P_x_out),
        .P_y_out(P_y_out),
        .rdy(inv_rdy)
    );

    always_ff @(posedge clk) begin
        rdy<=0;
        inv_req<=0;
    
        if(rst) begin
            rdy_count<=0;
            count<=0;
            buff_x<=0;
            buff_y<=0;
            buff_z<=0;
            op_req<=0;
            reqed<=0;
            reqed_2<=0;
            sent<=0;
            sum_x<=0;
            sum_y<=0;
            sum_z<=1;
            rec_x<=0;
            rec_y<=0;
            rec_z<=1;
            P_x<=0;
            P_y<=0;
            P_z<=0;
        end

        if(req) begin
            buff_x<=G_x;
            buff_y<=G_y;
            buff_z<=1;
            op_req<=1;
            reqed<=1;
        end

        if(reqed) begin
            op_req<=0;
            if(dub_rdy) begin
                rdy_count[0]<=1;
            end
            
            if(~sent & a[count] & add_rdy) begin
                sent<=1;
            end

            if(add_rdy) begin
                sum_x<=conn[0];
                sum_y<=conn[1];
                sum_z<=conn[2];
                rec_x<=conn_inv[0];
                rec_y<=conn_inv[1];
                rec_z<=conn_inv[2];
                rdy_count[1]<=1;
            end
            
            if(rdy_count==3) begin
                buff_x<=dub_x;
                buff_y<=dub_y;
                buff_z<=dub_z;

                count<=count+1;
                rdy_count<=0;
                if(count != 9'h1FF) op_req<=1;
                if(!reqed_2) reqed_2<=1;
            end
        end
        if(!count & reqed & reqed_2)begin
            op_req<=0;
            // rdy<=1;
            P_x_to_inv<=sum_x;
            P_y_to_inv<=sum_y;
            P_z_to_inv<=sum_z;
            sent<=0;
            reqed<=0;
            reqed_2<=0;
            reqed_inv<=1;
            inv_req<=1;
        end
        if(reqed_inv) begin
            if(inv_rdy) begin
                P_x<=P_x_out;
                P_y<=P_y_out;
                op_req<=0;
                rdy<=1;
                sent<=0;
                reqed<=0;
                reqed_2<=0;
                reqed_inv<=0;
            end
        end
    end

    always_comb begin
        check = a[count];
        if(add_rdy & sent) begin
            conn[0] = (check) ? add_x : sum_x;
            conn[1] = (check) ? add_y : sum_y;
            conn[2] = (check) ? add_z : sum_z;
            conn_inv[0] = ~(check) ? add_x : sum_x;
            conn_inv[1] = ~(check) ? add_y : sum_y;
            conn_inv[2] = ~(check) ? add_z : sum_z;
        end
        if(add_rdy & !sent) begin
            conn[0] = (check) ? buff_x : sum_x;
            conn[1] = (check) ? buff_y : sum_y;
            conn[2] = (check) ? buff_z : sum_z;
            conn_inv[0] = ~(check) ? buff_x : sum_x;
            conn_inv[1] = ~(check) ? buff_y : sum_y;
            conn_inv[2] = ~(check) ? buff_z : sum_z;
        end
    end

endmodule

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
    input logic do_inv,
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
        .rdy(mult_0_rdy), .M((512'd1<<512)-C)
    );

    
    modmul mult_1(
        .clk(clk),
        .rst(rst),
        .req(mult_1_req),
        .a(mult_1_a),
        .b(mult_1_b),
        .out(mult_1_out),
        .rdy(mult_1_rdy), .M((512'd1<<512)-C)
    );

    modmul mult_2(
        .clk(clk),
        .rst(rst),
        .req(mult_2_req),
        .a(mult_2_a),
        .b(mult_2_b),
        .out(mult_2_out),
        .rdy(mult_2_rdy), .M((512'd1<<512)-C)
    );

    
    modmul mult_3(
        .clk(clk),
        .rst(rst),
        .req(mult_3_req),
        .a(mult_3_a),
        .b(mult_3_b),
        .out(mult_3_out),
        .rdy(mult_3_rdy), .M((512'd1<<512)-C)
    );

    logic [WIDTH-1:0] add_1_a, add_1_b, add_2_a, add_2_b, add_1_out, add_2_out;
    logic add_1_ctrl, add_2_ctrl;

    modadd add_1(
        .a(add_1_a),
        .b(add_1_b),
        .ctrl(add_1_ctrl),
        .out(add_1_out)
    );

    modadd add_2(
        .a(add_2_a),
        .b(add_2_b),
        .ctrl(add_2_ctrl),
        .out(add_2_out)
    );

    logic sent = 0;
    logic [3:0] count = 0;
    logic [3:0] rdy_count = 0;

    logic [WIDTH-1:0] mem [7:0];

    always_ff @(posedge clk) begin

        if(rst) begin
            sent<=0;
            count<=0;
            rdy_count<=0;
            mem[0]<=0;
            mem[1]<=0;
            mem[2]<=0;
            mem[3]<=0;
            mem[4]<=0;
            mem[5]<=0;
            mem[6]<=0;
            P3_x<=0;
            P3_y<=0;
            P3_z<=0;
            P3_x_norm<=0;
            P3_y_norm<=0;
            P3_z_norm<=0;
        end

        mult_0_req <= 0;
        mult_1_req <= 0;
        mult_2_req <= 0;
        mult_3_req <= 0;

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
                mem[1]<=add_1_out;
                mem[2]<=add_2_out;
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
                    mult_0_req <= 1; 
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
                mem[5]<=add_1_out;
                mem[4]<=add_2_out;
                count<=6;
                v<=mem[0];
                g<=mem[2];
            end
            6: begin
                mem[5]<=add_1_out;
                count<=7;
            end
            7: begin //mem[0] =v mem[1] =r mem[2] =g mem[3] =s1 mem[4] =r**2 mem[5] =p3x mem[6] =p3z need to find v-p3_x
                mem[0]<=add_1_out;
                count<=8;
            end
            8: begin //mem[0] =v-p3x mem[1] =r mem[2] =g mem[3] =s1 mem[4] =r**2 mem[5] =p3x mem[6] =p3z need to find r*(v-p3_x), s1*g
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
                    count<=9;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            9: begin //mem[0] =r*(v-p3_x) mem[1] =s1*g mem[2] =g mem[3] =s1 mem[4] =r**2 mem[5] =p3x mem[6] =p3z need to find p3_y
                mem[0]<=add_1_out;
                count<=10;
            end
            10: begin
                P3_x<= mem[5];
                P3_y<= mem[0];
                P3_z<= mem[6];
                count<=0;
                rdy<=1;
            end
        endcase
    end

    always_comb begin 
        add_1_a=0;
        add_1_b=0;
        add_1_ctrl=0;
        add_2_a=0;
        add_2_b=0;
        add_2_ctrl=0;
        case(count)
            2:begin
                add_1_a=mem[3];
                add_1_b=mem[2];
                add_1_ctrl=1;
                add_2_a=mem[0];
                add_2_b=mem[1];
                add_2_ctrl=1;
            end
            5: begin
                add_1_a=mem[4];
                add_1_b=mem[2];
                add_1_ctrl=0;
                add_2_a=mem[0];
                add_2_b=mem[0];
                add_2_ctrl=0;

                // connect_5 = mem[4] + mem[2] - mem[0] - mem[0] + 2*((1<<512) - C);
                // connect_6 = connect_5[WIDTH-1:0] + connect_5[WIDTH+1:WIDTH]*C;
                // res_5 = connect_6 + C;
                // connect_3 = ~res_5[WIDTH] ? connect_6[WIDTH-1:0] : res_5[WIDTH-1:0];
            end
            6: begin
                add_1_a=mem[5];
                add_1_b=mem[4];
                add_1_ctrl=1;
            end
            7: begin
                add_1_a=mem[0];
                add_1_b=mem[5];
                add_1_ctrl=1;
            end
            9: begin
                add_1_a=mem[0];
                add_1_b=mem[1];
                add_1_ctrl=1;
            end
        endcase
    end
endmodule

module point_double #(
    parameter WIDTH = 512,
    parameter C =569
)(
    input logic clk,
    input logic rst,
    input logic req,
    input logic [WIDTH-1:0] P1_x,
    input logic [WIDTH-1:0] P1_y,
    input logic [WIDTH-1:0] P1_z,
    output logic rdy,
    output logic [WIDTH-1:0] P3_x,
    output logic [WIDTH-1:0] P3_y,
    output logic [WIDTH-1:0] P3_z
);

    logic [WIDTH-1:0] mult_0_a,mult_0_b,mult_0_out, mult_1_a,mult_1_b,mult_1_out;
    logic mult_0_rdy,mult_0_req, mult_1_rdy,mult_1_req;
    logic [WIDTH-1:0] M, T, S;

    modmul mult_0(
        .clk(clk),
        .rst(rst),
        .req(mult_0_req),
        .a(mult_0_a),
        .b(mult_0_b),
        .out(mult_0_out),
        .rdy(mult_0_rdy), .M((512'd1<<512)-C)
    );

    
    modmul mult_1(
        .clk(clk),
        .rst(rst),
        .req(mult_1_req),
        .a(mult_1_a),
        .b(mult_1_b),
        .out(mult_1_out),
        .rdy(mult_1_rdy), .M((512'd1<<512)-C)
    );

    logic sent = 0;
    logic [3:0] count = 0;
    logic [1:0] rdy_count = 0;

    logic [WIDTH-1:0] mem [3:0];

    always_ff @(posedge clk) begin

        if(rst) begin
            sent<=0;
            count<=0;
            rdy_count<=0;
            mem[0]<=0;
            mem[1]<=0;
            mem[2]<=0;
            mem[3]<=0;
            P3_x<=0;
            P3_y<=0;
            P3_z<=0;
        end

        mult_0_req <= 0;
        mult_1_req <= 0;

        case(count)
            0: begin // finding 0=z^2,1=y^2
                rdy<=0;
                if(req) begin
                    mult_0_a <= P1_z;
                    mult_0_b <= P1_z;
                    mult_0_req <= 1;
                    mult_1_a <= P1_y;
                    mult_1_b <= P1_y;
                    mult_1_req <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[0]<=mult_0_out;
                end
                if(mult_1_rdy == 1) begin
                    rdy_count[1]<=1;
                    mem[1]<=mult_1_out;
                end

                if(rdy_count == 3) begin
                    count<=1;
                    rdy_count<=0;
                end
            end

            1: begin // 0=x-z^2 1= y^2 2=x+z^2
                mem[0]<=connect_3;
                mem[2]<=connect_4;
                count<=2;
            end

            2: begin // 0=(x-z^2)(x+z^2) 1=y^2 2=xy^2 
                if(~sent) begin
                    mult_0_a <= mem[0];
                    mult_0_b <= mem[2];
                    mult_0_req <= 1;
                    mult_1_a <= P1_x;
                    mult_1_b <= mem[1];
                    mult_1_req <= 1;
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[0]<=mult_0_out;
                end
                if(mult_1_rdy == 1) begin
                    rdy_count[1]<=1;
                    mem[2]<=mult_1_out;
                end

                if(rdy_count == 3) begin
                    count<=3;
                    sent<=0;
                    rdy_count<=0;
                end
            end

            3: begin // 0= M 1=y^2 2=S
                mem[0]<=connect_3;
                mem[2]<=connect_4;
                count<=4;
            end

            4: begin // 0=M 1=T 2=S 3=M^2
                if(~sent) begin
                    mult_0_a <= mem[0];
                    mult_0_b <= mem[0];
                    mult_0_req <= 1;
                    mult_1_a <= mem[1];
                    mult_1_b <= mem[1];
                    mult_1_req <= 1;
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[3]<=mult_0_out;
                end
                if(mult_1_rdy == 1) begin
                    rdy_count[1]<=1;
                    mem[1]<=mult_1_out;
                end

                if(rdy_count == 3) begin
                    count<=5;
                    sent<=0;
                    rdy_count<=0;
                end
            end

            5: begin // 0=M 1=8T 2=S 3=x3
                mem[3]<= connect_3;
                mem[1]<= connect_4;
                count<=6;
            end

            6: begin // 0=M 1=8T 2=S-x^3 3=x3
                mem[2]<= connect_3;
                count<=7;
            end

            7: begin // 0=M(S-x^3) 1=8T 2=yz 3=x3
                if(~sent) begin
                    mult_0_a <= mem[0];
                    mult_0_b <= mem[2];
                    mult_0_req <= 1;
                    mult_1_a <= P1_y;
                    mult_1_b <= P1_z;
                    mult_1_req <= 1;
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count[0]<=1;
                    mem[0]<=mult_0_out;
                end
                if(mult_1_rdy == 1) begin
                    rdy_count[1]<=1;
                    mem[2]<=mult_1_out;
                end

                if(rdy_count == 3) begin
                    count<=8;
                    sent<=0;
                    rdy_count<=0;
                end
            end

            8: begin // 0=y3 1=z3 2=yz 3=x3
                mem[0]<=connect_3;
                mem[1]<=connect_4;
                count<=9;
            end

            9: begin
                P3_x <= mem[3];
                P3_y <= mem[0];
                P3_z <= mem[1];
                rdy<=1;
                count<=0;
            end

        endcase
    end

    logic [WIDTH+2:0] connect_9, connect_10, res_9, connect_11, connect_12, res_11;
    logic [WIDTH+1:0] connect_5, res_5,connect_6, connect_7, connect_8, res_7;
    logic [WIDTH:0] connect_1, connect_2, res_1, res_2;
    logic [WIDTH-1:0] connect_3, connect_4;

    always_comb begin
        case(count)
            1: begin
                connect_1 = P1_x-mem[0];
                connect_2 = P1_x+mem[0];
                res_1 = connect_1 - C;
                res_2 = connect_2 + C;
                connect_3 = ~connect_1[WIDTH] ? connect_1[WIDTH-1:0] : res_1[WIDTH-1:0];
                connect_4 = ~connect_2[WIDTH] ? connect_2[WIDTH-1:0] : res_2[WIDTH-1:0];
            end
            3: begin
                connect_5 = mem[0]+mem[0]+mem[0];
                connect_6 = connect_5[WIDTH-1:0] + connect_5[WIDTH+1:WIDTH]*C;
                res_5 = connect_6 + C;
                connect_3 = ~connect_6[WIDTH] ? connect_6[WIDTH-1:0] : res_5[WIDTH-1:0];

                connect_7 = mem[2]<<2;
                connect_8 = connect_7[WIDTH-1:0] + connect_7[WIDTH+1:WIDTH]*C;
                res_7 = connect_8 + C;
                connect_4 = ~connect_8[WIDTH] ? connect_8[WIDTH-1:0] : res_7[WIDTH-1:0];
            end
            5: begin
                connect_11 = mem[3]-mem[2]-mem[2]+2*((1<<WIDTH)-C);
                connect_12 = connect_11[WIDTH-1:0] + connect_11[WIDTH+2:WIDTH]*C;
                res_11 = connect_12 + C;
                connect_3 = ~connect_12[WIDTH] ? connect_12[WIDTH-1:0] : res_11[WIDTH-1:0];

                connect_9 = mem[1]<<3;
                connect_10 = connect_9[WIDTH-1:0] + connect_9[WIDTH+2:WIDTH]*C;
                res_9 = connect_10 + C;
                connect_4 = ~connect_10[WIDTH] ? connect_10[WIDTH-1:0] : res_9[WIDTH-1:0];
            end
            6: begin
                connect_1 = mem[2]-mem[3];
                res_1 = connect_1 - C;
                connect_3 = ~connect_1[WIDTH] ? connect_1[WIDTH-1:0] : res_1[WIDTH-1:0];
            end
            8: begin
                connect_1 = mem[0]-mem[1];
                connect_2 = mem[2]+mem[2];
                res_1 = connect_1 - C;
                res_2 = connect_2 + C;
                connect_3 = ~connect_1[WIDTH] ? connect_1[WIDTH-1:0] : res_1[WIDTH-1:0];
                connect_4 = ~connect_2[WIDTH] ? connect_2[WIDTH-1:0] : res_2[WIDTH-1:0];
            end
        endcase
    end

endmodule

module modmul#(
    parameter WIDTH = 512
)(
    input  logic              clk,
    input  logic              rst,
    input  logic              req,
    input  logic [WIDTH-1:0]  a,
    input  logic [WIDTH-1:0]  b,
    input  logic [WIDTH-1:0]  M,
    output logic [WIDTH-1:0]  out,
    output logic              rdy
);

    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        PRECOMP  = 2'b01, // Calculate 3b and 3M
        COMPUTE  = 2'b10, // Main loop (2 bits per cycle)
        FINISH   = 2'b11  // Final reduction
    } state_t;

    state_t state;

    logic [WIDTH+2:0] S;
    logic [WIDTH-1:0] a_reg;
    logic [WIDTH+1:0] b1, b2, b3;
    logic [WIDTH+1:0] M1, M2, M3; 
    logic [1:0] M_inv;
    logic [$clog2(WIDTH/2):0] count;

    logic [1:0] a_i;
    logic [1:0] q_i;
    logic [WIDTH+1:0] term_b;
    logic [WIDTH+1:0] term_M;

    assign a_i = a_reg[1:0];

    always_comb begin
        case (a_i)
            2'b01:   term_b = b1;
            2'b10:   term_b = b2;
            2'b11:   term_b = b3;
            default: term_b = '0;
        endcase
    end

    assign q_i = ( (S[1:0] + term_b[1:0]) * M_inv ) & 2'b11;

    always_comb begin
        case (q_i)
            2'b01:   term_M = M1;
            2'b10:   term_M = M2;
            2'b11:   term_M = M3;
            default: term_M = '0;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            rdy <= 1'b0;
            out <= '0;
            S <= '0;
        end else begin
            case (state)
                IDLE: begin
                    rdy <= 1'b0;
                    if (req) begin
                        a_reg <= a;
                        b1 <= {2'b0, b};
                        M1 <= {2'b0, M};
                        M_inv <= (M[1]) ? 2'b01 : 2'b11; 
                        state <= PRECOMP;
                    end
                end

                PRECOMP: begin
                    b2 <= b1 << 1;
                    b3 <= (b1 << 1) + b1;
                    M2 <= M1 << 1;
                    M3 <= (M1 << 1) + M1;
                    S <= '0;
                    count <= WIDTH / 2;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    if (count > 0) begin
                        S <= (S + term_b + term_M) >> 2;
                        a_reg <= a_reg >> 2;
                        count <= count - 1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    if (S >= M1) begin
                        out <= S - M1;
                    end else begin
                        out <= S[WIDTH-1:0];
                    end
                    rdy <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

module modadd #( //module for addition, ctrl=1 subtraction, ctrl=0 addition
    parameter WIDTH = 512,
    parameter C =569
)(
    input logic ctrl,
    input logic [WIDTH-1:0] a,
    input logic [WIDTH-1:0] b,
    output logic [WIDTH-1:0] out
);

    logic [WIDTH:0] res_1;
    logic [WIDTH-1:0] res_2;

    always_comb begin

        if(ctrl) begin
            res_1 = a - b;
            res_2 = res_1 - C;
            out = res_1[WIDTH] ? res_2 : res_1[WIDTH-1:0];
        end else begin
            res_1 = a + b;
            res_2 = res_1 + C;
            out = res_1[WIDTH] ? res_2 : res_1[WIDTH-1:0];
        end

    end

endmodule


module pm_inverter #(
    parameter WIDTH = 512,
    parameter C = 569
)(
    input  logic              clk,
    input  logic              reset,
    input  logic              req,
    input  logic [WIDTH-1:0]  z_in,
    output logic [WIDTH-1:0]  inv_out,
    output logic              rdy
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

    modmul #(.WIDTH(WIDTH)) mm_inst (
        .clk(clk), .rst(reset), .req(mm_req),
        .a(mm_a), .b(mm_b), .out(mm_out), .rdy(mm_rdy), .M((512'd1<<512)-C)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            rdy <= 0;
            bit_ptr <= 511;
        end else begin
            mm_req <= 0;
            case (state)
                IDLE: begin
                    rdy <= 0;
                    if (req) begin
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
                    rdy <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

module full_inversion #(
    parameter WIDTH = 512,
    parameter C = 569
)(
    input  logic              clk,
    input  logic              rst,
    input  logic              req,
    input  logic [WIDTH-1:0]  P_x,
    input  logic [WIDTH-1:0]  P_y,
    input  logic [WIDTH-1:0]  P_z,
    output  logic [WIDTH-1:0]  P_x_out,
    output  logic [WIDTH-1:0]  P_y_out,
    output logic              rdy
);

    logic [WIDTH-1:0] mult_0_a,mult_0_b,mult_0_out;
    logic mult_0_rdy,mult_0_req;

    modmul mult_0(
        .clk(clk),
        .rst(rst),
        .req(mult_0_req),
        .a(mult_0_a),
        .b(mult_0_b),
        .out(mult_0_out),
        .rdy(mult_0_rdy), .M((512'd1<<512)-C)
    );

    logic inv_req, sent=0;
    logic inv_rdy;
    logic [WIDTH-1:0] inv_in; 
    logic [WIDTH-1:0] inv_out; 

    pm_inverter inv_0(
        .clk(clk),
        .reset(rst),
        .req(inv_req),
        .z_in(inv_in),
        .inv_out(inv_out),
        .rdy(inv_rdy)
    );

    logic [WIDTH-1:0] mem[2];
    logic [2:0] count=0;
    logic rdy_count;

    always_ff @(posedge clk) begin
        if(req) count<=1;

        mult_0_req<=0;
        rdy<=0;
        inv_req<=0;

        case(count)
            0: begin
                P_x_out<=0;
                P_y_out<=0;
            end
            1: begin
                if(~sent) begin
                    inv_in <= P_z;
                    inv_req <= 1;
                    sent <= 1;
                end

                if(inv_rdy) begin
                    mem[0]<= inv_out;
                    count<=2;
                    sent<=0;
                end
            end 
            2: begin
                if(~sent) begin
                    mult_0_a <= mem[0]; 
                    mult_0_b <= mem[0];
                    mult_0_req <= 1; 
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count<=1;
                    mem[1]<=mult_0_out;
                end

                if(rdy_count == 1) begin
                    count<=3;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            3: begin
                if(~sent) begin
                    mult_0_a <= mem[1]; 
                    mult_0_b <= P_x;
                    mult_0_req <= 1; 
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count<=1;
                    P_x_out<=mult_0_out;
                end

                if(rdy_count == 1) begin
                    count<=4;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            4: begin
                if(~sent) begin
                    mult_0_a <= mem[0]; 
                    mult_0_b <= mem[1];
                    mult_0_req <= 1; 
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count<=1;
                    mem[0]<=mult_0_out;
                end

                if(rdy_count == 1) begin
                    count<=5;
                    rdy_count<=0;
                    sent<=0;
                end
            end
            5: begin
                if(~sent) begin
                    mult_0_a <= mem[0]; 
                    mult_0_b <= P_y;
                    mult_0_req <= 1; 
                    sent <= 1;
                end

                if(mult_0_rdy == 1) begin
                    rdy_count<=1;
                    P_y_out<=mult_0_out;
                end

                if(rdy_count == 1) begin
                    count<=0;
                    rdy_count<=0;
                    sent<=0;
                    rdy<=1;
                end
            end
        endcase
    end

endmodule