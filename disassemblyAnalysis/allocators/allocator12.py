import sys, pathlib, os
if sys.platform == 'win32':
  path = pathlib.Path(r'C:\\Program Files\\Graphviz\\bin')
  if path.is_dir() and str(path) not in os.environ['PATH']:
    os.environ['PATH'] += f';{path}'
import pygraphviz as pgv
from typing import List
from graphGen import decompInstruction

def get_next_alu_cache_idx(alu_cache_idx_counter: dict, alu_idx: int) -> dict:
  if alu_idx in alu_cache_idx_counter:
    alu_cache_idx_counter[alu_idx] = alu_cache_idx_counter[alu_idx] + 1
    if(alu_cache_idx_counter[alu_idx]) == 4:
      alu_cache_idx_counter[alu_idx] = 0
  else:
    alu_cache_idx_counter[alu_idx] = 0
  return alu_cache_idx_counter

def allocate(instructions: List[str]) -> List[dict]:
  
  #Will be implemented as memory cells unlike the batch tracker which is effectively an
  #iterative logic network
  register_tracker: dict = {}

  alu_idx_counter: int = 0
  alu_cache_idx_counter: dict = {}
  alu_cache_idx_counter[0] = 0
  
  max_instr_batch_size = 10

  #output
  renamedInstructions: List[dict] = []
  num_evaluated_instr: int = 0
  while num_evaluated_instr < len(instructions):
    #process in batches of 10 instructions. Batch register tracker will be reset for every batch
    #The batch tracker will be implemented as intercell signals between an iterative logic network cells
    #Note the possible propagation and max clk speed decrease as the batch size increases
    register_tracker_batch: dict = {}
    renamedInstructions_batch: List[dict] = []

    instr_batch_size = max_instr_batch_size if len(instructions) - num_evaluated_instr >= max_instr_batch_size else len(instructions) - instr_batch_size 

    #LOAD STAGE
    #Scans for load instructions, fetches them and also updates the batch tracker
    ld_reg_tracker: dict = {}
    for i in range(0, instr_batch_size):
      print("Load stage eval: " + instructions[num_evaluated_instr + i])
      valid, instr, destReg, srcs = decompInstruction(instructions[num_evaluated_instr + i])
      
      #ignore invalid instructions (i.e. malformed input)
      if not valid:
        print("Invalid instruction detected")
        sys.exit(1)
      
      #ld instructions should be evaluated as immediates
      #as they will be parsed to the alus from the ld buffer through the IQueue
      if instr == "ldr":
        ld_reg_tracker[destReg["value"]] = {
          "ld": "memval"
        }
        #ld should not be parsed to alus, so dont need to rename. The memory interface (ld buffer etc.) should
        #be able to fully evaluate and return the requested data which will be parsed as an immediate in the renamed
        #instruction (NOTE: the memory controller will need store locks to stop read before writes due to out of order (
        #also, if a ld uses a reg that is store locked, then this would be a writeback cancel))
    
    print(ld_reg_tracker)

    #RENAME STAGE
    for i in range(instr_batch_size-1, -1, -1):
      print("rename stage eval: " + instructions[num_evaluated_instr + i])
      valid, instr, destReg, srcs = decompInstruction(instructions[num_evaluated_instr + i])
      
      #str instructions in this model (for now) should just extract values from alu caches and into data cache through
      #interconnect
      if instr == "str":
        renamedInstructions_batch.append({
          "alu_idx": -1,
          "instruction": "iconmv",
          "destReg": {
            "alu_idx": -1,
            "alu_cache_idx": -1,
            "opx": -1,
            "dest_state": 0
          },
          "srcs": [ register_tracker[r] ]
        })
        continue

      if instr == "ldr":
        continue

      #if source registers are unallocated, allocate them to the same alu cache as the destination reg
      i_temp: int = 0
      #print(srcs)
      for s in srcs:
        if s["type"] == "reg":
          #print(s)
          if s["value"] in register_tracker_batch:
            #if "ld" in register_tracker_batch[s["value"]]: #ld shouldnt exist in batch tracker anymore
            #  continue
            #if reg is in batch reg tracker, then it has already been used as a dest reg. If so, the earlier
            #instructions (ones which are read in later here as reading backwards) that use this reg as a src
            #should use that reg from a different file as the later instructions dont use that "reg instance" anymore
            #from the point of view of the allocator, this should just involve resetting the batch reg tracker for that reg
            if register_tracker_batch[s["value"]]["dest_state"] == 0:
              #dependencyCounters[s["value"]] = dependencyCounters[s["value"]] + 1
              #del register_tracker_batch[s["value"]]
              continue
          
          #print("Adding to tracker: " + s["value"])
          register_tracker_batch[s["value"]] = {
            "alu_idx": register_tracker_batch[destReg["value"]]["alu_idx"],
            "alu_cache_idx": alu_cache_idx_counter[alu_idx_counter],
            "opx": i_temp % 2,
            "dest_state": 0
          }
          i_temp = i_temp + 1
          alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alu_idx_counter)

      #construct renamed instruction that would be dispatched
      alu_alloc_idx = -1
      print(register_tracker_batch)
      renamedSrcs: List[dict] = []
      for s in srcs:
        #if "ld" in s: #idek what this is
        #  renamedSrcs.append("#" + str(s["ld"]))
        if s["type"] == "reg":
          renamedSrcs.append(register_tracker_batch[s["value"]])
          if alu_alloc_idx == -1 and "ld" not in register_tracker_batch[s["value"]]:
            alu_alloc_idx = register_tracker_batch[s["value"]]["alu_idx"]
        else:
          renamedSrcs.append({
            "immValue": s["value"]
          })
      
      if alu_alloc_idx == -1:
        alu_alloc_idx = alu_idx_counter #allocate instruction in round robin if no restriction due to src locations
        alu_idx_counter = alu_idx_counter + 1
        if alu_idx_counter == 9: #set num alus to 10 for now
          alu_idx_counter = 0
        alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alu_idx_counter)

      #print(destReg)
      #print(instr)
      if (destReg["value"] not in register_tracker_batch) or ("ld" in register_tracker_batch[destReg["value"]]):
        #assign destination reg to next ALU idx (i.e. this is round robin dispatch)
        #TODO: setup an ALU queue tracker to better optimise ALU usage. e.g. dispatch to 
        #ALU with smallest current queue size. Round robin is still being considered for simplicity
        print("Adding destreg: " + destReg["value"])
        register_tracker_batch[destReg["value"]] = {
          "alu_idx": alu_alloc_idx,
          "alu_cache_idx": alu_cache_idx_counter[alu_alloc_idx],
          "opx": 0,
          "dest_state": 1 #if most recently evaluated instr used the reg as dest, then set to 1
        }
        alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alu_alloc_idx)

      #print(renamedSrcs[0])
      renamedInstructions_batch.append({
        "alu_idx": alu_alloc_idx, #all srcs should be in same alu. instruction should exec in same alu as srcs
        "instruction": instr,
        "destReg": register_tracker_batch[destReg["value"]],
        "srcs": renamedSrcs
      })

    #ld assign and redistribute data phase v2
    #This will be implemented as a carry chain between the cells (on
    #top of the reg tracker intercell signals)
    #ld assign:
    # requires a scan of all sources in instructions after the ld instruction
    # if any of the sources match the dest reg of the ld instruction, that source
    # should be reassigned to the value for that reg in the load register (and load it into
    # the renamed instruction as an intermediate)
    # This can actually be combined into one process with the load stage and implemented in
    # the same phase as the rename stage. Just means more intercell signals
    # The ld carry chain would work with the following gen, prop and block rules:
    # - Generate: if cell receives ld instruction, generate down the ld line with 
    # - Propagate: if cell does not have the reg that is being loaded as a dest reg
    #              if the reg is found as a source, actively mark to be loaded.
    #              it will then be loaded in another cycle to give the mmu time to fetch the data
    #              and also avoid having to propagate the actual immedate and creating a really wide intercell bus
    # - Block: if the cell contains the reg as a dest reg. Means from that point, that reg is overwritten
    for reg in ld_reg_tracker:
      for i in range(0, instr_batch_size):
        valid, instr, destReg, srcs = decompInstruction(instructions[num_evaluated_instr + i])
        #ignore load instructions here as they were handled earlier
        if instr == "ldr":
          break
        #Block
        if destReg == reg:
          break
        #Remap
        else:
          for j in range(0, len(renamedInstructions_batch[i]["srcs"])):
            if renamedInstructions_batch[i]["srcs"][j]

    #Redistribute data phase
    #This should compare the register tracker batch alu indexes to the
    #main register tracker alu indexes. Each batch is evaluated to be
    #as parallel as possible. For now, the redistribute phase should just
    #transfer data from where they currently are (i.e. from where the main tracker says)
    #to where the batch tracker says they should be
    #This type of setup means that interconnect micro ops can simply be a concatenation
    #of the two tracker values for each register (assuming 4 lanes and 16 total reg means
    #this phase would take at least 4 cycles (TODO: since interconnect arbitration is gone,
    #having extra interconnect lanes should be easier to implement. Consider this))
    for r in register_tracker_batch:
      #print(r)
      if r in register_tracker:
        #if "ld" in register_tracker_batch[r]:

        #else:
          renamedInstructions_batch.append({
            "alu_idx": -1,
            "instruction": "iconmv",
            "destReg": register_tracker_batch[r],
            "srcs": [ register_tracker[r] ]
          })
      else:
        register_tracker[r] = register_tracker_batch[r]

    #Flip buffer (since the instructions (inclulding redist phase ))
    reversed_renamedInstructions_batch: List[dict] = []
    for i in range(len(renamedInstructions_batch)-1, -1, -1):
      reversed_renamedInstructions_batch.append(renamedInstructions_batch[i])
    renamedInstructions = renamedInstructions + reversed_renamedInstructions_batch
    for i in renamedInstructions_batch:
      print(i)

    num_evaluated_instr = num_evaluated_instr + instr_batch_size

  return renamedInstructions