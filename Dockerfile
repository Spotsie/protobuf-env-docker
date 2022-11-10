
# TODO Handle platforms
# TODO One day if the grpc are release by version we could use this to downlaod the correct versions.
#  > git ls-remote --tags git@github.com:grpc/grpc.git v1.9.1 | cut -f1
#  > wget https://packages.grpc.io/# -O - | xmllint --xpath 'packages/builds/build[@commit="a3b54ef90841ec45fe5e28f54245b7944d0904f9"]' -

# Go compilers
FROM golang:1.18-alpine AS go

RUN apk add --no-cache git

# See https://pkg.go.dev/google.golang.org/protobuf@v1.28.0/cmd/protoc-gen-go
ARG GO_GEN_VERION=1.28.0
ARG GO_GRPC_URL="google.golang.org/protobuf/cmd/protoc-gen-go@v$GO_GEN_VERION"
RUN go install $GO_GRPC_URL

RUN go install github.com/bufbuild/connect-go/cmd/protoc-gen-connect-go@latest

# See https://pkg.go.dev/google.golang.org/grpc/cmd/protoc-gen-go-grpc
ARG GO_GRPC_VERSION=1.2.0
ARG GO_GRPC_URL="google.golang.org/grpc/cmd/protoc-gen-go-grpc@v$GO_GRPC_VERSION"
RUN go install $GO_GRPC_URL


FROM node:hydrogen as js
workdir /node
RUN npm install --save-dev @bufbuild/protoc-gen-connect-web @bufbuild/protoc-gen-es
RUN npm install @bufbuild/connect-web @bufbuild/protobuf


FROM golang:1.18-alpine AS java
RUN apk add bash

# See https://mvnrepository.com/artifact/io.grpc/protoc-gen-grpc-java
ARG JAVA_GRPC_VERSION=1.45.1
ARG JAVA_PLATFORM=linux-x86_64
ARG JAVA_GRPC_URL="https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/$JAVA_GRPC_VERSION/protoc-gen-grpc-java-$JAVA_GRPC_VERSION-$JAVA_PLATFORM.exe"

RUN echo "Installing protoc-gen-grpc-java-$JAVA_GRPC_VERSION-$JAVA_PLATFORM" && \
    wget --quiet "$JAVA_GRPC_URL" -O /go/bin/protoc-gen-grpc-java

ARG BUF_VERSION=1.3.1
FROM bufbuild/buf:1.3.1

RUN apk add --no-cache unzip
RUN apk add --no-cache gcompat
RUN apk add bash nodejs curl

# See https://github.com/protocolbuffers/protobuf/releases
ARG PROTOBUF_VERSION=3.20.0
ARG PROTOBUF_PLATFORM=linux-x86_64
ARG PROTOBUF_URL="https://github.com/protocolbuffers/protobuf/releases/download/v$PROTOBUF_VERSION/protoc-$PROTOBUF_VERSION-$PROTOBUF_PLATFORM.zip"

RUN echo "Installing protoc-$PROTOBUF_VERSION-$PROTOBUF_PLATFORM" && \
    wget --quiet $PROTOBUF_URL -O protoc.zip && \
    unzip protoc.zip -d protoc && \
    cp -R protoc/bin/* /usr/local/bin/ && \
    cp -R protoc/include/* /usr/local/include/ && \
    rm -rf protoc protoc.zip



COPY --from=js /node /node
COPY --from=go /go/bin/protoc-gen-go /usr/local/bin/
COPY --from=go /go/bin/protoc-gen-go-grpc /usr/local/bin/
COPY --from=go /go/bin/protoc-gen-connect-go /usr/local/bin/
COPY --from=java /go/bin/protoc-gen-grpc-java /usr/local/bin/


RUN ln -s /node/node_modules/@bufbuild/protoc-gen-connect-web/bin/protoc-gen-connect-web /usr/local/bin/protoc-gen-connect-web
RUN ln -s /node/node_modules/@bufbuild/protoc-gen-es/bin/protoc-gen-es /usr/local/bin/protoc-gen-es

ARG protodist_version="1.0.0-alpha.2"

# Install protodist
RUN curl -L https://github.com/4nte/protodist/releases/download/v${protodist_version}/protodist_${protodist_version}_Linux_amd64.tar.gz| tar -xz
RUN chmod +x protodist
RUN mv protodist /bin/protodist

COPY --from=go /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"

ENTRYPOINT bash
