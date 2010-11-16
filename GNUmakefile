# For more options, use the src/GNUmakefile
MAKE=gmake

all:
	$(MAKE) -C src

clean:
	$(MAKE) clean -C src

distclean:
	$(MAKE) distclean -C src

test:
	$(MAKE) test -C src

install:
	install -d /usr/local/bin
	install -m 555 src/bush /usr/local/bin/bush
	install -d /usr/local/man/man1
	install -m 555 src/bush.1 /usr/local/man/man1/bush.1


uninstall:
	rm /usr/local/bin/bush
	rm /usr/local/man/man1/bush.1

help:
	@echo "Try make, make install or make uninstall"
	@echo "If you have the sources, there are more options"
	@echo "in the src directory"

