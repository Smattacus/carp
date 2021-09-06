typedef class monitor;

class monitor_callbacks;

    virtual task pre_tx(input monitor mon, input arp_response resp);
    endtask : pre_tx

    virtual task post_tx(input monitor mon, input arp_response resp);
    endtask : post_tx

endclass : monitor_callbacks

class monitor;

    aif_tp atp;
    int num_recvd;
    monitor_callbacks cbsq[$];

    extern function new(input aif_tp atp);
    extern task run();
    extern task receive(arp_response response);

endclass : monitor

function monitor::new(input aif_tp atp);

    this.atp = atp;

endfunction : new

task monitor::run();

    arp_response result;
    $display("Monitor is running!");
    forever begin
        result = new();
        receive(result);
        foreach (cbsq[i]) begin
            cbsq[i].post_tx(this, result);
        end
        this.num_recvd++;
        if (this.num_recvd >= `NUM_TEST_VECS) break;
    end

endtask : run

task monitor::receive(arp_response response);

    int data_ack_tx_delay = 7; // we can randomize this in the future.
    bit response_started = 0;
    bit response_acked = 0;
    int response_clocks = 0;
    int response_octet = 0;
    int n_response_octets = 42;
    int total_clocks = 0;
    int max_clocks = 150 + data_ack_tx_delay;

    forever begin
        @atp.cb_tx
        total_clocks++;
        if (response_started && response_acked && atp.cb_tx.data_valid_tx_o) begin
            atp.cb_tx.data_ack_tx_i <= 0;
            response.data_tx[response_octet] = atp.cb_tx.data_tx_o;
            response_octet++;
            if (response_octet > (n_response_octets)) begin
                $display("ERROR: received too many response octets!");
                $fatal;
                $finish;
            end
        end else if (atp.cb_tx.data_valid_tx_o == 1 && !response_started) begin
            response_started = 1;
            response_clocks++;
        end else if (atp.cb_tx.data_valid_tx_o == 1 && response_started && response_clocks == data_ack_tx_delay) begin
            response_acked = 1;
            atp.cb_tx.data_ack_tx_i <= 1;
        end else if (atp.cb_tx.data_valid_tx_o == 1 && response_started) response_clocks++;
        else if (response_octet == n_response_octets && !atp.cb_tx.data_valid_tx_o) break;
        if (total_clocks > max_clocks) begin
            $display("Error: Went too many clocks in monitor receiver!");
            $fatal;
            $finish;
        end
    end

response.display("Received: ");

endtask : receive