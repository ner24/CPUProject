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
    if(alu_cache_idx_counter[alu_idx]) == 20: #set to high value. TODO: handle repeatedly allocated locations used for different values
                                              # i.e. when the counter resets and gives two different pieces of data, since order cannot
                                              # be controlled, an instruction looking for the new data may pick up the old data instead
                                              # may have to bring back dependency idx to fix this
      alu_cache_idx_counter[alu_idx] = 0
  else:
    alu_cache_idx_counter[alu_idx] = 0
  return alu_cache_idx_counter

def allocate(instructions: List[str], max_instr_batch_size: int = 10, num_alus: int = 10) -> List[dict]:
  
  #Will be implemented as memory cells unlike the batch tracker which is effectively an
  #iterative logic network
  register_tracker: dict = {}

  alu_idx_counter: int = 0
  alu_cache_idx_counter: dict = {}
  for i in range(0, num_alus):
    alu_cache_idx_counter[i] = 0

  #output
  renamedInstructions: List[dict] = []
  num_evaluated_instr: int = 0

  while num_evaluated_instr < len(instructions):
    instr_batch_size = max_instr_batch_size if len(instructions) - num_evaluated_instr >= max_instr_batch_size else len(instructions) - num_evaluated_instr
    
    #process in batches of 10 instructions. Batch register tracker will be reset for every batch
    #The batch tracker will be implemented as intercell signals between an iterative logic network cells
    #Note the possible propagation and max clk speed decrease as the batch size increases
    register_tracker_batch: dict = {}

    #decode instructions (makes the rest of the model easier to write)
    instructions_batch: List[dict] = []
    for i in range(0, instr_batch_size):
      valid, instr, destReg, srcs = decompInstruction(instructions[num_evaluated_instr + i])
      if not valid:
        print("Malformed instruction detected")
        sys.exit(1)
      instructions_batch.append({
        "instr": instr,
        "destReg": destReg,
        "srcs": srcs
      })

    #the icon_mv_instructions_batch store of the mv instructions to be dispatched to the interconnect
    #before the batch itself is dispatched. These mv instructions align the reg tracker with the reg_tracker_batch
    #(i.e. it is what the redistribute phase did in previous versions of this allocator)
    icon_mv_instructions_batch: List[dict] = []
    renamedInstructions_batch: List[dict] = []
    for i in range(instr_batch_size-1, -1, -1):
      instr = instructions_batch[i]
      srcs = instr["srcs"]
      destReg = instr["destReg"]
      #opcode = instr["instr"]
      print("Evaluating: " + str(instr["instr"]) + " : " + str(instr["destReg"]) + " < " + str(instr["srcs"]))

      #TODO: str handling
      if instr["instr"] == "str":
        continue

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
      if instr["instr"] == "ldr":
        #because renamedInstructions starts with 0 elements and is appended every time, it needs a different counter
        c: int = 1
        for j in range(i+1, instr_batch_size):
          print("Ld remap: iter=" + str(c) + ": " + str(instructions_batch[j]["srcs"]))
          print("Ld renamed before: " + str(renamedInstructions_batch[len(renamedInstructions_batch) - c]["srcs"]))
          #go through all instructions after the ld (when not reverse order) and check all source registers
          #if one of the source reg equals the dest reg of the load, remap to memory
          #print(instr["srcs"])
          for k in range(len(instructions_batch[j]["srcs"])-1, -1, -1):
            if instructions_batch[j]["srcs"][k] == instr["destReg"]:
              if len(instr["srcs"]) == 2:
                renamedInstructions_batch[len(renamedInstructions_batch) - c]["srcs"][k] = {
                  "immValue": "memval@" + instr["srcs"][0]["value"] + '+' + instr["srcs"][1]["value"]
                }
              else:
                renamedInstructions_batch[len(renamedInstructions_batch) - c]["srcs"][k] = {
                  "immValue": "memval@" + instr["srcs"][0]["value"]
                }
          print("Ld renamed after: " + str(renamedInstructions_batch[len(renamedInstructions_batch) - c]["srcs"]))
          
          #Block condition
          #should run after srcs check to account for cases where the matching reg is a src and a dest
          if instructions_batch[j]["destReg"] == instr["destReg"]:
            break
          #since ldr instructions are not added to rename list, should not increment c
          if not instructions_batch[j]["instr"] == "ldr":
            c = c + 1
        continue


      #Source register handling (and alu allocation)
      alloc_alu: int = -1
      renamedSrcs: List[dict] = []
      for s in instr["srcs"]:
        print("Src: " + str(s))
        print("alloc_alu: " + str(alloc_alu))
        if s["type"] == "reg":
          #if reg not in register_tracker_batch, then default back to register_tracker value.
          #if srcs are in different alus, then send a redistribute instruction
          if s["value"] in register_tracker_batch and alloc_alu == -1:
            #if reg is in batch reg tracker, then it has already been used as a dest reg. If so, the earlier read
            #instructions (ones which are later as reading backwards) that use this reg as a src
            #should use that reg from a different file as the later instructions dont use that "reg instance" anymore
            #from the point of view of the allocator, this should just involve resetting the batch reg tracker for that reg
            if register_tracker_batch[s["value"]]["dest_state"] == 0:
              #allocate to alu where the first src is
              alloc_alu = register_tracker_batch[s["value"]]["alu_idx"]

          #allocated alu should be set to wherever one of the sources is (in this case the first one)
          #if other sources are taken from reg tracker and are in another alu, dispatch a move to the interconnect
          else:
            #if no alu allocated via existing entries in caches, do a round robin allocate (for now)
            if alloc_alu == -1:
              alloc_alu = alu_idx_counter
              alu_idx_counter = alu_idx_counter + 1
              if alu_idx_counter == num_alus:
                alu_idx_counter = 0
            
            #generate a cache address in the allocated alu for the src
            register_tracker_batch[s["value"]] = {
              "alu_idx": alloc_alu,
              "alu_cache_idx": alu_cache_idx_counter[alu_idx_counter],
              "opx": 0, #TODO: sort out opx
              "dest_state": 0
            }
            alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alu_idx_counter)

          renamedSrcs.append(register_tracker_batch[s["value"]])
        else:
          renamedSrcs.append({
            "immValue": s["value"]
          })
          #if no alu allocated via existing entries in caches, do a round robin allocate (for now)
          if alloc_alu == -1:
            alloc_alu = alu_idx_counter
            alu_idx_counter = alu_idx_counter + 1
            if alu_idx_counter == num_alus:
              alu_idx_counter = 0
      
      #dest reg handling
      #all this needs to do is allocate a cache location if one isnt already allocated
      #print(destReg)
      if destReg["value"] not in register_tracker_batch:
        #assign destination reg to next ALU idx (i.e. this is round robin dispatch)
        #TODO: setup an ALU queue tracker to better optimise ALU usage. e.g. dispatch to 
        #ALU with smallest current queue size. Round robin is still being considered for simplicity
        print("Adding destreg: " + destReg["value"] + " " + str(alloc_alu) + str(alu_cache_idx_counter[alloc_alu]))
        register_tracker_batch[destReg["value"]] = {
          "alu_idx": alloc_alu,
          "alu_cache_idx": alu_cache_idx_counter[alloc_alu],
          "opx": 0,
          "dest_state": 1 #if most recently evaluated instr used the reg as dest, then set to 1
        }
        alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alloc_alu)
        
      #Construct the renamed instruction
      renamedInstructions_batch.append({
        "alu_idx": alloc_alu,
        "instruction": instr["instr"],
        "destReg": register_tracker_batch[destReg["value"]],
        "srcs": renamedSrcs
      })

    #redistribute phase
    #This can also be implemented as a carry chain going from first to last (in forward order)
    #the blocking condition is when the register is seen as a dest reg in the cell

    #finalise and append
    renamedInstructions = renamedInstructions + icon_mv_instructions_batch
    renamedInstructions = renamedInstructions + list(reversed(renamedInstructions_batch))

    num_evaluated_instr = num_evaluated_instr + instr_batch_size

  return renamedInstructions
