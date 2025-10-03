// Code your testbench here
// or browse Examples
`include "uvm_macros.svh"
import uvm_pkg::*;

class transaction extends uvm_sequence_item;
  `uvm_object_items(transaction)

    rand bit [31:0] addr;
    rand bit        wr_en;
         bit        valid;
    rand bit [31:0] wdata;
         bit [31:0] wdata;

    function void new (input string name = "transaction");
        super.new(transaction);
    endfunction

    constraint c {
        addr inside {32'h400, 32'h404, 32'h408
                    ,32'h40C, 32'h410};
    }

endclass

class driver extends uvm_driver;
    `uvm_component_utils(driver)

    virtual dma_if dif;
    transaction t;

    function void new(input string name = "driver", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        t = transaction::type_id::create("t");
        if (!uvm_config_db #(virtual dif) ::get (this, "", "dif", dif))
        `uvm_error("DRV", "ERROR");

    endfunction

    function void reset ();
        @(posedge dif.clk);
        dif.reset <= 1;
        dif.addr <= 0;
        dif.wr_en <= 0;
        dif.valid <= 0;
        dif.wdata <= 0;
        dif.rdata <= 0;
        @(posedge dif.clk);
        dif.reset <= 0;
    endfunction

    function void write();
        @(posedge clk);
        dif.addr <= t.addr;
        dif.wr_en <= 1'b1;
        dif.valid <= 1'b1;
        dif.wdata <= t.wdata;
        //dif.rdata <= t.rdata;
        @(posedge clk);
        `uvm_info("driver", $sformatf("Mode : Write WDATA : %0d ADDR : %0d", dif.wdata, dif.addr), UVM_NONE);
    endfunction

    function void read();
        @(posedge clk);
        dif.addr <= t.addr;
        dif.wr_en <= 1'b0;
        dif.valid <= 1'b1;
        
        //dif.rdata <= t.rdata;
        @(posedge clk);
        t.rdata <= dif.rdata;
        `uvm_info("driver", $sformatf("Mode : Read RDATA : %0d ADDR : %0d", dif.rdata, dif.addr), UVM_NONE);
    endfunction

    virtual task run_phase (uvm_phase phase);
        reset();
        forever begin
            seq_item_port.get_next_item(t);
            if (t.wr_en & t.valid) begin
                write();
            end else if (!t.wr_en & t.valid) begin
                read();
            end
            seq_item_port.item_done();
        end

    endtask

endclass

class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    virtual dma_if dif;
    transaction t;
    `uvm_analysis_port #(transaction) p;

    function new (input string name = "monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        t = transaction::type_id::create("t");
        p = new("p");
        if (!uvm_config_db#(virtual dma_if)::get(null, "", "dif", dif))
        `uvm_error("monitor", "ERROR");
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            
            if(dif.wr_en & dif.valid) begin
                @(posedge clk);
                t.addr = dif.addr;
                //t.wr_en = 1'b1;
                //t.valid = 1'b1;
                t.wdata = dif.wdata;
                @(posedge clk);
                `uvm_info("monitor", $sformatf("Mode : Write WDATA : %0d ADDR : %0d", dif.wdata, dif.addr), UVM_NONE);
            end else if (!dif.wr_en & dif.valid) begin
                @(posedge clk);
                t.addr = dif.addr;
                //t.wr_en = 1'b1;
                //t.valid = 1'b1;
                t.rdata = dif.rdata;
                @(posedge clk);
                `uvm_info("monitor", $sformatf("Mode : Read WDATA : %0d ADDR : %0d", dif.wdata, dif.addr), UVM_NONE);
            end
            p.write(t);
        end

    endtask

