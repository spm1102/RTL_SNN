module  spi_snn_256x32 #(
    parameter INSTR_TRANS_WIDTH = 7, // Length of SPI transaction for instruction 
    parameter ADDR_TRANS_WIDTH = 16, // Length of SPI transaction for address
    parameter DATA_TRANS_WIDTH = 33, // Length of SPI transaction for data
    parameter INSTR_WIDTH = 7, // Length of instruction
    parameter ADDR_WIDTH = 9, // Length of address
    parameter DATA_WIDTH = 32,  // Length of data
    parameter DEBUG_DATA_WIDTH = 16, // Length of debug data
    parameter FIFO_DEPTH = 32 // Depth of the FIFO
)(
    input   clk_snn,
    input   rst_i,

    input   clk_spi,
    input   cs_n_i,
    input   mosi_i,
    output  miso_o,

    input   debug_en_i,
    output  debug_snn_data_out_high_o,
    output  debug_snn_data_out_low_o,
    output  debug_snn_data_in_high_o,
    output  debug_snn_data_in_low_o,
    output  debug_snn_wr_en_addr_o,
    output  debug_empty_o,
    output  debug_full_o,
    output  debug_error_o,
    output  debug_valid_o
);

(* keep = "true" *) wire [DATA_WIDTH-1:0] data_out_snn;
(* keep = "true" *) wire [DATA_WIDTH-1:0] data_in_snn;
(* keep = "true" *) wire [ADDR_WIDTH-1:0] addr_snn;

(* keep = "true" *) wire en_snn;
(* keep = "true" *) wire we_snn;

    spi_slave #(
        .INSTR_TRANS_WIDTH(INSTR_TRANS_WIDTH),
        .ADDR_TRANS_WIDTH(ADDR_TRANS_WIDTH), 
        .DATA_TRANS_WIDTH(DATA_TRANS_WIDTH), 
        .INSTR_WIDTH(INSTR_WIDTH), 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH) 
    ) 
    spi_slave_inst (
        .clk_snn(clk_snn),
        .rst_i(rst_i),

        .clk_spi(clk_spi),
        .cs_n_i(cs_n_i),
        .mosi_i(mosi_i),
        .miso_o(miso_o),
        .data_out_snn_i(data_out_snn),
        .data_in_snn_o(data_in_snn),
        .addr_o(addr_snn),

        .en_snn_o(en_snn),
        .we_snn_o(we_snn)
    );

    neuron_core_256x32 uut_256x32 (
        .clk_i(clk_snn),
        .rst_i(rst_i),
        .en_i(en_snn),
        .we_i(we_snn),
        .addr_i(addr_snn),
        .d_i(data_in_snn),
        .d_o(data_out_snn)
    );

