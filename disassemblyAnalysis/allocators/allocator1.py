import sys, pathlib, os
if sys.platform == 'win32':
    path = pathlib.Path(r'C:\\Program Files\\Graphviz\\bin')
    if path.is_dir() and str(path) not in os.environ['PATH']:
        os.environ['PATH'] += f';{path}'
import pygraphviz as pgv
from typing import List
from graphGen import decompInstruction

#Idea is to process instructions in batches (e.g. 10 at a time)
#Between each batch, depending on where the registers and the dependency
#graph of the next batch, a redistribute function will dispatch a series
#of move instructions to relocate registers to other ALUs to optimise
#for parallel execution

def get_next_alu_cache_idx(alu_cache_idx_counter: dict, alu_idx: int) -> dict:
  if alu_idx in alu_cache_idx_counter:
    alu_cache_idx_counter[alu_idx] = alu_cache_idx_counter[alu_idx] + 1
    if(alu_cache_idx_counter[alu_idx]) == 4:
      alu_cache_idx_counter[alu_idx] = 0
  else:
    alu_cache_idx_counter[alu_idx] = 0

  return alu_cache_idx_counter

def is_in_tracker(reg_tracker: dict, dependency_idx: int, reg: str) -> bool:
  return (str(dependency_idx) + "," + reg) in reg_tracker

def get_from_tracker(reg_tracker: dict, dependency_idx: int, reg: str) -> dict:
  return reg_tracker[str(dependency_idx) + "," + reg]

def set_in_tracker(reg_tracker: dict, dependency_idx: int, reg: str, val: dict) -> dict:
  reg_tracker[str(dependency_idx) + "," + reg] = val
  return reg_tracker

