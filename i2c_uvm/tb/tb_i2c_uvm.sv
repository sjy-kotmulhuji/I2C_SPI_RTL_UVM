`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

// ============================================================
// Interface
// ============================================================
interface i2c_if (
    input logic clk,
    input logic reset
);
    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic       cmd_stop;
    logic [7:0] m_tx_data;
    logic [7:0] s_tx_data;
    logic       ack_in;
    logic [7:0] m_rx_data;
    logic [7:0] s_rx_data;
    logic       done;
    logic       ack_out;
    logic       busy;
    event       capture_ev;

    clocking drv_cb @(posedge clk);
        default output #0;
        output cmd_start;
        output cmd_write;
        output cmd_read;
        output cmd_stop;
        output ack_in;
        output m_tx_data;
        output s_tx_data;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input cmd_start;
        input cmd_write;
        input cmd_read;
        input cmd_stop;
        input m_tx_data;
        input s_tx_data;
        input ack_in;
        input m_rx_data;
        input s_rx_data;
        input done;
        input ack_out;
        input busy;
    endclocking
endinterface

// ============================================================
// Sequence Item
// ============================================================
class i2c_seq_item extends uvm_sequence_item;
    `uvm_object_utils(i2c_seq_item)

    logic            cmd_write;  // 1=write, 0=read
    rand logic [7:0] m_tx_data;
    rand logic [7:0] s_tx_data;

    // mon -> scb
    logic      [7:0] m_rx_data;
    logic      [7:0] s_rx_data;
    logic            ack_out;

    function new(string name = "i2c_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "cmd=%s m_tx=0x%02h s_tx=0x%02h m_rx=0x%02h s_rx=0x%02h ack_out=%0b",
            cmd_write ? "WRITE" : "READ",
            m_tx_data,
            s_tx_data,
            m_rx_data,
            s_rx_data,
            ack_out
        );
    endfunction
endclass

// ============================================================
// Sequence
// ============================================================
class i2c_write_read_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(i2c_write_read_seq)

    int num_trans = 5;

    function new(string name = "i2c_write_read_seq");
        super.new(name);
    endfunction

    task body();
        i2c_seq_item item;
        repeat (num_trans) begin
            item = i2c_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_fatal(get_type_name(), "randomize() fail!")
            // write/read 번갈아가며
            item.cmd_write = $urandom_range(0, 1);
            `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM)
            finish_item(item);
        end
    endtask
endclass

// ============================================================
// Driver
// ============================================================
class i2c_driver extends uvm_driver #(i2c_seq_item);
    `uvm_component_utils(i2c_driver)

    virtual i2c_if vif;

    function new(string name = "i2c_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual i2c_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        i2c_seq_item req;
        wait (vif.reset == 0);
        repeat (3) @(vif.drv_cb);
        vif.drv_cb.cmd_start <= 0;
        vif.drv_cb.cmd_write <= 0;
        vif.drv_cb.cmd_read  <= 0;
        vif.drv_cb.cmd_stop  <= 0;
        vif.drv_cb.m_tx_data <= 0;
        vif.drv_cb.s_tx_data <= 0;
        vif.drv_cb.ack_in    <= 1;

        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_item(i2c_seq_item req);
        vif.drv_cb.s_tx_data <= req.s_tx_data;
        vif.drv_cb.ack_in    <= 1'b1;
        @(vif.drv_cb);

        if (req.cmd_write) begin
            // START
            vif.drv_cb.cmd_start <= 1;
            while (!vif.done) @(vif.drv_cb);
            vif.drv_cb.cmd_start <= 0;
            @(vif.drv_cb);

            // ADDR (SLA_W = 8'h4A)
            vif.drv_cb.cmd_write <= 1;
            vif.drv_cb.m_tx_data <= 8'h4A;
            while (!vif.done) @(vif.drv_cb);
            vif.drv_cb.cmd_write <= 0;
            @(vif.drv_cb);

            // DATA
            vif.drv_cb.cmd_write <= 1;
            vif.drv_cb.m_tx_data <= req.m_tx_data;
            while (!vif.done) @(vif.drv_cb);
            vif.drv_cb.cmd_write <= 0;
            @(vif.drv_cb);

        end else begin
            // START
            vif.drv_cb.cmd_start <= 1;
            while (!vif.done) @(vif.drv_cb);
            vif.drv_cb.cmd_start <= 0;
            @(vif.drv_cb);

            // ADDR (SLA_R = 8'h4B)
            vif.drv_cb.cmd_write <= 1;
            vif.drv_cb.m_tx_data <= 8'h4B;
            while (!vif.done) @(vif.drv_cb);
            vif.drv_cb.cmd_write <= 0;
            @(vif.drv_cb);

            // READ
            vif.drv_cb.cmd_read <= 1;
            while (!vif.done) @(vif.drv_cb);
            vif.drv_cb.cmd_read <= 0;
            @(vif.drv_cb);
        end

        // STOP (공통)
        vif.drv_cb.cmd_stop <= 1;
        while (!vif.done) @(vif.drv_cb);
        vif.drv_cb.cmd_stop <= 0;
        @(vif.drv_cb);

        // 트랜잭션 완전히 끝난 시점에 monitor 트리거
        ->vif.capture_ev;
    endtask
endclass

// ============================================================
// Monitor
// ============================================================
class i2c_monitor extends uvm_monitor;
    `uvm_component_utils(i2c_monitor)

    virtual i2c_if vif;
    uvm_analysis_port #(i2c_seq_item) ap;

    function new(string name = "i2c_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual i2c_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
    i2c_seq_item item;
    forever begin
        @(vif.capture_ev);
        repeat(2) @(vif.mon_cb);  // rx_data 안정화 대기

        item = i2c_seq_item::type_id::create("item");
        item.cmd_write = vif.mon_cb.cmd_write;
        item.m_tx_data = vif.mon_cb.m_tx_data;
        item.s_tx_data = vif.mon_cb.s_tx_data;
        item.m_rx_data = vif.mon_cb.m_rx_data;
        item.s_rx_data = vif.mon_cb.s_rx_data;
        item.ack_out   = vif.mon_cb.ack_out;

        `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM)
        ap.write(item);
    end
