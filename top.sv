`timescale 1ns/1ns

module top;
    logic areset;
    logic clk_rx; 
    logic clk_tx;

    import clock::*;

    initial begin
        tbif.data_rx_i = 0;
        tbif.data_valid_rx_i = 0;
        tbif.data_ack_tx_i = 0;
        tbif.my_mac_i = 'h000223010203; // Reversed in groups of 8 bits.
        tbif.my_ipv4_i = 'hc0a80102; // Reversed in groups of 8 bits.
        tbif.data_valid_tx_o = 0;
        tbif.data_tx_o = 0;
        #(3 * period);
        areset = 0; clk_rx = 0; clk_tx = 0;
        #period areset = 1;
        #(2 * period);
        #period clk_rx = 1; clk_tx = 1;
        #period areset = 0; clk_rx = 0; clk_tx = 0;
        forever begin
            // TODO : skew these clocks relative to each other.
            #period clk_rx = ~clk_rx; clk_tx = ~clk_tx; 
        end
    end

    arp_if tbif(.clk_rx(clk_rx), .clk_tx(clk_tx), .areset(areset));

    arp dut(
        .areset(areset),
        .clk_rx(clk_rx),
        .clk_tx(clk_tx),
        .data_rx_i(tbif.data_rx_i),
        .data_valid_rx_i(tbif.data_valid_rx_i),
        .data_ack_tx_i(tbif.data_ack_tx_i),
        .my_mac_i(tbif.my_mac_i),
        .my_ipv4_i(tbif.my_ipv4_i),
        .data_valid_tx_o(tbif.data_valid_tx_o),
        .data_tx_o(tbif.data_tx_o)
    );

    arp_tester tester(.arp_if(tbif.tb), .clk_tx(clk_tx), .clk_rx(clk_rx));
endmodule : top

program automatic arp_tester(
    arp_if.tb arp_if,
    input logic clk_tx, clk_rx
); 
    // Just create an environment and run it.
    environment env;
    initial begin
        import clock::*;
        #(15 * period);
        env = new(arp_if);
        env.build();
        env.run();
        env.wrapup();
        $finish;
    end
endprogram