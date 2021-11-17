CXXFLAGS += `wx-config --cxxflags`
CCFLAGS += `wx-config --ccflags`
LDFLAGS += `wx-config --libs`

#SRC := $(wildcard *.cc)
#OBJ := $(patsubst %.cc,%.o, $(SRC))

#objs: $(OBJ)
objs: $(patsubst %.cc,%.o, $(wildcard *.cc))

wxgeas.o: wxgeas.cc wxgeas.hh

clean:
	rm *.o *~

%.d: %.cc
	@$(CXX) -M $(CCFLAGS) $< > $@.$$$$; \
	sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$

.PHONY: objs clean