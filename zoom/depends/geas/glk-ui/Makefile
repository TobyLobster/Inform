include module.mk

#Set GLKDIR manually
#GLKDIR=/home/tilford/src/dl/gargoyle/garglk/
#GLKLIB=-lglkterm -lncurses

obj: geasglk.o geasglkterm.o

CFLAGS += -I$(GLKDIR)
CXXFLAGS += -I$(GLKDIR)
LDFLAGS += -L$(GLKDIR) $(GLKLIB)

clean:
	rm *.o *~

.PHONY: clean obj


# link the program
include $(OBJ:.o=.d)

# calculate C++ include dependencies
%.d: %.cc
	@$(CXX) -M $(CCFLAGS) $< > $@.$$$$; \
	sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$
