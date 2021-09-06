
class validator;

    arp_request sent_reqs[$];
    int num_sent; // num of vectors sent / expected.
    int num_rec;
    bit [47:0] my_mac;
    bit [31:0] my_ipv4;
    arp_response rec_resp[$]; // received from DUT
    arp_response expected_resp[$]; // calculated by validator from req.

    extern function new(bit [47:0] my_mac, bit [31:0] my_ipv4);
    extern virtual function void run();
    extern virtual function void wrapup();
    extern function void save_sent(arp_request req);
    extern function void save_received(arp_response rec);
    extern function void calc_expected(arp_request req, arp_response expected);    
    extern task check_last_received();

endclass : validator

function validator::new(input bit [47:0] my_mac, input bit [31:0] my_ipv4);
    this.num_sent = 0;
    this.num_rec = 0;
    this.my_mac = my_mac;
    this.my_ipv4 = my_ipv4;
endfunction : new

function void validator::run();


endfunction : run

function void validator::wrapup();

    $display("Simulation done!");
    $display("Printing all vectors:");
    foreach(sent_reqs[i]) begin
        sent_reqs[i].display($sformatf("SENT: %0d", i));
        rec_resp[i].display($sformatf("RECD: %0d", i));
        expected_resp[i].display($sformatf("EXPT: %0d", i));
    end

endfunction : wrapup

function void validator::save_sent(arp_request req);

    arp_response expected;
    expected = new();
    calc_expected(req, expected);
    this.sent_reqs.push_back(req);
    this.expected_resp.push_back(expected);
    this.num_sent++;

endfunction : save_sent

function void validator::calc_expected(arp_request req, arp_response expected);

    // Todo: Make a check_validity() function for arp_request. If it fails, then expected is no response.
    expected.data_tx[0:5] = req.data_rx_i[22:27];
    expected.data_tx[6:11] = this.my_mac;
    expected.data_tx[12:13] = 'h0806;
    expected.data_tx[14:15] = 'h0001;
    expected.data_tx[16:17] = 'h0800;
    expected.data_tx[18] = 'h06;
    expected.data_tx[19] = 'h04;
    expected.data_tx[20:21] = 'h0002;
    expected.data_tx[22:27] = this.my_mac;
    expected.data_tx[28:31] = this.my_ipv4;
    expected.data_tx[32:37] = req.data_rx_i[22:27];
    expected.data_tx[38:41] = req.data_rx_i[28:31];

endfunction : calc_expected

function void validator::save_received(arp_response rec);
    this.rec_resp.push_back(rec);
    this.num_rec++;
endfunction : save_received

task validator::check_last_received();

    import clock::*;

    int i = this.num_rec - 1;

    if (!(rec_resp[i].compare(expected_resp[i]))) begin
        //Failed a comparison!.
        // Wait a few cycles, then kill the sim.
        #(3 * period);
        $display("Mismatch detected!");
        $display("--------Offending ARP responses:--------");
        sent_reqs[i].display("Sent----:");
        rec_resp[i].display("Received:");
        expected_resp[i].display("Expected:");
        $display("---------End of vectors. Exit $fatal.--------");
        $fatal;
        $finish;
    end

endtask : check_last_received