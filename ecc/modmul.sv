module modmul#( // radix 4 montgomery multiplication, requires and b be in a*R form alreadt
    parameter WIDTH = 512
)(
    input  logic              clk,
    input  logic              rst,
    input  logic              req,
    input  logic [WIDTH-1:0]  a,
    input  logic [WIDTH-1:0]  b,
    input  logic [WIDTH-1:0]  mod,
    output logic [WIDTH-1:0]  result,
    output logic              rdy
);

    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        PRECOMP  = 2'b01, // Calculate 3b and 3mod
        COMPUTE  = 2'b10, // Main loop (2 bits per cycle)
        FINISH   = 2'b11  // Final reduction
    } state_t;

    state_t state;

    logic [WIDTH+2:0] S;
    logic [WIDTH-1:0] a_reg;
    logic [WIDTH+1:0] b3;
    logic [WIDTH+1:0] mod3; 
    logic [1:0] mod_inv;
    logic [$clog2(WIDTH/2):0] count;

    logic [1:0] a_i;
    logic [1:0] q_i;
    logic [WIDTH+1:0] term_b;
    logic [WIDTH+1:0] term_mod;

    assign a_i = a_reg[1:0];

    always_comb begin
        case (a_i)
            2'b01:   term_b = {2'b0, b};
            2'b10:   term_b = {2'b0, b}<<1;
            2'b11:   term_b = b3;
            default: term_b = '0;
        endcase
    end

    assign q_i = ( (S[1:0] + term_b[1:0]) * mod_inv ) & 2'b11;

    always_comb begin
        case (q_i)
            2'b01:   term_mod = {2'b0, mod};
            2'b10:   term_mod = {2'b0, mod}<<1;
            2'b11:   term_mod = mod3;
            default: term_mod = '0;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            rdy <= 1'b0;
            result <= '0;
            S <= '0;
        end else begin
            case (state)
                IDLE: begin
                    rdy <= 1'b0;
                    if (req) begin
                        a_reg <= a;
                        mod_inv <= (mod[1]) ? 2'b01 : 2'b11; 
                        state <= PRECOMP;
                    end
                end

                PRECOMP: begin
                    b3 <= ({2'b0, b} << 1) + {2'b0, b};
                    mod3 <= ({2'b0, mod} << 1) + {2'b0, mod};
                    S <= '0;
                    count <= WIDTH / 2;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    if (count > 0) begin
                        S <= (S + term_b + term_mod) >> 2;
                        a_reg <= a_reg >> 2;
                        count <= count - 1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    if (S >= mod) begin
                        result <= S - mod;
                    end else begin
                        result <= S[WIDTH-1:0];
                    end
                    rdy <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule