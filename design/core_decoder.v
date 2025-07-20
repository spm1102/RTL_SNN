// Memory map
// slice0:          0       -   511 // 0 0000 0000 - 1 1111 1111
// choose_weight:   464     -   479 // 1 1101 0000 - 1 1101 1111
// done_pic:        448             // 1 1100 0000

module core_decoder # (
    parameter NUM_OF_SLICE = 1,
    parameter DONE_PIC_ADDR = 448 // 1 1100 0000
)
(
    input [8:0] addr_i,
    input we_i,
    input en_i,
    output reg [NUM_OF_SLICE-1:0] slice_o,
    output reg choose_weight_o,
    output reg done_pic_o,
    output reg send_spike_o
);

    // always @(addr_i) begin
    always @(*) begin
        // Default outputs to 0
        slice_o = 0;
        send_spike_o = 0;
        choose_weight_o = 0;
        done_pic_o = 0;

        if (en_i) begin

            // write to choose_weight_o and done_pic_o
            if (addr_i[8] && addr_i[7] && addr_i[6]) begin
                if (!(addr_i[5]|addr_i[4]|addr_i[3]|addr_i[2]|addr_i[1]|addr_i[0])) begin // Các bit địa chỉ sau bằng 0 cả
                    done_pic_o = 1;
                    slice_o = {NUM_OF_SLICE{1'b1}};
                end
                else choose_weight_o = addr_i[4];
            end

            else begin
                if (we_i || addr_i[8]) begin
                    slice_o[0] = 1;
                end
                else begin 
                    slice_o = {NUM_OF_SLICE{1'b1}};
                    send_spike_o = 1;
                end
            end
        end

    end

endmodule
