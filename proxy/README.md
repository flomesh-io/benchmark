# Proxy test

## setup

1. Prepare 3 hosts, 1 for wrk, 1 for proxy, 1 for backend server

2. Install ansible and set hosts (client, proxy, server) on client hosts, please change the IP accordingly

```
# cat /etc/hosts
...
1.1.1.1 client
1.1.1.2 proxy
1.1.1.3 server
```

In addition to the hosts settings, please ensure the client(wrk) host could ssh to all hosts by ssh key.

3. Use the ansible playbooks to init 3 hosts

```
# cd ansible
# ansible-playbooks -i inventory main.yml
```

### use fortio to as load generator

1. install fortio

```
# curl -LO https://github.com/fortio/fortio/releases/download/v1.25.0/fortio-linux_x64-1.25.0.tgz
# tar xvf fortio-linux_x64-1.25.0.tgz -C /
```

2. in the scripts dir, run fortio-test.sh

* Keep same connections, compare results of different QPS, between proxies

test nginx, with 32 connections, QPS increase from 1000 to 8000, step is 1000, duration 1 min.

```
# ./fortio-test.sh -c 32 -l 1000 -h 8000 -s 1000 -t nginx -d 1m
```

`-t` could be `nginx`, `haproxy`, `pipy`, `envoy` and `all`

* Keep same QPS, compare results of different connections, for particular proxy

test nginx, with 12000 QPS, connections increase from 16 to 64, step is 16, duration 1 min.

```
# ./fortio-test.sh -q 12000 -l 16 -h 64 -s 16 -t nginx -d 1m
```
