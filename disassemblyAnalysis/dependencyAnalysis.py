import sys, pathlib, os
from typing import List
if sys.platform == 'win32':
    path = pathlib.Path(r'C:\Program Files\Graphviz\bin')
    if path.is_dir() and str(path) not in os.environ['PATH']:
        os.environ['PATH'] += f';{path}'
import pygraphviz as pgv


assembly = open("common_equations_int_dis.txt", "r")

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


G: pgv.AGraph = pgv.AGraph()
regTracker: dict[str, tuple, pgv.Node] = {} #where the int in tuple is somewhat analogous to reg file index
#memTracker: dict[str, pgv.Node] = {}
for line in assembly:
    tokens: List[str] = getTokens(line)
    
    print(*tokens, sep=', ')

    #get code to ignore lines that are not instructions
    if len(tokens) < 2 or tokens[2] == ".word":
        continue

    #get instruction name (ignoring any operand width suffixes)
    instruction: str = tokens[2].split(".")[0]

    #ignore effects of branching on instruction order and therefore dependency order (for now)
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
    n: pgv.Node = G.get_node(line)
    print(type(n))
    match instruction:
        case "push":
            continue
        case "str":
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
        case "ldr":
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
            

G.layout()
filename = G.draw(path="./g.dot", format='dot')
