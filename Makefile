GREEN=\e[32m
NORMAL=\e[0m

PREFIX ?= /usr/local
LIBDIR = $(PREFIX)/lib
SFE_HEADERS_DIR = $(PREFIX)/include/sfe

clean:
	@rm -rf build

# Build release versions of libraries
.ONESHELL:
build-release:
	@set -e

	mkdir -p build/release && cd build/release
	cmake -DCMAKE_BUILD_TYPE=Release ${CURDIR}
	make -j16 sfe_basic sfe_preload

# Install headers and libraries (Tested only for Linux)
.ONESHELL:
install:
	@set -e

	make build-release
	mkdir -p ${SFE_HEADERS_DIR}
	echo -e '${GREEN}Install headers to ${SFE_HEADERS_DIR}${NORMAL}'
	install -m644 include/sfe/sfe.hpp ${SFE_HEADERS_DIR}
	install -m644 include/sfe/stacktrace.hpp ${SFE_HEADERS_DIR}
	echo -e '${GREEN}Install libs to ${LIBDIR}${NORMAL}'
	install -m644 build/release/src/sfe/libsfe_basic.so ${LIBDIR}
	install -m644 build/release/src/sfe/libsfe_preload.so ${LIBDIR}
	echo -e '${GREEN}Updating linker cache${NORMAL}'
	ldconfig
	echo -e "${GREEN}Install finished!${NORMAL}"


.ONESHELL:
run-tests-internal:
	@set -e

	echo -e "${GREEN}Test with compiler '$$CXX'${NORMAL}"

	export CMAKE_OPTS_INTERNAL="-DCMAKE_CXX_COMPILER=$$CXX"

	export LD_PRELOAD_INTERNAL=$$BUILD_DIR/src/sfe/libsfe_preload.so

	if [ "$$SANITIZE_ENABLE" = "ON" ]; then
		echo -e "${GREEN}And sanitizers${NORMAL}"
		export CMAKE_OPTS_INTERNAL="$$CMAKE_OPTS_INTERNAL -DSANITIZE_ENABLE=ON"
		export LD_PRELOAD_INTERNAL="$$($$CXX -print-file-name=libasan.so):$$LD_PRELOAD_INTERNAL"
	fi

	mkdir -p $$BUILD_DIR
	( cd $$BUILD_DIR && cmake ${CURDIR} $$CMAKE_OPTS_INTERNAL )
	make -j16 -C $$BUILD_DIR all

	set -x
	$$BUILD_DIR/tests/test_libsfe_basic
	LD_PRELOAD=$$LD_PRELOAD_INTERNAL $$BUILD_DIR/tests/test_libsfe_preload


# `AVAILABLE_COMPILERS=g++ make run-tests` -- Run tests with chosen compilers
AVAILABLE_COMPILERS ?= g++-10 clang++-10
.PHONY: run-tests
.ONESHELL:
run-tests:
	@set -e

	for CXX in ${AVAILABLE_COMPILERS}; do
		make run-tests-internal BUILD_DIR=build/test_$${CXX}
		make run-tests-internal BUILD_DIR=build/test_$${CXX}_sanitizers SANITIZE_ENABLE=ON
	done

	echo -e "${GREEN}Successfull!${NORMAL}"

