---
title: Pipy as HTTP Echo Server
---

# Benchmark : Pipy as HTTP Echo Server

## Background and context

When we want to test the performance of a proxy, we usually need a "backend service". It's also called "real server", "upstream", etc. There are many programs that provide this functionality, such as Nginx, which provides basic static pages; and hashicorp's http-echo(https://github.com/hashicorp/http-echo). The same functionality can be provided with very little PipyJS scripting, and with better customizability and even better performance.

In this article, we do baseline performance tests on several software programs: nginx, http-echo, and pipy, and we test various performance-related metrics on the output of the basic "Hello World" message from these three programs.

## Load Test Tools

We use three testing tools:
 * __ab__ (Apache Bench), ab is used to test HTTP short-lived connections, that is, one request each connection. `ab -c100 -n1000000 URL`
 * __wrk__ (https://github.com/wg/wrk), wrk is used to test long-lived HTTP connections, i.e. multiple request on each connection; wrk is also used to test the performance metrics of the server in the "extreme condition" (100% CPU usage). `wrk -c100 -t1 -n20 --latency URL`
 * __fortio__ (https://github.com/fortio/fortio), fortio is used to test the latency at the specified qps. `fortio load -c 100 -n 1000000 --qps 10000 URL` 

We run the test tool and the server in the same virtual machine, communicating via 127.0.0.1, mainly to avoid the influence of the physical network on the results, because the subject of our test is only the "software".

## Hardware 

We use a virtual machine with 2 VCPUs, one CPU running the test program and the other running the server-side software. Since all software can scale up almost linearly by adding CPUs or instances, we only test the performance baseline for the minimum configuration case.

## OS

We did this test on two operating systems, one is Ubuntu 21 server edition and the other is FreeBSD13, both being the ARM editions. Each virtual machine was configured with 2C4G.

## Why FreeBSD

We chose to do our testing on FreeBSD because we found that: when we want to provide a software load balancer, the overall cost (TCO) is better with FreeBSD (compared to Linux). In several of our test scenarios, FreeBSD such as Linux provided up to 30% better performance (latency, throughput rate).

## About ARM64

We chose the ARM64 platform for testing mainly because our junior partner's work machine is a Macbook M1, which is very easy to create and manage virtual machines using UTM(https://github.com/utmapp/UTM) software. Another reason is because we designed Pipy hoping it would run well in edge computing and IoT environments.

The low-end ARM64 servers also have a strong cost advantage. Our website, flomesh.io, is running on 10 2C0.5G aws ARM64 lightsail cloud hosts distributed around the world, providing access to North America, Europe, and Asia, using route53 as a smart DNS for proximity access. Low-end, or even ultra-low-end ARM64 cloud hosting coupled with FreeBSD is the lowest cost solution for static sites like ours (static content with some reverse proxy). Eat your own dog food ~

## Test Scope

Our tests did not cover the following cases.

 * Only HTTP GET was tested, not HTTP POST
 * Only tested the case where the return content contains very few characters (hello world)
 * Did not test the mixed load case, where all requests are the same
 * Only tested data in case of 100 concurrency, in most testing software the number of concurrency is specified by the '-c' parameter
 * For the extreme stress test, we only tested 20 seconds; for the fixed qps test, we only tested data with 1 million requests at 10,000 qps
 
## Software version and configration

 * nginx and wrk and ab, which we install using the system package manager, i.e. pkg and apt-get
 * http-echo and pipy and fortio are compiled from source code
 * Nginx we configured 1 worker, and turned off access logging and error logging (to avoid disk operations affecting performance)
 
We did not change any kernel parameters except for the "maximum open files"; we set the maximum open files to 1024000.

The script we use for pipy is tutorial/02-echo/echo.js. This script listens on 3 ports, 8080 for basic hello world information, 8081 for echo service, and 8082 for dynamic content with the client's IP address.

## Test Cases List 

So there is the test cases list (two platforms, 3 types of load tester, 3 types of servers. 2 x 3 x 3 = 18 test cases) :

 1. ubuntu21-arm64, ab test nginx
 2. ubuntu21-arm64, ab test http-echo
 3. ubuntu21-arm64, ab test pipy
 4. ubuntu21-arm64, wrk test nginx
 5. ubuntu21-arm64, wrk test http-echo
 6. ubuntu21-arm64, wrk test pipy
 7. ubuntu21-arm64, fortio test nginx
 8. ubuntu21-arm64, fortio test http-echo
 9. ubuntu21-arm64, fortio test pipy
 10. freebsd13-arm64, ab test nginx
 11. freebsd13-arm64, ab test http-echo
 12. freebsd13-arm64, ab test pipy
 13. freebsd13-arm64, wrk test nginx
 14. freebsd13-arm64, wrk test http-echo
 15. freebsd13-arm64, wrk test pipy
 16. freebsd13-arm64, fortio test nginx
 17. freebsd13-arm64, fortio test http-echo
 18. freebsd13-arm64, fortio test pipy

## Test Report

Major indicators we recorded are qps and latency, together with cpu and memory usage. We use 'top' to roughtly record mem and cpu. Put all key result into this table:

 * ab has no latency data
 * wrk has no latency data for P99.9

 | Test Case #| OS           | Tester | Upstream Server | QPS    | Latency P50 | P90/P50  | P99/P50  | P99.9/P50 | Mem(RES) | CPU |
 |------------|--------------|--------|-----------------|--------|-------------|----------|----------|-----------|----------|-----|
 | 1          |ubuntu21-arm64| ab     | nginx           | 60824  |             |          |          |           |      6.5M|  91%|
 | 2          |ubuntu21-arm64| ab     | http-echo       | 44826  |             |          |          |           |     11.9M| 106%|
 | 3          |ubuntu21-arm64| ab     | pipy            | 59698  |             |          |          |           |      9.3M|  94%|
 | 4          |ubuntu21-arm64| wrk    | nginx           | 82759  |    1.20ms   |    112.5%|      185%|           |      6.5M| 100%|
 | 5          |ubuntu21-arm64| wrk    | http-echo       | 94579  |    0.94ms   |    396.8%|     1023%|           |     12.7M| 107%|
 | 6          |ubuntu21-arm64| wrk    | pipy            |218539  |   0.445ms   |    111.9%|      137%|           |      9.3M| 100%|
 | 7          |ubuntu21-arm64| fortio | nginx           |        |   1.449ms   |    238.5%|    334.7%|     535.7%|      6.5M|  29%|
 | 8          |ubuntu21-arm64| fprtio | http-echo       |        |   0.633ms   |    240.1%|    311.6%|     471.9%|     11.4M|  15%|
 | 9          |ubuntu21-arm64| fortio | pipy            |        |   1.851ms   |    189.7%|    269.1%|     414.2%|      9.6M|  33%|
 
# Appendix : Test Records

Detail test result : 

## 1. ubuntu21-arm64, ab test nginx

~~~~bash
root@ubuntu21-arm64:~# ab -c100 -n1000000 http://127.0.0.1:80/
This is ApacheBench, Version 2.3 <$Revision: 1879490 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 127.0.0.1 (be patient)
Completed 100000 requests
Completed 200000 requests
Completed 300000 requests
Completed 400000 requests
Completed 500000 requests
Completed 600000 requests
Completed 700000 requests
Completed 800000 requests
Completed 900000 requests
Completed 1000000 requests
Finished 1000000 requests


Server Software:        nginx/1.18.0
Server Hostname:        127.0.0.1
Server Port:            80

Document Path:          /
Document Length:        6 bytes

Concurrency Level:      100
Time taken for tests:   16.441 seconds
Complete requests:      1000000
Failed requests:        0
Total transferred:      244000000 bytes
HTML transferred:       6000000 bytes
Requests per second:    60824.04 [#/sec] (mean)
Time per request:       1.644 [ms] (mean)
Time per request:       0.016 [ms] (mean, across all concurrent requests)
Transfer rate:          14493.23 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   0.1      1       3
Processing:     0    1   0.2      1       6
Waiting:        0    1   0.2      1       4
Total:          1    2   0.2      2       7

Percentage of the requests served within a certain time (ms)
  50%      2
  66%      2
  75%      2
  80%      2
  90%      2
  95%      2
  98%      2
  99%      2
 100%      7 (longest request)
~~~~

## 2. ubuntu21-arm64, ab test http-echo

~~~~bash
root@ubuntu21-arm64:~# ab -c100 -n1000000 http://127.0.0.1:9090/
This is ApacheBench, Version 2.3 <$Revision: 1879490 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 127.0.0.1 (be patient)
Completed 100000 requests
Completed 200000 requests
Completed 300000 requests
Completed 400000 requests
Completed 500000 requests
Completed 600000 requests
Completed 700000 requests
Completed 800000 requests
Completed 900000 requests
Completed 1000000 requests
Finished 1000000 requests


Server Software:        
Server Hostname:        127.0.0.1
Server Port:            9090

Document Path:          /
Document Length:        13 bytes

Concurrency Level:      100
Time taken for tests:   22.308 seconds
Complete requests:      1000000
Failed requests:        0
Total transferred:      166000000 bytes
HTML transferred:       13000000 bytes
Requests per second:    44826.84 [#/sec] (mean)
Time per request:       2.231 [ms] (mean)
Time per request:       0.022 [ms] (mean, across all concurrent requests)
Transfer rate:          7266.85 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.4      0       8
Processing:     0    2   1.7      2      23
Waiting:        0    2   1.6      2      23
Total:          0    2   1.6      2      23

Percentage of the requests served within a certain time (ms)
  50%      2
  66%      2
  75%      2
  80%      3
  90%      3
  95%      6
  98%      8
  99%     10
 100%     23 (longest request)
~~~~

## 3. ubuntu21-arm64, ab test pipy

~~~~bash
root@ubuntu21-arm64:~# ab -c100 -n1000000 http://127.0.0.1:8080/
This is ApacheBench, Version 2.3 <$Revision: 1879490 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 127.0.0.1 (be patient)
Completed 100000 requests
Completed 200000 requests
Completed 300000 requests
Completed 400000 requests
Completed 500000 requests
Completed 600000 requests
Completed 700000 requests
Completed 800000 requests
Completed 900000 requests
Completed 1000000 requests
Finished 1000000 requests


Server Software:        
Server Hostname:        127.0.0.1
Server Port:            8080

Document Path:          /
Document Length:        11 bytes

Concurrency Level:      100
Time taken for tests:   16.597 seconds
Complete requests:      1000000
Failed requests:        0
Total transferred:      69000000 bytes
HTML transferred:       11000000 bytes
Requests per second:    60253.07 [#/sec] (mean)
Time per request:       1.660 [ms] (mean)
Time per request:       0.017 [ms] (mean, across all concurrent requests)
Transfer rate:          4060.02 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   0.2      1       6
Processing:     0    1   0.2      1       7
Waiting:        0    1   0.2      1       6
Total:          1    2   0.2      2       9

Percentage of the requests served within a certain time (ms)
  50%      2
  66%      2
  75%      2
  80%      2
  90%      2
  95%      2
  98%      2
  99%      3
 100%      9 (longest request)
~~~~

## 4. ubuntu21-arm64, wrk test nginx

~~~~bash
root@ubuntu21-arm64:~# wrk -c100 -t1 -d20 --latency http://127.0.0.1:80/
Running 20s test @ http://127.0.0.1:80/
  1 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.23ms  695.34us  40.78ms   98.65%
    Req/Sec    83.20k     1.79k   90.72k    95.50%
  Latency Distribution
     50%    1.20ms
     75%    1.31ms
     90%    1.35ms
     99%    2.22ms
  1655833 requests in 20.01s, 393.12MB read
Requests/sec:  82759.60
Transfer/sec:     19.65MB
~~~~

## 5. ubuntu21-arm64, wrk test http-echo

~~~~bash
root@ubuntu21-arm64:~# wrk -c100 -t1 -d20 --latency http://127.0.0.1:9090/
Running 20s test @ http://127.0.0.1:9090/
  1 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.52ms    1.98ms  30.22ms   89.27%
    Req/Sec    95.12k     5.86k  105.40k    79.50%
  Latency Distribution
     50%    0.94ms
     75%    1.65ms
     90%    3.73ms
     99%    9.62ms
  1892395 requests in 20.01s, 299.58MB read
Requests/sec:  94579.38
Transfer/sec:     14.97MB
~~~~

## 6. ubuntu21-arm64, wrk test pipy

~~~~bash
root@ubuntu21-arm64:~# wrk -c100 -t1 -d20 --latency http://127.0.0.1:8080/
Running 20s test @ http://127.0.0.1:8080/
  1 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   462.39us  302.44us  30.95ms   99.48%
    Req/Sec   219.90k     9.82k  227.36k    92.00%
  Latency Distribution
     50%  445.00us
     75%  471.00us
     90%  498.00us
     99%  611.00us
  4372908 requests in 20.01s, 308.60MB read
Requests/sec: 218539.23
Transfer/sec:     15.42MB
~~~~

## 7. ubuntu21-arm64, fortio test nginx

~~~~bash
root@ubuntu21-arm64:~# fortio load -c 100 -n 1000000 -qps 10000 http://127.0.0.1:80/ | grep -v 'err EOF'
Fortio 1.22.0 running at 10000 queries per second, 2->2 procs, for 1000000 calls: http://127.0.0.1:80/
02:50:49 I httprunner.go:87> Starting http test for http://127.0.0.1:80/ with 100 threads at 10000.0 qps and parallel warmup
Starting at 10000 qps with 100 thread(s) [gomax 2] : exactly 1000000, 10000 calls each (total 1000000 + 0)
02:50:50 I http_client.go:778> Closing dead socket &{{0x4000fa8080}} (err EOF at first read)
02:50:50 I http_client.go:778> Closing dead socket &{{0x40001e3a80}} (err EOF at first read)
......
02:52:29 I periodic.go:693> T010 ended after 1m40.001425326s : 10000 calls. qps=99.99857469431525
02:52:29 I periodic.go:693> T006 ended after 1m40.001601316s : 10000 calls. qps=99.99839870964172
02:52:29 I periodic.go:693> T029 ended after 1m40.001740807s : 10000 calls. qps=99.99825922330356
02:52:29 I periodic.go:693> T099 ended after 1m40.001786513s : 10000 calls. qps=99.99821351891572
02:52:29 I periodic.go:693> T020 ended after 1m40.001942087s : 10000 calls. qps=99.99805795071629
02:52:29 I periodic.go:693> T035 ended after 1m40.002195779s : 10000 calls. qps=99.99780426921339
02:52:29 I periodic.go:693> T028 ended after 1m40.002527968s : 10000 calls. qps=99.99747209590461
02:52:29 I periodic.go:693> T083 ended after 1m40.00255205s : 10000 calls. qps=99.99744801512793
02:52:29 I periodic.go:693> T097 ended after 1m40.00259138s : 10000 calls. qps=99.99740868715077
02:52:29 I periodic.go:693> T090 ended after 1m40.002606505s : 10000 calls. qps=99.9973935629369
02:52:29 I periodic.go:693> T047 ended after 1m40.00263267s : 10000 calls. qps=99.99736739930769
02:52:29 I periodic.go:693> T013 ended after 1m40.002655627s : 10000 calls. qps=99.99734444352168
02:52:29 I periodic.go:693> T091 ended after 1m40.002704915s : 10000 calls. qps=99.99729515816368
02:52:29 I periodic.go:693> T050 ended after 1m40.002720998s : 10000 calls. qps=99.99727907603629
02:52:29 I periodic.go:693> T043 ended after 1m40.002735038s : 10000 calls. qps=99.99726503680229
02:52:29 I periodic.go:693> T002 ended after 1m40.002757204s : 10000 calls. qps=99.99724287201964
02:52:29 I periodic.go:693> T041 ended after 1m40.002780036s : 10000 calls. qps=99.99722004128385
02:52:29 I periodic.go:693> T024 ended after 1m40.002838782s : 10000 calls. qps=99.99716129858454
02:52:29 I periodic.go:693> T067 ended after 1m40.002874738s : 10000 calls. qps=99.9971253446388
02:52:29 I periodic.go:693> T076 ended after 1m40.002898612s : 10000 calls. qps=99.99710147201708
02:52:29 I periodic.go:693> T085 ended after 1m40.002928443s : 10000 calls. qps=99.99707164275527
02:52:29 I periodic.go:693> T051 ended after 1m40.002944192s : 10000 calls. qps=99.99705589468012
02:52:29 I periodic.go:693> T057 ended after 1m40.002958233s : 10000 calls. qps=99.99704185450884
02:52:29 I periodic.go:693> T059 ended after 1m40.002972357s : 10000 calls. qps=99.99702773134644
02:52:29 I periodic.go:693> T038 ended after 1m40.00298544s : 10000 calls. qps=99.99701464912586
02:52:29 I periodic.go:693> T055 ended after 1m40.003585487s : 10000 calls. qps=99.99641464155256
02:52:29 I periodic.go:693> T012 ended after 1m40.003731061s : 10000 calls. qps=99.99626907820297
02:52:29 I periodic.go:693> T082 ended after 1m40.003818764s : 10000 calls. qps=99.99618138182402
02:52:29 I periodic.go:693> T054 ended after 1m40.00402321s : 10000 calls. qps=99.99597695185568
02:52:29 I periodic.go:693> T049 ended after 1m40.004507764s : 10000 calls. qps=99.9954924391902
02:52:29 I periodic.go:693> T080 ended after 1m40.004777956s : 10000 calls. qps=99.99522227227773
02:52:29 I periodic.go:693> T023 ended after 1m40.004929614s : 10000 calls. qps=99.99507062899896
02:52:29 I periodic.go:693> T005 ended after 1m40.004951987s : 10000 calls. qps=99.99504825820961
02:52:29 I periodic.go:693> T040 ended after 1m40.004965487s : 10000 calls. qps=99.99503475954836
02:52:29 I periodic.go:693> T096 ended after 1m40.004978486s : 10000 calls. qps=99.99502176184089
02:52:29 I periodic.go:693> T039 ended after 1m40.004990568s : 10000 calls. qps=99.99500968104526
02:52:29 I periodic.go:693> T074 ended after 1m40.005029108s : 10000 calls. qps=99.99497114490656
02:52:29 I periodic.go:693> T019 ended after 1m40.005041232s : 10000 calls. qps=99.99495902212739
02:52:29 I periodic.go:693> T021 ended after 1m40.005053523s : 10000 calls. qps=99.99494673236804
02:52:29 I periodic.go:693> T036 ended after 1m40.005077146s : 10000 calls. qps=99.99492311176103
02:52:29 I periodic.go:693> T094 ended after 1m40.005109686s : 10000 calls. qps=99.99489057507557
02:52:29 I periodic.go:693> T060 ended after 1m40.00512856s : 10000 calls. qps=99.99487170300779
02:52:29 I periodic.go:693> T058 ended after 1m40.005140351s : 10000 calls. qps=99.9948599132185
02:52:29 I periodic.go:693> T079 ended after 1m40.005152517s : 10000 calls. qps=99.99484774847063
02:52:29 I periodic.go:693> T084 ended after 1m40.005164808s : 10000 calls. qps=99.99483545873863
02:52:29 I periodic.go:693> T066 ended after 1m40.005204347s : 10000 calls. qps=99.99479592383818
02:52:29 I periodic.go:693> T078 ended after 1m40.005254636s : 10000 calls. qps=99.99474564009748
02:52:29 I periodic.go:693> T011 ended after 1m40.005294633s : 10000 calls. qps=99.99470564731654
02:52:29 I periodic.go:693> T033 ended after 1m40.005309132s : 10000 calls. qps=99.99469114985386
02:52:29 I periodic.go:693> T087 ended after 1m40.005321132s : 10000 calls. qps=99.99467915112939
02:52:29 I periodic.go:693> T016 ended after 1m40.005332964s : 10000 calls. qps=99.99466732038988
02:52:29 I periodic.go:693> T073 ended after 1m40.005345089s : 10000 calls. qps=99.99465519668449
02:52:29 I periodic.go:693> T003 ended after 1m40.005357338s : 10000 calls. qps=99.99464294899533
02:52:29 I periodic.go:693> T022 ended after 1m40.005390544s : 10000 calls. qps=99.994609746564
02:52:29 I periodic.go:693> T075 ended after 1m40.005402752s : 10000 calls. qps=99.99459753988152
02:52:29 I periodic.go:693> T045 ended after 1m40.006334779s : 10000 calls. qps=99.99366562226884
02:52:29 I periodic.go:693> T095 ended after 1m40.006358944s : 10000 calls. qps=99.99364146033598
02:52:29 I periodic.go:693> T063 ended after 1m40.006372276s : 10000 calls. qps=99.99362813003314
02:52:29 I periodic.go:693> T004 ended after 1m40.006415607s : 10000 calls. qps=99.99358480457373
02:52:29 I periodic.go:693> T032 ended after 1m40.006436772s : 10000 calls. qps=99.99356364229367
02:52:29 I periodic.go:693> T062 ended after 1m40.006408982s : 10000 calls. qps=99.99359142872419
02:52:29 I periodic.go:693> T014 ended after 1m40.006451105s : 10000 calls. qps=99.99354931114071
02:52:29 I periodic.go:693> T044 ended after 1m40.006464562s : 10000 calls. qps=99.9935358558786
02:52:29 I periodic.go:693> T064 ended after 1m40.006478311s : 10000 calls. qps=99.99352210865796
02:52:29 I periodic.go:693> T009 ended after 1m40.006493561s : 10000 calls. qps=99.99350686063596
02:52:29 I periodic.go:693> T086 ended after 1m40.00650531s : 10000 calls. qps=99.99349511316306
02:52:29 I periodic.go:693> T088 ended after 1m40.006516934s : 10000 calls. qps=99.99348349067661
02:52:29 I periodic.go:693> T056 ended after 1m40.006460896s : 10000 calls. qps=99.99353952140481
02:52:29 I periodic.go:693> T053 ended after 1m40.0065311s : 10000 calls. qps=99.99346932652482
02:52:29 I periodic.go:693> T068 ended after 1m40.006543266s : 10000 calls. qps=99.99345716211529
02:52:29 I periodic.go:693> T092 ended after 1m40.006540349s : 10000 calls. qps=99.99346007873368
02:52:29 I periodic.go:693> T001 ended after 1m40.006555223s : 10000 calls. qps=99.99344520668132
02:52:29 I periodic.go:693> T018 ended after 1m40.006558432s : 10000 calls. qps=99.99344199810209
02:52:29 I periodic.go:693> T065 ended after 1m40.006568556s : 10000 calls. qps=99.99343187543093
02:52:29 I periodic.go:693> T017 ended after 1m40.006571014s : 10000 calls. qps=99.99342941775387
02:52:29 I periodic.go:693> T093 ended after 1m40.006580139s : 10000 calls. qps=99.9934202939538
02:52:29 I periodic.go:693> T070 ended after 1m40.006592346s : 10000 calls. qps=99.99340808856161
02:52:29 I periodic.go:693> T069 ended after 1m40.006603762s : 10000 calls. qps=99.99339667406794
02:52:29 I periodic.go:693> T026 ended after 1m40.006583222s : 10000 calls. qps=99.99341721135958
02:52:29 I periodic.go:693> T037 ended after 1m40.006615178s : 10000 calls. qps=99.99338525957685
02:52:29 I periodic.go:693> T072 ended after 1m40.006622428s : 10000 calls. qps=99.99337801053649
02:52:29 I periodic.go:693> T007 ended after 1m40.006627302s : 10000 calls. qps=99.99337313718222
02:52:29 I periodic.go:693> T077 ended after 1m40.006636052s : 10000 calls. qps=99.99336438834264
02:52:29 I periodic.go:693> T089 ended after 1m40.006639177s : 10000 calls. qps=99.99336126375745
02:52:29 I periodic.go:693> T008 ended after 1m40.006648468s : 10000 calls. qps=99.99335197399189
02:52:29 I periodic.go:693> T046 ended after 1m40.006650926s : 10000 calls. qps=99.99334951631874
02:52:29 I periodic.go:693> T098 ended after 1m40.006660925s : 10000 calls. qps=99.99333951864966
02:52:29 I periodic.go:693> T034 ended after 1m40.006662467s : 10000 calls. qps=99.9933379768551
02:52:29 I periodic.go:693> T071 ended after 1m40.0066728s : 10000 calls. qps=99.99332764523288
02:52:29 I periodic.go:693> T025 ended after 1m40.006674383s : 10000 calls. qps=99.99332606244415
02:52:29 I periodic.go:693> T030 ended after 1m40.006697757s : 10000 calls. qps=99.99330269156944
02:52:29 I periodic.go:693> T000 ended after 1m40.006704464s : 10000 calls. qps=99.99329598546825
02:52:29 I periodic.go:693> T048 ended after 1m40.006709589s : 10000 calls. qps=99.99329086115564
02:52:29 I periodic.go:693> T015 ended after 1m40.006717964s : 10000 calls. qps=99.99328248728008
02:52:29 I periodic.go:693> T061 ended after 1m40.006721338s : 10000 calls. qps=99.99327911373348
02:52:29 I periodic.go:693> T027 ended after 1m40.006729588s : 10000 calls. qps=99.99327086484307
02:52:29 I periodic.go:693> T042 ended after 1m40.006964157s : 10000 calls. qps=99.99303632796105
02:52:29 I periodic.go:693> T052 ended after 1m40.006988572s : 10000 calls. qps=99.99301191636727
02:52:29 I periodic.go:693> T031 ended after 1m40.007004405s : 10000 calls. qps=99.99299608558253
02:52:29 I periodic.go:693> T081 ended after 1m40.00706086s : 10000 calls. qps=99.99293963852224
Ended after 1m40.007300637s : 1000000 calls. qps=9999.3
Sleep times : count 999900 avg 0.0071740095 +/- 0.001588 min -0.022686331 max 0.009947412 sum 7173.29213
Aggregated Function Time : count 1000000 avg 0.0016620471 +/- 0.001176 min 1.454e-05 max 0.021023814 sum 1662.04713
# range, mid point, percentile, count
>= 1.454e-05 <= 0.001 , 0.00050727 , 36.27, 362698
> 0.001 <= 0.002 , 0.0015 , 66.80, 305350
> 0.002 <= 0.003 , 0.0025 , 84.52, 177131
> 0.003 <= 0.004 , 0.0035 , 96.50, 119811
> 0.004 <= 0.005 , 0.0045 , 99.44, 29376
> 0.005 <= 0.006 , 0.0055 , 99.75, 3151
> 0.006 <= 0.007 , 0.0065 , 99.86, 1040
> 0.007 <= 0.008 , 0.0075 , 99.91, 579
> 0.008 <= 0.009 , 0.0085 , 99.94, 242
> 0.009 <= 0.01 , 0.0095 , 99.96, 255
> 0.01 <= 0.011 , 0.0105 , 99.97, 106
> 0.011 <= 0.012 , 0.0115 , 99.98, 42
> 0.012 <= 0.014 , 0.013 , 99.99, 77
> 0.014 <= 0.016 , 0.015 , 99.99, 52
> 0.016 <= 0.018 , 0.017 , 99.99, 1
> 0.018 <= 0.02 , 0.019 , 99.99, 27
> 0.02 <= 0.0210238 , 0.0205119 , 100.00, 62
# target 50% 0.00144965
# target 75% 0.00246266
# target 90% 0.00345756
# target 99% 0.00485138
# target 99.9% 0.00776511
Sockets used: 10000 (for perfect keepalive, would be 100)
Uniform: false, Jitter: false
Code 200 : 1000000 (100.0 %)
Response Header Sizes : count 1000000 avg 242.95 +/- 0.4975 min 238 max 243 sum 242950000
Response Body/Total Sizes : count 1000000 avg 248.95 +/- 0.4975 min 244 max 249 sum 248950000
All done 1000000 calls (plus 0 warmup) 1.662 ms avg, 9999.3 qps
~~~~

* There plenty of 'err EOF...' errors while fortio load test nginx

## 8. ubuntu21-arm64, fortio test http-echo

~~~~bash
root@ubuntu21-arm64:~# fortio load -c 100 -n 1000000 -qps 10000 http://127.0.0.1:9090/
Fortio 1.22.0 running at 10000 queries per second, 2->2 procs, for 1000000 calls: http://127.0.0.1:9090/
03:12:37 I httprunner.go:87> Starting http test for http://127.0.0.1:9090/ with 100 threads at 10000.0 qps and parallel warmup
Starting at 10000 qps with 100 thread(s) [gomax 2] : exactly 1000000, 10000 calls each (total 1000000 + 0)
03:14:17 I periodic.go:693> T002 ended after 1m40.000957715s : 10000 calls. qps=99.9990422941721
03:14:17 I periodic.go:693> T042 ended after 1m40.001004672s : 10000 calls. qps=99.99899533809356
03:14:17 I periodic.go:693> T072 ended after 1m40.001020671s : 10000 calls. qps=99.99897933941757
03:14:17 I periodic.go:693> T039 ended after 1m40.001036712s : 10000 calls. qps=99.99896329874761
03:14:17 I periodic.go:693> T034 ended after 1m40.001041545s : 10000 calls. qps=99.99895846584803
03:14:17 I periodic.go:693> T090 ended after 1m40.001054544s : 10000 calls. qps=99.99894546712052
03:14:17 I periodic.go:693> T091 ended after 1m40.001075877s : 10000 calls. qps=99.99892413457498
03:14:17 I periodic.go:693> T044 ended after 1m40.001105167s : 10000 calls. qps=99.9988948452138
03:14:17 I periodic.go:693> T028 ended after 1m40.001240536s : 10000 calls. qps=99.99875947938911
03:14:17 I periodic.go:693> T012 ended after 1m40.001269077s : 10000 calls. qps=99.99873093910536
03:14:17 I periodic.go:693> T021 ended after 1m40.001250911s : 10000 calls. qps=99.99874910464759
03:14:17 I periodic.go:693> T008 ended after 1m40.001260452s : 10000 calls. qps=99.9987395638872
03:14:17 I periodic.go:693> T069 ended after 1m40.001265243s : 10000 calls. qps=99.9987347730082
03:14:17 I periodic.go:693> T017 ended after 1m40.001665434s : 10000 calls. qps=99.99833459373625
03:14:17 I periodic.go:693> T014 ended after 1m40.001676184s : 10000 calls. qps=99.99832384409545
03:14:17 I periodic.go:693> T092 ended after 1m40.001680184s : 10000 calls. qps=99.99831984422971
03:14:17 I periodic.go:693> T030 ended after 1m40.001683933s : 10000 calls. qps=99.99831609535583
03:14:17 I periodic.go:693> T088 ended after 1m40.001687267s : 10000 calls. qps=99.99831276146823
03:14:17 I periodic.go:693> T054 ended after 1m40.001690767s : 10000 calls. qps=99.99830926158644
03:14:17 I periodic.go:693> T099 ended after 1m40.001694016s : 10000 calls. qps=99.99830601269642
03:14:17 I periodic.go:693> T076 ended after 1m40.001697683s : 10000 calls. qps=99.99830234582079
03:14:17 I periodic.go:693> T060 ended after 1m40.001701224s : 10000 calls. qps=99.99829880494114
03:14:17 I periodic.go:693> T096 ended after 1m40.001704766s : 10000 calls. qps=99.99829526306178
03:14:17 I periodic.go:693> T047 ended after 1m40.001708224s : 10000 calls. qps=99.99829180517979
03:14:17 I periodic.go:693> T079 ended after 1m40.001711641s : 10000 calls. qps=99.99828838829664
03:14:17 I periodic.go:693> T025 ended after 1m40.001716057s : 10000 calls. qps=99.99828397244802
03:14:17 I periodic.go:693> T057 ended after 1m40.001719599s : 10000 calls. qps=99.99828043056971
03:14:17 I periodic.go:693> T070 ended after 1m40.001722848s : 10000 calls. qps=99.99827718168154
03:14:17 I periodic.go:693> T068 ended after 1m40.00172639s : 10000 calls. qps=99.99827363980371
03:14:17 I periodic.go:693> T067 ended after 1m40.001729765s : 10000 calls. qps=99.99827026492036
03:14:17 I periodic.go:693> T037 ended after 1m40.001733223s : 10000 calls. qps=99.9982668070401
03:14:17 I periodic.go:693> T093 ended after 1m40.00173689s : 10000 calls. qps=99.99826314016734
03:14:17 I periodic.go:693> T048 ended after 1m40.001740348s : 10000 calls. qps=99.99825968228758
03:14:17 I periodic.go:693> T038 ended after 1m40.001743681s : 10000 calls. qps=99.9982563494037
03:14:17 I periodic.go:693> T055 ended after 1m40.001747306s : 10000 calls. qps=99.99825272453025
03:14:17 I periodic.go:693> T065 ended after 1m40.001750889s : 10000 calls. qps=99.99824914165559
03:14:17 I periodic.go:693> T033 ended after 1m40.001754222s : 10000 calls. qps=99.99824580877241
03:14:17 I periodic.go:693> T086 ended after 1m40.001757722s : 10000 calls. qps=99.99824230889533
03:14:17 I periodic.go:693> T052 ended after 1m40.001761347s : 10000 calls. qps=99.9982386840229
03:14:17 I periodic.go:693> T015 ended after 1m40.001764763s : 10000 calls. qps=99.99823526814333
03:14:17 I periodic.go:693> T045 ended after 1m40.001768263s : 10000 calls. qps=99.99823176826699
03:14:17 I periodic.go:693> T050 ended after 1m40.001771846s : 10000 calls. qps=99.99822818539383
03:14:17 I periodic.go:693> T075 ended after 1m40.001775429s : 10000 calls. qps=99.99822460252092
03:14:17 I periodic.go:693> T087 ended after 1m40.001778721s : 10000 calls. qps=99.99822131063793
03:14:17 I periodic.go:693> T056 ended after 1m40.001782263s : 10000 calls. qps=99.99821776876405
03:14:17 I periodic.go:693> T049 ended after 1m40.001785637s : 10000 calls. qps=99.99821439488443
03:14:17 I periodic.go:693> T022 ended after 1m40.001789137s : 10000 calls. qps=99.99821089500954
03:14:17 I periodic.go:693> T016 ended after 1m40.001793179s : 10000 calls. qps=99.99820685315433
03:14:17 I periodic.go:693> T043 ended after 1m40.001796595s : 10000 calls. qps=99.99820343727696
03:14:17 I periodic.go:693> T023 ended after 1m40.001800012s : 10000 calls. qps=99.99820002039985
03:14:17 I periodic.go:693> T089 ended after 1m40.00180372s : 10000 calls. qps=99.99819631253348
03:14:17 I periodic.go:693> T059 ended after 1m40.00180772s : 10000 calls. qps=99.99819231267793
03:14:17 I periodic.go:693> T083 ended after 1m40.002326447s : 10000 calls. qps=99.9976736071223
03:14:17 I periodic.go:693> T094 ended after 1m40.002347863s : 10000 calls. qps=99.99765219212331
03:14:17 I periodic.go:693> T011 ended after 1m40.002364195s : 10000 calls. qps=99.99763586089286
03:14:17 I periodic.go:693> T040 ended after 1m40.002447608s : 10000 calls. qps=99.99755245190639
03:14:17 I periodic.go:693> T041 ended after 1m40.002792718s : 10000 calls. qps=99.99720735999057
03:14:17 I periodic.go:693> T006 ended after 1m40.002837841s : 10000 calls. qps=99.99716223953112
03:14:17 I periodic.go:693> T010 ended after 1m40.002858257s : 10000 calls. qps=99.997141824694
03:14:17 I periodic.go:693> T035 ended after 1m40.002874923s : 10000 calls. qps=99.99712515964946
03:14:17 I periodic.go:693> T053 ended after 1m40.002945128s : 10000 calls. qps=99.99705495873525
03:14:17 I periodic.go:693> T064 ended after 1m40.002966252s : 10000 calls. qps=99.99703383598391
03:14:17 I periodic.go:693> T046 ended after 1m40.003052499s : 10000 calls. qps=99.99694759417466
03:14:17 I periodic.go:693> T063 ended after 1m40.003073498s : 10000 calls. qps=99.996926596461
03:14:17 I periodic.go:693> T074 ended after 1m40.003129287s : 10000 calls. qps=99.99687081092131
03:14:17 I periodic.go:693> T077 ended after 1m40.003146411s : 10000 calls. qps=99.99685368799591
03:14:17 I periodic.go:693> T018 ended after 1m40.003161994s : 10000 calls. qps=99.99683810597891
03:14:17 I periodic.go:693> T005 ended after 1m40.003177743s : 10000 calls. qps=99.99682235797731
03:14:17 I periodic.go:693> T098 ended after 1m40.003224699s : 10000 calls. qps=99.99677540498348
03:14:17 I periodic.go:693> T007 ended after 1m40.003240449s : 10000 calls. qps=99.99675965600169
03:14:17 I periodic.go:693> T081 ended after 1m40.003280905s : 10000 calls. qps=99.99671920263985
03:14:17 I periodic.go:693> T078 ended after 1m40.003290238s : 10000 calls. qps=99.9967098702531
03:14:17 I periodic.go:693> T084 ended after 1m40.003295321s : 10000 calls. qps=99.99670478758783
03:14:17 I periodic.go:693> T026 ended after 1m40.003303613s : 10000 calls. qps=99.99669649613499
03:14:17 I periodic.go:693> T062 ended after 1m40.003312196s : 10000 calls. qps=99.9966879137028
03:14:17 I periodic.go:693> T085 ended after 1m40.003316945s : 10000 calls. qps=99.9966831650176
03:14:17 I periodic.go:693> T066 ended after 1m40.003263031s : 10000 calls. qps=99.99673707547024
03:14:17 I periodic.go:693> T031 ended after 1m40.003269489s : 10000 calls. qps=99.99673061789208
03:14:17 I periodic.go:693> T061 ended after 1m40.003273489s : 10000 calls. qps=99.9967266181538
03:14:17 I periodic.go:693> T001 ended after 1m40.003403358s : 10000 calls. qps=99.99659675782452
03:14:17 I periodic.go:693> T013 ended after 1m40.003277364s : 10000 calls. qps=99.99672274340763
03:14:17 I periodic.go:693> T036 ended after 1m40.003322237s : 10000 calls. qps=99.99667787336891
03:14:17 I periodic.go:693> T073 ended after 1m40.003334736s : 10000 calls. qps=99.99666537520093
03:14:17 I periodic.go:693> T019 ended after 1m40.003338444s : 10000 calls. qps=99.99666166744836
03:14:17 I periodic.go:693> T024 ended after 1m40.003341903s : 10000 calls. qps=99.99665820867942
03:14:17 I periodic.go:693> T082 ended after 1m40.003345402s : 10000 calls. qps=99.99665470991341
03:14:17 I periodic.go:693> T071 ended after 1m40.003349444s : 10000 calls. qps=99.996650668184
03:14:17 I periodic.go:693> T080 ended after 1m40.003352944s : 10000 calls. qps=99.99664716841856
03:14:17 I periodic.go:693> T029 ended after 1m40.003356485s : 10000 calls. qps=99.99664362765614
03:14:17 I periodic.go:693> T027 ended after 1m40.003359818s : 10000 calls. qps=99.99664029487997
03:14:17 I periodic.go:693> T009 ended after 1m40.003363318s : 10000 calls. qps=99.99663679511528
03:14:17 I periodic.go:693> T095 ended after 1m40.003367693s : 10000 calls. qps=99.99663242040974
03:14:17 I periodic.go:693> T000 ended after 1m40.003371235s : 10000 calls. qps=99.99662887864842
03:14:17 I periodic.go:693> T051 ended after 1m40.003374984s : 10000 calls. qps=99.99662512990132
03:14:17 I periodic.go:693> T032 ended after 1m40.003378818s : 10000 calls. qps=99.99662129616026
03:14:17 I periodic.go:693> T003 ended after 1m40.003384692s : 10000 calls. qps=99.99661542255753
03:14:17 I periodic.go:693> T004 ended after 1m40.003388401s : 10000 calls. qps=99.99661171380873
03:14:17 I periodic.go:693> T020 ended after 1m40.0033919s : 10000 calls. qps=99.99660821504595
03:14:17 I periodic.go:693> T097 ended after 1m40.003395859s : 10000 calls. qps=99.99660425631467
03:14:17 I periodic.go:693> T058 ended after 1m40.003399608s : 10000 calls. qps=99.99660050756943
Ended after 1m40.003515895s : 1000000 calls. qps=9999.6
Sleep times : count 999900 avg 0.0084883839 +/- 0.0006454 min -0.015657193 max 0.009937649 sum 8487.53507
Aggregated Function Time : count 1000000 avg 0.00071499763 +/- 0.0004117 min 1.5082e-05 max 0.012812771 sum 714.997633
# range, mid point, percentile, count
>= 1.5082e-05 <= 0.001 , 0.000507541 , 79.67, 796660
> 0.001 <= 0.002 , 0.0015 , 99.53, 198684
> 0.002 <= 0.003 , 0.0025 , 99.90, 3700
> 0.003 <= 0.004 , 0.0035 , 99.94, 404
> 0.004 <= 0.005 , 0.0045 , 99.96, 179
> 0.005 <= 0.006 , 0.0055 , 99.97, 112
> 0.006 <= 0.007 , 0.0065 , 99.98, 84
> 0.007 <= 0.008 , 0.0075 , 99.98, 4
> 0.008 <= 0.009 , 0.0085 , 99.99, 59
> 0.009 <= 0.01 , 0.0095 , 99.99, 5
> 0.01 <= 0.011 , 0.0105 , 99.99, 1
> 0.011 <= 0.012 , 0.0115 , 100.00, 78
> 0.012 <= 0.0128128 , 0.0124064 , 100.00, 30
# target 50% 0.000633236
# target 75% 0.000942314
# target 90% 0.00152012
# target 99% 0.0019731
# target 99.9% 0.00298811
Sockets used: 100 (for perfect keepalive, would be 100)
Uniform: false, Jitter: false
Code 200 : 1000000 (100.0 %)
Response Header Sizes : count 1000000 avg 153 +/- 0 min 153 max 153 sum 153000000
Response Body/Total Sizes : count 1000000 avg 166 +/- 0 min 166 max 166 sum 166000000
All done 1000000 calls (plus 0 warmup) 0.715 ms avg, 9999.6 qps
~~~~

## 9. ubuntu21-arm64, fortio test pipy

~~~~bash
root@ubuntu21-arm64:~# fortio load -c 100 -n 1000000 -qps 10000 http://127.0.0.1:8080/
Fortio 1.22.0 running at 10000 queries per second, 2->2 procs, for 1000000 calls: http://127.0.0.1:8080/
03:25:17 I httprunner.go:87> Starting http test for http://127.0.0.1:8080/ with 100 threads at 10000.0 qps and parallel warmup
Starting at 10000 qps with 100 thread(s) [gomax 2] : exactly 1000000, 10000 calls each (total 1000000 + 0)
03:26:57 I periodic.go:693> T053 ended after 1m40.00219697s : 10000 calls. qps=99.9978030782657
03:26:57 I periodic.go:693> T085 ended after 1m40.002869455s : 10000 calls. qps=99.99713062733537
03:26:57 I periodic.go:693> T042 ended after 1m40.002944541s : 10000 calls. qps=99.99705554570066
03:26:57 I periodic.go:693> T060 ended after 1m40.002967238s : 10000 calls. qps=99.9970328500424
03:26:57 I periodic.go:693> T043 ended after 1m40.002995682s : 10000 calls. qps=99.99700440773842
03:26:57 I periodic.go:693> T054 ended after 1m40.003072683s : 10000 calls. qps=99.99692741141091
03:26:57 I periodic.go:693> T014 ended after 1m40.003099253s : 10000 calls. qps=99.99690084305071
03:26:57 I periodic.go:693> T019 ended after 1m40.003124282s : 10000 calls. qps=99.99687581560833
03:26:57 I periodic.go:693> T000 ended after 1m40.003151643s : 10000 calls. qps=99.99684845632541
03:26:57 I periodic.go:693> T064 ended after 1m40.003193288s : 10000 calls. qps=99.99680681396762
03:26:57 I periodic.go:693> T024 ended after 1m40.003229061s : 10000 calls. qps=99.99677104326499
03:26:57 I periodic.go:693> T040 ended after 1m40.003260503s : 10000 calls. qps=99.99673960330533
03:26:57 I periodic.go:693> T066 ended after 1m40.003292153s : 10000 calls. qps=99.99670795537914
03:26:57 I periodic.go:693> T033 ended after 1m40.003320763s : 10000 calls. qps=99.996679347271
03:26:57 I periodic.go:693> T022 ended after 1m40.003346167s : 10000 calls. qps=99.99665394496459
03:26:57 I periodic.go:693> T047 ended after 1m40.003373195s : 10000 calls. qps=99.9966269187806
03:26:57 I periodic.go:693> T011 ended after 1m40.003405053s : 10000 calls. qps=99.99659506293992
03:26:57 I periodic.go:693> T093 ended after 1m40.003438244s : 10000 calls. qps=99.99656187421115
03:26:57 I periodic.go:693> T065 ended after 1m40.003464106s : 10000 calls. qps=99.99653601399615
03:26:57 I periodic.go:693> T075 ended after 1m40.003479723s : 10000 calls. qps=99.9965203980805
03:26:57 I periodic.go:693> T023 ended after 1m40.003493174s : 10000 calls. qps=99.99650694801838
03:26:57 I periodic.go:693> T039 ended after 1m40.003506334s : 10000 calls. qps=99.99649378893947
03:26:57 I periodic.go:693> T098 ended after 1m40.003528698s : 10000 calls. qps=99.9964714265127
03:26:57 I periodic.go:693> T038 ended after 1m40.003551311s : 10000 calls. qps=99.99644881511362
03:26:57 I periodic.go:693> T068 ended after 1m40.003573966s : 10000 calls. qps=99.99642616172775
03:26:57 I periodic.go:693> T092 ended after 1m40.003595705s : 10000 calls. qps=99.9964044242863
03:26:57 I periodic.go:693> T058 ended after 1m40.004146919s : 10000 calls. qps=99.99585325296225
03:26:57 I periodic.go:693> T010 ended after 1m40.004201599s : 10000 calls. qps=99.99579857752693
03:26:57 I periodic.go:693> T031 ended after 1m40.004230709s : 10000 calls. qps=99.99576946998141
03:26:57 I periodic.go:693> T013 ended after 1m40.004250824s : 10000 calls. qps=99.99574935668737
03:26:57 I periodic.go:693> T050 ended after 1m40.004283307s : 10000 calls. qps=99.99571687645934
03:26:57 I periodic.go:693> T056 ended after 1m40.004334656s : 10000 calls. qps=99.99566553188428
03:26:57 I periodic.go:693> T081 ended after 1m40.004420486s : 10000 calls. qps=99.99557970939833
03:26:57 I periodic.go:693> T086 ended after 1m40.004469086s : 10000 calls. qps=99.99553111371837
03:26:57 I periodic.go:693> T090 ended after 1m40.004535635s : 10000 calls. qps=99.99546457071052
03:26:57 I periodic.go:693> T012 ended after 1m40.004578446s : 10000 calls. qps=99.99542176361209
03:26:57 I periodic.go:693> T074 ended after 1m40.004618592s : 10000 calls. qps=99.99538162130406
03:26:57 I periodic.go:693> T082 ended after 1m40.004678145s : 10000 calls. qps=99.99532207384017
03:26:57 I periodic.go:693> T030 ended after 1m40.004734032s : 10000 calls. qps=99.99526619209998
03:26:57 I periodic.go:693> T076 ended after 1m40.004778426s : 10000 calls. qps=99.99522180232263
03:26:57 I periodic.go:693> T073 ended after 1m40.004927516s : 10000 calls. qps=99.99507272679217
03:26:57 I periodic.go:693> T017 ended after 1m40.00499344s : 10000 calls. qps=99.99500680933197
03:26:57 I periodic.go:693> T032 ended after 1m40.005039583s : 10000 calls. qps=99.99496067096118
03:26:57 I periodic.go:693> T088 ended after 1m40.005087683s : 10000 calls. qps=99.99491257583202
03:26:57 I periodic.go:693> T071 ended after 1m40.005128828s : 10000 calls. qps=99.99487143503528
03:26:57 I periodic.go:693> T004 ended after 1m40.00519267s : 10000 calls. qps=99.99480759962422
03:26:57 I periodic.go:693> T001 ended after 1m40.005237855s : 10000 calls. qps=99.99476241933688
03:26:57 I periodic.go:693> T049 ended after 1m40.005302405s : 10000 calls. qps=99.99469787614008
03:26:57 I periodic.go:693> T089 ended after 1m40.005418803s : 10000 calls. qps=99.99458149061834
03:26:57 I periodic.go:693> T079 ended after 1m40.005464071s : 10000 calls. qps=99.9945362275444
03:26:57 I periodic.go:693> T006 ended after 1m40.005532078s : 10000 calls. qps=99.99446822802194
03:26:57 I periodic.go:693> T009 ended after 1m40.005607247s : 10000 calls. qps=99.99439306739455
03:26:57 I periodic.go:693> T051 ended after 1m40.005720106s : 10000 calls. qps=99.99428022117742
03:26:57 I periodic.go:693> T035 ended after 1m40.005764124s : 10000 calls. qps=99.99423620823211
03:26:57 I periodic.go:693> T080 ended after 1m40.005822678s : 10000 calls. qps=99.99417766101605
03:26:57 I periodic.go:693> T055 ended after 1m40.007113885s : 10000 calls. qps=99.9928866210376
03:26:57 I periodic.go:693> T002 ended after 1m40.007370835s : 10000 calls. qps=99.99262970825204
03:26:57 I periodic.go:693> T005 ended after 1m40.007437675s : 10000 calls. qps=99.99256287814895
03:26:57 I periodic.go:693> T095 ended after 1m40.007390283s : 10000 calls. qps=99.99261026312246
03:26:57 I periodic.go:693> T097 ended after 1m40.00747145s : 10000 calls. qps=99.99252910818394
03:26:57 I periodic.go:693> T046 ended after 1m40.00750564s : 10000 calls. qps=99.99249492330404
03:26:57 I periodic.go:693> T029 ended after 1m40.00752309s : 10000 calls. qps=99.99247747592625
03:26:57 I periodic.go:693> T028 ended after 1m40.007545703s : 10000 calls. qps=99.99245486633338
03:26:57 I periodic.go:693> T037 ended after 1m40.007452918s : 10000 calls. qps=99.99254763741847
03:26:57 I periodic.go:693> T036 ended after 1m40.007571606s : 10000 calls. qps=99.99242896724877
03:26:57 I periodic.go:693> T091 ended after 1m40.008220229s : 10000 calls. qps=99.9917804466661
03:26:57 I periodic.go:693> T007 ended after 1m40.008274034s : 10000 calls. qps=99.99172665053975
03:26:57 I periodic.go:693> T094 ended after 1m40.013309679s : 10000 calls. qps=99.9866920922398
03:26:57 I periodic.go:693> T078 ended after 1m40.013475968s : 10000 calls. qps=99.98652584777244
03:26:57 I periodic.go:693> T099 ended after 1m40.013529732s : 10000 calls. qps=99.98647209828886
03:26:57 I periodic.go:693> T045 ended after 1m40.014402031s : 10000 calls. qps=99.98560004288629
03:26:57 I periodic.go:693> T041 ended after 1m40.014530298s : 10000 calls. qps=99.98547181298888
03:26:57 I periodic.go:693> T059 ended after 1m40.014597721s : 10000 calls. qps=99.98540440962356
03:26:57 I periodic.go:693> T063 ended after 1m40.014617545s : 10000 calls. qps=99.98538459141393
03:26:57 I periodic.go:693> T096 ended after 1m40.014731111s : 10000 calls. qps=99.98527105873669
03:26:57 I periodic.go:693> T003 ended after 1m40.014752142s : 10000 calls. qps=99.98525003393593
03:26:57 I periodic.go:693> T008 ended after 1m40.014766842s : 10000 calls. qps=99.98523533827426
03:26:57 I periodic.go:693> T069 ended after 1m40.014780419s : 10000 calls. qps=99.985221765285
03:26:57 I periodic.go:693> T061 ended after 1m40.014802282s : 10000 calls. qps=99.98519990875124
03:26:57 I periodic.go:693> T077 ended after 1m40.014922887s : 10000 calls. qps=99.9850793395933
03:26:57 I periodic.go:693> T016 ended after 1m40.014943501s : 10000 calls. qps=99.98505873174857
03:26:57 I periodic.go:693> T027 ended after 1m40.014956869s : 10000 calls. qps=99.98504536774476
03:26:57 I periodic.go:693> T044 ended after 1m40.01497057s : 10000 calls. qps=99.9850316708442
03:26:57 I periodic.go:693> T057 ended after 1m40.014984438s : 10000 calls. qps=99.98501780699742
03:26:57 I periodic.go:693> T020 ended after 1m40.015065521s : 10000 calls. qps=99.98493674835734
03:26:57 I periodic.go:693> T021 ended after 1m40.015140399s : 10000 calls. qps=99.9848618929698
03:26:57 I periodic.go:693> T083 ended after 1m40.015182419s : 10000 calls. qps=99.98481988570856
03:26:57 I periodic.go:693> T062 ended after 1m40.016353771s : 10000 calls. qps=99.98364890302096
03:26:57 I periodic.go:693> T070 ended after 1m40.016444058s : 10000 calls. qps=99.98355864562585
03:26:57 I periodic.go:693> T067 ended after 1m40.016487119s : 10000 calls. qps=99.98351559880284
03:26:57 I periodic.go:693> T034 ended after 1m40.016529597s : 10000 calls. qps=99.98347313482421
03:26:57 I periodic.go:693> T015 ended after 1m40.01657828s : 10000 calls. qps=99.98342446793811
03:26:57 I periodic.go:693> T018 ended after 1m40.016619426s : 10000 calls. qps=99.98338333559424
03:26:57 I periodic.go:693> T084 ended after 1m40.016680519s : 10000 calls. qps=99.9833222629331
03:26:57 I periodic.go:693> T025 ended after 1m40.016757896s : 10000 calls. qps=99.98324491180026
03:26:57 I periodic.go:693> T026 ended after 1m40.016846933s : 10000 calls. qps=99.98315590471346
03:26:57 I periodic.go:693> T072 ended after 1m40.016894825s : 10000 calls. qps=99.98310802886897
03:26:57 I periodic.go:693> T087 ended after 1m40.01693697s : 10000 calls. qps=99.98306589812375
03:26:57 I periodic.go:693> T048 ended after 1m40.017045164s : 10000 calls. qps=99.98295774088102
03:26:57 I periodic.go:693> T052 ended after 1m40.017066444s : 10000 calls. qps=99.98293646813812
Ended after 1m40.017312109s : 1000000 calls. qps=9998.3
Sleep times : count 999900 avg 0.0066465619 +/- 0.001464 min -0.02811884 max 0.009837646 sum 6645.89726
Aggregated Function Time : count 1000000 avg 0.0019837534 +/- 0.001101 min 1.0122e-05 max 0.035247159 sum 1983.75342
# range, mid point, percentile, count
>= 1.0122e-05 <= 0.001 , 0.000505061 , 18.09, 180892
> 0.001 <= 0.002 , 0.0015 , 55.60, 375083
> 0.002 <= 0.003 , 0.0025 , 83.70, 281069
> 0.003 <= 0.004 , 0.0035 , 96.04, 123391
> 0.004 <= 0.005 , 0.0045 , 99.03, 29852
> 0.005 <= 0.006 , 0.0055 , 99.71, 6776
> 0.006 <= 0.007 , 0.0065 , 99.87, 1662
> 0.007 <= 0.008 , 0.0075 , 99.91, 413
> 0.008 <= 0.009 , 0.0085 , 99.93, 209
> 0.009 <= 0.01 , 0.0095 , 99.95, 106
> 0.01 <= 0.011 , 0.0105 , 99.95, 42
> 0.011 <= 0.012 , 0.0115 , 99.96, 100
> 0.012 <= 0.014 , 0.013 , 99.98, 226
> 0.014 <= 0.016 , 0.015 , 99.99, 80
> 0.016 <= 0.018 , 0.017 , 99.99, 30
> 0.018 <= 0.02 , 0.019 , 99.99, 9
> 0.02 <= 0.025 , 0.0225 , 99.99, 2
> 0.03 <= 0.035 , 0.0325 , 100.00, 57
> 0.035 <= 0.0352472 , 0.0351236 , 100.00, 1
# target 50% 0.00185077
# target 75% 0.00269031
# target 90% 0.00351022
# target 99% 0.00499039
# target 99.9% 0.00766586
Sockets used: 100 (for perfect keepalive, would be 100)
Uniform: false, Jitter: false
Code 200 : 1000000 (100.0 %)
Response Header Sizes : count 1000000 avg 63 +/- 0 min 63 max 63 sum 63000000
Response Body/Total Sizes : count 1000000 avg 74 +/- 0 min 74 max 74 sum 74000000
All done 1000000 calls (plus 0 warmup) 1.984 ms avg, 9998.3 qps
~~~~

## 10. freebsd13-arm64, ab test nginx

## 11. freebsd13-arm64, ab test http-echo

## 12. freebsd13-arm64, ab test pipy

## 13. freebsd13-arm64, wrk test nginx

## 14. freebsd13-arm64, wrk test http-echo

## 15. freebsd13-arm64, wrk test pipy

## 16. freebsd13-arm64, fortio test nginx

## 17. freebsd13-arm64, fortio test http-echo

## 18. freebsd13-arm64, fortio test pipy