endclass

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard);

    uvm_analysis_imp #(transaction, scoreboard) i;
    transaction t;
    bit [31:0] arr [32];
    bit [31:0] temp;

    function new (input string name = "scoreboard", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        t = transaction::type_id::create("t");
        i = new("i");
    endfunction

    virtual function void write (transaction t);
        if (t.reset == 1) `uvm_info("scoreboard", "Reset", UVM_NONE);
        else begin
            if(t.wr_en & t.valid) begin
                arr[t.addr] = t.wdata;
                `uvm_info("scoreboard", $sformatf("DATA Stored Addr : %0d Data :%0d", t.addr, t.wdata), UVM_NONE);
            end else begin
                temp = arr[t.addr];
                if(temp == t.rdata) 
                    `uvm_info("SCO", $sformatf("Test Passed -> Addr : %0d Data :%0d", t.paddr, t.wdata), UVM_NONE);
                else 
                    `uvm_info("SCO", $sformatf("Test Failed -> Addr : %0d Data :%0d", t.paddr, t.wdata), UVM_NONE);

            end
        end
        $display("----------------------------------------------------------------");
    endfunction

endclass

class agent extends uvm_agent;
    `uvm_component_utils(agent)

    driver d;
    monitor m;
    uvm_sequencer#(transaction) sqr;

    function new (input string name = "scoreboard", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        d = driver::type_id::create("driver",this);
        m = monitor::type_id::create("monitor", this);
        sqr = uvm_sequence#(transaction)::type_id::create("sqr", this);

    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        d.seq_item_port(sqr.seq_item_export);
    endfunction

endclass

class intr_reg extends uvm_reg;
    `uvm_object_utils(intr_reg)

    rand uvm_reg_field mask;
    rand uvm_reg_field status;

    function new (string name = "intr_reg");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE)); // register width = 32
    endfunction

    virtual function void build();
        status = uvm_reg_field::type_id::create("status");
        status.configure(
            .parent(this),              //reg
            .size(16),                  //bitwidth
            .lsb_pos(0),                //lsb
            .access("RW"),              //access   
            .volatile(0),               //volatile
            .reset(0),                  //reset value
            .has_reset(1),              //has_reset
            .is_rand(1),                //is_random
            .individually_accessible(0) //field_access -> 0 or 1 ??
        );

        mask = uvm_reg_field::type_id::create("mask");
        mask.configure(
            .parent(this), 
            .size(16), 
            .lsb_pos(16), 
            .access("RW"),  
            .volatile(0), 
            .reset(0), 
            .has_reset(1), 
            .is_rand(1), 
            .individually_accessible(0)
        ); 
       
    endfunction

endclass

class ctrl_reg extends uvm_reg;
    `uvm_object_utils(ctrl_reg)

    rand uvm_reg_field start_dma;
    rand uvm_reg_field w_count;
    rand uvm_reg_field io_mem;
    rand uvm_reg_field resvd;

    function new (string name = "intr_reg");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE)); // register width = 32
    endfunction

    virtual function void build();
        start_dma = uvm_reg_field::type_id::create("start_dma");
        start_dma.configure(
            .parent(this),              //reg
            .size(1),                   //bitwidth
            .lsb_pos(0),                //lsb
            .access("RW"),              //access   
            .volatile(0),               //volatile
            .reset(0),                  //reset value
            .has_reset(1),              //has_reset
            .is_rand(1),                //is_random
            .individually_accessible(0) //field_access -> 0 or 1 ??
        );

        w_count = uvm_reg_field::type_id::create("w_count");
        w_count.configure(
            .parent(this), 
            .size(8), 
            .lsb_pos(1), 
            .access("RW"),  
            .volatile(0), 
            .reset(0), 
            .has_reset(1), 
            .is_rand(1), 
            .individually_accessible(0)
        ); 

        io_mem = uvm_reg_field::type_id::create("io_mem");
        io_mem.configure(
            .parent(this), 
            .size(1), 
            .lsb_pos(9), 
            .access("RW"),  
            .volatile(0), 
            .reset(0), 
            .has_reset(1), 
            .is_rand(1), 
            .individually_accessible(0)
        ); 

        resvd = uvm_reg_field::type_id::create("resvd");
        resvd.configure(
            .parent(this), 
            .size(22), 
            .lsb_pos(10), 
            .access("RW"),  
            .volatile(0), 
            .reset(0), 
            .has_reset(1), 
            .is_rand(1), 
            .individually_accessible(0)
        ); 
       
    endfunction

endclass

class io_addr extends uvm_reg;
    `uvm_object_utils(io_addr)

    rand uvm_reg_field address;

    function new (string name = "io_addr");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE)); // register width = 32
    endfunction

    virtual function void build();
        address = uvm_reg_field::type_id::create("address");
        address.configure(
            .parent(this),              //reg
            .size(32),                  //bitwidth
            .lsb_pos(0),                //lsb
            .access("RW"),              //access   
            .volatile(0),               //volatile
            .reset(0),                  //reset value
            .has_reset(1),              //has_reset
            .is_rand(1),                //is_random
            .individually_accessible(0) //field_access -> 0 or 1 ??
        );
       
    endfunction

