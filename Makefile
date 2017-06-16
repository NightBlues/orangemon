E=$(shell opam config env)

.PHONY: default configure build clean deb
default: build

configure:
	$Eopam install -y ocamlbuild conf-libev lwt cohttp opium redis ppx_deriving ppx_deriving_yojson

build: monitor fanctl

fanctl:
	gcc src/fanctl.c -o fanctl -lwiringPi -lpthread

monitor:
	# gcc -o libpinger.o -I src -c src/pinger.c
	$Eocamlbuild -use-ocamlfind src/ping_func.o src/pinger.o
	# ocamlbuild -use-ocamlfind -lflags -thread src/monitor.native -cflag libpinger.o -no-hygiene
	$Eocamlbuild -use-ocamlfind src/monitor.native -lflag src/pinger.o -lflag -thread

clean:
	$Eocamlbuild -clean
	rm -rf fanctl

install:
	install _build/src/monitor.native $(DESTDIR)/usr/bin/monitor
	install fanctl $(DESTDIR)/usr/bin/fanctl
	cp -r static $(DESTDIR)/usr/share/orangemon/

deb:
	rm -rf ../orangemon_*.orig*
	tar -czf ../orangemon_0.1.orig.tar.gz .merlin *
	debuild
