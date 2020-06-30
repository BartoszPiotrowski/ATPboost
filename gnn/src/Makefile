FILES = cnf fof fof_parse fof_lexer features args dtree logic circuit premsel_parse cnfpremsel_parse fcop
FILES_CMX = $(addprefix _build/,$(addsuffix .cmx,$(FILES)))
SOURCES = *.ml *.mll *.mly
LIB = -L`ocamlopt -where` -lunix -lcamlstr -lasmrun_pic -lm -ldl -L /usr/lib/x86_64-linux-gnu/ -lpython3.8
OBJ = cint.o oo.o graph_indices.o module.o

all: fcoplib.so

fcoplib.so: $(OBJ)
	gcc -shared -Wl,-soname,fcoplib -o fcoplib.so -fPIC $(OBJ) $(LIB)

oo.o: $(SOURCES)
	ocamlbuild -no-hygiene -libs str,unix,nums fcop.o
	ocamlopt -output-obj -o oo.o str.cmxa unix.cmxa $(FILES_CMX)

.c.o:
	gcc -c -fPIC -I /usr/include/python3.8 -o $*.o $<

test: $(OBJ) test.o
	gcc -o test -fPIC $^ $(LIB)

clean:
	@ocamlbuild -clean
	@rm -f fcoplib.so *o *~ *cmi *cmx
