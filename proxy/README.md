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

4. Go to scripts dir and start test by `latency.sh` and `throughput.sh`

in `latency.sh` you need to set `PROXY_IP` and `REAL_SERVER_IP`, run script with position arguments:

```
# cd scripts
# ./latency.sh 2 256 512 5m
```

in `throughput.sh` you need to set `proxy` to the target proxy name/type and `proxy_addr`, then set other option as you need:

```
# cd scripts
# ./throughput.sh
```

### use fortio to as load generator

1. install fortio

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

## Reference

* https://github.com/CatTail/autobench2
* https://github.com/MaartenSmeets/db_perftest/blob/master/test_scripts/wrk_parser.py
* https://qiita.com/hippocampus-coronatus/items/982255fc4f61c3f1ff52
