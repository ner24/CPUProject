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
             num_alus: int = 4,
             alu_alloc_lookback_size: int = 2,
             arch_reg_idx_range: int = getNumArchReg(),
             str_tracker_ram_size: int = 16) -> List[dict]:
  
  alu_cache_idx_counter: dict = {}
  for i in range(0, num_alus):
    alu_cache_idx_counter[i] = 0

  num_evaluated_instr: int = 0

  # ----------------------------------------
  # memory units within the ILN pipeline
  # ----------------------------------------
  #reg tracker will have to be made up of individual registers for each arch
  #register. This is fine as there wont be that many anyway
  MEM_ILN_rename_addr_euidx = np.zeros((arch_reg_idx_range,), dtype=int)
  MEM_ILN_rename_addr_uid = np.zeros((arch_reg_idx_range,), dtype=int)
  MEM_ILN_rename_addr_spec = np.zeros((arch_reg_idx_range,), dtype=int)
  MEM_ILN_rename_addr_valid = np.zeros((arch_reg_idx_range,), dtype=bool)

  MEM_ILN_ldstr_ldprop_val = np.empty(arch_reg_idx_range, dtype=object)
  MEM_ILN_ldstr_ldprop_val_valid = np.zeros((arch_reg_idx_range,), dtype=bool)

  MEM_ILN_str_tracker = np.zeros((str_tracker_ram_size,2), dtype=int) #first attribute: tag addr, second attribute: corresponding backend cache addr
  MEM_ILN_str_regaddr_map = np.zeros((arch_reg_idx_range,), dtype=int)

  while num_evaluated_instr < len(instructions):
    instr_batch_size = max_instr_batch_size if len(instructions) - num_evaluated_instr >= max_instr_batch_size else len(instructions) - num_evaluated_instr

    print("-------------------------batch separator-------------------------")

    #decode instructions (makes the rest of the model easier to write)
    instructions_batch: List[dict] = []
    for i in range(0, instr_batch_size):
      valid, instr, destReg, srcs = decompInstruction(instructions[num_evaluated_instr + i])
      if not valid:
        print("Malformed instruction detected")
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
        op0, op0m = srcs[0]["value"], srcs[0]["type"]
        if op0m == "reg" and ILN_ldstr_ldprop_val_valid[getArchRegIdx(op0)]:
          sRegIdx = getArchRegIdx(op0)
          #if ILN_ldstr_ldprop_val_valid[sRegIdx]:
          ILN_ldstr_out_op0[i] = ILN_ldstr_ldprop_val[sRegIdx]
          ILN_ldstr_out_op0m[i] = "imm"
        else:
          ILN_ldstr_out_op0[i] = srcs[0]["value"]
          ILN_ldstr_out_op0m[i] = srcs[0]["type"]
        if len(srcs) == 2:
          ILN_ldstr_out_op1v[i] = True
          op1, op1m = srcs[1]["value"], srcs[1]["type"]
          if op1m == "reg" and ILN_ldstr_ldprop_val_valid[getArchRegIdx(op1)]:
            sRegIdx = getArchRegIdx(op1)
            #if ILN_ldstr_ldprop_val_valid[sRegIdx]:
            ILN_ldstr_out_op1[i] = ILN_ldstr_ldprop_val[sRegIdx]
            ILN_ldstr_out_op1m[i] = "imm"
          else:
            ILN_ldstr_out_op1[i] = srcs[1]["value"]
            ILN_ldstr_out_op1m[i] = srcs[1]["type"]
        else:
          ILN_ldstr_out_op1v[i] = False
        
        if "value" in destReg:
          destRegIdx = getArchRegIdx(destReg["value"])
          ILN_ldstr_ldprop_val_valid[destRegIdx] = False
          ILN_ldstr_out_opdIdx[i] = destRegIdx
          ILN_ldstr_out_opdIdx_valid[i] = True
        else:
          ILN_ldstr_out_opdIdx_valid[i] = False

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

    ILN_eu_alloc_opx_locations = np.zeros((arch_reg_idx_range,), dtype=int)
    ILN_eu_alloc_opx_locations_valid = np.zeros((arch_reg_idx_range,), dtype=bool)
    round_robin_alloc = 0
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

    ILN_rename_out_icon_dist_destlist = np.zeros((instr_batch_size,num_alus,2), dtype=bool)
    ILN_rename_out_icon_src_addr_euidx = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_icon_src_addr_uid = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_icon_src_addr_spec = np.zeros((instr_batch_size,), dtype=int)
    ILN_rename_out_icon_valid = np.zeros((instr_batch_size,), dtype=bool)

    for i in range(instr_batch_size-1, -1, -1):
      alloc_alu = ILN_rename_in_eu_alloc[i]
      ILN_rename_out_opcode[i] = ILN_rename_in_opcode[i]

      #ignore instructions that wont be dispatched (e.g. ldr, str)
      if alloc_alu < 0:
        continue
      else:
        ILN_rename_out_valid[i] = True
      
      #dest reg handling
      destRegIdx = ILN_rename_in_destRegIdx[i]
      if not ILN_rename_addr_valid[destRegIdx]:
        ILN_rename_addr_euidx[destRegIdx] = alloc_alu
        ILN_rename_addr_uid[destRegIdx] = 0
        ILN_rename_addr_spec[destRegIdx] = alu_cache_idx_counter[alloc_alu]
        ILN_rename_addr_valid[destRegIdx] = True
        
        alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alloc_alu)

      else:
        #when reg is about to be reassigned (i.e. is a destReg)
        #dispatch icon instruction to all eus that requested that destreg up until this point
        ILN_rename_out_icon_dist_destlist[i] = ILN_rename_reg_icon_track[destRegIdx]
        for c in range(num_alus):
          ILN_rename_reg_icon_track[destRegIdx][c][0] = False
          ILN_rename_reg_icon_track[destRegIdx][c][1] = False
        ILN_rename_out_icon_src_addr_euidx[i] = ILN_rename_addr_euidx[destRegIdx]
        ILN_rename_out_icon_src_addr_uid[i] = ILN_rename_addr_uid[destRegIdx]
        ILN_rename_out_icon_src_addr_spec[i] = ILN_rename_addr_spec[destRegIdx]
        ILN_rename_out_icon_valid[i] = True

      ILN_rename_out_opd_euidx[i] = ILN_rename_addr_euidx[destRegIdx]
      ILN_rename_out_opd_uid[i] = ILN_rename_addr_uid[destRegIdx]
      ILN_rename_out_opd_spec[i] = ILN_rename_addr_spec[destRegIdx]

      #Source register handling
      if ILN_rename_in_opm[0][i] == "reg":
        op0RegIdx = getArchRegIdx(ILN_rename_in_operands[0][i])
        if ILN_rename_addr_valid[op0RegIdx]:
          if not (ILN_rename_addr_euidx[op0RegIdx] == alloc_alu):
            ILN_rename_reg_icon_track[op0RegIdx][alloc_alu][0] = True
          ILN_rename_out_op0_euidx[i] = ILN_rename_addr_euidx[op0RegIdx]
          ILN_rename_out_op0_uid[i] = ILN_rename_addr_uid[op0RegIdx]
          ILN_rename_out_op0_spec[i] = ILN_rename_addr_spec[op0RegIdx]
          ILN_rename_out_op0m[i] = "reg"
      else:
        ILN_rename_out_op0m[i] = "imm"
        ILN_rename_out_op0_imm[i] = ILN_rename_in_operands[0][i]
      
      if ILN_rename_in_op1v[i]:
        if ILN_rename_in_opm[1][i] == "reg":
          op1RegIdx = getArchRegIdx(ILN_rename_in_operands[1][i])
          if ILN_rename_addr_valid[op1RegIdx]:
            if not (ILN_rename_addr_euidx[op1RegIdx] == alloc_alu):
              ILN_rename_reg_icon_track[op1RegIdx][alloc_alu][1] = True
            ILN_rename_out_op1_euidx[i] = ILN_rename_addr_euidx[op1RegIdx]
            ILN_rename_out_op1_uid[i] = ILN_rename_addr_uid[op1RegIdx]
            ILN_rename_out_op1_spec[i] = ILN_rename_addr_spec[op1RegIdx]
          ILN_rename_out_op1m[i] = "reg"
        else:
          ILN_rename_out_op1m[i] = "imm"
          ILN_rename_out_op1_imm[i] = ILN_rename_in_operands[1][i]
        ILN_rename_out_op1v[i] = True
      else:
        ILN_rename_out_op1v[i] = False


    #print renamed instructions
    for i in range(instr_batch_size):
      if ILN_rename_out_icon_valid[i]:
        print("iconmv", end="\t")
        print(str(ILN_rename_out_icon_src_addr_euidx[i]), end=",")
        print(str(ILN_rename_out_icon_src_addr_uid[i]), end=",")
        print(str(ILN_rename_out_icon_src_addr_spec[i]), end="\t")
        for j in range(num_alus):
          print(1 if ILN_rename_out_icon_dist_destlist[i][j][0] else 0, end="")
          print(1 if ILN_rename_out_icon_dist_destlist[i][j][1] else 0, end=",")
        print()
      
      print(ILN_rename_out_opcode[i], end="\t")

      print(ILN_rename_out_opd_euidx[i], end=",")
      print(ILN_rename_out_opd_uid[i], end=",")
      print(ILN_rename_out_opd_spec[i], end="\t")
      
      if ILN_rename_out_op0m[i] == "reg":
        print(ILN_rename_out_op0_euidx[i], end=",")
        print(ILN_rename_out_op0_uid[i], end=",")
        print(ILN_rename_out_op0_spec[i], end="\t")
      else:
        print("#" + str(ILN_rename_out_op0_imm[i]), end="\t")

      if ILN_rename_out_op1v[i] and (ILN_rename_out_op1m[i] == "reg"):
        print(ILN_rename_out_op1_euidx[i], end=",")
        print(ILN_rename_out_op1_uid[i], end=",")
        print(ILN_rename_out_op1_spec[i], end="\n")
      else:
        print("#" + str(ILN_rename_out_op1_imm[i]), end="\n")
      

    # ----------------------------------
    # ILN str
    # ----------------------------------
    ILN_str_prop_regaddr = MEM_ILN_str_regaddr_map

    for i in range(instr_batch_size-1, -1, -1):
      instr = ILN_ldstr_in[i]
      srcs = instr["srcs"]
      dataReg = srcs[0]
      dataRegIdx = getArchRegIdx(dataReg)

      #if instr["instr"] == "str":
        #in str instruction, there is no dest reg
        #(written like that for dependency graph gen reasons)
        #reg containing the data is srcs[0]
      #  if len(srcs == 2):
      #    ILN_str_prop_regaddr[dataRegIdx] = 