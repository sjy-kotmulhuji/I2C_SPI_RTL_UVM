`include "uvm_macros.svh"
import uvm_pkg::*;

interface spi_if (
    input logic clk,
    input logic reset
);

    logic       cpol;
    logic       cpha;
    logic [7:0] clk_div;
    logic [7:0] m_tx_data;
    logic [7:0] s_tx_data;
    logic       start;
    logic [7:0] m_rx_data;
    logic [7:0] s_rx_data;
    logic       m_rx_done;
    logic       s_rx_done;
    
    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output cpol;
        output cpha;
        output clk_div;
        output m_tx_data;
        output s_tx_data;
        output start;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input cpol;
        input cpha;
        input clk_div;
        input m_tx_data;
        input s_tx_data;
        input start;
        input m_rx_data;
        input s_rx_data;
        input m_rx_done;
        input s_rx_done;
    endclocking

endinterface

class spi_seq_item extends uvm_sequence_item;
    `uvm_object_utils(spi_seq_item)

    rand logic [7:0] m_tx_data;
    rand logic [7:0] s_tx_data;
    logic      [7:0] m_rx_data;
    logic      [7:0] s_rx_data;

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "m_tx_data = 0x%02h, s_tx_data = 0x%02h, m_rx_data = 0x%02h, s_rx_data = 0x%02h",
            m_tx_data,
            s_tx_data,
            m_rx_data,
            s_rx_data
        );
    endfunction
endclass

class spi_write_read_seq extends uvm_sequence #(spi_seq_item);
    `uvm_object_utils(spi_write_read_seq)
    int num_trans = 100;

    function new(string name = "spi_write_read_seq");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        repeat (num_trans) begin
            item = spi_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize()) begin
                `uvm_fatal(get_type_name(), "uart_seq_item randomize() fail!")
            end
            `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM)
            finish_item(item);
        end
    endtask
endclass

class spi_coverage extends uvm_subscriber #(spi_seq_item);
    `uvm_component_utils(spi_coverage)

    spi_seq_item item;

    covergroup spi_cg;
        cp_m_tx: coverpoint item.m_tx_data {
            bins zeroTo4F = {[8'h00 : 8'h4F]};
            bins to8F = {[8'h50 : 8'h8F]};
            bins toCF = {[8'h90 : 8'hCF]};
            bins toMax = {[8'hD0 : 8'hFF]};
        }
        cp_s_tx: coverpoint item.s_tx_data {
            bins zeroTo4F = {[8'h00 : 8'h4F]};
            bins to8F = {[8'h50 : 8'h8F]};
            bins toCF = {[8'h90 : 8'hCF]};
            bins toMax = {[8'hD0 : 8'hFF]};
        }
        cp_m_rx: coverpoint item.m_rx_data {
            bins zeroTo4F = {[8'h00 : 8'h4F]};
            bins to8F = {[8'h50 : 8'h8F]};
            bins toCF = {[8'h90 : 8'hCF]};
            bins toMax = {[8'hD0 : 8'hFF]};
        }
        cp_s_rx: coverpoint item.s_rx_data {
            bins zeroTo4F = {[8'h00 : 8'h4F]};
            bins to8F = {[8'h50 : 8'h8F]};
            bins toCF = {[8'h90 : 8'hCF]};
            bins toMax = {[8'hD0 : 8'hFF]};
        }

        // m_tx랑 s_rx가 같은지 (MOSI 경로)
        //cx_mosi: cross cp_m_tx, cp_s_rx;
        // s_tx랑 m_rx가 같은지 (MISO 경로)
        //cx_miso: cross cp_s_tx, cp_m_rx;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        spi_cg = new();
    endfunction

    function void write(spi_seq_item t);
        item = t;
        spi_cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "\n\n ===== Coverage Summary =====", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf(
              "Overall    : %.1f%%", spi_cg.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf(
              "cp_m_tx    : %.1f%%", spi_cg.cp_m_tx.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf(
              "cp_s_tx    : %.1f%%", spi_cg.cp_s_tx.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf(
              "cp_m_rx    : %.1f%%", spi_cg.cp_m_rx.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf(
              "cp_s_rx    : %.1f%%", spi_cg.cp_s_rx.get_coverage()), UVM_LOW)
    //`uvm_info(get_type_name(), $sformatf(
    //          "cx_mosi    : %.1f%%", spi_cg.cx_mosi.get_coverage()), UVM_LOW)
    //`uvm_info(get_type_name(), $sformatf(
    //          "cx_miso    : %.1f%%", spi_cg.cx_miso.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), " ===== Coverage Summary =====\n\n", UVM_LOW)
endfunction

endclass

class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)

    uvm_analysis_imp #(spi_seq_item, spi_scoreboard) analysis_imp;

    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_imp = new("analysis_imp", this);
    endfunction

    function void write(spi_seq_item item);
        //MOSI m_tx_data == s_rx_data 검사
        if (item.m_tx_data === item.s_rx_data) begin
            `uvm_info(get_type_name(),
                      $sformatf("PASS MOSI: m_tx=0x%02h s_rx=0x%02h",
                                item.m_tx_data, item.s_rx_data), UVM_MEDIUM)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf(
                       "FAIL MOSI: m_tx=0x%02h s_rx=0x%02h",
                       item.m_tx_data,
                       item.s_rx_data
                       ))
            fail_cnt++;
        end

        //MISO 검사 s_tx_data == m_rx_data
        if (item.s_tx_data === item.m_rx_data) begin
            `uvm_info(get_type_name(),
                      $sformatf("PASS MISO: s_tx=0x%02h m_rx=0x%02h",
                                item.s_tx_data, item.m_rx_data), UVM_MEDIUM)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf(
                       "FAIL MISO: s_tx=0x%02h m_rx=0x%02h",
                       item.s_tx_data,
                       item.m_rx_data
                       ))
            fail_cnt++;
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "\n\n", UVM_LOW)
        `uvm_info(get_type_name(), " ===== Scoreboard Summary =====", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  " Total transactions : %0d", pass_cnt + fail_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" PASS : %0d", pass_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" FAIL: %0d", fail_cnt), UVM_LOW)

        if (fail_cnt > 0) begin
            `uvm_error(get_type_name(),
                       $sformatf("TEST FAILED : %0d mismatches detected!",
                                 fail_cnt))
        end else begin
            `uvm_info(get_type_name(), $sformatf(
                      "TEST PASSED : %0d matches detected!", pass_cnt), UVM_LOW)
        end
        `uvm_info(get_type_name(), "\n\n", UVM_LOW)
    endfunction