#for now just assume infinite ALUs. TODO: dont assume this
def allocate(instructions: List[str]) -> List[dict]:
  #Perhaps a useful thing to know for implementation is that the dependency idx should never decrease
  #Once it is declared that the next reg file should be used, there shouldn't be an instruction after that refers to the
  #previous register file (except maybe in branch mispredictions but that imo is out of scope)

  instr_batch_size = 10

  #where map is [dependency idx][reg idx] = concat(dependency_idx, alu_idx, alu_cache_idx, opx, fromLd)
  #NOTE: the default value (i.e. if no key exists) is concat(0,0,0,0,1) (i.e. if requested reg not tracked, then
  #take from ld register).
  #It is assumed that the software actually specifies/assigns values to registers before using them as it doesn't make sense
  #to not do that
  register_tracker: dict = {}

  dependencyCounters: dict = {}
  for i in range(0, 8):
    dependencyCounters["r" + str(i)] = 0
  alu_idx_counter: int = 0
  alu_cache_idx_counter: dict = {}
  alu_cache_idx_counter[0] = 0
  
  #output
  renamedInstructions: List[dict] = []

  num_evaluated_instr: int = 0
  while num_evaluated_instr < len(instructions):
    #process in batches of 10 instructions. Batch register tracker will be reset for every batch
    register_tracker_batch: dict = {}
    renamedInstructions_batch: List[dict] = []
    for i in range(instr_batch_size-1, -1, -1):
      print("evaluating " + instructions[i])
      valid, instr, destReg, srcs = decompInstruction(instructions[i])

      #ignore invalid instructions (i.e. malformed input)
      if not valid:
        continue

      #ld instructions should be evaluated as immediates
      #as they will be parsed to the alus from the ld buffer through the IQueue
      #print(instr)
      if instr == "ldr":
        set_in_tracker(register_tracker_batch, dependencyCounters[destReg["value"]], destReg["value"], {
          "ld": "memval"
        })
        #ld should not be parsed to alus, so dont need to rename. The memory interface (ld buffer etc.) should
        #be able to fully evaluate and return the requested data which will be parsed as an immediate in the renamed
        #instruction (NOTE: the memory controller will need store locks to stop read before writes due to out of order (
        #also, if a ld uses a reg that is store locked, then this would be a writeback cancel))
        continue

      inc_alu_cnt: bool = False
      if (not is_in_tracker(register_tracker_batch, dependencyCounters[destReg["value"]], destReg["value"])) or ("ld" in get_from_tracker(register_tracker_batch, dependencyCounters[destReg["value"]], destReg["value"])):
        #assign destination reg to next ALU idx (i.e. this is round robin dispatch)
        #TODO: setup an ALU queue tracker to better optimise ALU usage. e.g. dispatch to 
        #ALU with smallest current queue size. Round robin is still being considered for simplicity
        set_in_tracker(register_tracker_batch, dependencyCounters[destReg["value"]], destReg["value"], {
          "dependency_idx": dependencyCounters[destReg["value"]],
          "alu_idx": alu_idx_counter,
          "alu_cache_idx": alu_cache_idx_counter[alu_idx_counter],
          "opx": 0,
          "dest_state": 1 #if most recently evaluated instr used the reg as dest, then set to 1
        })
        inc_alu_cnt = True
        alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alu_idx_counter)
      
      #if source registers are unallocated, allocate them to the same alu cache as the destination reg
      i_temp: int = 0
      for s in srcs:
        if s["type"] == "reg":
          print(s)
          if is_in_tracker(register_tracker_batch, dependencyCounters[s["value"]], s["value"]):
            if ("ld" in get_from_tracker(register_tracker_batch, dependencyCounters[s["value"]], s["value"])):
              continue
            #if reg is in batch reg tracker, then it has already been used as a dest reg. If so, the earlier
            #instructions (ones which are read in later here as reading backwards) that use this reg as a src
            #should use that reg from a different file as the later instructions dont use that "reg instance" anymore
            elif (get_from_tracker(register_tracker_batch, dependencyCounters[s["value"]], s["value"])["dest_state"] == 1):
              dependencyCounters[s["value"]] = dependencyCounters[s["value"]] + 1

          if not is_in_tracker(register_tracker_batch, dependencyCounters[s["value"]], s["value"]):
            print("Adding to tracker: " + s["value"])
            set_in_tracker(register_tracker_batch, dependencyCounters[s["value"]], s["value"], {
              "dependency_idx": dependencyCounters[s["value"]],
              "alu_idx": alu_idx_counter,
              "alu_cache_idx": alu_cache_idx_counter[alu_idx_counter],
              "opx": i_temp % 2,
              "dest_state": 0
            })
            i_temp = i_temp + 1
            alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alu_idx_counter)
      
      #construct renamed instruction that would be dispatched
      renamedSrcs: List[dict] = []
      for s in srcs:
        if "ld" in s:
          renamedSrcs.append("#" + str(s["ld"]))
        elif s["type"] == "reg":
          renamedSrcs.append(get_from_tracker(register_tracker_batch, dependencyCounters[s["value"]], s["value"]))
        else:
          renamedSrcs.append({
            "immValue": s["value"]
          })
      
      renamedInstructions_batch.append({
        "alu_idx": alu_idx_counter,
        "instruction": instr,
        "destReg": get_from_tracker(register_tracker_batch, dependencyCounters[destReg["value"]], destReg["value"]),
        "srcs": renamedSrcs
      })

      if inc_alu_cnt:
        alu_idx_counter = alu_idx_counter + 1
        if alu_idx_counter == 9: #set num alus to 4 for now
          alu_idx_counter = 0
        alu_cache_idx_counter = get_next_alu_cache_idx(alu_cache_idx_counter, alu_idx_counter)

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
      r_name = r.split(',')[1]
      #print(r_name)
      if (r in register_tracker) and ("ld" not in get_from_tracker(register_tracker_batch, dependencyCounters[r_name], r_name)):
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

    num_evaluated_instr = num_evaluated_instr + instr_batch_size

  return renamedInstructions
