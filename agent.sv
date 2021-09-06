class agent;

    mailbox gen2drv;

    extern function new(input mailbox gen2drv);
    extern virtual task run();
    extern virtual function wrapup();
    extern virtual task default_arp_request();

endclass : agent

function agent::new(input mailbox gen2drv);
    this.gen2drv = gen2drv;
endfunction : new

task agent::run();
    arp_request req;
    $display("Agent is running!");
    // create just one vector for now per the typical setup.
    // then put it in the mailbox for the driver to dribble it out according to the clocking blocks.
    req = new();
    req.set_arp_defaults();
    this.gen2drv.put(req);
    $display("Agent has populated the mailbox.");
    $display("Populated with vector:");
    req.display();


endtask : run

task agent::default_arp_request();

    arp_request arp_req;
    arp_req = new();
    arp_req.set_arp_defaults();
    this.gen2drv.put(arp_req);

endtask : default_arp_request

function agent::wrapup();

    $display("Wrapping up!");

endfunction : wrapup