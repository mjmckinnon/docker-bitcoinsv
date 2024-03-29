FROM mjmckinnon/ubuntubuild as builder

# Bitcoin SV
ARG VERSION="v1.0.13"
ARG GITREPO="https://github.com/bitcoin-sv/bitcoin-sv.git"
ARG GITNAME="bitcoin-sv"
ARG COMPILEFLAGS="--disable-tests --disable-bench --enable-cxx --disable-shared --with-pic --disable-wallet --without-gui --without-miniupnpc"
ENV DEBIAN_FRONTEND="noninteractive"

# Get the source from Github
WORKDIR /root
RUN git clone ${GITREPO} --branch ${VERSION}
WORKDIR /root/${GITNAME}
# Bitcoin-SV v1.0.13 has a compiler error under Ubuntu 22.04
# so as a kludge this patch file inserts '#include <mutex>'
# to two files: src/txn_util.h and src/txn_recent_rejects.cpp
#COPY ./bsv-mutex.patch ./
#RUN \
#    echo "** patching files (kludge) **" \
#    && git apply ./bsv-mutex.patch

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
    # No need to clean up, this build image is discarded
    # && cd .. && rm -rf ${GITREPO}

# Final stage
FROM ubuntu:22.04
LABEL maintainer="Michael J. McKinnon<mjmckinnon@gmail.com>"

# Put our entrypoint script in
COPY ./docker-entrypoint.sh /usr/local/bin/

# Copy the compiled files
COPY --from=builder /dist-files/ /

ENV DEBIAN_FRONTEND="noninteractive"
RUN \
    echo "** update and install dependencies **" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    gosu \
    libboost-filesystem1.74.0 \
    libboost-thread1.74.0 \
    libevent-2.1-7 \
    libevent-pthreads-2.1-7 \
    libboost-program-options1.74.0 \
    libboost-chrono1.74.0 \
    libczmq4 \
    && echo "** cleanup **" \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
    && rm -rf /tmp/* /var/tmp/*

RUN \
    echo "** setup the bitcoinsv user **" \
    && groupadd -r bitcoinsv \
    && useradd --no-log-init -m -d /data -r -g bitcoinsv bitcoinsv

ENV DATADIR="/data"
EXPOSE 8332
EXPOSE 8333
VOLUME /data

USER bitcoinsv

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bitcoind", "-printtoconsole", "-excessiveblocksize=2000000000", "-maxstackmemoryusageconsensus=200000000", "-minminingtxfee=0.00000500"]
