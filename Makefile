build:
	# gcc -o libpinger.o -I src -c src/pinger.c
	ocamlbuild -use-ocamlfind src/ping_func.o src/pinger.o
	# ocamlbuild -use-ocamlfind -lflags -thread src/monitor.native -cflag libpinger.o -no-hygiene
	ocamlbuild -use-ocamlfind src/monitor.native -lflag src/pinger.o -lflag -thread

clean:
	ocamlbuild -clean
	# rm -rf _build monitor
	rm -rf src/*.o
	rm -rf *.o
