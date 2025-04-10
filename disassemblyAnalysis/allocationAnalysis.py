from typing import List
from allocators.allocator17 import allocate as allocate1
import sys

#assembly = open("./allocators/testAsm3.txt", "r")
#assembly = open("./allocators/customTestAsmMd5gg.txt", "r")
#assembly = open("./allocators/manualCustomTestAsmMd5gg.txt", "r")
assembly = open("./allocators/parallelAsm.txt", "r")

lines: List[str] = []
for line in assembly:
  lines.append(line)

renamedInstructions: List[dict] = allocate1(lines, output_filename = "forSim/renamedAssemblyMtxTest.txt", num_alus = 7)
#for i in renamedInstructions:
#  print(i)
sys.exit()

def reg_dict_to_addr(obj) -> str:
  #print(obj)
  #print("ld" in obj)
  return str(obj["alu_idx"]) + str(obj["alu_cache_idx"]) + str(obj["opx"])

for i in renamedInstructions:
  srcs_addrs: list[str] = []
  #print(i)
  for j in i["srcs"]:
    #print(j)
    if "immValue" in j:
      srcs_addrs.append(j["immValue"])
    elif "ld" in j:
      srcs_addrs.append(j["ld"])
    else:
      srcs_addrs.append(reg_dict_to_addr(j))
  print( str(i["alu_idx"]) + "\t" + str(i["instruction"]) + "\t" + reg_dict_to_addr(i["destReg"]) + "\t" + str(srcs_addrs) )

