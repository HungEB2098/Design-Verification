`include "uvm_macros.svh"
import uvm_pkg::*;

class transaction extends uvm_sequence_item;
  `uvm_object_utils(transaction)

    rand bit [31:0] addr;
    rand bit        wr_en;
         bit        valid;
    rand bit [31:0] wdata;
  		 bit [31:0] rdata;

    function new (input string name = "transaction");
      super.new(name);
    endfunction

    constraint c {
        addr inside {32'h400, 32'h404, 32'h408
                    ,32'h40C, 32'h410};
    }

endclass

class driver extends uvm_driver #(transaction);
    `uvm_component_utils(driver)

    virtual dma_if dif;
    transaction t;

    function new(input string name = "driver", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        //t = transaction::type_id::create("t");
      if (!uvm_config_db #(virtual dma_if) ::get (this, "", "dif", dif))
        `uvm_error("DRV", "ERROR");

    endfunction

    virtual task reset ();
        @(posedge dif.clk);
        dif.reset <= 1;
        dif.addr <= 0;
        dif.valid <= 0;
        dif.wdata <= 0;
        //dif.rdata <= 0;
        @(posedge dif.clk);
        dif.reset <= 0;
    endtask

    virtual task write();
        @(posedge dif.clk);
        dif.addr <= t.addr;
        dif.wr_en <= 1'b1;
        dif.valid <= 1'b1;
        dif.wdata <= t.wdata;
        //dif.rdata <= t.rdata;
        @(posedge dif.clk);
        `uvm_info("driver", $sformatf("Time: %0t | Mode : Write | WDATA : %0d ADDR : %0d", $time, dif.wdata, dif.addr), UVM_NONE);
        dif.valid <= 1'b0;
        @(posedge dif.clk);
    endtask

    virtual task read();
        @(posedge dif.clk);
        dif.addr <= t.addr;
        dif.wr_en <= 1'b0;
        dif.valid <= 1'b1;
        
        //dif.rdata <= t.rdata;
        repeat(2) @(posedge dif.clk);
        dif.valid <= 1'b0;
        t.rdata = dif.rdata;
        
        `uvm_info("driver", $sformatf("Time: %0t | Mode : Read RDATA : %0d ADDR : %0d", $time, dif.rdata, dif.addr), UVM_NONE);
    endtask

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
    //transaction t;
    uvm_analysis_port #(transaction) p;

    function new (input string name = "monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
      	p = new("p", this);
        if (!uvm_config_db#(virtual dma_if)::get(this, "", "dif", dif))
        `uvm_error("monitor", "ERROR");
    endfunction

    virtual task run_phase(uvm_phase phase);
        transaction t = transaction::type_id::create("t");
        fork
        forever begin
            @(posedge dif.clk);

            if (dif.valid) begin
                t.addr = dif.addr;
                t.wr_en = dif.wr_en;
                t.valid = dif.valid;

                if (dif.wr_en) begin
                    t.wdata = dif.wdata;
                    @(posedge dif.clk);
                    `uvm_info("monitor",
                              $sformatf("Time: %0t | Mode : Write | WDATA : %0d ADDR : %0d", $time, 
                                        dif.wdata, dif.addr),
                              UVM_NONE);
                end
                else begin
                    @(posedge dif.clk);
                    t.rdata = dif.rdata;
                    `uvm_info("monitor",
                              $sformatf("Time: %0t | Mode : Read | RDATA : %0d ADDR : %0d", $time,
                                        dif.rdata, dif.addr),
                              UVM_NONE);
                end
                p.write(t);
            end
        end
        join_none
    endtask

endclass

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard);

    uvm_analysis_imp #(transaction, scoreboard) i;
    transaction t;
    bit [31:0] arr [*];
    bit [31:0] temp;

    function new (input string name = "scoreboard", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        t = transaction::type_id::create("t");
      i = new("i", this);
    endfunction

    virtual function void write (transaction t);
        if(t.wr_en & t.valid) begin
            arr[t.addr] = t.wdata;
            `uvm_info("scoreboard", $sformatf("DATA Stored | Addr : %0d Data :%0d", t.addr, t.wdata), UVM_NONE)
        end else begin
            temp = arr[t.addr];
            if(temp == t.rdata) 
                `uvm_info("SCO", $sformatf("Test Passed -> Addr : %0d Data :%0d", t.addr, t.wdata), UVM_NONE)
            else 
                `uvm_info("SCO", $sformatf("Test Failed -> Addr : %0d Data :%0d", t.addr, t.wdata), UVM_NONE)
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
        sqr = uvm_sequencer#(transaction)::type_id::create("sqr", this);

    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        d.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass

class intr extends uvm_reg;
    `uvm_object_utils(intr)

    rand uvm_reg_field mask;
    rand uvm_reg_field status;

    function new (string name = "intr");
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

class ctrl extends uvm_reg;
    `uvm_object_utils(ctrl)

    rand uvm_reg_field start_dma;
    rand uvm_reg_field w_count;
    rand uvm_reg_field io_mem;
    rand uvm_reg_field resvd;

    function new (string name = "ctrl");
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

    intr intr1;
    ctrl ctrl1;
    io_addr io1;
    mem_addr mem1;

    function new (input string name = "reg_block");
        super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction

    function void build();
      	default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN);

        intr1 = intr::type_id::create("intr1");
        intr1.build();
        intr1.configure(this,null);

        ctrl1 = ctrl::type_id::create("ctrl1");
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
        t.valid    = 1'b1;
        if (t.wr_en) t.wdata    = rw.data;
        if (!t.wr_en) t.rdata    = rw.data;            // an toàn để khởi tạo
        
        return t;
    endfunction

    function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        transaction t;
    
        assert($cast(t, bus_item));

        rw.kind = (t.wr_en) ? UVM_WRITE : UVM_READ;
        //rw.data = (t.wr_en == 1'b1) ? t.wdata : t.rdata;
        rw.data = t.rdata;
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
        a.m.p.connect(s.i);
        a.m.p.connect(predictor_inst.bus_in);
    
        regmodel.default_map.set_sequencer( .sequencer(a.sqr), .adapter(adapter_inst) );
        regmodel.default_map.set_base_addr('h400);
    
        predictor_inst.map       = regmodel.default_map;
        predictor_inst.adapter   = adapter_inst;
    endfunction 

endclass

class ctrl_wr extends uvm_sequence;
    `uvm_object_utils(ctrl_wr)

    reg_block regmodel;

    function new(input string name = "ctrl_wr");
        super.new(name);
    endfunction

    task body();
        uvm_status_e   status;
        bit [31:0] wdata; 
    
        for(int i = 0; i < 3; i++) begin
            wdata = $urandom();
            regmodel.ctrl1.write(status, wdata);
        end
    endtask

endclass

class ctrl_rd extends uvm_sequence;
    `uvm_object_utils(ctrl_rd)
  
    reg_block regmodel;
  
    function new (string name = "ctrl_rd"); 
        super.new(name);    
    endfunction
  

    task body;  
        uvm_status_e   status;
        bit [31:0] rdata;
        for(int i = 0; i < 3; i++) begin
            regmodel.ctrl1.read(status, rdata); 
        end
    endtask
  
endclass

class intr_wr extends uvm_sequence;
    `uvm_object_utils(intr_wr)

    reg_block regmodel;

    function new(input string name = "intr_wr");
        super.new(name);
    endfunction

    task body();
        uvm_status_e   status;
        bit [31:0] wdata; 
    
        for(int i = 0; i < 3; i++) begin
            wdata = $urandom();
            regmodel.intr1.write(status, wdata);
        end
    endtask

endclass

class intr_rd extends uvm_sequence;
    `uvm_object_utils(intr_rd)
  
    reg_block regmodel;
  
    function new (string name = "intr_rd"); 
        super.new(name);    
    endfunction
  

    task body;  
        uvm_status_e status;
        bit [31:0] rdata;
        for(int i = 0; i < 3; i++) begin
            regmodel.intr1.read(status, rdata); 
        end
    endtask
  
endclass  

class io_wr extends uvm_sequence;
    `uvm_object_utils(io_wr)

    reg_block regmodel;

    function new(input string name = "io_wr");
        super.new(name);
    endfunction

    task body();
        uvm_status_e   status;
        bit [31:0] wdata; 
    
        for(int i = 0; i < 3; i++) begin
            wdata = $urandom();
            regmodel.io1.write(status, wdata);
        end
    endtask

endclass

class io_rd extends uvm_sequence;
  `uvm_object_utils(io_rd)
  
    reg_block regmodel;
  
    function new (string name = "io_rd"); 
        super.new(name);    
    endfunction
  

    task body;  
        uvm_status_e   status;
        bit [31:0] rdata;
        for(int i = 0; i < 3; i++) begin
            regmodel.io1.read(status, rdata); 
        end
    endtask
  
endclass  

class mem_wr extends uvm_sequence;
    `uvm_object_utils(mem_wr)

    reg_block regmodel;

    function new(input string name = "mem_wr");
        super.new(name);
    endfunction

    task body();
        uvm_status_e   status;
        bit [31:0] wdata; 
    
        for(int i = 0; i < 3; i++) begin
            wdata = $urandom();
            regmodel.mem1.write(status, wdata);
        end
    endtask

endclass

class mem_rd extends uvm_sequence;
    `uvm_object_utils(mem_rd)
  
    reg_block regmodel;
  
    function new (string name = "mem_rd"); 
        super.new(name);    
    endfunction
  

    task body;  
        uvm_status_e   status;
        bit [31:0] rdata;
        for(int i = 0; i < 3; i++) begin
            regmodel.mem1.read(status, rdata); 
        end
    endtask
  
endclass  

class dma_reg_seq extends uvm_sequence;

  `uvm_object_utils(dma_reg_seq)
  
  reg_block regmodel;
  
  //---------------------------------------
  // Constructor 
  //---------------------------------------    
  function new (string name = "dma_reg_seq"); 
    super.new(name);    
  endfunction
  
  //---------------------------------------
  // Sequence body 
  //---------------------------------------      
  task body;  
    uvm_status_e   status;
    uvm_reg_data_t incoming;
    bit [31:0] wdata;
    bit [31:0] rdata;
    
    if (starting_phase != null)
      starting_phase.raise_objection(this);
    
    //Write to the Registers
    wdata = $urandom();
    regmodel.intr1.write(status, wdata);
    wdata = $urandom();
    regmodel.ctrl1.write(status, wdata);
    wdata = $urandom();
    regmodel.io1.write(status, wdata);
    wdata = $urandom();
    regmodel.mem1.write(status, wdata);
    
    //Read from the registers
    regmodel.intr1.read(status, rdata);
    regmodel.ctrl1.read(status, rdata);
    regmodel.io1.read(status, rdata);
    regmodel.mem1.read(status, rdata);
      
    if (starting_phase != null)
      starting_phase.drop_objection(this);  
    
  endtask
endclass

class test extends uvm_test;
    `uvm_component_utils(test)

    function new(input string inst = "test", uvm_component c);
        super.new(inst,c);
    endfunction

    env e;

    ctrl_wr  cwr;
    ctrl_rd  crd;

    intr_wr  iwr;
    intr_rd  ird;

    io_wr  iowr;
    io_rd  iord;

    mem_wr  mwr;
    mem_rd  mrd;

    dma_reg_seq dseq;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        e = env::type_id::create("env",this);
  
        cwr = ctrl_wr::type_id::create("cwr");
        crd = ctrl_rd::type_id::create("crd");

        iwr = intr_wr::type_id::create("iwr");
        ird = intr_rd::type_id::create("ird");

        iowr = io_wr::type_id::create("iowr");
        iord = io_rd::type_id::create("iord");

        mwr = mem_wr::type_id::create("mwr");
        mrd = mem_rd::type_id::create("mrd");

        dseq = dma_reg_seq::type_id::create("dseq");
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        // cwr.regmodel = e.regmodel;
        // cwr.start(e.a.sqr);

        // crd.regmodel = e.regmodel;
        // crd.start(e.a.sqr);

        dseq.regmodel = e.regmodel;
        dseq.start(e.a.sqr);

        phase.drop_objection(this);

    endtask

endclass

module tb;
    dma_if dif();

    DMA dut (dif.clk, dif.reset, dif.addr, dif.wr_en, dif.valid, dif.wdata, dif.rdata);

    initial begin
        dif.clk <= 0;
        dif.reset <= 0;
    end

    always #5 dif.clk = ~dif.clk;

    initial begin
        uvm_config_db#(virtual dma_if)::set(null, "*", "dif", dif);
        run_test("test");
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end

endmodule