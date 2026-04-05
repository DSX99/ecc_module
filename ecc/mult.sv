module mod_mult #(
    parameter WIDTH = 512
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             req,
    input  logic [WIDTH-1:0] mult_a,
    input  logic [WIDTH-1:0] mult_b,
    input  logic [WIDTH-1:0] mod,
    
    output logic [WIDTH-1:0] mult_out,
    output logic             rdy
);

    typedef enum logic [1:0] {
        IDLE, 
        CALC, 
        DONE_ST
    } state_t;
    
    state_t state;

    logic [WIDTH-1:0]       a_reg, b_reg, m_reg;
    logic [$clog2(WIDTH)-1:0] count;
    logic [WIDTH+1:0]       p_reg; 
    logic [WIDTH+1:0]       next_p, trial_val;

    always_comb begin
        trial_val = (p_reg << 1) + (a_reg[WIDTH-1] ? b_reg : 0);

        if (trial_val >= {m_reg, 1'b0}) begin
            next_p = trial_val - {m_reg, 1'b0};
        end else if (trial_val >= m_reg) begin
            next_p = trial_val - m_reg;
        end else begin
            next_p = trial_val;
        end
    end


    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state  <= IDLE;
            p_reg  <= '0;
            a_reg  <= '0;
            b_reg  <= '0;
            m_reg  <= '0;
            count  <= '0;
            rdy   <= 1'b0;
            mult_out <= '0;
        end else begin
            case (state)
                IDLE: begin
                    rdy <= 1'b0;
                    if (req) begin
                        a_reg <= mult_a;
                        b_reg <= mult_b;
                        m_reg <= mod;
                        p_reg <= '0;
                        count <= WIDTH - 1;
                        state <= CALC;
                    end
                end

                CALC: begin
                    p_reg <= next_p;
                    a_reg <= {a_reg[WIDTH-2:0], 1'b0};
                    
                    if (count == 0) begin
                        state <= DONE_ST;
                    end else begin
                        count <= count - 1;
                    end
                end

                DONE_ST: begin
                    mult_out <= p_reg[WIDTH-1:0];
                    rdy   <= 1'b1;
                    state  <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule