
WX_CXXFLAGS += `wx-config --cxxflags`
WX_LDFLAGS := `wx-config --libs`

WX_SRC := $(wildcard wx-ui/*.cc)
#IN_WX_SRC := $(wildcard wx-ui/*.cc)
#WX_SRC := $(patsubst %,wx-ui/%, $(IN_WX_SRC))
WX_OBJ += $(patsubst %.cc,%.o, $(filter %.cc,$(WX_SRC)))

OBJ += WX_OBJ
SRC += WX_SRC
