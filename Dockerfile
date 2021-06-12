FROM mjmckinnon/ubuntubuild as builder

# Bitcoin SV
ARG VERSION="v1.0.8"
ARG GITREPO="https://github.com/bitcoin-sv/bitcoin-sv.git"
ARG GITNAME="bitcoin-sv"
ARG COMPILEFLAGS="--disable-tests --disable-bench --enable-cxx --disable-shared --with-pic --disable-wallet --without-gui --without-miniupnpc"
ENV DEBIAN_FRONTEND="noninteractive"

# Get the source from Github
WORKDIR /root
RUN git clone ${GITREPO} --branch ${VERSION}
WORKDIR /root/${GITNAME}
RUN \
    echo "** compile **" \
    && ./autogen.sh \
    && ./configure CXXFLAG="-O2" LDFLAGS=-static-libstdc++ ${COMPILEFLAGS} \
    && make \
    && echo "** install and strip the binaries **" \
    && mkdir -p /dist-files \
    && make install DESTDIR=/dist-files \
    && strip /dist-files/usr/local/bin/* \
    && echo "** removing extra lib files **" \
    && find /dist-files -name "lib*.la" -delete \
    && find /dist-files -name "lib*.a" -delete
    # && cd .. && rm -rf ${GITREPO}

# Final stage
FROM ubuntu:20.04
LABEL maintainer="Michael J. McKinnon <mjmckinnon@gmail.com>"

# Put our entrypoint script in
COPY ./docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Copy the compiled files
COPY --from=builder /dist-files/ /

RUN \
    echo "** setup the bitcoinsv user **" \
    && groupadd -g 1000 bitcoinsv \
    && useradd -u 1000 -g bitcoinsv bitcoinsv

ENV DEBIAN_FRONTEND="noninteractive"
RUN \
    echo "** update and install dependencies ** " \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    gosu \
    libboost-filesystem1.71.0 \
    libboost-thread1.71.0 \
    libevent-2.1-7 \
    libevent-pthreads-2.1-7 \
    libboost-program-options1.71.0 \
    libboost-chrono1.71.0 \
    libczmq4 \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
    && rm -rf /tmp/* /var/tmp/*

ENV DATADIR="/data"
EXPOSE 8333
VOLUME /data
CMD ["bitcoind", "-printtoconsole", "-excessiveblocksize=2000000000", "-maxstackmemoryusageconsensus=200000000"]