//This block actually sends the request into the ARP block.

typedef class driver;

class driver_callbacks;
    //I may not use these, but I'll put in the structure.
    virtual task pre_tx(input driver drv, input arp_request req);
    endtask : pre_tx

    virtual task post_tx(input driver drv, input arp_request req);
    endtask : post_tx

endclass : driver_callbacks

class driver;

    //pass
    aif_tp atp;
    mailbox gen2drv;
    driver_callbacks cbsq[$]; // queue of callbacks

    extern function new(input aif_tp atp, input mailbox gen2drv);
    extern task reset();
    extern task run();
    extern task send(input arp_request req);

endclass : driver

function driver::new(input aif_tp atp, input mailbox gen2drv);

    this.atp = atp;
    this.gen2drv = gen2drv;
    atp.tb_areset_i <= 1'b0;

endfunction : new

task driver::run();

    arp_request req_to_send;
    $display("Driver is running!");
    forever begin
        if (gen2drv.try_get(req_to_send) == 0) break;
        send(req_to_send);
        foreach(cbsq[i]) cbsq[i].post_tx(this, req_to_send);
    end
    $display("Driver loop is over.");

endtask : run


task driver::send(input arp_request req);

    req.display("driver sending req: ");
    atp.cb_rx.data_valid_rx_i <= 1'b1;
    for (int i=0; i < $size(req.data_rx_i); i++) begin
        $display("Driver: sending %x at %0t", req.data_rx_i[i], $time);
        atp.cb_rx.data_rx_i <= req.data_rx_i[i];
        @atp.cb_rx;
    end
    atp.cb_rx.data_valid_rx_i <= 1'b0;
    atp.cb_rx.data_rx_i <= 'h00;
    // wait 50 clock cycles (give enough time for the output to finish) 
    // but we probably don't need this. We could throw in a small memory to store pending 
    // valid requests while it's still responding to an earlier one.
    //(TODO: randomize this.)
    for (int i=0; i < 50; i++) @atp.cb_rx;


endtask : send

task driver::reset();

    atp.tb_areset_i <= 1'b1;
    @atp.cb_rx;
    atp.tb_areset_i <= 1'b0;

endtask : reset