//  Design for Debug

    wire [DEBUG_DATA_WIDTH-1:0] fifo_data_out_snn_high;
    wire full_fifo_data_out_snn_high;
    wire empty_fifo_data_out_snn_high;
    wire error_fifo_data_out_snn_high;
    wire valid_fifo_data_out_snn_high;

    wire [DEBUG_DATA_WIDTH-1:0] fifo_data_out_snn_low;
    wire full_fifo_data_out_snn_low;
    wire empty_fifo_data_out_snn_low;
    wire error_fifo_data_out_snn_low;
    wire valid_fifo_data_out_snn_low;

    wire [DEBUG_DATA_WIDTH-1:0] fifo_data_in_snn_high;
    wire full_fifo_data_in_snn_high;
    wire empty_fifo_data_in_snn_high;
    wire error_fifo_data_in_snn_high;
    wire valid_fifo_data_in_snn_high;

    wire [DEBUG_DATA_WIDTH-1:0] fifo_data_in_snn_low;
    wire full_fifo_data_in_snn_low;
    wire empty_fifo_data_in_snn_low;
    wire error_fifo_data_in_snn_low;
    wire valid_fifo_data_in_snn_low;

    wire fifo_write_en_snn;
    wire [ADDR_WIDTH-1:0] fifo_addr_snn;
    wire full_wr_en_addr_snn;
    wire empty_wr_en_addr_snn;
    wire error_wr_en_addr_snn;
    wire valid_wr_en_addr_snn;

    assign debug_full_o   = full_fifo_data_out_snn_high | full_fifo_data_out_snn_low |
                            full_fifo_data_in_snn_high | full_fifo_data_in_snn_low |
                            full_wr_en_addr_snn;
    assign debug_empty_o  = full_fifo_data_out_snn_high | full_fifo_data_out_snn_low |
                            full_fifo_data_in_snn_high | full_fifo_data_in_snn_low |
                            full_wr_en_addr_snn;    
    assign debug_error_o  = full_fifo_data_out_snn_high | full_fifo_data_out_snn_low |
                            full_fifo_data_in_snn_high | full_fifo_data_in_snn_low |
                            full_wr_en_addr_snn;
    assign debug_valid_o  = valid_fifo_data_out_snn_high & valid_fifo_data_out_snn_low &
                            valid_fifo_data_in_snn_high & valid_fifo_data_in_snn_low &
                            valid_wr_en_addr_snn;

    fifo_spi_snn #(
        .DATA_WIDTH(DEBUG_DATA_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .POINTER_WIDTH($clog2(FIFO_DEPTH)),
        .PADDING(0)
    )   fifo_inst_data_out_snn_high   
    (
        .clk(clk_snn),
        .rst_i(rst_i),
        .data_in(data_out_snn[DATA_WIDTH-1:DEBUG_DATA_WIDTH]),
        .write_en(debug_en_i && en_snn),
        .read_en(debug_en_i),
        .data_out_parallel(fifo_data_out_snn_high),
        .data_out_serial(debug_snn_data_out_high_o),
        .full(full_fifo_data_out_snn_high),
        .empty(empty_fifo_data_out_snn_high),
        .error(error_fifo_data_out_snn_high),
        .valid(valid_fifo_data_out_snn_high)
    );

    fifo_spi_snn #(
        .DATA_WIDTH(DEBUG_DATA_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .POINTER_WIDTH($clog2(FIFO_DEPTH)),
        .PADDING(0)
    )   fifo_inst_data_out_snn_low   
    (
        .clk(clk_snn),
        .rst_i(rst_i),
        .data_in(data_out_snn[DEBUG_DATA_WIDTH-1:0]),
        .write_en(debug_en_i && en_snn),
        .read_en(debug_en_i),
        .data_out_parallel(fifo_data_out_snn_low),
        .data_out_serial(debug_snn_data_out_low_o),
        .full(full_fifo_data_out_snn_low),
        .empty(empty_fifo_data_out_snn_low),
        .error(error_fifo_data_out_snn_low),
        .valid(valid_fifo_data_out_snn_low)
    );

    fifo_spi_snn #(
        .DATA_WIDTH(DEBUG_DATA_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .POINTER_WIDTH($clog2(FIFO_DEPTH)),
        .PADDING(0)
    )   fifo_inst_data_in_snn_high   
    (
        .clk(clk_snn),
        .rst_i(rst_i),
        .data_in(data_in_snn[DATA_WIDTH-1:DEBUG_DATA_WIDTH]),
        .write_en(debug_en_i && en_snn),
        .read_en(debug_en_i),
        .data_out_parallel(fifo_data_in_snn_high),
        .data_out_serial(debug_snn_data_in_high_o),
        .full(full_fifo_data_in_snn_high),
        .empty(empty_fifo_data_in_snn_high),
        .error(error_fifo_data_in_snn_high),
        .valid(valid_fifo_data_in_snn_high)
    );

    fifo_spi_snn #(
        .DATA_WIDTH(DEBUG_DATA_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .POINTER_WIDTH($clog2(FIFO_DEPTH)),
        .PADDING(0)
    )   fifo_inst_data_in_snn_low   
    (
        .clk(clk_snn),
        .rst_i(rst_i),
        .data_in(data_in_snn[DEBUG_DATA_WIDTH-1:0]),
        .write_en(debug_en_i && en_snn),
        .read_en(debug_en_i),
        .data_out_parallel(fifo_data_in_snn_low),
        .data_out_serial(debug_snn_data_in_low_o),
        .full(full_fifo_data_in_snn_low),
        .empty(empty_fifo_data_in_snn_low),
        .error(error_fifo_data_in_snn_low),
        .valid(valid_fifo_data_in_snn_low)
    );


    fifo_spi_snn #(
        .DATA_WIDTH((ADDR_WIDTH + 1)), // 9 bit address + 1 bit write enable
        .DEPTH(FIFO_DEPTH),
        .POINTER_WIDTH($clog2(FIFO_DEPTH)),
        .PADDING(DEBUG_DATA_WIDTH-(ADDR_WIDTH + 1)) // Padding để đồng bộ 16 bit với dữ liệu mà ko cần lưu fifo có width lớn
    )   fifo_inst_wr_en_addr_snn
    (
        .clk(clk_snn),
        .rst_i(rst_i),
        .data_in({we_snn, addr_snn}),
        .write_en(debug_en_i && en_snn),
        .read_en(debug_en_i),
        .data_out_parallel({fifo_write_en_snn, fifo_addr_snn}),
        .data_out_serial(debug_snn_wr_en_addr_o),
        .full (full_wr_en_addr_snn),
        .empty(empty_wr_en_addr_snn),
        .error(error_wr_en_addr_snn),
        .valid(valid_wr_en_addr_snn)
    );


endmodule