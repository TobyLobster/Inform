GLKDIR=/home/tilford/src/dl/glkterm/
#GLKDIR=/home/tilford/src/dl/gargoyle/garglk/
GLKLIB=-lglkterm -lncurses -L$(GLKDIR)
#GLKLIB=-lglkterm -lncurses -L/home/tilford/src/dl/glkterm

#GLK_OBJ=$(patsubst %.cc,%.o, $(wildcard *.cc)) $(patsubst %.c,%.o, $(wildcard $(GLKDIR)/*.c))
GLK_SRC := $(wildcard glk-ui/*.cc glk-ui/*.c)
GLK_OBJ := $(patsubst %.cc,%.o, $(filter %.cc, $(GLK_SRC))) $(patsubst %.c,%.o, $(filter %.c, $(GLK_SRC))) 
#GLK_OBJ=$(patsubst %.cc,%.o, $(wildcard *.cc)) $(patsubst %.c,%.o, $(wildcard *.c)) 

