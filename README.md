# Docker Image for Bitcoin SV (Satoshi Vision)

This is a docker image for [Bitcoin-SV](https://github.com/bitcoin-sv/bitcoin-sv) which uses the sourcecode from the official
repository and builds from that source, so this image can be reasonably trusted; unlike many other images which are not always
obvious about whether or not other malicious artefacts have been inserted.

Current release builds from the tag: v1.0.13
The build and final image is based on: Ubuntu 22.04.

Note: Previously bitcoin-sv v1.0.11 did not compile on Ubuntu 22.04 without fixing some errors in the BSV source code but
this seems to have been fixed now. Previous commit in this repo applied a patch (inserts #include <mutex> in two places).

## Usage in docker-compose

Run this image in docker-compose as follows (with options such as txindex used for collecting utxo):

  bitcoincore:
    image: mjmckinnon/bitcoinsv
    container_name: bitcoinsv
    environment: *default-environment
    command:
      -printtoconsole
      -server=1
      -txindex=1
      -maxconnections=50
      -dbcache=1024
      -port=8333
      -rpcport=8332
      -rpcbind=127.0.0.1
      -rpcbind=bitcoinsv
      -rpcallowip=0.0.0.0/0
    volumes:
      - /nfs/appstorage/bitcoinsv:/data
    ports:
      - 8332:8332
      - 8333:8333
    networks:
      - network
    restart: unless-stopped

