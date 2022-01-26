
all: update build demo

update:
	go get -d github.com/GoogleContainerTools/kpt@oci-support

build:
	mkdir -p bin
	go build -o bin/kpt github.com/GoogleContainerTools/kpt

demo:
	./demo.sh
