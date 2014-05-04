all: cal 

%: %.tab.o %.yy.o
	gcc $^ -lfl -lmcheck -o $@ 

%.tab.o: %.tab.c pseudo_test.c
	gcc -c -o $@ $(word 1, $^)

%.yy.o: lex.yy.c %.tab.h
	gcc -c -o $@ $< -include $(word 2, $^)

lex.yy.c: cal.l 
	flex $<
	
parse = bison --verbose --report=solved -d $^
%.tab.h %.tab.c: %.y 
	$(parse) 2>&1 | grep --color conflicts || $(parse) 
	ctags --langmap=c:.c.y $^

clean:
	find . -mindepth 1 \( -path './.git' -o -name "*.[yl]" -o -name "list*" -o -name "pseudo_test.c" -o -name "README.md" -o -name "test_input*" -o -name "Makefile" -o -name "*.swp" \) -prune -o -print | xargs rm -f
