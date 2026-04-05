module modadd #( //module for addition, ctrl=1 subtraction, ctrl=0 addition
    parameter WIDTH = 512
)(
    input logic ctrl,
    input logic [WIDTH-1:0] a,
    input logic [WIDTH-1:0] b,
    input logic [WIDTH-1:0] mod,
    output logic [WIDTH-1:0] result
);
    logic [WIDTH:0] val_1;
    logic [WIDTH:0] val_2;

    always_comb begin
        if(ctrl) begin
            val_1 = {1'b0,a} - {1'b0,b};
            val_2 = val_1[WIDTH-1:0] + mod;
            result = (a>=b) ? val_1[WIDTH-1:0] : val_2[WIDTH-1:0];
        end else begin
            val_1 = {1'b0,a} + {1'b0,b};
            val_2 = val_1[WIDTH-1:0] - mod;
            result = (val_1>={1'b0,mod}) ? val_2[WIDTH-1:0] : val_1[WIDTH-1:0];
        end
    end

endmodule