endclass

class mem_addr extends uvm_reg;
    `uvm_object_utils(mem_addr)

    rand uvm_reg_field address;

    function new (string name = "mem_addr");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE)); // register width = 32
    endfunction

    virtual function void build();
        address = uvm_reg_field::type_id::create("address");
        address.configure(
            .parent(this),              //reg
            .size(32),                  //bitwidth
            .lsb_pos(0),                //lsb
            .access("RW"),              //access   
            .volatile(0),               //volatile
            .reset(0),                  //reset value
            .has_reset(1),              //has_reset
            .is_rand(1),                //is_random
            .individually_accessible(0) //field_access -> 0 or 1 ??
        );
       
    endfunction

endclass

class reg_block extends uvm_reg_block;
    `uvm_object_utils(reg_block)

    intr_reg intr1;
    ctrl_reg ctrl1;
    io_addr io1;
    mem_addr mem1;

    function new (input string name = "reg_block");
        super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction

    virtual function void build();
        default_map() = create_map("default_map");

        intr1 = intr_reg::type_id::create("intr1");
        intr1.build();
        intr1.configure(this,null);

        ctrl1 = ctrl_reg::type_id::create("ctrl1");
        ctrl1.build();
        ctrl1.configure(this,null);

        io1 = io_addr::type_id::create("io1");
        io1.build();
        io1.configure(this,null);

        mem1 = mem_addr::type_id::create("mem1");
        mem1.build();
        mem1.configure(this,null);

        default_map.add_reg(intr1, 32'h400, "RW");  // reg, offset, access
        default_map.add_reg(ctrl1, 32'h404, "RW");  // reg, offset, access
        default_map.add_reg(io1, 32'h408, "RW");  // reg, offset, access
        default_map.add_reg(mem1, 32'h40c, "RW");  // reg, offset, access

        lock_model();
    endfunction

endclass

class top_adapter extends uvm_reg_adapter;
    `uvm_object_utils(top_adapter)

    function new (input string name = "top_adapter");
        super.new(name);
    endfunction

    function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        transaction t;    
        t = transaction::type_id::create("t");
    
        t.wr_en    = (rw.kind == UVM_WRITE) ? 1'b1 : 1'b0;
        t.addr     = rw.addr;
        t.wdata    = rw.data;

        return t;
    endfunction

    function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        transaction t;
    
        assert($cast(t, bus_item));

        rw.kind = (t.wr_en == 1'b1) ? UVM_WRITE : UVM_READ;
        rw.data = (t.wr_en == 1'b1) ? r.wdata : t.rdata;
        rw.addr = t.addr;
        rw.status = UVM_IS_OK;
    endfunction

endclass

class env extends uvm_env;
    `uvm_component_utils(env)

    agent a;
    scoreboard s;
    reg_block  regmodel;   
    top_adapter    adapter_inst;
    uvm_reg_predictor   #(transaction)  predictor_inst;

    function new(input string name = "env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        a = agent::type_id::create("a", this);
        s = scoreboard::type_id::create("s", this);
    
        regmodel   = reg_block::type_id::create("regmodel", this);
        regmodel.build();

   
        predictor_inst = uvm_reg_predictor#(transaction)::type_id::create("predictor_inst", this);
        adapter_inst = top_adapter::type_id::create("adapter_inst",, get_full_name());
    
    endfunction

    function void connect_phase(uvm_phase phase);
        a.m.mon_ap.connect(s.recv);
        a.m.mon_ap.connect(predictor_inst.bus_in);
    
        regmodel.default_map.set_sequencer( .sequencer(a.sqr), .adapter(adapter_inst) );
        regmodel.default_map.set_base_addr(0);
    
        predictor_inst.map       = regmodel.default_map;
        predictor_inst.adapter   = adapter_inst;
    endfunction 

endclass