virtual class base_tr;
    static int count;
    int id;

    function new();
        id = count++;
    endfunction

    pure virtual function bit compare(input base_tr to);
    pure virtual function base_tr copy(input base_tr = null);
    pure virtual function void display(input string prefix = "");

endclass : base_tr

class arp_request extends base_tr;
    bit [0:41][7:0] data_rx_i;  // We need 42 chunks of 8 bits per the spec.

    extern virtual function void set_arp_defaults();
    extern virtual function bit compare(input base_tr to);
    extern virtual function base_tr copy(input base_tr = null);
    extern virtual function void display(input string prefix = "");

endclass : arp_request   

function arp_request::set_arp_defaults();

    int wl = 8;

    bit [47:0] source_mac = 'h000142005f68;

    this.data_rx_i[0:5] = 'hffffffffffff; // MAC DEST   
    this.data_rx_i[6:11] = source_mac; // MAC Source
    this.data_rx_i[12:13] = 'h0806; // ARP Ethertype (0x0806)
    this.data_rx_i[14:15] = 'h0001; // HW Type (Should be 0x0001 for ethertype)
    this.data_rx_i[16:17] = 'h0800; // Protocol type (0x0800 for ipv4)
    this.data_rx_i[18] = 'h06; // HW addr length (0x06 = 6 octets)
    this.data_rx_i[19] = 'h04; // Protocl length (0x04 = 4 octets)
    this.data_rx_i[20:21] = 'h0001; // optype (0x0001 = request)
    this.data_rx_i[22:27] = source_mac; //sender MAC
    this.data_rx_i[28:31] = 'hc0a80101; // sender protocol
    this.data_rx_i[32:37] = 'h000000000000; // target MAC
    this.data_rx_i[38:41] = 'hc0a80102; // target protocol address

endfunction : set_arp_defaults

function bit arp_request::compare(input base_tr to);

    //implementes the abc's compare method.
    arp_request other;
    $cast(other, to);
    return this.data_rx_i == other.data_rx_i;

endfunction : compare

function base_tr arp_request::copy(input base_tr = null);

    //pass for now

endfunction : copy

function void arp_request::display(input string prefix="");

    $display("%0t: %s ARP REQUEST: %x | %x | %x | %x | %x | %x | %x | %x | %x | %x | %x | %x",
        $time,
        prefix,
    this.data_rx_i[0:5],
    this.data_rx_i[6:11],
    this.data_rx_i[12:13],
    this.data_rx_i[14:15],
    this.data_rx_i[16:17],
    this.data_rx_i[18],
    this.data_rx_i[19],
    this.data_rx_i[20:21],  
    this.data_rx_i[22:27],
    this.data_rx_i[28:31],
    this.data_rx_i[32:37],
    this.data_rx_i[38:41]
    );

endfunction : display

class arp_response extends base_tr;
    bit [0:41][7:0] data_tx; // TODO: make this dynamic - error in the logic may make it go longer than 42 octets.

    extern virtual function bit compare(input base_tr to);
    extern virtual function base_tr copy(input base_tr = null);
    extern virtual function void display(input string prefix = "");

endclass : arp_response

function bit arp_response::compare(input base_tr to);

    arp_response to_compare;
    $cast(to_compare, to);
    return this.data_tx == to_compare.data_tx;    

endfunction : compare

function base_tr arp_response::copy(input base_tr = null);

    // pass

endfunction : copy

function void arp_response::display(input string prefix = "");

    $display("%0t: %s ARP RESPONSE: %x | %x | %x | %x | %x | %x | %x | %x | %x | %x | %x | %x",
    $time,
    prefix,
    this.data_tx[0:5],
    this.data_tx[6:11],
    this.data_tx[12:13],
    this.data_tx[14:15],
    this.data_tx[16:17],
    this.data_tx[18],
    this.data_tx[19],
    this.data_tx[20:21],  
    this.data_tx[22:27],
    this.data_tx[28:31],
    this.data_tx[32:37],
    this.data_tx[38:41]);

endfunction : display