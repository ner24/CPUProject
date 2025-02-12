# translates arm assembly codes to a custom instruction set
# it is easier to map to a custom set than to try and handle arm code directly

import sys
from typing import List
from graphGen import decompInstruction

arm_assembly = open("./allocators/testAsmMd5gg.txt", "r")
custom_assembly = open("./allocators/customTestAsmMd5gg.txt", "w")

def concat_srcs(srcs: List[dict]):
    out = ""
    for i in srcs:
        out += i["value"] + ","
    return out[:len(out)-1]

def write_instruction(instr, destReg, srcsString, hasDestreg = True):
    #print(destReg)
    out = "   " + str(0) + ":\t"
    out += "0000     \t"
    out += instr + "\t"
    if hasDestreg:
        out += destReg["value"].strip("{").strip("}") + "\t"
    out += srcsString + "\n"
    custom_assembly.write(out)

def write_instruction_raw(line: str):
    custom_assembly.write(line)

for line in arm_assembly:
    valid, instr, destReg, srcs = decompInstruction(line)
    if not valid:
        print("Malformed instruction detected")
        print(line)
        sys.exit(1)

    match instr:
        case "nop":
            continue

        #call stack management. Load/Store specified registers to/from memory
        #i.e. for each src reg, generate a str instruction.
        #First arg, should be a base address (either a reg value or immediate)
        case "push" | "vpush": #just delete for now (might add later)
            continue
        case "pop" | "vpop":
            continue
        
        case "bx":
            write_instruction("b", destReg, concat_srcs(srcs))
            continue
      
        case "str" | "strb":
            op1 = str(srcs[2]["value"])
            if srcs[1]["type"] == "reg":
                op0 = srcs[1]['value'].replace("r","m")
                write_instruction("str", srcs[0], f"[{op0}, {op1}]", hasDestreg=True)
            else:
                op0 = srcs[1]['value']
                write_instruction("str", srcs[0], f"[{op0}, {op1}]", hasDestreg=True)
            continue
        case "stmia":
            destReg_val = destReg["value"]
            if destReg_val.find("!") == -1:
                registers = [destReg] + srcs
            else:
                destReg_val = destReg_val.replace('!', '')
                registers = srcs
            offset = 0
            for reg in registers:
                op0 = destReg_val.replace("r","m")
                op1 = str(offset)
                write_instruction("str", reg, f"[{op0}, #{op1}]")
                offset += 1
            continue
        #ld instructions will allocate to reg in new file so ignore dependencies (for now)
        #assumes each ld access a different memory address (for now)
        case "ldr" | "ldrb":
            #write_instruction_raw(line)
            op1 = str(srcs[1]["value"])
            if srcs[0]["type"] == "reg":
                op0 = srcs[0]['value'].replace("r","m")
                write_instruction("ldr", destReg, f"[{op0}, {op1}]")
            else:
                op0 = srcs[0]['value']
                write_instruction("ldr", destReg, f"[{op0}, {op1}]")
            continue
        case "ldmia":
            destReg_val = destReg["value"]
            if destReg_val.find("!") == -1:
                registers = [destReg] + srcs
            else:
                destReg_val = destReg_val.replace('!', '')
                registers = srcs
            offset = 0
            for reg in registers:
                op0 = destReg_val.replace("r","m")
                op1 = str(offset)
                write_instruction("ldr", reg, f"[{op0}, #{op1}]")
                offset += 1
            continue
            
        #for most instructions destination is first operand
        #source operands are after
        case _:
            write_instruction_raw(line)

arm_assembly.close()
custom_assembly.close()
