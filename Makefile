quick:
	stack install --test --flag "skylighting:executable" --test-arguments '--hide-successes $(TESTARGS)'

test:
	stack test --test-arguments '--hide-successes $(TESTARGS)'

bench:
	stack bench --flag 'skylighting:executable'

format: skylighting-format skylighting-core-format

skylighting-core-format:
	stylish-haskell -i -c .stylish-haskell \
	      skylighting-core/bin/*.hs \
	      skylighting-core/test/test-skylighting.hs \
	      skylighting-core/benchmark/benchmark.hs \
	      skylighting-core/Setup.hs \
	      skylighting-core/src/Skylighting/*.hs \
	      skylighting-core/src/Skylighting/Format/*.hs

skylighting-format:
	stylish-haskell -i -c .stylish-haskell \
	      skylighting/bin/*.hs \
	      skylighting/Setup.hs \
	      skylighting/src/Skylighting.hs

XMLS=$(wildcard skylighting-core/xml/*.xml)
bootstrap: $(XMLS)
	-rm -rf skylighting/src/Skylighting/Syntax skylighting/src/Skylighting/Syntax.hs
	cd skylighting && skylighting-extract ../skylighting-core/xml/*.xml
	stack install --flag "skylighting:executable" --test --test-arguments \
	    '--hide-successes $(TESTARGS)' --fast

syntax-highlighting:
	git clone https://github.com/KDE/syntax-highlighting

update-xml: syntax-highlighting
	cd syntax-highlighting; \
	git pull; \
	cd ../skylighting-core/xml; \
	for x in *.xml; do cp ../../syntax-highlighting/data/syntax/$$x ./; done ; \
	for x in *.xml.patch; do patch < $$x; done

clean:
	stack clean

.PHONY: all update-xml quick clean test format