endtask

    //task run_phase(uvm_phase phase);
    //    i2c_seq_item item;
    //    forever begin
    //        // done 뜰 때마다 캡처
    //        @(posedge vif.clk);
    //        if (vif.mon_cb.done) begin
    //            @(vif.mon_cb);
    //            item = i2c_seq_item::type_id::create("item");
    //            item.cmd_write = vif.mon_cb.cmd_write;
    //            item.m_tx_data = vif.mon_cb.m_tx_data;
    //            item.s_tx_data = vif.mon_cb.s_tx_data;
    //            item.m_rx_data = vif.mon_cb.m_rx_data;
    //            item.s_rx_data = vif.mon_cb.s_rx_data;
    //            item.ack_out   = vif.mon_cb.ack_out;
    //            `uvm_info(get_type_name(), item.convert2string(), UVM_HIGH)
    //            ap.write(item);
    //        end
    //    end
    //endtask
endclass

// ============================================================
// Scoreboard
// ============================================================
class i2c_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2c_scoreboard)

    uvm_analysis_imp #(i2c_seq_item, i2c_scoreboard) analysis_imp;

    int pass_cnt;
    int fail_cnt;

    function new(string name = "i2c_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_imp = new("analysis_imp", this);
    endfunction

    function void write(i2c_seq_item item);
        if (item.cmd_write) begin
            // Write: m_tx_data == s_rx_data
            if (item.m_tx_data === item.s_rx_data) begin
                `uvm_info(get_type_name(),
                          $sformatf("WRITE PASS: m_tx=0x%02h s_rx=0x%02h",
                                    item.m_tx_data, item.s_rx_data), UVM_MEDIUM)
                pass_cnt++;
            end else begin
                `uvm_error(get_type_name(), $sformatf(
                           "WRITE FAIL: m_tx=0x%02h != s_rx=0x%02h",
                           item.m_tx_data,
                           item.s_rx_data
                           ))
                fail_cnt++;
            end
        end else begin
            // Read: s_tx_data == m_rx_data
            if (item.s_tx_data === item.m_rx_data) begin
                `uvm_info(get_type_name(),
                          $sformatf("READ PASS: s_tx=0x%02h m_rx=0x%02h",
                                    item.s_tx_data, item.m_rx_data), UVM_MEDIUM)
                pass_cnt++;
            end else begin
                `uvm_error(get_type_name(), $sformatf(
                           "READ FAIL: s_tx=0x%02h != m_rx=0x%02h",
                           item.s_tx_data,
                           item.m_rx_data
                           ))
                fail_cnt++;
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf(
                  "=== RESULT: PASS=%0d FAIL=%0d ===", pass_cnt, fail_cnt),
                  UVM_NONE)
    endfunction
