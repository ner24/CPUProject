CC=arm-linux-gnueabihf-gcc
CXX=arm-linux-gnueabihf-g++
OBJDUMP=arm-linux-gnueabihf-objdump

#FILENAME=fft
FILENAME=disMd5/md5ggOnly

obj:
	$(CXX) -c srcs/$(FILENAME).cpp -o $(FILENAME).o
$(FILENAME).o: obj

dmp: $(FILENAME).o
	$(OBJDUMP) -marm -d $(FILENAME).o > $(FILENAME)_dis.txt

dmp_sig: $(FILENAME).o
	$(OBJDUMP) -marm -t $(FILENAME).o

#sanity check that source code can run without error
test:
	g++ $(FILENAME).cpp -o test
	./test
	rm test

#NOTE: assuming ubuntu 22.04 in WSL
dg:
	python3 ./dependencyAnalysis.py
	dot -Tpng g.dot > g.png
#	explorer.exe g.png

#NOTE: using ubuntu 22.04 in WSL
install:
	sudo apt-get install gcc-arm-linux-gnueabihf
	sudo apt-get install g++-arm-linux-gnueabihf
	sudo apt install graphviz graphviz-dev
	python3 -m pip install pygraphviz
