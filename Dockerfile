# First stage - compile
FROM mjmckinnon/ubuntubuild as builder

# bitcoin
ARG VERSION="v1.0.8"
ARG GITREPO="https://github.com/bitcoin-sv/bitcoin-sv.git"
ARG GITNAME="bitcoin-sv"
ARG COMPILEFLAGS="--enable-cxx --disable-shared --with-pic --disable-wallet --without-gui --without-miniupnpc"

ENV DEBIAN_FRONTEND="noninteractive"
ENV TZ="Australia/Melbourne"

# Get the source from Github
WORKDIR /root
RUN git clone ${GITREPO}

# Checkout the right version, compile, and grab
WORKDIR /root/${GITNAME}
RUN \
    echo "** checkout and compile **" \
    && git checkout ${VERSION} \
	&& ./autogen.sh \
	&& ./configure ${COMPILEFLAGS} \
	&& make \
    && mkdir /install \
    && make install DESTDIR=/install \
    && echo "** removing extra lib files **" \
    && find /install -name "lib*.la" -delete \
    && find /install -name "lib*.a" -delete

# Package up compiled binaries
WORKDIR /install
RUN \
    echo "** packaging up installed files **" \
    && find . | sort | \
    tar --no-recursion --mode='u+rw,go+r-w,a+X' --owner=0 --group=0 -c -T - | \
    gzip -9n > /root/dist-files.tar.gz

# Last stage
FROM ubuntu:20.04
LABEL maintainer="Michael J. McKinnon <mjmckinnon@gmail.com>"

# Put our entrypoint script in
COPY ./docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Copy the dist archive from build image
COPY --from=builder /root/dist-files.tar.gz /root

ENV DEBIAN_FRONTEND="noninteractive"
RUN \
    echo "** extract compiled files **" \
    && tar -xzvf /root/dist-files.tar.gz -C / \
    && echo "** update and install dependencies ** " \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    gosu \
    libboost-filesystem-dev \
    libboost-thread-dev \
    libevent-dev \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    && groupadd -g 1000 bitcoinsv \
    && useradd -u 1000 -g bitcoinsv bitcoinsv

ENV DATADIR="/data"
EXPOSE 8333
VOLUME /data
CMD ["bitcoind", "-printtoconsole", "-server=1"]