endclass

// ============================================================
// Coverage
// ============================================================
class i2c_coverage extends uvm_subscriber #(i2c_seq_item);
    `uvm_component_utils(i2c_coverage)

    i2c_seq_item item;

    covergroup i2c_cg;
        cp_cmd: coverpoint item.cmd_write {
            bins write_op = {1}; bins read_op = {0};
        }
        cp_m_tx: coverpoint item.m_tx_data {
            bins zero = {8'h00};
            bins max = {8'hFF};
            bins others = {[8'h01 : 8'hFE]};
        }
        cp_s_tx: coverpoint item.s_tx_data {
            bins zero = {8'h00};
            bins max = {8'hFF};
            bins others = {[8'h01 : 8'hFE]};
        }
        cx_cmd_data: cross cp_cmd, cp_m_tx;
    endgroup

    function new(string name = "i2c_coverage", uvm_component parent = null);
        super.new(name, parent);
        i2c_cg = new();
    endfunction

    function void write(i2c_seq_item t);
        item = t;
        i2c_cg.sample();
    endfunction
endclass

// ============================================================
// Agent
// ============================================================
class i2c_agent extends uvm_agent;
    `uvm_component_utils(i2c_agent)

    i2c_driver drv;
    i2c_monitor mon;
    uvm_sequencer #(i2c_seq_item) seqr;

    function new(string name = "i2c_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv  = i2c_driver::type_id::create("drv", this);
        mon  = i2c_monitor::type_id::create("mon", this);
        seqr = uvm_sequencer#(i2c_seq_item)::type_id::create("seqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

// ============================================================
// Env
// ============================================================
class i2c_env extends uvm_env;
    `uvm_component_utils(i2c_env)

    i2c_agent      agent;
    i2c_scoreboard scb;
    i2c_coverage   cov;

    function new(string name = "i2c_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = i2c_agent::type_id::create("agent", this);
        scb   = i2c_scoreboard::type_id::create("scb", this);
        cov   = i2c_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.mon.ap.connect(scb.analysis_imp);
        agent.mon.ap.connect(cov.analysis_export);
    endfunction
endclass

// ============================================================
// Test
// ============================================================
class i2c_write_read_test extends uvm_test;
    `uvm_component_utils(i2c_write_read_test)

    i2c_env env;

    function new(string name = "i2c_write_read_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = i2c_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        i2c_write_read_seq seq;
        phase.raise_objection(this);
        seq = i2c_write_read_seq::type_id::create("seq");
        seq.num_trans = 10;
        seq.start(env.agent.seqr);
        #50000;
        phase.drop_objection(this);
    endtask
endclass

// ============================================================
// Testbench Top
// ============================================================
module tb_i2c_uvm;

    logic clk, reset;

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        #20 reset = 0;
        #100;
    end

    i2c_if dut_if (
        .clk  (clk),
        .reset(reset)
    );

    i2c_top U_DUT (
        .clk      (clk),
        .reset    (reset),
        .cmd_start(dut_if.cmd_start),
        .cmd_write(dut_if.cmd_write),
        .cmd_read (dut_if.cmd_read),
        .cmd_stop (dut_if.cmd_stop),
        .m_tx_data(dut_if.m_tx_data),
        .s_tx_data(dut_if.s_tx_data),
        .ack_in   (dut_if.ack_in),
        .m_rx_data(dut_if.m_rx_data),
        .s_rx_data(dut_if.s_rx_data),
        .done     (dut_if.done),
        .ack_out  (dut_if.ack_out),
        .busy     (dut_if.busy)
    );

    initial begin
        uvm_config_db#(virtual i2c_if)::set(null, "uvm_test_top.*", "vif",
                                            dut_if);
        run_test("i2c_write_read_test");
    end

endmodule
