FROM golang:1.11 as builder

RUN go get -d -u github.com/golang/dep \
    && cd $(go env GOPATH)/src/github.com/golang/dep \
    && DEP_VERSION=v0.5.0 \
    && git checkout $DEP_VERSION \
    && go install -ldflags="-X main.version=$DEP_VERSION" ./cmd/dep \
    && go get honnef.co/go/tools/cmd/gosimple \
    && go get honnef.co/go/tools/cmd/unused

COPY VERSION /VERSION

RUN VERSION=$(cat /VERSION) \
    && mkdir -p $(go env GOPATH)/src/github.com/coreos \
    && cd $(go env GOPATH)/src/github.com/coreos \
    && git clone https://github.com/coreos/etcd-operator.git \
    && cd etcd-operator \
    && git checkout $VERSION \
    && dep ensure -v

RUN cd $(go env GOPATH)/src/github.com/coreos/etcd-operator \
    && GOOS=linux CGO_ENABLED=0 go build -o /build/etcd-operator -installsuffix cgo ./cmd/operator/

RUN cd $(go env GOPATH)/src/github.com/coreos/etcd-operator \
    && GOOS=linux CGO_ENABLED=0 go build -o /build/etcd-backup-operator -installsuffix cgo ./cmd/backup-operator/

RUN cd $(go env GOPATH)/src/github.com/coreos/etcd-operator \
    && GOOS=linux CGO_ENABLED=0 go build -o /build/etcd-restore-operator -installsuffix cgo ./cmd/restore-operator/


FROM alpine:3.6

RUN apk add --no-cache ca-certificates

COPY --from=builder /build/etcd-backup-operator /usr/local/bin/etcd-backup-operator
COPY --from=builder /build/etcd-restore-operator /usr/local/bin/etcd-restore-operator
COPY --from=builder /build/etcd-operator /usr/local/bin/etcd-operator

RUN adduser -D etcd-operator
USER etcd-operator
