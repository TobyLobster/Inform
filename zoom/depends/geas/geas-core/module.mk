#SRC += $(shell echo "In module.mk")

IN_CORE_SRC := geasfile.cc geas-runner.cc geas-state.cc geas-util.cc \
	gtk-geas.cc istring.cc readfile.cc
CORE_SRC += $(wildcard geas-core/*.cc)
#CORE_SRC := geas-core/geasfile.cc
#CORE_SRC := $(patsubst %,geas-core/%, $(IN_CORE_SRC))
CORE_OBJ += $(patsubst %.cc,%.o, $(filter %.cc,$(CORE_SRC)))

OBJ += CORE_OBJ
SRC += CORE_SRC
