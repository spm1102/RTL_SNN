module fifo_spi_snn #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH = 32,
    parameter POINTER_WIDTH = $clog2(DEPTH),
    parameter PADDING = 0
)(
    input clk,
    input rst_i,
    input [DATA_WIDTH-1:0] data_in,
    input write_en, // write_en = debug_en && en_snn
    input read_en,  // read_en  = debug_en 
    output reg [DATA_WIDTH-1:0] data_out_parallel,
    output reg data_out_serial,
    output reg full,
    output reg empty,
    output reg error, // Khi full và đang truyền dở lại ghi đè 
    output valid // xác định khi nào thì data serial có nghĩa
);


integer i;

reg [$clog2(DEPTH)-1:0] write_ptr;
reg [$clog2(DEPTH)-1:0] read_ptr;
reg [$clog2(DEPTH):0] ptr_gap;

reg [$clog2(DATA_WIDTH)-1:0] read_serial_count;
reg read_serial_ready;

reg [DATA_WIDTH-1:0] fifo_mem [0:DEPTH-1];

assign full = (ptr_gap == DEPTH);
assign empty = (ptr_gap == 0);

always @(posedge clk or posedge rst_i) begin
    if (rst_i) begin
        write_ptr <= 0;
        read_ptr <= 0;
        ptr_gap <= 0;
        data_out_parallel <= 0;
        error <= 0;
    end else begin
        // Write operation only
        if (write_en && (!read_en)) begin // Chỉ ghi thì cứ tăng gap và con trỏ ghi lên
            if(!full) begin
                fifo_mem[write_ptr] <= data_in;
                write_ptr <= (write_ptr + 1);
                ptr_gap <= ptr_gap + 1;
            end else if (full) begin
                fifo_mem[write_ptr] <= data_in; // Overwrite
                write_ptr <= (write_ptr + 1);
                read_ptr <= (read_ptr + 1); // Data cũ nhất trong fifo
                ptr_gap <= ptr_gap; // full 
            end
            error <= 0;
        end else if ((!write_en) && read_en && (!empty)) begin // Chỉ đọc thì cứ lấy data ra và giảm gap
                data_out_parallel <= fifo_mem[read_ptr];
                if(read_serial_count == 0) begin
                    read_ptr <= (read_ptr + 1);
                    ptr_gap <= ptr_gap - 1;
                end else begin // Đợi truyền serial
                    read_ptr <= read_ptr; 
                    ptr_gap <= ptr_gap; 
                end
            error <= 0;
        end else if (write_en && read_en) begin // Ghi và đọc đồng thời
            if(empty) begin // Data đọc ra từ trường hợp này là ko có, do empty thì ko đọc ra
                fifo_mem[write_ptr] <= data_in;
                write_ptr <= (write_ptr + 1);
                ptr_gap <= (ptr_gap + 1);
                data_out_parallel <= data_in; 
                read_ptr <= read_ptr; // Giữ nguyên đợi khi có data mới cho đọc ra
                error <= 0;
            end else begin
                if(read_serial_count == 0) begin // Truyền tới bit cuối, thì lúc đó có thể tăng read_ptr, write_ptr, giữ nguyên gap mà ko có lỗi
                    data_out_parallel <= data_out_parallel;
                    fifo_mem[write_ptr] <= data_in; // Overwrite
                    read_ptr <= (read_ptr + 1);
                    write_ptr <= (write_ptr + 1);
                    ptr_gap <= ptr_gap;
                end else begin
                    if(full) begin // Nếu full mà vẫn đang truyền dở thì bị ghi đè -> lỗi, lúc này tăng write_ptr, read_ptr, giữ nguyên gap và error sẽ cho người dùng biết là sau error là truyền data mới
                        fifo_mem[write_ptr] <= data_in; // Overwrite
                        read_ptr <= (read_ptr + 1);
                        write_ptr <= (write_ptr + 1);
                        ptr_gap <= ptr_gap;
                        error <= 1; // Error: FIFO full, data lost
                    end else begin // Nếu không full thì ghi data mới vào fifo_mem[write_ptr] và truyền data ra từ fifo_mem[read_ptr], tăng write_ptr, giữ nguyên read_ptr, gap tăng lên 1
                        fifo_mem[write_ptr] <= data_in;
                        write_ptr <= (write_ptr + 1);
                        ptr_gap <= ptr_gap + 1;
                        data_out_parallel <= fifo_mem[read_ptr];
                        read_ptr <= read_ptr; // Giữ nguyên đợi truyền xong
                        error <= 0;
                    end
                end
            end
        end else begin // giữ nguyên
            write_ptr <= write_ptr; 
            read_ptr <= read_ptr;
            ptr_gap <= ptr_gap; 
            data_out_parallel <= data_out_parallel;
        end
    end

