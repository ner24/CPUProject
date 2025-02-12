import sys
from typing import List
from graphGen import decompInstruction

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

def allocate(instructions: List[str], max_instr_batch_size: int = 10, num_alus: int = 10, alu_alloc_lookback_size: int = 2) -> List[dict]:
  
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
      #in the Python model the branches wont be evaluated
      #instead, the branches which are triggered are specified externally
      if instr[0] == 'b':
        continue
      instructions_batch.append({
        "instr": instr,
        "destReg": destReg,
        "srcs": srcs
      })
    instr_batch_size = len(instructions_batch)

    #ldr str carry chains.
    #These will have to be a separate ILN because causing conflicts with icon logic
    #note that for the following ILNs in the pipeline, ldr and str will be replaced with a 
    #passthrough instruction
    ldstr_evaluated_instr = []
    for i in range(instr_batch_size-1, -1, -1):
      instr = instructions_batch[i]
      srcs = instr["srcs"]
      destReg = instr["destReg"]

      #if (not instr["instr"] == "ldr") and (not instr["instr"] == "str"):
      ldstr_evaluated_instr.append(instr)
        #continue

      #TODO: str handling
      if instr["instr"] == "str":
        continue

      if instr["instr"] == "ldr":
        #go through all instrs apart from the one being evaluated
        for j in range(len(ldstr_evaluated_instr)-2, -1, -1):
          
          #go through all instructions after the ld (when not reverse order) and check all source registers
          #if one of the source reg equals the dest reg of the load, remap to memory
          for k in range(len(ldstr_evaluated_instr[j]["srcs"])):
            if ldstr_evaluated_instr[j]["srcs"][k] == instr["destReg"]:
              if len(instr["srcs"]) == 2:
                ldstr_evaluated_instr[j]["srcs"][k] = {
                  "value": "memval@" + instr["srcs"][0]["value"] + '+' + instr["srcs"][1]["value"],
                  "type": "imm"
                }
              else:
                ldstr_evaluated_instr[j]["srcs"][k] = {
                  "value": "memval@" + instr["srcs"][0]["value"],
                  "type": "imm"
                }
          #print("Ld renamed after: " + str(ldstr_evaluated_instr[j]["srcs"]))

          #Block condition
          if ldstr_evaluated_instr[j]["destReg"] == instr["destReg"]:
            break

    ldstr_evaluated_instr = list(reversed(ldstr_evaluated_instr))

    print("After ldr str eval:")
    for x in ldstr_evaluated_instr:
      print(x)
    #print(ldstr_evaluated_instr)
    print()

    #contains the allocated alu for each instruction in the batch
    alu_alloc_arr = []

    #alu alloc
    #might implement as another iterative logic circuit that sits before
    #the rename ILN
    round_robin_alloc = 0
    for i in range(len(ldstr_evaluated_instr)):
      instr = ldstr_evaluated_instr[i]
      srcs = instr["srcs"]
      destReg = instr["destReg"]

      #alu alloc only applies to instructions that get dispatched
      #and are not resolved internally by the front end
      if instr["instr"] == "str":
        alu_alloc_arr.append(-2)
        continue
      if instr["instr"] == "ldr":
        alu_alloc_arr.append(-2)
        if(destReg["value"] in register_tracker_batch):
          del register_tracker_batch[destReg["value"]]
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

    print("EU allocations:")
    print(alu_alloc_arr)
    print()

    # reset batch reg tracker before rename
    register_tracker_batch: dict = {}

    # track icon instructions to add additional receivers if multiple parallel instrs using same reg instance
    reg_icon_instr_tracker: dict = {}
    renamedInstructions_batch: List[dict] = []
    for i in range(len(ldstr_evaluated_instr)-1, -1, -1):
      instr = ldstr_evaluated_instr[i]
      srcs = instr["srcs"]
      destReg = instr["destReg"]
      #opcode = instr["instr"]
      print("Evaluating: " + str(instr["instr"]) + " : " + str(instr["destReg"]) + " < " + str(instr["srcs"]))

      alloc_alu = alu_alloc_arr[i]
      #ignore instructions that wont be dispatched (e.g. ldr, str)
      if alloc_alu < 0:
        continue
      
      #dest reg handling
      #all this needs to do is allocate a cache location if one isnt already allocated
      #(this is really only applicable to final usages of a register within a batch)
      if destReg["value"] not in register_tracker_batch:
        register_tracker_batch[destReg["value"]] = {
          "alu_idx": alloc_alu,
          "alu_cache_idx": alu_cache_idx_counter[alloc_alu],
          "opx": 0,
        }
        alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alloc_alu)

      if not (register_tracker_batch[destReg["value"]]["alu_idx"] == alloc_alu):
        if destReg["value"] in reg_icon_instr_tracker:
          reg_icon_instr_tracker[destReg["value"]].append( register_tracker_batch[destReg["value"]]["alu_idx"] )
        else:
          reg_icon_instr_tracker[destReg["value"]] = [ register_tracker_batch[destReg["value"]]["alu_idx"] ]

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

      #reallcoate dest reg every instruction.
      #gives front end more freedom.
      #for accumulative instructions, ys reg will keep hitting anyway so no performance diff
      dest_reg_map_cpy = register_tracker_batch[destReg["value"]]
      del register_tracker_batch[destReg["value"]]

      #Source register handling
      #opx
      si = 0
      opx = []
      for s in instr["srcs"]:
        if s["type"] == "reg":
          if s["value"] not in register_tracker_batch:
            #opx
            #if first src is unknown, assign to 0 and second assign to 1,
            #if one is known, assign the other to be ~that
            #if both are known, do nothing. Caches will resolve opx collisions themselves
            #by either being in dual read (if possible) or by fetching the operands across 2 cycles instead of 1 or 0
            if len(opx) == 0:
              opx = [0, 1]
          else:
            o = register_tracker_batch[s["value"]]["opx"]
            if si == 0:
              opx = [o, ~o]
            else:
              opx = [~o, o]
        si += 1

      #source register rename and icon tracking
      renamedSrcs: List[dict] = []
      si = 0
      for s in instr["srcs"]:
        if s["type"] == "reg":
          #if not in register_tracker_batch, generate new address in allocated eu
          #if srcs are in different alus, then send a icon instruction
          if s["value"] not in register_tracker_batch:
            if s["value"] in register_tracker:
              register_tracker_batch[s["value"]] = register_tracker[s["value"]]
            else:
              #generate a cache address in the allocated alu for the src
              register_tracker_batch[s["value"]] = {
                "alu_idx": alloc_alu,
                "alu_cache_idx": alu_cache_idx_counter[alloc_alu],
                "opx": opx[si] & 0b1,
              }
              alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alloc_alu)
         
          if not (register_tracker_batch[s["value"]]["alu_idx"] == alloc_alu):
            if s["value"] in reg_icon_instr_tracker:
              reg_icon_instr_tracker[s["value"]].append(alloc_alu)
            else:
              reg_icon_instr_tracker[s["value"]] = [alloc_alu]

          renamedSrcs.append(register_tracker_batch[s["value"]])
        else:
          renamedSrcs.append({
            "immValue": s["value"]
          })
        
        si += 1
      
      #Construct the renamed instruction
      print(register_tracker)
      print(register_tracker_batch)
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
        if not (register_tracker[key] == val):
          renamedInstructions_batch.append({
            "alu_idx": -1,
            "instruction": "iconmvb",
            "destReg": val,
            "srcs": [ register_tracker[key] ]
          })
      
      register_tracker[key] = val

    #finalise and append
    renamedInstructions = renamedInstructions + list(reversed(renamedInstructions_batch))

    num_evaluated_instr = num_evaluated_instr + instr_batch_size

  return renamedInstructions
