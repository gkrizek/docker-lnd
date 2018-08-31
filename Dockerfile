FROM golang:1.10-stretch as builder

MAINTAINER Tom Kirkpatrick <tkp@kirkdesigns.co.uk>

WORKDIR $GOPATH/src/github.com/lightningnetwork/lnd

# Grab and install the latest version of lnd and all related dependencies.
ENV GODEBUG netdns=cgo
RUN git clone https://github.com/lightningnetwork/lnd $GOPATH/src/github.com/lightningnetwork/lnd
WORKDIR $GOPATH/src/github.com/lightningnetwork/lnd
RUN make
RUN make install
RUN cp /go/bin/lncli /bin/
RUN cp /go/bin/lnd /bin/

# Install zapconnect
RUN go get -d github.com/LN-Zap/zapconnect
WORKDIR $GOPATH/src/github.com/LN-Zap/zapconnect
RUN make

FROM ubuntu:xenial
MAINTAINER Tom Kirkpatrick <tkp@kirkdesigns.co.uk>

ARG USER_ID
ARG GROUP_ID

ENV HOME /lnd

# add user with specified (or default) user/group ids
ENV USER_ID ${USER_ID:-1000}
ENV GROUP_ID ${GROUP_ID:-1000}

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -g ${GROUP_ID} lnd \
	&& useradd -u ${USER_ID} -g lnd -s /bin/bash -m -d /lnd lnd

# Copy the compiled binaries from the builder image.
COPY --from=builder /go/bin/lncli /bin/
COPY --from=builder /go/bin/lnd /bin/
COPY --from=builder /go/bin/zapconnect /bin/

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.7
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends \
		ca-certificates \
		wget \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y \
		ca-certificates \
		wget \
	&& apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD ./bin /usr/local/bin

VOLUME ["/lnd"]

# Expose p2p port
EXPOSE 9735 9735

# Expose grpc port
EXPOSE 10009 10009


WORKDIR /lnd

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["lnd_oneshot"]