end

generate
    if(PADDING > 0) begin
        always @(posedge clk or posedge rst_i) begin /// Cứ có read en thì bắt đầu lấy data từ fifo_mem[read_ptr] và truyền serial ra, còn việc có bị lỗi hay không thì sẽ quản lý chung ở trên cùng với các tín hiệu write_en, read_en, full, empty
            if(rst_i) begin
                data_out_serial <= 0;
                read_serial_count <= DATA_WIDTH+PADDING-1;
                read_serial_ready <= 1;
            end else begin
                if (read_en && (!empty) && read_serial_ready) begin
                    data_out_serial <= 0; // Padding 0 trước 
                    read_serial_count <= read_serial_count - 1;
                    read_serial_ready <= 0;
                end else if (!read_serial_ready) begin // đang truyền dở thì cứ truyền nốt, bất kể có bật read_en ko
                    if (read_serial_count > (DATA_WIDTH-1)) begin // vẫn đang padding
                        data_out_serial <= 0;
                        read_serial_count <= read_serial_count - 1;
                        read_serial_ready <= 0;
                    end else if (read_serial_count > 0) begin // Bắt đầu truyền
                        data_out_serial <= fifo_mem[read_ptr][read_serial_count];
                        read_serial_count <= read_serial_count - 1;
                        read_serial_ready <= 0;
                    end else begin
                        data_out_serial <= fifo_mem[read_ptr][0];
                        read_serial_count <= (DATA_WIDTH+PADDING-1); // Reset for next read
                        read_serial_ready <= 1; // Ready for next read
                    end
                end else begin
                    data_out_serial <= 0; // Default value when not reading
                    read_serial_count <= (DATA_WIDTH+PADDING-1); // Reset for next read
                    read_serial_ready <= 1; // Ready for next read
                end        
            end
        end
    end else begin
        always @(posedge clk or posedge rst_i) begin /// Cứ có read en thì bắt đầu lấy data từ fifo_mem[read_ptr] và truyền serial ra, còn việc có bị lỗi hay không thì sẽ quản lý chung ở trên cùng với các tín hiệu write_en, read_en, full, empty
            if(rst_i) begin
                data_out_serial <= 0;
                read_serial_count <= DATA_WIDTH-1;
                read_serial_ready <= 1;
            end else begin
                if (read_en && (!empty) && read_serial_ready) begin
                    data_out_serial <= fifo_mem[read_ptr][DATA_WIDTH-1];
                    read_serial_count <= read_serial_count - 1;
                    read_serial_ready <= 0;
                end else if (!read_serial_ready) begin // đang truyền dở thì cứ truyền nốt, bất kể có bật read_en ko
                    if (read_serial_count > 0) begin
                        data_out_serial <= fifo_mem[read_ptr][read_serial_count];
                        read_serial_count <= read_serial_count - 1;
                        read_serial_ready <= 0;
                    end else begin
                        data_out_serial <= fifo_mem[read_ptr][0];
                        read_serial_count <= (DATA_WIDTH-1); // Reset for next read
                        read_serial_ready <= 1; // Ready for next read
                    end
                end else begin
                    data_out_serial <= 0; // Default value when not reading
                    read_serial_count <= (DATA_WIDTH-1); // Reset for next read
                    read_serial_ready <= 1; // Ready for next read
                end        
            end
        end
    end
endgenerate

assign valid = (~read_serial_ready) | (~(|read_serial_count)); // Khi đang truyền thì valid - 1, đang truyền bit cuối thì valid vẫn bằng 1 

endmodule