# Connections Per Second

## Methodlogy

Client create new connection each time, and server send 0-byte response to client.

We use 4 jmeter server, each server own 200 threads. The [script](./cps.jmx) is as follows

```
jmeter -n -t cps.jmx \
    -R 192.168.10.31,192.168.10.32,192.168.10.33,192.168.10.42 \
    -Ghost=192.168.10.84 \
    -Gport=9001 \
    -Gthreads=200 \
    -Gduration=180 \
    -Gpath=/ \
    -l x64-4c-c800.jtl \
    -e \
    -o x64-4c-c800
```
