module spi_slave #(
    parameter INSTR_TRANS_WIDTH = 7, // Length of SPI transaction for instruction 
    parameter ADDR_TRANS_WIDTH = 16, // Length of SPI transaction for address
    parameter DATA_TRANS_WIDTH = 33, // Length of SPI transaction for data
    parameter INSTR_WIDTH = 7, // Length of instruction
    parameter ADDR_WIDTH = 9, // Length of address
    parameter DATA_WIDTH = 32  // Length of data
)(
    input clk_snn,
    input rst_i,

    input clk_spi,
    input cs_n_i,
    input mosi_i,

    output reg miso_o,
    input [DATA_WIDTH-1:0] data_out_snn_i,

    output reg [DATA_WIDTH-1:0] data_in_snn_o,
    output reg [ADDR_WIDTH-1:0] addr_o,

    output reg en_snn_o,
    output reg we_snn_o
);

    // State Encoding
    parameter STATE_IDLE        = 3'd0;
    parameter STATE_GET_INSTR   = 3'd1;
    parameter STATE_GET_ADDR    = 3'd2;
    parameter STATE_WRITE_DATA  = 3'd3;
    parameter STATE_READ_DATA   = 3'd4;
    parameter STATE_WAIT        = 3'd5;
    parameter STATE_INVALID     = 3'd6;

    // Address 
    parameter SPIKE_OUT_BASE0 = 384;
    parameter DONE_PIC_ADDR = 448;

    // Instruction command

    parameter INSTR_WRITE = 7'b0000010; // Write command // 2
    parameter INSTR_READ  = 7'b0000011; // Read command  // 3
    // Internal signals
    reg [2:0] state;
    // reg [2:0] next_state;
    reg [INSTR_WIDTH-1:0] instr_reg;// Instruction register (7 bits)
    reg [ADDR_WIDTH-1:0] addr_reg;  // Address register
    reg [DATA_WIDTH-1:0] data_reg;  // Data buffer
    reg [$clog2(INSTR_WIDTH+ADDR_WIDTH+DATA_WIDTH):0] spi_sclk_edge_counter;

    reg spi_done_trans;
    wire spi_done_trans_n;
    assign spi_done_trans_n = ~spi_done_trans;

    // SPI slave get instruction, address and data
    always @(posedge clk_spi or posedge rst_i) begin
        if(rst_i) begin
            state <= STATE_IDLE;
            spi_sclk_edge_counter <= 0;
            spi_done_trans <= 0;
            
            instr_reg <= 0;
            addr_reg <= 0;
            data_reg <= 0;

        end else begin
            // spi_done_trans <= 0; // Reset done transaction flag
            if(!cs_n_i) begin
                case(state)
                STATE_IDLE: begin
                    
                    state <= STATE_GET_INSTR;
                    spi_sclk_edge_counter <= INSTR_TRANS_WIDTH-1; 
                    
                    spi_done_trans <= 0;
                    
                    instr_reg <= 0;
                    addr_reg <= 0;
                    data_reg <= 0;
                end 
                STATE_GET_INSTR: begin
                        spi_done_trans <= 0;
                    if(spi_sclk_edge_counter == 0) begin
                        state <= STATE_GET_ADDR;
                        spi_sclk_edge_counter <= ADDR_TRANS_WIDTH-1;
                        addr_reg <= {addr_reg[ADDR_WIDTH-2:0], mosi_i};
                    end else begin
                        state <= STATE_GET_INSTR;
                        spi_sclk_edge_counter <= spi_sclk_edge_counter - 1;
                        instr_reg <= {instr_reg[INSTR_WIDTH-2:0], mosi_i};
                    end
                end
                STATE_GET_ADDR: begin
                    if(spi_sclk_edge_counter == 0) begin
                        if(instr_reg == INSTR_WRITE) begin
                            state <= STATE_WRITE_DATA;
                            spi_sclk_edge_counter <= DATA_TRANS_WIDTH-1;
                            spi_done_trans <= 0;
                            data_reg <= {data_reg[DATA_WIDTH-2:0], mosi_i}; // Đọc bit 1 của data
                        end else if(instr_reg == INSTR_READ) begin
                            if(addr_reg != SPIKE_OUT_BASE0) begin // Nếu chưa phải là đọc ra spike out thì skip phần gửi data từ data_out_snn nhưng vẫn phải bật spi_done trans lên cho các packet ghi vào
                                state <= STATE_IDLE;
                                spi_sclk_edge_counter <= 0;
                                spi_done_trans <= 1;
                            end else begin
                                state <= STATE_READ_DATA;
                                spi_sclk_edge_counter <= DATA_TRANS_WIDTH-1;
                                spi_done_trans <= 1;
                            end
                        end else begin
                            state <= STATE_INVALID;
                        end
                    end else begin
                        state <= STATE_GET_ADDR;
                        spi_sclk_edge_counter <= spi_sclk_edge_counter - 1;
                        addr_reg <= {addr_reg[ADDR_WIDTH-2:0], mosi_i};
                    end
                end
                STATE_WRITE_DATA: begin
                    if(spi_sclk_edge_counter == 2) begin
                        state <= STATE_WRITE_DATA;
                        spi_sclk_edge_counter <= 1;
                        spi_done_trans <= 1;
                        data_reg <= {data_reg[DATA_WIDTH-2:0], mosi_i};
                    end else if(spi_sclk_edge_counter == 1) begin
                        state <= STATE_IDLE;
                        spi_done_trans <= 0;
                        spi_sclk_edge_counter <= 0;
                    end else begin
                        state <= STATE_WRITE_DATA;
                        spi_sclk_edge_counter <= spi_sclk_edge_counter - 1;
                        spi_done_trans <= 0;
                        data_reg <= {data_reg[DATA_WIDTH-2:0], mosi_i};
                    end
                end
                STATE_READ_DATA: begin
                    if(spi_sclk_edge_counter == 1) begin
                        spi_done_trans <= 0;
                        state <= STATE_IDLE;
                        spi_sclk_edge_counter <= 0;
                    end else begin
                        spi_done_trans <= 0;
                        state <= STATE_READ_DATA;
                        spi_sclk_edge_counter <= spi_sclk_edge_counter - 1; 
                    end
                end
                STATE_INVALID: begin
                    state <= STATE_IDLE;
                    spi_sclk_edge_counter <= 0;
                end 
                default: begin
                    state <= STATE_IDLE;
                end 
                endcase
            end else begin
                state <= STATE_IDLE;
                spi_sclk_edge_counter <= 0;
                spi_done_trans <= 0;

                instr_reg <= instr_reg;
                addr_reg <= addr_reg;
                data_reg <= data_reg;
            end
        end
    end

    // always @(negedge clk_spi or posedge rst_i) begin // MISO
    //     if(rst_i) begin
    //         miso_o <= 1'hz; // High impedance state
    //     end else begin
    //         case (state)
    //             STATE_GET_ADDR: begin
    //                 if((spi_sclk_edge_counter == 0) && (instr_reg == INSTR_READ) && (addr_reg == SPIKE_OUT_BASE0)) begin
    //                     miso_o <= data_out_snn_i[DATA_WIDTH-1]; // Send the most significant bit of address
    //                 end else begin
    //                     miso_o <= 1'hz; // High impedance state for other bits
    //                 end
    //             end
    //             STATE_READ_DATA: begin
    //                 if(spi_sclk_edge_counter == 1) begin
    //                     miso_o <= 1'hz; 
    //                 end else begin
    //                     miso_o <= data_out_snn_i[spi_sclk_edge_counter-2]; // Bắt đầu từ 32, nên phải trừ 2
    //                 end
    //             end
    //             default: begin
    //                 miso_o <= 1'hz; // High impedance state for other states
    //             end
    //         endcase
    //     end
    // end

    always @(posedge clk_spi or posedge rst_i) begin // MISO
        if(rst_i) begin
            miso_o <= 1'hz; // High impedance state
        end else begin
            case (state)
                STATE_GET_ADDR: begin
                    // if((spi_sclk_edge_counter == 0) && (instr_reg == INSTR_READ) && (addr_reg == SPIKE_OUT_BASE0)) begin
                    if((instr_reg == INSTR_READ)) begin
                        if(spi_sclk_edge_counter == 1) begin
                        miso_o <= data_out_snn_i[DATA_WIDTH-1]; // Send the most significant bit of result
                        end else if(spi_sclk_edge_counter == 0) begin
                            miso_o <= data_out_snn_i[DATA_WIDTH-2]; // Send the second most significant bit of result
                        end else begin
                            miso_o <= 1'hz; 
                        end
                    end else begin
                        miso_o <= 1'hz; // High impedance state for other bits
                    end
                end
                STATE_READ_DATA: begin
                    if(spi_sclk_edge_counter == 1) begin
                        miso_o <= 1'hz; 
                    end else begin
                        miso_o <= data_out_snn_i[spi_sclk_edge_counter-3]; // Bắt đầu từ 32, nên phải trừ 3
                    end
                end
                default: begin
                    miso_o <= 1'hz; // High impedance state for other states
                end
            endcase
        end
    end

    
    // Drive SNN signals

    reg en_snn_meta_syn;
    reg we_snn_meta_syn;

    always @(posedge clk_snn or posedge spi_done_trans) begin // cần sửa
        if(spi_done_trans) begin
            en_snn_meta_syn <= 1;
        end else begin
            en_snn_meta_syn <= 0;
        end
    end   

    wire spi_done_trans_write;
    assign spi_done_trans_write = (spi_done_trans && (instr_reg == INSTR_WRITE));

    always @(posedge clk_snn or posedge spi_done_trans_write) begin
        if(spi_done_trans_write) begin
            we_snn_meta_syn <= 1;
        end else begin
            we_snn_meta_syn <= 0; // Reset write enable signal
        end
    end

    // always @(posedge clk_snn or posedge spi_done_trans) begin
    //     if(spi_done_trans) begin
    //         we_snn_meta_syn <= (instr_reg == INSTR_WRITE) ? 1 : 0;
    //     end else begin
    //         we_snn_meta_syn <= 0;
    //     end
    // end 

    always @(posedge spi_done_trans) begin
        addr_o <= addr_reg;
        data_in_snn_o <= data_reg;
    end

    // always @(posedge clk_snn or posedge spi_done_trans) begin
    //     if(spi_done_trans) begin
    //         en_snn_o <= en_snn_o ? 0: en_snn_meta_syn;
    //         we_snn_o <= we_snn_o ? 0: we_snn_meta_syn;
    //     end else begin
    //         en_snn_o <= en_snn_o ? 0: en_snn_meta_syn;
    //         we_snn_o <= we_snn_o ? 0: we_snn_meta_syn;
    //     end
    // end 

    always @(posedge clk_snn or posedge rst_i) begin
        if(rst_i) begin
            en_snn_o <= 0;
            we_snn_o <= 0;
        end else begin
            en_snn_o <= en_snn_o ? 0: en_snn_meta_syn;
            we_snn_o <= we_snn_o ? 0: we_snn_meta_syn;
        end
    end 

endmodule
