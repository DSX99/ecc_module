module inverse #( 
    parameter WIDTH = 512 
)( 
    input  logic              clk, 
    input  logic              rst, 
    input  logic              req, 
    input  logic [WIDTH-1:0]  inv_in, 
    input  logic [WIDTH-1:0]  mod, 
    output logic [WIDTH-1:0]  inv_out, 
    output logic              rdy 
); 

    logic [WIDTH-1:0] u, v, x, y; 
    
    typedef enum logic [1:0] {IDLE, COMPUTE, DONE} state_t; 
    state_t state; 

    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            state <= IDLE; 
            rdy   <= 1'b0; 
            inv_out   <= 1'b0;
            u <= 1'b0; v <= 1'b0; x <= 1'b0; y <= 1'b0;
        end else begin 
            case (state) 
                IDLE: begin 
                    rdy <= 1'b0; 
                    if (req) begin 
                        u <= inv_in; 
                        v <= mod; 
                        x <= 1; 
                        y <= 0; 
                        state <= COMPUTE; 
                    end 
                end 

                COMPUTE: begin 
                    if (u == 1) begin 
                        inv_out   <= x; 
                        state <= DONE; 
                    end else if (v == 1) begin 
                        inv_out   <= y; 
                        state <= DONE; 
                    end else begin 
                        if (!u[0]) begin 
                            u <= u >> 1; 
                            // Use concatenation to prevent overflow truncation before shift
                            if (x[0]) x <= ( {1'b0, x} + {1'b0, mod} ) >> 1; 
                            else      x <= x >> 1; 
                        end else if (!v[0]) begin 
                            v <= v >> 1; 
                            if (y[0]) y <= ( {1'b0, y} + {1'b0, mod} ) >> 1; 
                            else      y <= y >> 1; 
                        end else if (u >= v) begin 
                            u <= u - v; 
                            if (x < y) x <= (x + mod) - y; 
                            else       x <= x - y; 
                        end else begin 
                            v <= v - u; 
                            if (y < x) y <= (y + mod) - x; 
                            else       y <= y - x; 
                        end 
                    end 
                end 

                DONE: begin 
                    rdy <= 1'b1; 
                    if (!req) state <= IDLE; 
                end
                
                default: state <= IDLE;
            endcase 
        end 
    end 
endmodule