import sys, pathlib, os
from typing import List
if sys.platform == 'win32':
    path = pathlib.Path(r'C:\\Program Files\\Graphviz\\bin')
    if path.is_dir() and str(path) not in os.environ['PATH']:
        os.environ['PATH'] += f';{path}'
import pygraphviz as pgv

def getTokens(line) -> List[str]:
    tokens: List[str] = list()
    
    temp: str = ""
    #temp_q: str = ""
    for i in line:
        #temp_q = line[i-1]
        if i == '\t' or i == ',':
            #if not (temp_q == ' '):
            tokens.append(temp)
            #print(temp.replace(' ',''))
            temp = ""
        else:
            temp += i
    tokens.append(temp.replace('\n',''))
    for i in range(0, len(tokens)):
        tokens[i] = tokens[i].replace(' ','')

    #print(*tokens, sep=', ')

    return tokens

def getOperands(tokens) -> List[dict]:
    commentTokenIdx: int = 100
    for i in range(3, len(tokens)):
        if tokens[i][0] ==  ";":
            commentTokenIdx = i
            break
    operands: List[str]
    if not (commentTokenIdx == 100):
        operands: List[str] = tokens[3:commentTokenIdx]
    else:
        operands: List[str] = tokens[3:]
    for i in range(0, len(operands)):
        operands[i] = operands[i].replace(',','')

    operandTypes: List[str] = []
    for s in operands:
        operandTypes.append("reg" if s.find("#") == -1 else "imm")
    
    out: List[dict] = []
    for i in range(0, len(operands)):
        out.append({
            "value": operands[i],
            "type": operandTypes[i]
        })
    return out

def decompInstruction(line) -> tuple[bool, str, str, List[str]]:
    tokens: List[str] = getTokens(line)

    #get code to ignore lines that are not instructions
    if len(tokens) < 3:
        return False, "", "", []
    if tokens[2] == ".word":
        return False, "", "", []

    #get instruction name (ignoring any operand width suffixes)
    instruction: str = tokens[2].split(".")[0]

    operands = getOperands(tokens)

    match instruction:
        case "nop":
            return True, "", "", []
        case "str" | "strb":
            for i in range(len(operands)):
                operands[i]["value"] = operands[i]["value"].replace('[','').replace(',','').replace(']','')
            #if not (operands[1]["value"].find("m") == -1):
            #    operands[1]["loc"] = "sys"
            return True, instruction, {}, operands
        #case "stmia":
        #    memBaseIdxReg: str = operands[0].replace('!','')
        #ld instructions will allocate to reg in new file so ignore dependencies (for now)
        #assumes each ld access a different memory address (for now)
        case "ldr" | "ldrb":
            for i in range(len(operands)):
                operands[i]["value"] = operands[i]["value"].replace('[','').replace(',','').replace(']','')
            destReg: str = operands[0]
            operands = operands[1:]
            #if not (operands[0]["value"].find("m") == -1):
            #    operands[0]["loc"] = "sys"

            return True, instruction, destReg, operands
        #case "ldmia":
        #    memBaseIdxReg: str = operands[0].replace('!','')

        case "mov":
            destReg = operands[0]
            srcReg = operands[1]
            return True, instruction, destReg, [ srcReg ]
        
        case "mvn" | "mvns":
            destReg = operands[0]
            srcReg = operands[1]
            return True, instruction, destReg, [ srcReg ]
            
        #for most instructions destination is first operand
        #source operands are after
        case _:
            destReg = operands[0]
            srcReg = operands[1:]
            if len(srcReg) == 1: #if true, this is an accumulative op (where one reg is dest and src (e.g. add r2, r3))
                srcReg.append(destReg)
                srcReg.reverse()
            return True, instruction, destReg, srcReg

def getNumArchReg() -> int:
    return 16
def getArchRegIdx(archreg: str) -> int:
    #print(archreg)
    match archreg:
        case "r0": return 0
        case "r1": return 1
        case "r2": return 2
        case "r3": return 3
        case "r4": return 4
        case "r5": return 5
        case "r6": return 6
        case "r7": return 7
        case "r8": return 8
        case "r9": return 9
        case "r10": return 10
        case "r11": return 11
        case "r12": return 12
        case "r13": return 13
        case "r14": return 14
        case "sp": return 15
        case _: raise LookupError("No arch reg mapping for " + archreg)
def convImmStrToVal(immStr: str) -> int:
    i = immStr.replace("#","")
    return int(i)

