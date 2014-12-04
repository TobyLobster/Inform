
EXTRA_DIST = varopdecode.pl

noinst_PROGRAMS = builder

CC = @BUILDERCC@
CFLAGS =

builder_SOURCES = main.c gram.y gram.h lex.l operation.h
LDADD = @LEXLIB@
YFLAGS = -d

main.c: gram.c

builder$(EXEEXT): $(builder_OBJECTS) $(builder_DEPENDENCIES)
	@rm -f builder
	$(CC) -o builder $(builder_OBJECTS)
