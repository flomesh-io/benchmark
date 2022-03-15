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

## Reference

* https://github.com/CatTail/autobench2
* https://github.com/MaartenSmeets/db_perftest/blob/master/test_scripts/wrk_parser.py
* https://qiita.com/hippocampus-coronatus/items/982255fc4f61c3f1ff52
