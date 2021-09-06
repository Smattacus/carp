interface arp_if
    (
        input logic clk_rx, clk_tx, areset
    );

    logic [7:0] data_rx_i;
    logic data_valid_rx_i; 
    logic data_ack_tx_i;
    logic [47:0] my_mac_i; //static
    logic [31:0] my_ipv4_i; //static
    logic data_valid_tx_o;
    logic [7:0] data_tx_o;

    logic tb_areset_i;
    assign tb_areset_i = areset;

    // Clocking blocks for the test bench.
    clocking cb_rx @(posedge clk_rx);
        output data_rx_i, data_valid_rx_i;
    endclocking

    clocking cb_tx @(posedge clk_tx);
        input data_valid_tx_o, data_tx_o;
        output data_ack_tx_i;
    endclocking

    modport tb (clocking cb_rx, 
                clocking cb_tx, 
                output tb_areset_i, 
                input my_mac_i, 
                input my_ipv4_i);

    modport dut (input data_rx_i, 
        data_valid_rx_i, 
        data_ack_tx_i, 
        my_mac_i, 
        my_ipv4_i,
        output data_valid_tx_o, data_tx_o);

endinterface : arp_if


typedef virtual arp_if.tb aif_tp;