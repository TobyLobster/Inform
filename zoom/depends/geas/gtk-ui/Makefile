#CCFLAGS += `pkg-config gtkmm-2.4 --cflags`
CXXFLAGS += `pkg-config gtkmm-2.4 --cflags`
#LDFLAGS += `pkg-config gtkmm-2.4 --libs`

#SRC := $(wildcard *.cc)
#OBJ := $(patsubst %.cc,%.o, $(SRC))

#objs: $(OBJ)
objs: $(patsubst %.cc,%.o, $(wildcard *.cc))


clean:
	rm *.o *~

%.d: %.cc
	@$(CXX) -M $(CCFLAGS) $< > $@.$$$$; \
	sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$

.PHONY: objs clean