import sys, pathlib, os
from typing import List
if sys.platform == 'win32':
    path = pathlib.Path(r'C:\\Program Files\\Graphviz\\bin')
    if path.is_dir() and str(path) not in os.environ['PATH']:
        os.environ['PATH'] += f';{path}'
import pygraphviz as pgv

#name = "travelling_salesman_dis"
#assembly = open("md5Dis/md5_dis.txt", "r")
assembly = open("disFFT/fft_dis.txt", "r")
#assembly = open(name + ".txt", "r")

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

lines: List[str] = []
for line in assembly:
    lines.append(line)

GList: List[pgv.AGraph] = []
G: pgv.AGraph

instructionCounts: dict[str, int] = {}

regTracker: dict[str, pgv.Node] = {}
#memTracker: dict[str, pgv.Node] = {}
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
    if instruction in instructionCounts:
        instructionCounts[instruction] = instructionCounts[instruction] + 1
    else:
        instructionCounts[instruction] = 1

    #ignore effects of branching on instruction order and therefore dependency order (for now)
    #effectively assumes all false
    if instruction[0] == 'b':
        continue

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
            
i: int = 0
for g in GList:
    g.layout()
    print("Drawing g" + str(i))
    filename = g.draw(path="./graphs/g" + str(i) + ".dot", format='dot')
    i = i + 1

print("Instructions counts:")
print(type(instructionCounts))
for k, v in instructionCounts.items():
    print(k + ": " + str(v))
