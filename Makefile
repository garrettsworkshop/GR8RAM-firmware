SRCS = $(wildcard src/*.v)
SIMS = $(wildcard sim/*.v)
TESTS = $(wildcard tests/*.v)
VCDS = $(patsubst tests%,test_outputs%,$(TESTS:.v=.vcd))
EXE_TO_NAME = $(patsubst obj/%/VUUT,%,$@)

.PHONY: all clean test
all: test
clean:
	rm -fr bin/ obj/ test_outputs/

test: $(VCDS)

obj test_outputs:
	mkdir -p $@

obj/%/VUUT: obj tests/%.v $(SRCS) $(SIMS)
	@echo building $@
	mkdir -p obj/$(EXE_TO_NAME)/
	verilator --trace --binary -Mdir obj/$(EXE_TO_NAME)/ --top UUT -j 6 tests/$(EXE_TO_NAME).v $(SRCS) $(SIMS)

test_outputs/%.vcd: obj/%/VUUT test_outputs
	@echo building $@
	$<
