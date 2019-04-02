ifneq ($(strip $(shell git status --porcelain 2>/dev/null)),)
	GIT_STATE=-prerelease
endif
VERSION=$(shell git rev-list --count HEAD)-$(shell git rev-parse --short=7 HEAD)$(GIT_STATE)

version:
	echo $(VERSION)

.PHONY: app wrapper

all: app wrapper docker

app: app/banking.cbl
	cobc -free -x app/banking.cbl -o dist/banking

wrapper:
	pushd wrapper && \
	go build -o ../dist/wrapper && \
	popd

docker:
	docker build -t eveld/cobol:$(VERSION) .

push:
	docker push eveld/cobol:$(VERSION)

run:
	docker run \
		-ti \
		-p8080:8080 \
		eveld/cobol:$(VERSION)
