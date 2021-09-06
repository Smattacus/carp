class chk_driver_cbs extends driver_callbacks;

    validator chk;

    function new(validator chk);
        this.chk = chk;
    endfunction : new

    virtual task post_tx(input driver drv, input arp_request req);
        this.chk.save_sent(req);
    endtask : post_tx

endclass : chk_driver_cbs

class mon_driver_cbs extends monitor_callbacks;

    validator chk;

    function new(validator chk);
        this.chk = chk;
    endfunction : new

    virtual task post_tx(input monitor mon, input arp_response resp);
        this.chk.save_received(resp);
        this.chk.check_last_received();
    endtask : post_tx


endclass : mon_driver_cbs


class environment;

    aif_tp aif;
    agent ag;
    mailbox gen2drv;
    driver drv;
    monitor mon;
    validator chk;
    //other chunks will go here: agent, driver, monitor, checker.
    
    extern function new(input aif);
    extern virtual function build();
    extern virtual task run();
    extern virtual function wrapup();

endclass : environment

function environment::new(input aif_tp aif);
    this.aif = aif;
endfunction : new

function environment::build();

    $display("-----BUILDING ENVIRONMENT-----");
    this.gen2drv = new();
    this.ag = new(this.gen2drv);
    this.drv = new(this.aif, this.gen2drv);
    this.mon = new(this.aif);
    this.chk = new(this.aif.my_mac_i, this.aif.my_ipv4_i);

    begin
        chk_driver_cbs drv2chk;
        mon_driver_cbs mon2chk;
        drv2chk = new(this.chk);
        mon2chk = new(this.chk);
        // Connect monitor and driver to validator by handing 
        // them a callback with the instantiated validator.
        this.mon.cbsq.push_back(mon2chk);
        this.drv.cbsq.push_back(drv2chk);
    end

    $display("-----DONE BUILDING ENVIRONMENT------");
endfunction : build

task environment::run();

    $display("----------RUNNING SIMULATION------------");
    // run simulation here. Let it clock using the interface clocking block.
    $display("time = %0t", $time);
    $display("Clocking on clk_rx clock block:");
    @this.aif.cb_rx;
    $display("time = %0t", $time);
    this.ag.run();
    fork
        this.drv.run();
        this.mon.run();
    join
    $display("----------SIMULATION DONE---------------");

endtask : run

function environment::wrapup();

    $display("----------WRAPPING UP-------------------");
    this.chk.wrapup();


endfunction : wrapup