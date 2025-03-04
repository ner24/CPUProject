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

def allocate(instructions: List[str], max_instr_batch_size: int = 10, num_alus: int = 10, alu_alloc_lookback_size: int = 4) -> List[dict]:
  
  #Will be implemented as memory cells unlike the batch tracker which is effectively an
  #iterative logic network
  register_tracker: dict = {}

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

    #contains the allocated alu for each instruction in the batch
    alu_alloc_arr = []

    #alu alloc
    #might implement as another iterative logic circuit that sits before
    #the rename ILN
    round_robin_alloc = 0
    for i in range(instr_batch_size):
      instr = instructions_batch[i]
      srcs = instr["srcs"]
      destReg = instr["destReg"]

      #alu alloc only applies to instructions that get dispatched
      #and are not resolved internally by the front end
      if instr["instr"] == "str" or instr["instr"] == "ldr":
        alu_alloc_arr.append(-2)
        continue
      
      #rules:
      #check if dependent on previous alu_alloc_lookback_size instructions (in forward direction)
      #if yes, allocate to same alu as dependent, else, allocate to next alu pointed by
      #round robin counter
      #in this setup, the first src is prioritised over the second
      has_been_allocated = False
      for s in srcs:
        if s["type"] == "reg" and not has_been_allocated:
          if s["value"] in register_tracker_batch:
            alloc_alu = register_tracker_batch[s["value"]]["alu_idx"]
            has_been_allocated = True
          elif s["value"] in register_tracker:
            alloc_alu = register_tracker[s["value"]]["alu_idx"]
            has_been_allocated = True
      
      if not has_been_allocated:
        alloc_alu = round_robin_alloc
        round_robin_alloc = (round_robin_alloc + 1) % num_alus
          
      register_tracker_batch[destReg["value"]] = {"alu_idx": alloc_alu}
      #reset batch tracker every alu_alloc_lookback_size instructions
      if ((i-1) % alu_alloc_lookback_size) == 0:
        register_tracker_batch = {}
      
      alu_alloc_arr.append(alloc_alu)

    # reset batch reg tracker before rename
    register_tracker_batch: dict = {}

    # track icon instructions to add additional receivers if multiple parallel instrs using same reg instance
    reg_icon_instr_tracker: dict = {}
    print(alu_alloc_arr)
    renamedInstructions_batch: List[dict] = []
    for i in range(instr_batch_size-1, -1, -1):
      instr = instructions_batch[i]
      srcs = instr["srcs"]
      destReg = instr["destReg"]
      #opcode = instr["instr"]
      print("Evaluating: " + str(instr["instr"]) + " : " + str(instr["destReg"]) + " < " + str(instr["srcs"]))

      alloc_alu = alu_alloc_arr[i]

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
        #for j in range(instr_batch_size-1, i, -1):
        for j in range(i+1, instr_batch_size):
          #print()
          #print("Ld remap: renamed_instr=" + str(len(renamedInstructions_batch) - c) + ": " + str(instructions_batch[j]["srcs"]))
          #print("Ld renamed before: " + str(renamedInstructions_batch[len(renamedInstructions_batch) - c]["srcs"]))
          
          #ignore generated interconnect instructions
          print(c)
          try:
            while renamedInstructions_batch[len(renamedInstructions_batch) - c]["instruction"] == "iconmv":
              c += 1
          except IndexError:
            continue #happens when ld is evaluated but no instructions after (in forward dir) were alu instr
                     #meaning renamedInstructions_batch is still empty
          #print("After incon skip: renamed_instr=" + str(len(renamedInstructions_batch) - c) + ": " + str(instructions_batch[j]["srcs"]))
          #print(len(renamedInstructions_batch) - c)
          #print(j)

          #go through all instructions after the ld (when not reverse order) and check all source registers
          #if one of the source reg equals the dest reg of the load, remap to memory
          for k in range(len(instructions_batch[j]["srcs"])):
            #print(k)
            #print(instructions_batch[j]["srcs"])
            #print(renamedInstructions_batch[len(renamedInstructions_batch) - c]["srcs"])
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

      
      #dest reg handling
      #all this needs to do is allocate a cache location if one isnt already allocated
      #(this is really only applicable to final usages of a register within a batch)
      if destReg["value"] not in register_tracker_batch:
        #assign destination reg to next ALU idx (i.e. this is round robin dispatch)
        print("Adding destreg: " + destReg["value"] + " " + str(alloc_alu) + str(alu_cache_idx_counter[alloc_alu]))
        register_tracker_batch[destReg["value"]] = {
          "alu_idx": alloc_alu,
          "alu_cache_idx": alu_cache_idx_counter[alloc_alu],
          "opx": 0,
          "dest_state": 1 #if most recently evaluated instr used the reg as dest, then set to 1
        }
        alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alloc_alu)

      #also reset and dispatch icon for when reg instance is discarded when instr has it a dest reg
      if destReg["value"] in reg_icon_instr_tracker:
        dest_eus_str = ""
        for n in reg_icon_instr_tracker[destReg["value"]]:
          dest_eus_str += str(n)
        renamedInstructions_batch.append({
          "alu_idx": -1,
          "instruction": "iconmv",
          "destReg": {
            "alu_idx": dest_eus_str,
            "alu_cache_idx": "",
            "opx": ""
          },
          "srcs": [ register_tracker_batch[destReg["value"]] ]
        })
        del reg_icon_instr_tracker[destReg["value"]]

      #reallcoate
      dest_reg_map_cpy = register_tracker_batch[destReg["value"]]
      del register_tracker_batch[destReg["value"]]

      #Source register handling
      renamedSrcs: List[dict] = []
      for s in instr["srcs"]:
        if s["type"] == "reg":
          #if not in register_tracker_batch, generate new address in allocated eu
          #if srcs are in different alus, then send a icon instruction
          if s["value"] not in register_tracker_batch:
            #generate a cache address in the allocated alu for the src
            register_tracker_batch[s["value"]] = {
              "alu_idx": alloc_alu,
              "alu_cache_idx": alu_cache_idx_counter[alloc_alu],
              "opx": 0, #TODO: sort out opx
              "dest_state": 0
            }
            alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alloc_alu)
          #else:
            #if not equal, then need icon instruction to move it to allocated alu's tx buffer
            #print("src: " + str(s["value"]) + " alloc: " + str(alloc_alu))
          if not (register_tracker_batch[s["value"]]["alu_idx"] == alloc_alu):# or not (dest_reg_map_cpy["alu_idx"] == alloc_alu):
            if s["value"] in reg_icon_instr_tracker:
              reg_icon_instr_tracker[s["value"]].append(alloc_alu)
            else:
              reg_icon_instr_tracker[s["value"]] = [alloc_alu]

          renamedSrcs.append(register_tracker_batch[s["value"]])
        else:
          renamedSrcs.append({
            "immValue": s["value"]
          })
      
      #Construct the renamed instruction
      renamedInstructions_batch.append({
        "alu_idx": alloc_alu,
        "instruction": instr["instr"],
        "destReg": dest_reg_map_cpy,
        "srcs": renamedSrcs
      })

    #redistribute phase
    #This can also be implemented as a carry chain going from first to last (in forward order)
    #the blocking condition is when the register is seen as a dest reg in the cell
    for key, val in register_tracker_batch.items():
      if key in register_tracker:
        renamedInstructions_batch.append({
          "alu_idx": -1,
          "instruction": "iconmv",
          "destReg": val,
          "srcs": [ register_tracker[key] ]
        })
      
      register_tracker[key] = val

    #finalise and append
    renamedInstructions = renamedInstructions + list(reversed(renamedInstructions_batch))

    num_evaluated_instr = num_evaluated_instr + instr_batch_size

  return renamedInstructions
