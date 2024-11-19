import sys, pathlib, os
from typing import List
from dependencyAnalysis import getTokens
if sys.platform == 'win32':
    path = pathlib.Path(r'C:\\Program Files\\Graphviz\\bin')
    if path.is_dir() and str(path) not in os.environ['PATH']:
        os.environ['PATH'] += f';{path}'
import pygraphviz as pgv


#name = "travelling_salesman_dis"
#assembly = open("md5Dis/md5_dis.txt", "r")
assembly = open("fft_dis.txt", "r")
#assembly = open(name + ".txt", "r")

lines: List[str] = []
for line in assembly:
  lines.append(line)


