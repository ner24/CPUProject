`ifndef EU_TEST_GENERAL_TESTS
`define EU_TEST_GENERAL_TESTS

//demo test. Also tests that eu is stable in unstimulated state
`ifdef EU_TEST_IDLE //will be defined from cmd line
`ifndef INC_CONSTRAINTS //make sure this test adds no code to seqItem

`define NUM_SEQ_ITEMS 1
function execution_unit_sequence_item get_seq_item_from_test(int step);
  seq_item = execution_unit_sequence_item::type_id::create("sequence_item");
  case(step)
    1: begin
      seq_item.icon_rx0_i      <= 'b0;
      seq_item.icon_rx0_resp_o <= 'b0;
      seq_item.icon_rx1_i      <= 'b0;
      seq_item.icon_rx1_resp_o <= 'b0;
      
      seq_item.icon_tx_data_o      <= 'b0;
      seq_item.icon_tx_addr_i      <= 'b0;
      seq_item.icon_tx_req_valid_i <= 'b0;
      seq_item.icon_tx_success_o   <= 'b0;

      seq_item.dispatched_instr_i       <= 'b0;
      seq_item.dispatched_instr_valid_i <= 'b0;
      seq_item.ready_for_next_instr_o   <= 'b0;
    end
  endcase
  return seq_item;
endfunction
`endif
`endif

/*`ifdef EU_TEST_SINGLE_ADD
`define NUM_SEQ_ITEMS 3
`define USE_RAND 1'b1
`ifdef INC_CONSTRAINTS
  constraint cons {
    
  }
`endif
`endif*/

`endif
