ODIN_ROOT = $(shell odin root)

SRC_PATH = src
WEB_PATH = bin/web
OUT_PATH = bin/osx
OUT_OPT = -out:${OUT_PATH}/game

.PHONY: install_dependencies run build_debug build_production build_web test serve
default: run

run:
	odin run ${SRC_PATH}

deps: install_dependencies
dependencies: install_dependencies
install_dependencies:
		git clone --depth 1 git@github.com:karl-zylinski/karl2d.git

b: build_vet
vet: build_vet
check: build_vet
build: build_vet
build_vet:
	mkdir -p ${OUT_PATH}
	odin build ${SRC_PATH} -debug -vet ${OUT_OPT}

dbg: build_debug
debug: build_debug
build_debug:
	mkdir -p ${OUT_PATH}
	odin build ${SRC_PATH} -debug ${OUT_OPT}

prod: build_production
build_production:
	mkdir -p ${OUT_PATH}
	odin build ${SRC_PATH} -o:speed ${OUT_OPT}

t: test
test:
	odin test ${SRC_PATH}

w: build_web
web: build_web
build_web:
	odin run ./tasks/build_web -- ./src
	mkdir -p ./bin/web
	mv ./src/bin/web/* ./bin/web/
	rm -r ./src/bin
	rm -r ./src/build

s: serve
serve:
	python3 -m http.server 3000 -d ${WEB_PATH}