def genGraph(lines: List[str]) -> List[pgv.AGraph]:
  GList: List[pgv.AGraph] = []
  G: pgv.AGraph
  
  for ptr in range(0, len(lines)):
    line = lines[ptr]

    tokens: List[str] = getTokens(line)
    
    #print(*tokens, sep=', ')

    #create new graph for each function
    if(line.find(">:") != -1): #char sequence only found in function declarations
        print(line)
        G = pgv.AGraph(directed=True)
        GList.append(G)
        regTracker = {}

    #get code to ignore lines that are not instructions
    if len(tokens) < 3:
        continue
    if tokens[2] == ".word":
        continue

    #get instruction name (ignoring any operand width suffixes)
    instruction: str = tokens[2].split(".")[0]

    #count instructions
    #if instruction in instructionCounts:
    #    instructionCounts[instruction] = instructionCounts[instruction] + 1
    #else:
    #    instructionCounts[instruction] = 1

    #ignore effects of branching on instruction order and therefore dependency order (for now)
    #effectively assumes all false
    if instruction[0] == 'b':
        continue

    operands = getOperands(tokens)
    #commentTokenIdx: int = 100
    #for i in range(3, len(tokens)):
    #    if tokens[i][0] ==  ";":
    #        commentTokenIdx = i
    #        break
    #operands: List[str]
    #if not (commentTokenIdx == 100):
    #    operands: List[str] = tokens[3:commentTokenIdx]
    #else:
    #    operands: List[str] = tokens[3:]
    #for i in range(0, len(operands)):
    #    operands[i] = operands[i].replace(',','')

    G.add_node(line)
    n = G.get_node(line)

    #resolve push/pop
    #evauate each function independently (for now)
    #i.e. reset regTracker on each push or pop and also start new graph
    #in the case of bx, there is no pop but instead a ldr.w followed by bx for some functions
    #TODO: setup stack tracker
    n: pgv.Node
    match instruction:
        case "push" | "vpush":
            op: str = operands[i].replace('{','').replace('}','')
            #if op in regTracker:
            #    regTracker[op] = n
        case "pop" | "vpop":
            op: str = operands[i].replace('{','').replace('}','')
            #if op in regTracker:
            #    regTracker[op] = n
        case "bx":
            continue
        case _:
            G.add_node(line)
            n: pgv.Node = G.get_node(line)
    #print(type(n))

    match instruction:
        case "nop":
            continue
        case "str" | "strb":
            firstSrc: str = operands[1].replace('[','').replace(',','')
            secondSrc: str = operands[2].replace(']','')
            if firstSrc in regTracker:
                G.add_edge(regTracker[firstSrc], n)
            if secondSrc in regTracker:
                G.add_edge(regTracker[secondSrc], n)
            if operands[0] in regTracker:
                G.add_edge(regTracker[operands[0]], n)
        case "stmia":
            memBaseIdxReg: str = operands[0].replace('!','')
            if memBaseIdxReg in regTracker:
                G.add_edge(regTracker[memBaseIdxReg], n)
            for i in range(1, len(operands)):
                op: str = operands[i].replace('{','').replace('}','')
                if op in regTracker:
                    G.add_edge(regTracker[op], n)
        #ld instructions will allocate to reg in new file so ignore dependencies (for now)
        #assumes each ld access a different memory address (for now)
        case "ldr" | "ldrb":
            firstSrc: str = operands[1].replace('[','').replace(',','')
            secondSrc: str = operands[2].replace(']','')
            if firstSrc in regTracker:
                G.add_edge(regTracker[firstSrc], n)
            if secondSrc in regTracker:
                G.add_edge(regTracker[secondSrc], n)
            regTracker[operands[0]] = n          
        case "ldmia":
            memBaseIdxReg: str = operands[0].replace('!','')
            if memBaseIdxReg in regTracker:
                G.add_edge(regTracker[memBaseIdxReg], n)
            for i in range(1, len(operands)):
                op: str = operands[i].replace('{','').replace('}','')
                if op in regTracker:
                    regTracker[op] = n
            
        #for most instructions destination is first operand
        #source operands are after
        case _:
            for i in range(1, len(operands)):
                if operands[i] in regTracker:
                    G.add_edge(regTracker[operands[i]], n)
            if len(operands) < 3:
                if operands[0] in regTracker:
                    G.add_edge(regTracker[operands[0]], n)
            #update resource tracker to track destination reg of this instruction
            regTracker[operands[0]] = n

  return GList
