# Proxy latency test

## Setup

1. Prepare at least 3 hosts:

   * 1 for load generator (wrk/fortio)

   * 1 for proxy

   * 1 for backend upstream server

   in case you need more upstream, add those host to the upstream server group please.

2. Install ansible and set hosts `client`, `proxy`, `server01`, `server02`... on client hosts, please change the IP accordingly

```
# cat /etc/hosts
...
1.1.1.1 client
1.1.1.2 proxy
1.1.1.3 server01
# if there are multiple upstreams
1.1.1.4 server02
1.1.1.5 server03
```

In addition to the hosts settings, please ensure the client host could ssh to all other hosts by ssh key.

3. Use the ansible playbooks to init all the hosts, in case you need more upstreams, add additional server to the `upstream_group` in the ansible inventory

```
# cd ansible
# ansible-playbooks -i inventory main.yml
```

## Tests

Go into the scripts dir and test with script `run.sh`

```
Usage: ./run.sh [-l <floor level QPS> |-u <upper limit QPS> |-s <QPS steps>|-t <proxy type>|-d <duration>|-c <connections>|-q <QPS>]
       -l <floor level QPS>   Set floor level QPS
       -u <upper limit QPS>   Set uppper limit QPS
       -s <QPS steps>         QPS steps between each test case
       -c <connecitons>       Number of connections
       -t <proxy type>        Could be nginx, haproxy, pipy, envoy and all
       -d <duration>          Test duration
       -q <QPS>               Set QPS
       -m <mode>              test proxy with getting different payload size
```

### QPS vs latency

Test pipy proxy, with 32 connections, QPS increase from 1000 to 8000, in steps of 1000, each test is last for 1 min.
```
# ./run.sh -c 32 -l 1000 -h 8000 -s 1000 -t pipy -d 1m
```

`-t` could be `nginx`, `haproxy`, `pipy`, `envoy` and `all`

### connections vs latency

Test pipy, with 12000 QPS, connections increase from 16 to 64, in steps of 16, each test is last for 1 min.

```
# ./run.sh -q 12000 -l 16 -h 64 -s 16 -t pipy -d 1m
```

### upstream count vs latency

Modify `upstream_group` in the ansible inventory and setup the env again at first, then test proxy with same connections and QPS.

```
# modify upstream_group in ansible inventory
# ansible-playbooks -i inventory main.yml
```

```
# ./run.sh -q 12000 -l 32 -h 32 -s 32 -t pipy -d 1m
```

### payload vs latency

As we need different payload size in this case, `http-echo` is not easy to setup, so we use `pipy` as upstream, we could get different payload through different path.

set `mode` to `payload` when setup environment

```
# ansible-playbooks -i inventory main.yml -e mode=payload
```

We will test latency by different payload size: 1k, 100k and 1M
```
./run.sh -t pipy -m payload -d 1m
```