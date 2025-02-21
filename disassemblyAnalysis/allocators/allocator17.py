import sys
from typing import List
from graphGen import decompInstruction, getNumArchReg, getArchRegIdx, convImmStrToVal
import numpy as np

alu_cache_uid_counter = {}
def get_next_alu_cache_idx(alu_cache_idx_counter: dict, alu_idx: int) -> dict:
  if alu_idx in alu_cache_idx_counter:
    alu_cache_idx_counter[alu_idx] = alu_cache_idx_counter[alu_idx] + 1

    if(alu_cache_idx_counter[alu_idx] % 16) == 0: # where 16 is max val per round robin
      if alu_idx not in alu_cache_uid_counter:
        alu_cache_uid_counter[alu_idx] = 0
      else:
        alu_cache_uid_counter[alu_idx] = alu_cache_uid_counter[alu_idx] + 1
      
      #mul by value that shifts the value by 2 in base 10
      alu_cache_idx_counter[alu_idx] = alu_cache_uid_counter[alu_idx] * 100
  else:
    alu_cache_idx_counter[alu_idx] = 0
  return alu_cache_idx_counter

def allocate(instructions: List[str],
             max_instr_batch_size: int = 8,
             num_alus: int = 10,
             alu_alloc_lookback_size: int = 1,
             arch_reg_idx_range: int = getNumArchReg(),
             str_tracker_ram_size: int = 16,
             output_filename: str = "forSim/renamedAssembly.txt") -> List[dict]:
  
  alu_cache_idx_counter: dict = {}
  for i in range(0, num_alus):
    alu_cache_idx_counter[i] = 0

  num_evaluated_instr: int = 0

  renamed_output = open(output_filename, "w")
  renamed_output_formats = open(output_filename + "_formats.txt", "w")
  original_stdout = sys.stdout
  stdouts = [renamed_output, original_stdout]
  
	#for the proof of concept, to keep it simple, load prefetch will be assumed to work every time
  #to emulate this in the model, the ld register will store all the necessary data that is specified
  #by the ldr in the input assembly
  #for performance analysis, a stochastic evaluation of the prefetch success could be worked out by considering
  #the hit rate and latency of l1 cache. (Note that if l1 cache latency too high, then a solution could be to make the ld
  #reg bigger (effectively making it an l0 cache)).
  l0_cache = np.zeros((7,), dtype=int)
  for i in range(7): #load it with some data
    l0_cache[i] = i+1

  mx_reg_file = np.zeros((8,), dtype=int)

  # ----------------------------------------
  # memory units within the ILN pipeline
  # ----------------------------------------
  #reg tracker will have to be made up of individual registers for each arch
  #register. This is fine as there wont be that many anyway
  MEM_ILN_rename_addr_euidx = np.zeros((arch_reg_idx_range,), dtype=int)
  MEM_ILN_rename_addr_uid = np.zeros((arch_reg_idx_range,), dtype=int)
  MEM_ILN_rename_addr_spec = np.zeros((arch_reg_idx_range,), dtype=int)
  MEM_ILN_rename_addr_valid = np.zeros((arch_reg_idx_range,), dtype=bool)

  MEM_ILN_rename_addr_euidx_q = np.zeros((arch_reg_idx_range,), dtype=int)
  MEM_ILN_rename_addr_uid_q = np.zeros((arch_reg_idx_range,), dtype=int)
  MEM_ILN_rename_addr_spec_q = np.zeros((arch_reg_idx_range,), dtype=int)
  MEM_ILN_rename_addr_valid_q = np.zeros((arch_reg_idx_range,), dtype=bool)

  MEM_ILN_ldstr_ldprop_val = np.empty(arch_reg_idx_range, dtype=object)
  MEM_ILN_ldstr_ldprop_val_valid = np.zeros((arch_reg_idx_range,), dtype=bool)

  MEM_ILN_str_tracker = np.zeros((str_tracker_ram_size,4), dtype=object) #first attribute: mem addr, 2nd,3rd,4th: euidx,uid,spec

  round_robin_alloc = 0
  MEM_ILN_eu_alloc_opx_locations = np.zeros((arch_reg_idx_range,), dtype=int)
  MEM_ILN_eu_alloc_opx_locations_valid = np.zeros((arch_reg_idx_range,), dtype=bool)

  MEM_ILN_icongen_destreg_prop_accumulated = np.zeros((arch_reg_idx_range,num_alus,2), dtype=bool)

  while num_evaluated_instr < len(instructions):
    instr_batch_size = max_instr_batch_size if len(instructions) - num_evaluated_instr >= max_instr_batch_size else len(instructions) - num_evaluated_instr

    print("-------------------------batch separator-------------------------")

    #decode instructions (makes the rest of the model easier to write)
    instructions_batch: List[dict] = []
    for i in range(0, instr_batch_size):
      valid, instr, destReg, srcs = decompInstruction(instructions[num_evaluated_instr + i])
      if not valid:
        print("Malformed instruction detected at line: " + str(num_evaluated_instr+i))
        sys.exit(1)
      #in the Python model the branches wont be evaluated (for now)
      #instead, the branches which are triggered are specified externally
      if instr[0] == 'b':
        continue
      instructions_batch.append({
        "instr": instr,
        "destReg": destReg,
        "srcs": srcs
      })
    instr_batch_size = len(instructions_batch)

    num_evaluated_instr += max_instr_batch_size

    # ------------------------
    # ILN ldr
    # ------------------------
    ILN_ldstr_in = instructions_batch
    ILN_ldstr_out_opcode = np.empty(instr_batch_size, dtype=object)
    ILN_ldstr_out_opdIdx = np.empty(instr_batch_size, dtype=int)
    ILN_ldstr_out_opdIdx_valid = np.zeros(instr_batch_size, dtype=bool)
    ILN_ldstr_out_op0 = np.empty(instr_batch_size, dtype=object)
    ILN_ldstr_out_op0m = np.empty(instr_batch_size, dtype=object)
    ILN_ldstr_out_op1 = np.empty(instr_batch_size, dtype=object)
    ILN_ldstr_out_op1m = np.empty(instr_batch_size, dtype=object)
    ILN_ldstr_out_op1v = np.zeros((instr_batch_size,), dtype=bool) #unlike op0, op1 is not always valid

    ILN_ldstr_ldprop_val = MEM_ILN_ldstr_ldprop_val #stores the memvals for each arch reg
    ILN_ldstr_ldprop_val_valid = MEM_ILN_ldstr_ldprop_val_valid #keeps track of which values are real entries
    for i in range(instr_batch_size): #ldr ILN (same cells just different ICS in different directions to str)
      instr = ILN_ldstr_in[i]
      srcs = instr["srcs"]
      destReg = instr["destReg"]
      #print(instr)

      ILN_ldstr_out_opcode[i] = instr["instr"]
      
      if instr["instr"] == "ldr":

        destRegIdx = getArchRegIdx(destReg["value"])
        ILN_ldstr_out_opdIdx[i] = destRegIdx
        ILN_ldstr_out_opdIdx_valid[i] = True

        ILN_ldstr_out_op0[i] = srcs[0]["value"]
        ILN_ldstr_out_op0m[i] = srcs[0]["type"]

        ILN_ldstr_ldprop_val_valid[destRegIdx] = True
        if len(instr["srcs"]) == 2:
          ILN_ldstr_ldprop_val[destRegIdx] = srcs[0]["value"] + '+' + srcs[1]["value"]
          ILN_ldstr_out_op1[i] = srcs[1]["value"]
          ILN_ldstr_out_op1m[i] = srcs[1]["type"]
          ILN_ldstr_out_op1v[i] = True
        else:
          ILN_ldstr_ldprop_val[destRegIdx] = srcs[0]["value"]
          ILN_ldstr_out_op1v[i] = False
       
      # NOTE: this assumes that non ld str instructions
      # have max 2 operands (which is only enforced in
      # the custom isa and not arm)
      else:
        o = 0
        if "value" in destReg:
          destRegIdx = getArchRegIdx(destReg["value"])
        else: #only really applies to str instructions
          destRegIdx = getArchRegIdx(srcs[0]["value"])
          o = 1
        ILN_ldstr_out_opdIdx[i] = destRegIdx
        ILN_ldstr_out_opdIdx_valid[i] = True

        op0, op0m = srcs[o+0]["value"], srcs[o+0]["type"]
        if op0m == "reg" and ILN_ldstr_ldprop_val_valid[getArchRegIdx(op0)]:
          sRegIdx = getArchRegIdx(op0)
          #if ILN_ldstr_ldprop_val_valid[sRegIdx]:
          ILN_ldstr_out_op0[i] = ILN_ldstr_ldprop_val[sRegIdx]
          ILN_ldstr_out_op0m[i] = "mem"
        else:
          ILN_ldstr_out_op0[i] = srcs[o+0]["value"]
          ILN_ldstr_out_op0m[i] = srcs[o+0]["type"]
        
        if len(srcs) == (o+2):
          ILN_ldstr_out_op1v[i] = True
          op1, op1m = srcs[o+1]["value"], srcs[o+1]["type"]
          #print(ILN_ldstr_ldprop_val_valid[getArchRegIdx(op1)])
          if op1m == "reg" and ILN_ldstr_ldprop_val_valid[getArchRegIdx(op1)]:
            sRegIdx = getArchRegIdx(op1)
            #if ILN_ldstr_ldprop_val_valid[sRegIdx]:
            ILN_ldstr_out_op1[i] = ILN_ldstr_ldprop_val[sRegIdx]
            ILN_ldstr_out_op1m[i] = "mem"
          else:
            ILN_ldstr_out_op1[i] = srcs[o+1]["value"]
            ILN_ldstr_out_op1m[i] = srcs[o+1]["type"]
        else:
          ILN_ldstr_out_op1v[i] = False

        if "value" in destReg:
          ILN_ldstr_ldprop_val_valid[destRegIdx] = False

    for i in range(instr_batch_size-1, -1, -1): #str ILN
      t = 0
    
    MEM_ILN_ldstr_ldprop_val = ILN_ldstr_ldprop_val
    MEM_ILN_ldstr_ldprop_val_valid = ILN_ldstr_ldprop_val_valid

    print("ILN ldstr out:")
    print(*ILN_ldstr_out_opcode, sep='\t')
    print(*ILN_ldstr_out_op0, sep='\t')
    print(*ILN_ldstr_out_op0m, sep='\t')
    print(*ILN_ldstr_out_op1, sep='\t')
    print(*ILN_ldstr_out_op1m, sep='\t')
    print(*ILN_ldstr_out_op1v, sep='\t')
    print()


    # ------------------------
    # ILN eu alloc
    # ------------------------
    ILN_eu_alloc_in_opcode = ILN_ldstr_out_opcode
    ILN_eu_alloc_in_opx = (ILN_ldstr_out_op0, ILN_ldstr_out_op1)
    ILN_eu_alloc_in_op1v = ILN_ldstr_out_op1v
    ILN_eu_alloc_in_opxm = (ILN_ldstr_out_op0m, ILN_ldstr_out_op1m)
    ILN_eu_alloc_in_destRegIdx = ILN_ldstr_out_opdIdx
    ILN_eu_alloc_in_destRegIdx_valid = ILN_ldstr_out_opdIdx_valid

    ILN_eu_alloc_out = np.zeros((instr_batch_size,), dtype=int)

    ILN_eu_alloc_opx_locations = MEM_ILN_eu_alloc_opx_locations
    ILN_eu_alloc_opx_locations_valid = MEM_ILN_eu_alloc_opx_locations_valid
    for i in range(instr_batch_size):

      #alu alloc only applies to instructions that get dispatched
      #and are not resolved internally by the front end
      if ILN_eu_alloc_in_opcode[i] == "str":
        ILN_eu_alloc_out[i] = -2
        continue
      if ILN_eu_alloc_in_opcode[i] == "ldr":
        ILN_eu_alloc_out[i] = -2
        continue
      
      #rules:
      #check if dependent on previous alu_alloc_lookback_size instructions (in forward direction)
      #if yes, allocate to same alu as dependent, else, allocate to next alu pointed by
      #round robin counter
      #in this setup, the first src is prioritised over the second
      has_been_allocated = False
      if ILN_eu_alloc_in_opxm[0][i] == "reg":
        op0Idx = getArchRegIdx(ILN_eu_alloc_in_opx[0][i])
        if ILN_eu_alloc_opx_locations_valid[op0Idx]:
          alloc_alu = ILN_eu_alloc_opx_locations[op0Idx]
          has_been_allocated = True
      if (not has_been_allocated) and ILN_eu_alloc_in_op1v[i] and (ILN_eu_alloc_in_opxm[1][i] == "reg"):
        op1Idx = getArchRegIdx(ILN_eu_alloc_in_opx[1][i])
        if ILN_eu_alloc_opx_locations_valid[op1Idx]:
          alloc_alu = ILN_eu_alloc_opx_locations[op1Idx]
          has_been_allocated = True
      
      if not has_been_allocated:
        alloc_alu = round_robin_alloc
        round_robin_alloc = (round_robin_alloc + 1) % num_alus
      
      if ILN_eu_alloc_in_destRegIdx_valid[i]:
        ILN_eu_alloc_opx_locations[ILN_eu_alloc_in_destRegIdx[i]] = alloc_alu
      #reset batch tracker every alu_alloc_lookback_size instructions
      if ((i-1) % alu_alloc_lookback_size) == 0:
        ILN_eu_alloc_opx_locations_valid = np.zeros((arch_reg_idx_range,), dtype=bool)
      ILN_eu_alloc_opx_locations_valid[ILN_eu_alloc_in_destRegIdx[i]] = True
      
      ILN_eu_alloc_out[i] = alloc_alu

    MEM_ILN_eu_alloc_opx_locations = ILN_eu_alloc_opx_locations
    MEM_ILN_eu_alloc_opx_locations_valid = ILN_eu_alloc_opx_locations_valid

    print("EU allocations:")
    print(*ILN_eu_alloc_out, sep='\t')
    print()


    # ----------------------------------
    # ILN arch reg rename
    # ----------------------------------
    ILN_rename_in_opcode = ILN_ldstr_out_opcode
    ILN_rename_in_operands = (ILN_ldstr_out_op0, ILN_ldstr_out_op1)
    ILN_rename_in_op1v = ILN_ldstr_out_op1v
    ILN_rename_in_opm = (ILN_ldstr_out_op0m, ILN_ldstr_out_op1m)
    ILN_rename_in_destRegIdx = ILN_ldstr_out_opdIdx
    ILN_rename_in_eu_alloc = ILN_eu_alloc_out

    ILN_rename_addr_euidx = MEM_ILN_rename_addr_euidx
    ILN_rename_addr_uid = MEM_ILN_rename_addr_uid
    ILN_rename_addr_spec = MEM_ILN_rename_addr_spec
    ILN_rename_addr_valid = MEM_ILN_rename_addr_valid

    ILN_rename_reg_icon_track = np.zeros((arch_reg_idx_range,num_alus,2), dtype=bool) #2 for both opx

    ILN_rename_out_op0_imm = np.empty((instr_batch_size,), dtype=object)
    ILN_rename_out_op0_euidx = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_op0_uid = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_op0_spec = np.zeros((instr_batch_size,), dtype=int)
    #ILN_rename_out_op0_opx = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_op0m = np.empty(instr_batch_size, dtype=object)

    ILN_rename_out_op1_imm = np.empty((instr_batch_size,), dtype=object)
    ILN_rename_out_op1_euidx = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_op1_uid = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_op1_spec = np.zeros((instr_batch_size,), dtype=int)
    #ILN_rename_out_op1_opx = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_op1m = np.empty(instr_batch_size, dtype=object)
    ILN_rename_out_op1v = np.zeros((instr_batch_size,), dtype=bool)

    ILN_rename_out_opd_euidx = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_opd_uid = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_opd_spec = np.zeros((instr_batch_size,), dtype=int)
    
    ILN_rename_out_opcode = np.empty(instr_batch_size, dtype=object)
    ILN_rename_out_valid = np.zeros((instr_batch_size,), dtype=bool)

    ILN_rename_out_retire_valid = np.zeros((instr_batch_size,), dtype=bool)

    #need to save old reg tracker values before theyre overwritten
    #needed for icon ILN
    MEM_ILN_rename_addr_euidx_q = MEM_ILN_rename_addr_euidx
    MEM_ILN_rename_addr_uid_q = MEM_ILN_rename_addr_uid
    MEM_ILN_rename_addr_spec_q = MEM_ILN_rename_addr_spec
    MEM_ILN_rename_addr_valid_q = MEM_ILN_rename_addr_valid

    for i in range(instr_batch_size):
      alloc_alu = ILN_rename_in_eu_alloc[i]
      ILN_rename_out_opcode[i] = ILN_rename_in_opcode[i]

      #ignore instructions that wont be dispatched (e.g. ldr, str)
      if alloc_alu < 0:
        continue
      else:
        ILN_rename_out_valid[i] = True

      #str instruction handling
      #used to create mappings in the str tracker
      if ILN_rename_in_opcode[i] == "str":
        dataRegIdx = ILN_ldstr_out_opdIdx[i]
        MEM_ILN_str_tracker[0] = ILN_rename_in_operands[0][i] + '+' + ILN_rename_in_operands[1][i]
        #NOTE: this assumes str only appears after datareg is assigned at least ones
        MEM_ILN_str_tracker[1] = ILN_rename_addr_euidx[dataRegIdx]
        MEM_ILN_str_tracker[2] = ILN_rename_addr_uid[dataRegIdx]
        MEM_ILN_str_tracker[3] = ILN_rename_addr_spec[dataRegIdx]

      #srcs handling
      #Source register handling
      if ILN_rename_in_opm[0][i] == "reg":
        op0RegIdx = getArchRegIdx(ILN_rename_in_operands[0][i])
        if ILN_rename_addr_valid[op0RegIdx]:
          ILN_rename_out_op0_euidx[i] = ILN_rename_addr_euidx[op0RegIdx]
          ILN_rename_out_op0_uid[i] = ILN_rename_addr_uid[op0RegIdx]
          ILN_rename_out_op0_spec[i] = ILN_rename_addr_spec[op0RegIdx]
          ILN_rename_out_op0m[i] = "reg"
      elif ILN_rename_in_opm[0][i] == "mem":
        #for now, just always assume successful prefetch
        prefetch_successful = True
        if prefetch_successful:
          ILN_rename_out_op0m[i] = "imm"
          #ILN_rename_out_op0_imm[i] = "#1234" #temp
          mem_ops = ILN_rename_in_operands[0][i].split("+")
          mx_data = mx_reg_file[int(mem_ops[0].replace("m",""))] #note this assumes mx reg is always first operand (this is fine for proof of concept)
          mx_offset = int(mem_ops[1].replace("#",""))
          ILN_rename_out_op0_imm[i] = "#" + str(l0_cache[mx_data+mx_offset])
        else:
          ILN_rename_out_op0m[i] = "mem"
          ILN_rename_out_op0_imm[i] = ILN_rename_in_operands[0][i]
      else:
        ILN_rename_out_op0m[i] = "imm"
        ILN_rename_out_op0_imm[i] = ILN_rename_in_operands[0][i]
      
      if ILN_rename_in_op1v[i]:
        if ILN_rename_in_opm[1][i] == "reg":
          op1RegIdx = getArchRegIdx(ILN_rename_in_operands[1][i])
          if ILN_rename_addr_valid[op1RegIdx]:
            ILN_rename_out_op1_euidx[i] = ILN_rename_addr_euidx[op1RegIdx]
            ILN_rename_out_op1_uid[i] = ILN_rename_addr_uid[op1RegIdx]
            ILN_rename_out_op1_spec[i] = ILN_rename_addr_spec[op1RegIdx]
          ILN_rename_out_op1m[i] = "reg"
        elif ILN_rename_in_opm[1][i] == "mem":
          #for now, just always assume successful prefetch
          prefetch_successful = True
          if prefetch_successful:
            ILN_rename_out_op1m[i] = "imm"
            #ILN_rename_out_op1_imm[i] = "#1234" #temp
            mem_ops = ILN_rename_in_operands[1][i].split("+")
            #print(mem_ops)
            mx_data = mx_reg_file[int(mem_ops[0].replace("m",""))] #note this assumes mx reg is always first operand (this is fine for proof of concept)
            mx_offset = int(mem_ops[1].replace("#",""))
            ILN_rename_out_op1_imm[i] = "#" + str(l0_cache[mx_data+mx_offset])
          else:
            ILN_rename_out_op1m[i] = "mem"
            ILN_rename_out_op1_imm[i] = ILN_rename_in_operands[1][i]
        else:
          ILN_rename_out_op1m[i] = "imm"
          ILN_rename_out_op1_imm[i] = ILN_rename_in_operands[1][i]
        ILN_rename_out_op1v[i] = True
      else:
        ILN_rename_out_op1v[i] = False
      
      #dest reg handling
      #for now, assign new address for each instruction dest reg
      #in future, could look at address reuse mechanisms (e.g. for instructions
      #which exec in the same eu, the op0 address can become the opd address)
      #although it is looking that address reuse would be very difficult to do
      #(especially if wanting to support the eus themselves going out of order)
      destRegIdx = ILN_rename_in_destRegIdx[i]
      #if not ILN_rename_addr_valid[destRegIdx]:
      
      mappingChanged = True #since no address reuse, mapping always changes
      #if arch reg rename mapping changes, need to invalidate all instances of the old reg instance
      #in any rx buffers it was sent to and the y buffer in the eu that originally assigned this reg instance
      ILN_rename_out_retire_valid[i] = mappingChanged
      
      ILN_rename_addr_euidx[destRegIdx] = alloc_alu
      ILN_rename_addr_uid[destRegIdx] = 0
      ILN_rename_addr_spec[destRegIdx] = alu_cache_idx_counter[alloc_alu]
      ILN_rename_addr_valid[destRegIdx] = True
      
      alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alloc_alu)

      ILN_rename_out_opd_euidx[i] = ILN_rename_addr_euidx[destRegIdx]
      ILN_rename_out_opd_uid[i] = ILN_rename_addr_uid[destRegIdx]
      ILN_rename_out_opd_spec[i] = ILN_rename_addr_spec[destRegIdx]

    for regidx in range(arch_reg_idx_range):
      #if arch reg rename mapping changes, need to invalidate all instances of the old reg instance
      #in any rx buffers it was sent to and the y buffer in the eu that originally assigned this reg instance

      MEM_ILN_rename_addr_euidx[regidx] = ILN_rename_addr_euidx[regidx]
      MEM_ILN_rename_addr_uid[regidx] = ILN_rename_addr_uid[regidx]
      MEM_ILN_rename_addr_spec[regidx] = ILN_rename_addr_spec[regidx]
      MEM_ILN_rename_addr_valid[regidx] = ILN_rename_addr_valid[regidx]

    # ----------------------------------
    # ILN icon instruction gen
    # ----------------------------------

    ILN_icongen_destreg_prop = np.zeros((arch_reg_idx_range,num_alus,2), dtype=bool)
    ILN_icongen_destreg_prop_accumulated = MEM_ILN_icongen_destreg_prop_accumulated
    ILN_icongen_destreg_prop_src = []
    ILN_icongen_destreg_prop_src.append(MEM_ILN_rename_addr_euidx_q)
    ILN_icongen_destreg_prop_src.append(MEM_ILN_rename_addr_uid_q)
    ILN_icongen_destreg_prop_src.append(MEM_ILN_rename_addr_spec_q)
    ILN_icongen_destreg_prop_src.append(MEM_ILN_rename_addr_valid_q)

    ILN_icongen_out_icon_dist_destlist = np.zeros((instr_batch_size+arch_reg_idx_range,num_alus,2), dtype=bool)
    ILN_icongen_out_icon_src_addr_euidx = np.zeros((instr_batch_size+arch_reg_idx_range,), dtype=int)
    ILN_icongen_out_icon_src_addr_uid = np.zeros((instr_batch_size+arch_reg_idx_range,), dtype=int)
    ILN_icongen_out_icon_src_addr_spec = np.zeros((instr_batch_size+arch_reg_idx_range,), dtype=int)
    ILN_icongen_out_icon_invalidateSrc = np.zeros((instr_batch_size+arch_reg_idx_range,), dtype=bool)
    ILN_icongen_out_icon_valid = np.zeros((instr_batch_size+arch_reg_idx_range,), dtype=bool)

    ILN_icongen_out_retire_rxlist = np.zeros((instr_batch_size,num_alus,2), dtype=int)
    ILN_icongen_out_retire_euidx = np.zeros((instr_batch_size,), dtype=int)
    ILN_icongen_out_retire_uid = np.zeros((instr_batch_size,), dtype=int)
    ILN_icongen_out_retire_spec = np.zeros((instr_batch_size,), dtype=int)
    ILN_icongen_out_retire_valid = np.zeros((instr_batch_size,), dtype=int)
    
    #add this as future improvement instead. For now, both strx and stry will be constant 1
    #ILN_icongen_out_opd_strx = np.zeros((instr_batch_size,), dtype=bool)
    #ILN_icongen_out_opd_stry = np.zeros((instr_batch_size,), dtype=bool)

    for i in range(instr_batch_size):
      alloc_alu = ILN_rename_in_eu_alloc[i]

      #ignore instructions that wont be dispatched (e.g. ldr, str)
      if alloc_alu < 0:
        continue
      
      #src reg handling
      #srcs should just add eus to the dest lists
      if ILN_rename_in_opm[0][i] == "reg":
        op0RegIdx = getArchRegIdx(ILN_rename_in_operands[0][i])
        if not (ILN_eu_alloc_out[i] == ILN_rename_out_op0_euidx[i]):
          ILN_icongen_destreg_prop[op0RegIdx][ILN_eu_alloc_out[i]][0] = True
        
      if ILN_rename_in_op1v[i]:
        if ILN_rename_in_opm[1][i] == "reg":
          op1RegIdx = getArchRegIdx(ILN_rename_in_operands[1][i])
          if not (ILN_eu_alloc_out[i] == ILN_rename_out_op1_euidx[i]):
            ILN_icongen_destreg_prop[op1RegIdx][ILN_eu_alloc_out[i]][1] = True
            #print(ILN_icongen_destreg_prop)

      #accumulate dest lists
      for regidx in range(arch_reg_idx_range):
        ILN_icongen_destreg_prop_accumulated[destRegIdx] = ILN_icongen_destreg_prop_accumulated[destRegIdx] | ILN_icongen_destreg_prop[destRegIdx]

      #dest reg handling
      #for each dest reg, dispatch icon instr corresponding to the cache address
      #of the previous instance of that reg (i.e. the addr before reassignment)
      #then reset dest list back to 0
      destRegIdx = ILN_rename_in_destRegIdx[i]

      ILN_icongen_out_icon_src_addr_euidx[i] = ILN_icongen_destreg_prop_src[0][destRegIdx]
      ILN_icongen_out_icon_src_addr_uid[i] = ILN_icongen_destreg_prop_src[1][destRegIdx]
      ILN_icongen_out_icon_src_addr_spec[i] = ILN_icongen_destreg_prop_src[2][destRegIdx]
      
      ILN_icongen_out_retire_euidx[i] = ILN_icongen_destreg_prop_src[0][destRegIdx]
      ILN_icongen_out_retire_uid[i] = ILN_icongen_destreg_prop_src[1][destRegIdx]
      ILN_icongen_out_retire_spec[i] = ILN_icongen_destreg_prop_src[2][destRegIdx]
      
      hasdest = ILN_icongen_destreg_prop[destRegIdx].any()
      ILN_icongen_out_icon_valid[i] = hasdest
      ILN_icongen_out_icon_invalidateSrc[i] = True
      ILN_icongen_out_retire_valid[i] = True

      ILN_icongen_out_icon_dist_destlist[i] = ILN_icongen_destreg_prop[destRegIdx]
      ILN_icongen_out_retire_rxlist[i] = ILN_icongen_destreg_prop_accumulated[destRegIdx]
      ILN_icongen_destreg_prop[destRegIdx] = np.zeros((num_alus,2), dtype=bool)
      ILN_icongen_destreg_prop_accumulated[destRegIdx] = np.zeros((num_alus,2), dtype=bool)

      ILN_icongen_destreg_prop_src[0][destRegIdx] = ILN_rename_out_opd_euidx[i]
      ILN_icongen_destreg_prop_src[1][destRegIdx] = ILN_rename_out_opd_uid[i]
      ILN_icongen_destreg_prop_src[2][destRegIdx] = ILN_rename_out_opd_spec[i]
    
    #after batch, any outstanding dest lists (which appear
    #when src reg is not reassigned but is used in other eus)
    #should also be dispatched
    #print(ILN_icongen_destreg_prop)
    for i in range(instr_batch_size, instr_batch_size+arch_reg_idx_range):
      hasdest = ILN_icongen_destreg_prop[i-instr_batch_size].any()
      ILN_icongen_out_icon_valid[i] = hasdest
      ILN_icongen_out_icon_invalidateSrc[i] = False
      ILN_icongen_out_icon_src_addr_euidx[i] = ILN_icongen_destreg_prop_src[0][i-instr_batch_size]
      ILN_icongen_out_icon_src_addr_uid[i] = ILN_icongen_destreg_prop_src[1][i-instr_batch_size]
      ILN_icongen_out_icon_src_addr_spec[i] = ILN_icongen_destreg_prop_src[2][i-instr_batch_size]
      ILN_icongen_out_icon_dist_destlist[i] = ILN_icongen_destreg_prop[i-instr_batch_size]

    MEM_ILN_icongen_destreg_prop_accumulated = ILN_icongen_destreg_prop_accumulated

    # ----------------------------------
    # print output
    # instruction format code: 4 signals, iconmv(1) or alu(0), op0m, op1v, op1m
    # ----------------------------------
    output_formats = True
    for o in stdouts:
      sys.stdout = o
      for i in range(instr_batch_size):
        if ILN_icongen_out_icon_valid[i]:
          if output_formats:
            renamed_output_formats.write("1000\n")
          print("-2\ticonmv", end="\t")
          print(str(ILN_icongen_out_icon_src_addr_euidx[i]), end=",")
          print(str(ILN_icongen_out_icon_src_addr_uid[i]), end=",")
          print(str(ILN_icongen_out_icon_src_addr_spec[i]), end="\t")
          for j in range(num_alus):
            print(1 if ILN_icongen_out_icon_dist_destlist[i][j][0] else 0, end="")
            print(1 if ILN_icongen_out_icon_dist_destlist[i][j][1] else 0, end=",")
          print("\t" + str(ILN_icongen_out_icon_invalidateSrc[i]), end="")
          print()

        #leave retire instructions for now
        #if ILN_icongen_out_retire_valid[i]:
        #  print("-3\tretire", end="\t")
        #  print(str(ILN_icongen_out_retire_euidx[i]), end=",")
        #  print(str(ILN_icongen_out_retire_uid[i]), end=",")
        #  print(str(ILN_icongen_out_retire_spec[i]), end="\t")
        #  for j in range(num_alus):
        #    print(1 if ILN_icongen_out_retire_rxlist[i][j][0] else 0, end="")
        #    print(1 if ILN_icongen_out_retire_rxlist[i][j][1] else 0, end=",")
        #  print()

        if ILN_eu_alloc_out[i] < 0:
          continue
        
        print(ILN_eu_alloc_out[i], end="\t")
        print(ILN_rename_out_opcode[i], end="\t")

        print(ILN_rename_out_opd_euidx[i], end=",")
        print(ILN_rename_out_opd_uid[i], end=",")
        print(ILN_rename_out_opd_spec[i], end="\t")
        
        instr_fmt = 0
        if ILN_rename_out_op0m[i] == "reg":
          print(ILN_rename_out_op0_euidx[i], end=",")
          print(ILN_rename_out_op0_uid[i], end=",")
          print(ILN_rename_out_op0_spec[i], end="\t")
          instr_fmt |= 100
        else:
          print(str(ILN_rename_out_op0_imm[i]), end="\t")

        if ILN_rename_out_op1v[i] and (ILN_rename_out_op1m[i] == "reg"):
          print(ILN_rename_out_op1_euidx[i], end=",")
          print(ILN_rename_out_op1_uid[i], end=",")
          print(ILN_rename_out_op1_spec[i], end="\n")
          instr_fmt |= 11
        else:
          print(str(ILN_rename_out_op1_imm[i]), end="\n")
          instr_fmt |= int(ILN_rename_out_op1v[i]) * 10

        if output_formats:
            s = str(instr_fmt)
            for c in range(len(s), 4):
              s = "0" + s
            renamed_output_formats.write(s + "\n")  

      for i in range(instr_batch_size, instr_batch_size+arch_reg_idx_range):
        if ILN_icongen_out_icon_valid[i]:
          if output_formats:
            renamed_output_formats.write("1000\n")
          print("-2\ticonmv", end="\t")
          print(str(ILN_icongen_out_icon_src_addr_euidx[i]), end=",")
          print(str(ILN_icongen_out_icon_src_addr_uid[i]), end=",")
          print(str(ILN_icongen_out_icon_src_addr_spec[i]), end="\t")
          for j in range(num_alus):
            print(1 if ILN_icongen_out_icon_dist_destlist[i][j][0] else 0, end="")
            print(1 if ILN_icongen_out_icon_dist_destlist[i][j][1] else 0, end=",")
          print("\t" + str(ILN_icongen_out_icon_invalidateSrc[i]), end="")
          print()
      
      output_formats = False

  sys.stdout = original_stdout
  renamed_output.close()
  renamed_output_formats.close()


#arch_destreg_new_addr_eidx = alloc_alu
#      arch_destreg_new_addr_uid = 0
#      arch_destreg_new_addr_spec = alu_cache_idx_counter[alloc_alu]
#      arch_destreg_new_addr_valid = True
