ifneq ($(strip $(shell git status --porcelain 2>/dev/null)),)
	GIT_STATE=-prerelease
endif
VERSION=$(shell git rev-list --count HEAD)-$(shell git rev-parse --short=7 HEAD)$(GIT_STATE)

version:
	echo $(VERSION)

.PHONY: app banking wrapper rating frontend nginx consul nomad

build: banking wrapper rating frontend

banking: banking/banking.cbl
	cobc -free -x banking/banking.cbl -o dist/banking
	pushd dist && \
	chmod +x banking && \
	zip banking.zip banking && \
	rm banking && \
	popd

wrapper:
	pushd wrapper && \
	go build -o ../dist/wrapper && \
	popd

rating:
	pushd rating && \
	go build -o ../dist/rating && \
	popd

frontend:
	echo "nothing yet"

deploy:
	nomad run nomad/job.hcl

nginx:
	docker run \
		-p 8888:80 \
		-v $(PWD)/dist:/usr/share/nginx/html/files \
		nginx

consul:
	consul agent -dev -grpc-port=8502

nomad:
	sudo nomad agent -dev -data-dir=$(HOME)/nomad