endclass

class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)

    uvm_analysis_port #(spi_seq_item) ap;
    virtual spi_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        spi_seq_item item;
        @(negedge vif.reset);

        forever begin
            @(posedge vif.m_rx_done);
            @(vif.mon_cb);

            item = spi_seq_item::type_id::create("item");
            item.m_tx_data = vif.mon_cb.m_tx_data;
            item.s_tx_data = vif.mon_cb.s_tx_data;
            item.m_rx_data = vif.mon_cb.m_rx_data;
            item.s_rx_data = vif.mon_cb.s_rx_data;

            `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM)
            ap.write(item);  //mon -> scb로 데이터 전송
        end
    endtask

endclass

class spi_driver extends uvm_driver #(spi_seq_item);
    `uvm_component_utils(spi_driver)

    virtual spi_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        spi_seq_item item;
        vif.drv_cb.cpol      <= 0;
        vif.drv_cb.cpha      <= 0;
        vif.drv_cb.clk_div   <= 8'd4;
        vif.drv_cb.m_tx_data <= 0;
        vif.drv_cb.s_tx_data <= 0;
        vif.drv_cb.start     <= 0;
        wait (vif.reset == 0);

        forever begin
            seq_item_port.get_next_item(item);
            drive(item);
            seq_item_port.item_done();
        end
    endtask

    task drive(spi_seq_item item);
        //데이터 생성
        @(vif.drv_cb);
        vif.drv_cb.m_tx_data <= item.m_tx_data;
        vif.drv_cb.s_tx_data <= item.s_tx_data;

        //start 신호
        @(vif.drv_cb);
        vif.drv_cb.start <= 1;
        @(vif.drv_cb);
        vif.drv_cb.start <= 0;

        //m_rx_done 대기
        @(posedge vif.m_rx_done);
        @(vif.drv_cb);
    endtask
endclass

class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)

    spi_driver driver;
    spi_monitor monitor;
    uvm_sequencer #(spi_seq_item) sequencer;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver = spi_driver::type_id::create("driver", this);
        monitor = spi_monitor::type_id::create("monitor", this);
        sequencer =
            uvm_sequencer#(spi_seq_item)::type_id::create("sequencer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(
            sequencer.seq_item_export);  //seq sqr 연결
    endfunction

endclass

class spi_env extends uvm_env;
    `uvm_component_utils(spi_env)

    spi_agent      agent;
    spi_scoreboard scoreboard;
    spi_coverage   coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = spi_agent::type_id::create("agent", this);
        scoreboard = spi_scoreboard::type_id::create("scoreboard", this);
        coverage   = spi_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.monitor.ap.connect(scoreboard.analysis_imp);  //mon scb 연결
        agent.monitor.ap.connect(coverage.analysis_export);
    endfunction

endclass

class spi_write_read_test extends uvm_test;
    `uvm_component_utils(spi_write_read_test)

    spi_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = spi_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        spi_write_read_seq seq;
        phase.raise_objection(this);
        seq = spi_write_read_seq::type_id::create("seq");
        //seq.num_trans = 100;
        seq.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask

endclass

module tb_spi_uvm ();

    logic clk;
    logic reset;

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);
    end

    spi_if dut_if (
        .clk  (clk),
        .reset(reset)
    );

    spi_top DUT (
        .clk      (clk),
        .reset    (reset),
        .cpol     (dut_if.cpol),
        .cpha     (dut_if.cpha),
        .clk_div  (dut_if.clk_div),
        .m_tx_data(dut_if.m_tx_data),
        .s_tx_data(dut_if.s_tx_data),
        .start    (dut_if.start),
        .m_rx_data(dut_if.m_rx_data),
        .s_rx_data(dut_if.s_rx_data),
        .m_rx_done(dut_if.m_rx_done),
        .s_rx_done(dut_if.s_rx_done)
    );

    initial begin
        uvm_config_db#(virtual spi_if)::set(null, "uvm_test_top.*", "vif",
                                            dut_if);
        run_test("spi_write_read_test");
    end

    initial begin
        $fsdbDumpfile("spi.fsdb");
        $fsdbDumpvars(0, tb_spi_uvm, "+all");
    end


endmodule
