export

MODULES := geas-core gtk-ui

# look for include files in each of the modules
#CFLAGS += $(patsubst %,-I%, $(MODULES)) -g -Wall
#CXXFLAGS += $(patsubst %,-I%, $(MODULES)) -g -Wall
CFLAGS += -I../geas-core -g -Wall
CXXFLAGS += -I../geas-core -g -Wall



# extra libraries if required
LIBS := 

# each module will add to this
#SRC :=

CORE_OBJ :=
GTK_OBJ :=
GLK_OBJ := 
WX_OBJ :=

# include the description for each module
#include $(patsubst %,  %/module.mk,$(MODULES))
include geas-core/module.mk
include gtk-ui/module.mk
include glk-ui/module.mk
include wx-ui/module.mk

# determine the object files
OBJ := $(patsubst %.cc,%.o, $(filter %.cc,$(SRC))) $(patsubst %.c,%.o, $(filter %.cc,$(SRC)))



gtk-geas: core_obj gtk_obj $(CORE_OBJ) $(GTK_OBJ)
	@#@echo "CORE_SRC == $(CORE_SRC), CORE_OBJ == $(CORE_OBJ), GTK_OBJ == $(GTK_OBJ)"
	$(CXX) $(LDFLAGS) $(GTK_LDFLAGS) $(CORE_OBJ) $(GTK_OBJ) -o gtk-geas

glk-geas: core_obj glk_obj $(CORE_OBJ) $(GLK_OBJ)
	echo "GLK_SRC == $(GLK_SRC), GLK_OBJ == $(GLK_OBJ)"
#	$(CXX) $(GLK_LDFLAGS) $(CORE_OBJ) $(GLK_OBJ) $(GLKLIB) \
#             -o glk-geas
	$(CXX)   \
		$(GLK_LDFLAGS) $(CORE_OBJ) $(GLK_OBJ) $(GLKLIB)  \
		-o glk-geas


wx-geas: core_obj wx_obj $(CORE_OBJ) $(WX_OBJ)
	$(CXX) $(LDFLAGS) $(WX_LDFLAGS) $(CORE_OBJ) $(WX_OBJ) -o wx-geas



ALL_SRC := $(wildcard */*.[ch][ch] $(wildcard */*.[ch]) doc/* Makefile */Makefile */module.mk geas-core/uncas.pl)
src-tarball: $(ALL_SRC)
	tar -czf geas-src.tgz $(ALL_SRC)

core_obj:
	$(MAKE) -C geas-core

gtk_obj:
	$(MAKE) -C gtk-ui

glk_obj:
	$(MAKE) -C glk-ui

wx_obj:
	$(MAKE) -C wx-ui

clean:
	-rm gtk-geas glk-geas
	-$(MAKE) clean -C geas-core
	-$(MAKE) clean -C gtk-ui
	-$(MAKE) clean -C glk-ui
	-$(MAKE) clean -C wx-ui


.PHONY: core_obj gtk_obj glk_obj clean

# link the program
include $(OBJ:.o=.d)


# calculate C++ include dependencies
%.d: %.cc
	@$(CXX) -M $(CCFLAGS) $< > $@.$$$$; \
	sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$
