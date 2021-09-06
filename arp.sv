module arp(input logic areset, clk_rx, clk_tx,
    input logic [7:0] data_rx_i,
    input logic data_valid_rx_i, data_ack_tx_i,
    input logic [47:0] my_mac_i, //static
    input logic [31:0] my_ipv4_i, //static
    output logic data_valid_tx_o,
    output logic [7:0] data_tx_o
    );

    logic [7:0] data_rx_r;
    logic data_valid_rx_r, data_ack_tx_r;
    logic data_valid_tx_ro;
    logic [7:0] data_tx_ro;

    //Register inputs.
    always_ff @(posedge clk_rx, posedge areset)
        if (areset) begin
            data_rx_r <= 0;
            data_valid_rx_r <= 0;
            data_ack_tx_r <= 0;            
        end
        else begin
            data_rx_r <= data_rx_i;
            data_valid_rx_r <= data_valid_rx_i;
            data_ack_tx_r <= data_ack_tx_i;
        end

    //ARP logic goes here

    //General sketch of architecture I am thinking of:

    // fsm for arp request receive and reading.
    typedef enum logic [3:0] {
        initialize,
        arp_mac_dest,
        mac_source_first,
        arp_ethertype,
        hwtype,
        prot_type,
        hw_len,
        prot_len,
        optype,
        sender_mac,
        sender_ip,
        target_mac,
        target_ip,
        data_captured
    } statetype;

    statetype state;

    logic [2:0] req_count_rx;
    logic [5:0][7:0] mac_of_sender_rx;
    logic [4:0][7:0] ip_of_sender_rx;
    logic [0:3][7:0] my_ipv4_subfields;
    logic [0:5][7:0] my_mac_subfields;
    assign my_ipv4_subfields = my_ipv4_i;
    assign my_mac_subfields = my_mac_i;

    logic data_ready_rx;


    always_ff @(posedge clk_rx, posedge areset)
        if (areset) begin
            state <= initialize;
            req_count_rx <= 0;
            mac_of_sender_rx <= 0;
            ip_of_sender_rx <= 0;
            data_ready_rx <= 0;
        end else begin
            case (state)
            // --------- STATE: INITIALIZE -----------------
                initialize : begin
                    if ((data_valid_rx_r) && (data_rx_r == 'hff)) begin
                        state <= arp_mac_dest;
                        req_count_rx <= 1;
                    end else begin 
                        state <= initialize;
                        req_count_rx <= 0;
                    end
                end
            // --------- STATE: ARP REQUEST CHECK -----------------
                arp_mac_dest : begin
                    if ((data_rx_r == 'hff) && (req_count_rx == 5)) begin 
                        state <= mac_source_first;
                        req_count_rx <= 0;
                    end else if ((data_rx_r == 'hff) && (req_count_rx < 5)) begin
                        req_count_rx <= req_count_rx + 1;
                    end else state <= initialize;
                end
            // --------- STATE: MAC SOURCE -----------------
                mac_source_first: begin
                    if (data_valid_rx_r && req_count_rx < 5) begin 
                        req_count_rx <= req_count_rx + 1;
                    end else if (data_valid_rx_r && req_count_rx == 5) begin
                        req_count_rx <= 0;
                        state <= arp_ethertype;
                    end else state <= initialize;
                end
            // --------- STATE: CHECK ETHERTYPE IS ARP (0806) -----------------
                arp_ethertype : begin
                    if (data_valid_rx_r && req_count_rx == 0 && data_rx_r == 'h08) 
                        req_count_rx <= req_count_rx + 1;
                    else if (data_valid_rx_r && req_count_rx == 1 && data_rx_r == 'h06) begin
                        req_count_rx <= 0;
                        state <= hwtype;
                    end else state <= initialize;
                end
            // --------- STATE: Check HW Type is 0x0001 (Ethernet) ----------
                hwtype : begin
                    if (data_valid_rx_r && req_count_rx == 0 && data_rx_r == 'h00) req_count_rx <= req_count_rx +1;
                    else if (data_valid_rx_r && req_count_rx == 1 && data_rx_r == 'h01) begin
                        req_count_rx <= 0;
                        state <= prot_type;
                    end else state <= initialize;
                end
            // --------- STATE: Check protocol is IPV4 (0x0800)
                prot_type : begin
                    if (data_valid_rx_r && req_count_rx == 0 && data_rx_r == 'h08 ) req_count_rx <= req_count_rx + 1;
                    else if (data_valid_rx_r && req_count_rx == 1 && data_rx_r == 'h00) begin
                        req_count_rx <= 0;
                        state <= hw_len;
                    end
                end
            // --------- STATE: Check hardware length is 0x06
            // TODO: We could make this flexible in hardware or parameterizable.
                hw_len : begin
                    if (data_valid_rx_r && data_rx_r == 'h06) state <= prot_len;
                    else state <= initialize;
                end
            // --------- STATE: Check protocol length is 0x04.
            // TODO: Make it flexible in HW or parameterizable in systemverilog.
                prot_len : begin
                    if (data_valid_rx_r && data_rx_r == 'h04) state <= optype;
                    else state <= initialize;
                end
            // --------- STATE: Check optype is a request (0x0001)
                optype : begin
                    if (data_valid_rx_r && data_rx_r == 'h00) req_count_rx <= 1;
                    else if (data_valid_rx_r && data_rx_r == 'h01 && req_count_rx == 1) begin
                        req_count_rx <= 0;
                        state <= sender_mac;
                    end
                    else state <= initialize;
                end
            // --------- STATE: Store sender mac.
                sender_mac : begin
                    if (data_valid_rx_r && req_count_rx < 5) begin
                        req_count_rx <= req_count_rx + 1;
                        mac_of_sender_rx[req_count_rx] <= data_rx_r;
                    end
                    else if (data_valid_rx_r && req_count_rx == 5) begin
                        mac_of_sender_rx[req_count_rx] <= data_rx_r;
                        req_count_rx <= 0;
                        state <= sender_ip;
                    end
                    else state <= initialize;
                end
            // --------- STATE: Store sender IP address.
                sender_ip : begin
                    if (data_valid_rx_r && req_count_rx < 3) begin
                        req_count_rx <= req_count_rx + 1;
                        ip_of_sender_rx[req_count_rx] <= data_rx_r;
                    end
                    else if (data_valid_rx_r && req_count_rx == 3) begin
                        ip_of_sender_rx[req_count_rx] <= data_rx_r;
                        req_count_rx <= 0;
                        state <= target_mac;
                    end else state <= initialize;
                end
            // --------- STATE: Read target mac. Ignore since sender doesn't know it.
                target_mac : begin
                    if (data_valid_rx_r && req_count_rx < 5) req_count_rx <= req_count_rx + 1;
                    else if (data_valid_rx_r && req_count_rx == 5) begin
                        req_count_rx <= 0;
                        state <= target_ip;
                    end else state <= initialize;
                end
            // ------- STATE: Read target IP. Make sure it's mine.
                target_ip : begin
                    if (data_valid_rx_r && 
                        req_count_rx < 3 && 
                        data_rx_r == my_ipv4_subfields[req_count_rx]) begin
                        req_count_rx <= req_count_rx + 1;
                    end    
                    else if (data_valid_rx_r && 
                            req_count_rx == 3 && 
                            data_rx_r == my_ipv4_subfields[req_count_rx]) begin
                        req_count_rx <= 0;
                        state <= data_captured;
                    end
                    else state <= initialize;
                end
            // ------- STATE: ARP formatted successfully. Assert clock domain crossing signal.
                data_captured : begin
                    if (req_count_rx < 1) begin
                        data_ready_rx <= 1;
                        req_count_rx <= req_count_rx + 1;
                    end
                    else begin
                        data_ready_rx <= 0;
                        state <= initialize;
                    end
                end
                default : state <= initialize;
            endcase
        end

    logic [5:0][7:0] mac_of_sender_cdc;
    logic [4:0][7:0] ip_of_sender_cdc;

    // Data source FF
    always_ff @(posedge clk_rx, posedge areset) begin
        if (areset) begin
            mac_of_sender_cdc <= 0;
            ip_of_sender_cdc <= 0;
        end
        else if (data_ready_rx) begin // Only update when the FSM asserts data_ready_rx.
            mac_of_sender_cdc <= mac_of_sender_rx;
            ip_of_sender_cdc <= ip_of_sender_rx;
        end
    end

    logic data_tx_ts1, data_tx_ts2;
    // Cross the domain with the data ready signal.
    always_ff @(posedge clk_tx, posedge areset) begin
        if (areset) begin
            data_tx_ts1 <= 0;
            data_tx_ts2 <= 0;
        end else begin
            data_tx_ts1 <= data_ready_rx;
            data_tx_ts2 <= data_tx_ts1;
        end
    end

    logic [5:0][7:0] mac_of_sender_tx;
    logic [4:0][7:0] ip_of_sender_tx;
    logic output_is_ready; // controlled by the output FSM. Otherwise, the stored data could update in the middle of a ARP response.
    //Bring data into TX with the CDC'd signal.
    always_ff @(posedge clk_tx, posedge areset) begin
        if (areset) begin
            mac_of_sender_tx <= 0;
            ip_of_sender_tx <= 0;
        end else if (data_tx_ts2 && output_is_ready) begin
            mac_of_sender_tx <= mac_of_sender_cdc;
            ip_of_sender_tx <= ip_of_sender_cdc;
        end
    end

    typedef enum logic [3:0] {
        initialize_tx,
        data_ack_rdy_tx,
        arp_resp_mac_tx,
        mac_source_first_tx,
        arp_ethertype_tx,
        hwtype_tx,
        prot_type_tx,
        hw_len_tx,
        prot_len_tx,
        optype_tx,
        sender_mac_tx,
        sender_ip_tx,
        target_mac_tx,
        target_ip_tx,
        data_captured_tx
    } statetype_tx;



    //Now output using another FSM. Same drill as before.
    //We can use the same statetype enum; the logic's just a little different.
    statetype_tx state_tx;
    logic [2:0] req_count_tx;

    always_ff @(posedge clk_tx, posedge areset) begin
        if (areset) begin
            state_tx <= initialize_tx;
            req_count_tx <= 0;
            data_valid_tx_o <= 0;
            output_is_ready <= 0;
        end else begin
            case(state_tx)
            // ------ STATE : initialize_tx
                initialize_tx : begin
                    if (data_tx_ts2 && output_is_ready) begin
                        state_tx <= data_ack_rdy_tx;
                        data_valid_tx_o <= 1;
                        data_tx_o <= mac_of_sender_tx[0];
                        output_is_ready <= 0;
                    end
                    else begin 
                        state_tx <= initialize_tx;
                        data_valid_tx_o <= 0;
                        output_is_ready <= 1;
                    end
                end
            // --------- STATE: data_ack_rdy_tx --- waiting for data ack pulse.
                data_ack_rdy_tx : begin
                    if (data_ack_tx_i) begin
                        req_count_tx <= 2;
                        data_tx_o <= mac_of_sender_tx[1];
                        state_tx <= arp_resp_mac_tx;
                    end else state_tx <= data_ack_rdy_tx;
                end
            // --------- STATE: arp_resp_mac_tx
                arp_resp_mac_tx : begin
                    if (req_count_tx == 5) begin
                        state_tx <= mac_source_first_tx;
                        data_tx_o <= mac_of_sender_tx[req_count_tx];
                        req_count_tx <= 0;
                    end else if (req_count_tx < 5 && req_count_tx >= 2) begin
                        data_tx_o <= mac_of_sender_tx[req_count_tx];
                        req_count_tx <= req_count_tx + 1;
                    end else state_tx <= initialize_tx;
                end
            // --------- STATE: mac_source_first_tx
                mac_source_first_tx : begin
                    if (req_count_tx == 5) begin
                        state_tx <= arp_ethertype_tx;
                        data_tx_o <= my_mac_subfields[req_count_tx];
                        req_count_tx <= 0;
                    end else if (req_count_tx < 5) begin
                        data_tx_o <= my_mac_subfields[req_count_tx];
                        req_count_tx <= req_count_tx + 1;
                    end else state_tx <= initialize_tx;
                end
            // --------- STATE: arp_ethertype_tx
                arp_ethertype_tx : begin
                    if (req_count_tx == 1) begin
                        state_tx <= hwtype_tx;
                        data_tx_o <= 'h06;
                        req_count_tx <= 0;
                    end else if (req_count_tx < 1) begin
                        req_count_tx <= req_count_tx + 1;
                        data_tx_o <= 'h08;
                    end else state_tx <= initialize_tx;
                end
            // --------- STATE: hwtype_tx
                hwtype_tx : begin
                    if (req_count_tx == 1) begin
                        state_tx <= prot_type_tx;
                        data_tx_o <= 'h01;
                        req_count_tx <= 0;
                    end else if (req_count_tx < 1) begin
                        req_count_tx <= req_count_tx + 1;
                        data_tx_o <= 'h00;
                    end else state_tx <= initialize_tx;
                end
            // -------- STATE: prot_type_tx
                prot_type_tx : begin
                    if (req_count_tx == 1) begin
                        state_tx <= hw_len_tx;
                        data_tx_o <= 'h00;
                        req_count_tx <= 0;
                    end else if (req_count_tx < 1) begin
                        req_count_tx <= req_count_tx + 1;
                        data_tx_o <= 'h08;
                    end else state_tx <= initialize_tx;
                end
            // -------- STATE: optype_tx
                hw_len_tx : begin
                    data_tx_o <= 'h06; // hard code for now.
                    state_tx <= prot_len_tx;
                end
            // -------- STATE: hardware address length
                prot_len_tx : begin
                    data_tx_o <= 'h04;
                    state_tx <= optype_tx;
                    req_count_tx <= 0;
                end
            // --------- STATE: optype_tx - 0x0002 for arp response.
                optype_tx : begin
                    if (req_count_tx == 1) begin
                        state_tx <= sender_mac_tx;
                        data_tx_o <= 'h02;
                        req_count_tx <= 0;
                    end else if (req_count_tx < 1) begin
                        data_tx_o <= 'h00;
                        req_count_tx <= req_count_tx + 1;
                    end else state_tx <= initialize_tx;
                end
            // -------- STATE: MAC of sender.
                sender_mac_tx : begin
                    if (req_count_tx == 5) begin
                        state_tx <= sender_ip_tx;
                        data_tx_o <= my_mac_subfields[req_count_tx];
                        req_count_tx <= 0;
                    end else if (req_count_tx < 5) begin
                        req_count_tx <= req_count_tx + 1;
                        data_tx_o <= my_mac_subfields[req_count_tx];
                    end else state_tx <= initialize_tx;
                end
            // -------- STATE: IPV4 Sender.
                sender_ip_tx : begin
                    if (req_count_tx == 3) begin
                        state_tx <= target_mac_tx;
                        data_tx_o <= my_ipv4_subfields[req_count_tx];
                        req_count_tx <= 0;
                    end else if (req_count_tx < 3) begin
                        data_tx_o <= my_ipv4_subfields[req_count_tx];
                        req_count_tx <= req_count_tx + 1;
                    end else state_tx <= initialize_tx;
                end
            // -------- STATE: Target MAC Address
                target_mac_tx : begin
                    if (req_count_tx == 5) begin
                        state_tx <= target_ip_tx;
                        data_tx_o <= mac_of_sender_tx[req_count_tx];
                        req_count_tx <= 0;
                    end else if (req_count_tx < 5) begin
                        data_tx_o <= mac_of_sender_tx[req_count_tx];
                        req_count_tx <= req_count_tx + 1;
                    end else state_tx <= initialize_tx;
                end
            // -------- STATE: Target IP Address.
                target_ip_tx : begin
                    if (req_count_tx == 3) begin
                        state_tx <= initialize_tx; // Ready for the next ARP out!
                        data_tx_o <= ip_of_sender_tx[req_count_tx];
                        req_count_tx <= 0;
                    end else if (req_count_tx < 3) begin
                        data_tx_o <= ip_of_sender_tx[req_count_tx];
                        req_count_tx <= req_count_tx + 1;
                    end else begin
                        state_tx <= initialize_tx;
                        data_valid_tx_o <= 0;
                    end
                end
            default : state_tx <= initialize_tx;
            endcase
        end
    end

endmodule