
GTK_CXXFLAGS += `pkg-config gtkmm-2.4 --cflags`
GTK_LDFLAGS := `pkg-config gtkmm-2.4 --libs`

GTK_SRC := $(wildcard gtk-ui/*.cc)
#IN_GTK_SRC := $(wildcard gtk-ui/*.cc)
#GTK_SRC := $(patsubst %,gtk-ui/%, $(IN_GTK_SRC))
GTK_OBJ += $(patsubst %.cc,%.o, $(filter %.cc,$(GTK_SRC)))

OBJ += GTK_OBJ
SRC += GTK_SRC
