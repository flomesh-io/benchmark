------
使用Pipy在测试中提供Echo服务
------

# 基准测试 ： Pipy作为Echo服务器

## 背景概述

当我们想要测试一个代理（proxy）的性能时候，通常我们需要一个“后端服务”。有很多软件提供这个功能，比如Nginx提供基本的静态页面，还有hashicorp的http-echo测试程序。同样的功能，通过非常少的PipyJS脚本也能提供同样的功能，并且具有更好的可定制性，甚至更好的性能。


在本文的测试里，我们对几个软件做性能基线测试：nginx、http-echo、pipy。我们测试这三款软件在输出基本的"Hello World"信息时，各种性能相关的指标。

## 测试工具

我们使用三种测试工具：

 * __ab__ (apache bench), ab用来测试HTTP短连接，也就是没有keep-alive的场景。`ab -c100 -n1000000 URL`
 * __wrk__ (https://github.com/wg/wrk), wrk用来测试HTTP长连接，也就是带有keep-alive的情况；同时wrk用来测试“极限状态（CPU100%使用）“下服务端的性能指标。 `wrk -c100 -t1 -n20 --latency URL`
 * __fortio__ (https://github.com/fortio/fortio), fortio用来测试在指定的qps下的延迟。 `fortio load -c 100 -n 1000000 --qps 10000 URL` 

我们把测试工具和服务端运行在同一个虚拟机里，使用127.0.0.1来通讯，主要是为了避免物理网络对结果的影响，因为我们测试的目标是“软件”。

## 硬件环境 

我们使用2个VCPU的虚拟机，一个CPU运行测试程序，另一个CPU运行服务端软件。因为所有的软件都可以几乎线性的通过增加CPU或者实例扩容，我们只测试最小配置情况下的性能基线。

## 操作系统

我们在两个操作系统上做了这个测试，一个是ubuntu21服务器版，另外一个是freebsd13，使用的都是arm版的。每个虚拟机配置都是2C4G。

## 关于Freebsd

我们选择在FreeBSD上做测试，是因为我们发现：当我们想提供一种软负载软件或者服务的时候，使用FreeBSD的整体成本（TCO）更有优势（相比Linux）。在我们的多个测试场景中，FreeBSD比如Linux提供最多高达30%的性能（延迟、吞吐率）。

## 关于ARM64

我们选择ARM64平台做测试主要是因为我们小伙伴的工作机是Macbook M1，非常容易使用UTM软件创建和管理虚拟机。另外一个原因是因为我们设计Pipy希望它可以很好的运行在边缘计算和物联网的环境中。

低端的ARM64服务器同时也有着很强的成本优势。我们的网站，flomesh.io，就是运行在分布在全球的10个2C0.5G的aws ARM64的lightsail云主机上，为北美、欧洲、亚洲提供访问，使用了route53作为智能DNS实现了就近接入。低端、甚至是超低端的ARM64云主机加上FreeBSD，就是像我们这种静态站（静态内容加上一些反向代理）的最低成本方案。吃自己的狗粮～

## 测试范围

我们的测试没有涵盖如下的情况：

 * 只测试了HTTP GET，没有测试HTTP POST
 * 只测试返回内容包含非常少字符(hello world)的情况
 * 没有测试混合负载的情况，所有的请求都是相同的
 * 只测试在100并发情况下的数据，在多数测试软件中，通过'-c'参数指定并发数量
 * 对于极限压力测试，我们只测试20秒；对于固定qps测试，我们只测试了100万个请求在1万qps情况下的数据
 
## 软件版本和配置
 
 * nginx和wrk和ab，我们使用系统包管理器安装，也就是pkg和apt-get
 * http-echo和pipy和fortio是从源码编译的
 * Nginx我们配置了1个worker，并且关闭了访问日志和错误日志（为了避免磁盘操作影响性能）

除了“最大打开文件数”，我们没有修改别的内核参数；最大打开文件数我们设置为1024000。

我们使用pipy的脚本是tutorial/02-echo/hello.js。这个脚本会监听3个端口，8080提供基本的hello world信息；8081提供回显服务；8082提供包含客户端IP地址的动态内容。

## 测试案例清单

如下是测试案例的清单，3个测试软件、3个服务软件、2个操作系统，共 3 x 3 x 2 = 18个测试案例：

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

## 测试报告

我们关注4个主要的指标：吞吐率qps，延迟，CPU占用，内存占用。对于CPU和内存使用，我们简单的使用'top'命令来观察和记录，其中内存记录了RES数据。测试数据汇总在如下表格中：

 * ab 工具不提供延迟数据
 * wrk 工具不提供P99.9数据

 | Test Case #| OS            | Tester | Upstream Server |  qps | Latency P50 | P90/P50  | P99/P50  | P99.9/P50 | Mem(RES) | CPU |
 |------------|---------------|--------|-----------------|------|-------------|----------|----------|-----------|----------|-----|
 | 1          |ubuntu21-arm64 | ab     | nginx           | 60824|             |          |          |           |      6.5M|  91%|
 | 2          |ubuntu21-arm64 | ab     | http-echo       | 44826|             |          |          |           |     11.9M| 106%|
 | 3          |ubuntu21-arm64 | ab     | pipy            | 59698|             |          |          |           |      9.3M|  94%|
 | 4          |ubuntu21-arm64 | wrk    | nginx           | 82759|    1.20ms   |    112.5%|      185%|           |      6.5M| 100%|
 | 5          |ubuntu21-arm64 | wrk    | http-echo       | 94579|    0.94ms   |    396.8%|     1023%|           |     12.7M| 107%|
 | 6          |ubuntu21-arm64 | wrk    | pipy            |218539|    0.45ms   |    111.9%|      137%|           |      9.3M| 100%|
 | 7          |ubuntu21-arm64 | fortio | nginx           |      |   1.449ms   |    238.5%|    334.7%|     535.7%|      6.5M|  29%|
 | 8          |ubuntu21-arm64 | fprtio | http-echo       |      |   0.633ms   |    240.1%|    311.6%|     471.9%|     11.4M|  15%|
 | 9          |ubuntu21-arm64 | fortio | pipy            |      |   1.851ms   |    189.7%|    269.1%|     414.2%|      9.6M|  33%|
 | 10         |freebsd13-arm64| ab     | nginx           | 93680|             |          |          |           |      7.5M|  59%|
 | 11         |freebsd13-arm64| ab     | http-echo       | 61230|             |          |          |           |       13M| 106%|
 | 12         |freebsd13-arm64| ab     | pipy            | 95074|             |          |          |           |      8.1M|  73%|
 | 13         |freebsd13-arm64| wrk    | nginx           |204544|     485us   |      104%|      123%|           |      7.5M|  89%|
 | 14         |freebsd13-arm64| wrk    | http-echo       |134889|     645us   |      142%|      213%|           |       13M| 136%|
 | 15         |freebsd13-arm64| wrk    | pipy            |281176|     350us   |      108%|      122%|           |      9.5M|  85%|
 | 16         |freebsd13-arm64| fortio | nginx           |      |     507us   |      178%|      195%|     356.4%|      6.5M| 5.5%|
 | 17         |freebsd13-arm64| fprtio | http-echo       |      |     527us   |      178%|      336%|     378.7%|       13M|  11%|
 | 18         |freebsd13-arm64| fortio | pipy            |      |     506us   |      178%|    195.8%|     342.9%|      9.5M| 3.7%|
 
# 附录 : 测试结果详情

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
root@ubuntu21-arm64:~# ab -c100 -n1000000 http://127.0.0.1:8081/
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
Server Port:            8081

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
root@ubuntu21-arm64:~# wrk -c100 -t1 -d20 --latency http://127.0.0.1:8081/
Running 20s test @ http://127.0.0.1:8081/
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
root@ubuntu21-arm64:~# fortio load -c 100 -n 1000000 -qps 10000 http://127.0.0.1:80/ 
Fortio 1.22.0 running at 10000 queries per second, 2->2 procs, for 1000000 calls: http://127.0.0.1:80/
02:50:49 I httprunner.go:87> Starting http test for http://127.0.0.1:80/ with 100 threads at 10000.0 qps and parallel warmup
Starting at 10000 qps with 100 thread(s) [gomax 2] : exactly 1000000, 10000 calls each (total 1000000 + 0)
02:50:50 I http_client.go:778> Closing dead socket &{{0x4000fa8081}} (err EOF at first read)
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
root@ubuntu21-arm64:~# fortio load -c 100 -n 1000000 -qps 10000 http://127.0.0.1:8081/
Fortio 1.22.0 running at 10000 queries per second, 2->2 procs, for 1000000 calls: http://127.0.0.1:8081/
03:25:17 I httprunner.go:87> Starting http test for http://127.0.0.1:8081/ with 100 threads at 10000.0 qps and parallel warmup
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
03:26:57 I periodic.go:693> T075 ended after 1m40.003479723s : 10000 calls. qps=99.9965203980815
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

~~~~bash
root@freebsd13-aa64:~ # ab -c100 -n1000000 http://127.0.0.1:80/
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


Server Software:        nginx/1.20.2
Server Hostname:        127.0.0.1
Server Port:            80

Document Path:          /
Document Length:        11 bytes

Concurrency Level:      100
Time taken for tests:   10.675 seconds
Complete requests:      1000000
Failed requests:        0
Total transferred:      241000000 bytes
HTML transferred:       11000000 bytes
Requests per second:    93680.20 [#/sec] (mean)
Time per request:       1.067 [ms] (mean)
Time per request:       0.011 [ms] (mean, across all concurrent requests)
Transfer rate:          22047.78 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.0      0       1
Processing:     0    1   0.2      1      11
Waiting:        0    1   0.2      1      11
Total:          0    1   0.2      1      11

Percentage of the requests served within a certain time (ms)
  50%      1
  66%      1
  75%      1
  80%      1
  90%      1
  95%      1
  98%      1
  99%      2
 100%     11 (longest request)
~~~~

## 11. freebsd13-arm64, ab test http-echo

~~~~bash
root@freebsd13-aa64:~ # ab -c100 -n1000000 http://127.0.0.1:9090/
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
Document Length:        9 bytes

Concurrency Level:      100
Time taken for tests:   16.332 seconds
Complete requests:      1000000
Failed requests:        0
Total transferred:      161000000 bytes
HTML transferred:       9000000 bytes
Requests per second:    61230.92 [#/sec] (mean)
Time per request:       1.633 [ms] (mean)
Time per request:       0.016 [ms] (mean, across all concurrent requests)
Transfer rate:          9627.13 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.3      0      11
Processing:     0    1   0.6      1      19
Waiting:        0    1   0.5      1      18
Total:          0    2   0.7      2      19

Percentage of the requests served within a certain time (ms)
  50%      2
  66%      2
  75%      2
  80%      2
  90%      2
  95%      3
  98%      3
  99%      3
 100%     19 (longest request)
~~~~

## 12. freebsd13-arm64, ab test pipy

~~~~bash
root@freebsd13-aa64:~ # ab -c100 -n1000000 http://127.0.0.1:8081/
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
Server Port:            8081

Document Path:          /
Document Length:        0 bytes

Concurrency Level:      100
Time taken for tests:   10.518 seconds
Complete requests:      1000000
Failed requests:        0
Total transferred:      57000000 bytes
HTML transferred:       0 bytes
Requests per second:    95074.65 [#/sec] (mean)
Time per request:       1.052 [ms] (mean)
Time per request:       0.011 [ms] (mean, across all concurrent requests)
Transfer rate:          5292.24 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.0      0      10
Processing:     0    1   0.3      1      11
Waiting:        0    1   0.3      1      11
Total:          0    1   0.3      1      11

Percentage of the requests served within a certain time (ms)
  50%      1
  66%      1
  75%      1
  80%      1
  90%      1
  95%      1
  98%      1
  99%      2
 100%     11 (longest request)
~~~~

## 13. freebsd13-arm64, wrk test nginx

~~~~bash
root@freebsd13-aa64:~ # wrk -c100 -t1 -d20 --latency http://127.0.0.1:80/
Running 20s test @ http://127.0.0.1:80/
  1 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   487.68us   41.93us   1.92ms   96.12%
    Req/Sec   205.47k     1.65k  210.33k    68.66%
  Latency Distribution
     50%  485.00us
     75%  495.00us
     90%  506.00us
     99%  598.00us
  4111530 requests in 20.10s, 0.94GB read
Requests/sec: 204544.67
Transfer/sec:     47.99MB
~~~~

## 14. freebsd13-arm64, wrk test http-echo

~~~~bash
root@freebsd13-aa64:~ # wrk -c100 -t1 -d20 --latency http://127.0.0.1:9090/
Running 20s test @ http://127.0.0.1:9090/
  1 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   606.09us  303.38us   6.91ms   68.30%
    Req/Sec   135.66k    11.16k  175.08k    84.00%
  Latency Distribution
     50%  645.00us
     75%  778.00us
     90%    0.92ms
     99%    1.38ms
  2698301 requests in 20.00s, 414.30MB read
Requests/sec: 134889.80
Transfer/sec:     20.71MB
~~~~

## 15. freebsd13-arm64, wrk test pipy

~~~~bash
root@freebsd13-aa64:~ # wrk -c100 -t1 -d20 --latency http://127.0.0.1:8081/
Running 20s test @ http://127.0.0.1:8081/
  1 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   352.92us   29.64us   1.98ms   91.79%
    Req/Sec   282.64k     3.14k  289.16k    65.17%
  Latency Distribution
     50%  350.00us
     75%  364.00us
     90%  377.00us
     99%  427.00us
  5652112 requests in 20.10s, 334.20MB read
Requests/sec: 281176.51
Transfer/sec:     16.63MB
~~~~

## 16. freebsd13-arm64, fortio test nginx

~~~~bash
root@freebsd13-aa64:~ # fortio load -c 100 -n 1000000 -qps 10000 http://127.0.0.1:80/ 
Fortio dev running at 10000 queries per second, 2->2 procs, for 1000000 calls: http://127.0.0.1:80/
15:34:31 I httprunner.go:87> Starting http test for http://127.0.0.1:80/ with 100 threads at 10000.0 qps and parallel warmup
Starting at 10000 qps with 100 thread(s) [gomax 2] : exactly 1000000, 10000 calls each (total 1000000 + 0)
15:34:41 I http_client.go:778> Closing dead socket &{{0x40000d6780}} (err read tcp 127.0.0.1:53341->127.0.0.1:80: read: connection reset by peer at first read)
15:34:41 I http_client.go:778> Closing dead socket &{{0x40000d7500}} (err read tcp 127.0.0.1:16010->127.0.0.1:80: read: connection reset by peer at first read)
15:34:41 I http_client.go:778> Closing dead socket &{{0x40000d6500}} (err EOF at first read)
15:34:41 I http_client.go:778> Closing dead socket &{{0x4000201580}} (err read tcp 127.0.0.1:13350->127.0.0.1:80: read: connection reset by peer at first read)
15:34:41 I http_client.go:778> Closing dead socket &{{0x4000258880}} (err EOF at first read)
......
15:36:11 I periodic.go:693> T015 ended after 1m40.0006695s : 10000 calls. qps=99.99933050448227
15:36:11 I periodic.go:693> T012 ended after 1m40.000726s : 10000 calls. qps=99.99927400527072
15:36:11 I periodic.go:693> T074 ended after 1m40.000731875s : 10000 calls. qps=99.99926813035637
15:36:11 I periodic.go:693> T039 ended after 1m40.000737167s : 10000 calls. qps=99.99926283843412
15:36:11 I periodic.go:693> T005 ended after 1m40.00074275s : 10000 calls. qps=99.99925725551674
15:36:11 I periodic.go:693> T041 ended after 1m40.000746792s : 10000 calls. qps=99.99925321357694
15:36:11 I periodic.go:693> T025 ended after 1m40.0007525s : 10000 calls. qps=99.99924750566251
15:36:11 I periodic.go:693> T078 ended after 1m40.000770291s : 10000 calls. qps=99.99922971493343
15:36:11 I periodic.go:693> T069 ended after 1m40.000775708s : 10000 calls. qps=99.99922429801718
15:36:11 I periodic.go:693> T009 ended after 1m40.000781125s : 10000 calls. qps=99.99921888110151
15:36:11 I periodic.go:693> T072 ended after 1m40.000784875s : 10000 calls. qps=99.99921513116024
15:36:11 I periodic.go:693> T014 ended after 1m40.000789583s : 10000 calls. qps=99.99921042323436
15:36:11 I periodic.go:693> T021 ended after 1m40.000795s : 10000 calls. qps=99.99920500632021
15:36:11 I periodic.go:693> T097 ended after 1m40.000974791s : 10000 calls. qps=99.99902521850208
15:36:11 I periodic.go:693> T098 ended after 1m40.000990375s : 10000 calls. qps=99.99900963480833
15:36:11 I periodic.go:693> T055 ended after 1m40.000994625s : 10000 calls. qps=99.99900538489268
15:36:11 I periodic.go:693> T073 ended after 1m40.000998708s : 10000 calls. qps=99.99900130197408
15:36:11 I periodic.go:693> T046 ended after 1m40.001002875s : 10000 calls. qps=99.99899713505748
15:36:11 I periodic.go:693> T054 ended after 1m40.001006708s : 10000 calls. qps=99.99899330213451
15:36:11 I periodic.go:693> T011 ended after 1m40.001010875s : 10000 calls. qps=99.99898913521858
15:36:11 I periodic.go:693> T085 ended after 1m40.001015167s : 10000 calls. qps=99.99898484330554
15:36:11 I periodic.go:693> T077 ended after 1m40.001019166s : 10000 calls. qps=99.99898084438688
15:36:11 I periodic.go:693> T095 ended after 1m40.001022792s : 10000 calls. qps=99.99897721846092
15:36:11 I periodic.go:693> T017 ended after 1m40.001027417s : 10000 calls. qps=99.99897259355575
15:36:11 I periodic.go:693> T058 ended after 1m40.001031958s : 10000 calls. qps=99.99896805264926
15:36:11 I periodic.go:693> T056 ended after 1m40.001035833s : 10000 calls. qps=99.99896417772939
15:36:11 I periodic.go:693> T004 ended after 1m40.001039625s : 10000 calls. qps=99.99896038580809
15:36:11 I periodic.go:693> T007 ended after 1m40.001043416s : 10000 calls. qps=99.99895659488705
15:36:11 I periodic.go:693> T067 ended after 1m40.0010475s : 10000 calls. qps=99.99895251097244
15:36:11 I periodic.go:693> T082 ended after 1m40.00105175s : 10000 calls. qps=99.99894826106166
15:36:11 I periodic.go:693> T070 ended after 1m40.001056292s : 10000 calls. qps=99.99894371915741
15:36:11 I periodic.go:693> T048 ended after 1m40.001060708s : 10000 calls. qps=99.99893930325089
15:36:11 I periodic.go:693> T032 ended after 1m40.001064458s : 10000 calls. qps=99.99893555333058
15:36:11 I periodic.go:693> T061 ended after 1m40.001068708s : 10000 calls. qps=99.99893130342124
15:36:11 I periodic.go:693> T068 ended after 1m40.001446792s : 10000 calls. qps=99.99855322893177
15:36:11 I periodic.go:693> T006 ended after 1m40.001451875s : 10000 calls. qps=99.9985481460791
15:36:11 I periodic.go:693> T049 ended after 1m40.001073s : 10000 calls. qps=99.99892701151316
15:36:11 I periodic.go:693> T018 ended after 1m40.001459708s : 10000 calls. qps=99.99854031330716
15:36:11 I periodic.go:693> T028 ended after 1m40.0010975s : 10000 calls. qps=99.99890251204494
15:36:11 I periodic.go:693> T023 ended after 1m40.001130292s : 10000 calls. qps=99.99886972077546
15:36:11 I periodic.go:693> T047 ended after 1m40.001142042s : 10000 calls. qps=99.99885797104245
15:36:11 I periodic.go:693> T050 ended after 1m40.001154208s : 10000 calls. qps=99.9988458053218
15:36:11 I periodic.go:693> T052 ended after 1m40.001464s : 10000 calls. qps=99.99853602143264
15:36:11 I periodic.go:693> T060 ended after 1m40.001166167s : 10000 calls. qps=99.9988338465993
15:36:11 I periodic.go:693> T022 ended after 1m40.001178041s : 10000 calls. qps=99.99882197287764
15:36:11 I periodic.go:693> T086 ended after 1m40.001189875s : 10000 calls. qps=99.99881013915787
15:36:11 I periodic.go:693> T044 ended after 1m40.001202542s : 10000 calls. qps=99.9987974724609
15:36:11 I periodic.go:693> T042 ended after 1m40.001214208s : 10000 calls. qps=99.99878580674284
15:36:11 I periodic.go:693> T079 ended after 1m40.001225625s : 10000 calls. qps=99.99877439002138
15:36:11 I periodic.go:693> T099 ended after 1m40.0012375s : 10000 calls. qps=99.99876251531387
15:36:11 I periodic.go:693> T001 ended after 1m40.001249458s : 10000 calls. qps=99.99875055761126
15:36:11 I periodic.go:693> T019 ended after 1m40.001261458s : 10000 calls. qps=99.99873855791256
15:36:11 I periodic.go:693> T075 ended after 1m40.0012735s : 10000 calls. qps=99.99872651621781
15:36:11 I periodic.go:693> T031 ended after 1m40.001285708s : 10000 calls. qps=99.99871430853024
15:36:11 I periodic.go:693> T051 ended after 1m40.001297875s : 10000 calls. qps=99.99870214184457
15:36:11 I periodic.go:693> T037 ended after 1m40.001488583s : 10000 calls. qps=99.99851143915846
15:36:11 I periodic.go:693> T026 ended after 1m40.001301542s : 10000 calls. qps=99.9986984749399
15:36:11 I periodic.go:693> T096 ended after 1m40.001318458s : 10000 calls. qps=99.99868155938309
15:36:11 I periodic.go:693> T064 ended after 1m40.001322416s : 10000 calls. qps=99.99867760148761
15:36:11 I periodic.go:693> T003 ended after 1m40.001326125s : 10000 calls. qps=99.99867389258584
15:36:11 I periodic.go:693> T084 ended after 1m40.001352083s : 10000 calls. qps=99.99864793528104
15:36:11 I periodic.go:693> T094 ended after 1m40.001363083s : 10000 calls. qps=99.9986369355797
15:36:11 I periodic.go:693> T062 ended after 1m40.001375708s : 10000 calls. qps=99.99862431092546
15:36:11 I periodic.go:693> T010 ended after 1m40.001386833s : 10000 calls. qps=99.99861318623279
15:36:11 I periodic.go:693> T059 ended after 1m40.001399042s : 10000 calls. qps=99.9986009775729
15:36:11 I periodic.go:693> T053 ended after 1m40.001418417s : 10000 calls. qps=99.99858160311878
15:36:11 I periodic.go:693> T066 ended after 1m40.001429208s : 10000 calls. qps=99.99857081242605
15:36:11 I periodic.go:693> T089 ended after 1m40.001432542s : 10000 calls. qps=99.99856747852147
15:36:11 I periodic.go:693> T080 ended after 1m40.001436083s : 10000 calls. qps=99.99856393762305
15:36:11 I periodic.go:693> T020 ended after 1m40.001439125s : 10000 calls. qps=99.99856089571051
15:36:11 I periodic.go:693> T027 ended after 1m40.001442375s : 10000 calls. qps=99.99855764580415
15:36:11 I periodic.go:693> T040 ended after 1m40.001455833s : 10000 calls. qps=99.99854418819419
15:36:11 I periodic.go:693> T043 ended after 1m40.001110458s : 10000 calls. qps=99.99888955433103
15:36:11 I periodic.go:693> T016 ended after 1m40.001469s : 10000 calls. qps=99.9985310215793
15:36:11 I periodic.go:693> T091 ended after 1m40.001477917s : 10000 calls. qps=99.99852210484207
15:36:11 I periodic.go:693> T034 ended after 1m40.001482375s : 10000 calls. qps=99.99851764697404
15:36:11 I periodic.go:693> T013 ended after 1m40.001588167s : 10000 calls. qps=99.99841185822235
15:36:11 I periodic.go:693> T088 ended after 1m40.00159675s : 10000 calls. qps=99.99840327549569
15:36:11 I periodic.go:693> T081 ended after 1m40.0016015s : 10000 calls. qps=99.9983985256476
15:36:11 I periodic.go:693> T000 ended after 1m40.001606458s : 10000 calls. qps=99.99839356780666
15:36:11 I periodic.go:693> T092 ended after 1m40.001610833s : 10000 calls. qps=99.99838919294741
15:36:11 I periodic.go:693> T038 ended after 1m40.001614833s : 10000 calls. qps=99.99838519307643
15:36:11 I periodic.go:693> T045 ended after 1m40.001619s : 10000 calls. qps=99.99838102621118
15:36:11 I periodic.go:693> T063 ended after 1m40.001623167s : 10000 calls. qps=99.99837685934628
15:36:11 I periodic.go:693> T002 ended after 1m40.001627416s : 10000 calls. qps=99.9983726104844
15:36:11 I periodic.go:693> T087 ended after 1m40.001652375s : 10000 calls. qps=99.99834765230297
15:36:11 I periodic.go:693> T029 ended after 1m40.001657416s : 10000 calls. qps=99.99834261146982
15:36:11 I periodic.go:693> T035 ended after 1m40.001661792s : 10000 calls. qps=99.99833823561508
15:36:11 I periodic.go:693> T057 ended after 1m40.001672167s : 10000 calls. qps=99.99832786096096
15:36:11 I periodic.go:693> T083 ended after 1m40.001676917s : 10000 calls. qps=99.99832311112004
15:36:11 I periodic.go:693> T033 ended after 1m40.001681042s : 10000 calls. qps=99.99831898625854
15:36:11 I periodic.go:693> T036 ended after 1m40.001685083s : 10000 calls. qps=99.99831494539457
15:36:11 I periodic.go:693> T071 ended after 1m40.001689s : 10000 calls. qps=99.99831102852673
15:36:11 I periodic.go:693> T030 ended after 1m40.001693542s : 10000 calls. qps=99.99830648668036
15:36:11 I periodic.go:693> T090 ended after 1m40.0017385s : 10000 calls. qps=99.99826153022329
15:36:11 I periodic.go:693> T065 ended after 1m40.001744416s : 10000 calls. qps=99.99825561442935
15:36:11 I periodic.go:693> T093 ended after 1m40.001748625s : 10000 calls. qps=99.99825140557635
15:36:11 I periodic.go:693> T008 ended after 1m40.001752792s : 10000 calls. qps=99.99824723872226
15:36:11 I periodic.go:693> T024 ended after 1m40.001757041s : 10000 calls. qps=99.99824298987139
15:36:11 I periodic.go:693> T076 ended after 1m40.0014925s : 10000 calls. qps=99.99850752227523
Ended after 1m40.001788208s : 1000000 calls. qps=9999.8
Sleep times : count 999900 avg 0.0091517963 +/- 0.000293 min 0.001929521 max 0.009965707 sum 9150.88108
Aggregated Function Time : count 1000000 avg 0.00036542271 +/- 0.0001783 min 1.1334e-05 max 0.007371417 sum 365.422709
# range, mid point, percentile, count
>= 1.1334e-05 <= 0.001 , 0.000505667 , 99.72, 997223
> 0.001 <= 0.002 , 0.0015 , 99.94, 2201
> 0.002 <= 0.003 , 0.0025 , 99.97, 326
> 0.003 <= 0.004 , 0.0035 , 99.98, 91
> 0.004 <= 0.005 , 0.0045 , 99.99, 25
> 0.005 <= 0.006 , 0.0055 , 99.99, 30
> 0.006 <= 0.007 , 0.0065 , 99.99, 19
> 0.007 <= 0.00737142 , 0.00718571 , 100.00, 85
# target 50% 0.000507043
# target 75% 0.000754898
# target 90% 0.000903611
# target 99% 0.000992839
# target 99.9% 0.00180736
Sockets used: 1000 (for perfect keepalive, would be 100)
Jitter: false
Uniform: false
Code 200 : 1000000 (100.0 %)
Response Header Sizes : count 1000000 avg 234.995 +/- 0.158 min 230 max 235 sum 234995000
Response Body/Total Sizes : count 1000000 avg 245.995 +/- 0.158 min 241 max 246 sum 245995000
All done 1000000 calls (plus 0 warmup) 0.365 ms avg, 9999.8 qps
~~~~

## 17. freebsd13-arm64, fortio test http-echo

~~~~bash
root@freebsd13-aa64:~ # fortio load -c 100 -n 1000000 -qps 10000 http://127.0.0.1:9090/
Fortio dev running at 10000 queries per second, 2->2 procs, for 1000000 calls: http://127.0.0.1:9090/
15:43:55 I httprunner.go:87> Starting http test for http://127.0.0.1:9090/ with 100 threads at 10000.0 qps and parallel warmup
Starting at 10000 qps with 100 thread(s) [gomax 2] : exactly 1000000, 10000 calls each (total 1000000 + 0)
15:45:35 I periodic.go:693> T070 ended after 1m40.001176708s : 10000 calls. qps=99.99882330584626
15:45:35 I periodic.go:693> T091 ended after 1m40.00114675s : 10000 calls. qps=99.9988532631502
15:45:35 I periodic.go:693> T095 ended after 1m40.001153542s : 10000 calls. qps=99.99884647130644
15:45:35 I periodic.go:693> T079 ended after 1m40.001200542s : 10000 calls. qps=99.99879947241283
15:45:35 I periodic.go:693> T039 ended after 1m40.001207042s : 10000 calls. qps=99.99879297256932
15:45:35 I periodic.go:693> T080 ended after 1m40.00121175s : 10000 calls. qps=99.99878826468321
15:45:35 I periodic.go:693> T058 ended after 1m40.001212333s : 10000 calls. qps=99.99878768169734
15:45:35 I periodic.go:693> T006 ended after 1m40.001217167s : 10000 calls. qps=99.99878284781478
15:45:35 I periodic.go:693> T021 ended after 1m40.001217834s : 10000 calls. qps=99.99878218083101
15:45:35 I periodic.go:693> T013 ended after 1m40.001221625s : 10000 calls. qps=99.9987783899235
15:45:35 I periodic.go:693> T082 ended after 1m40.001226417s : 10000 calls. qps=99.9987735980408
15:45:35 I periodic.go:693> T002 ended after 1m40.001226958s : 10000 calls. qps=99.99877305705407
15:45:35 I periodic.go:693> T063 ended after 1m40.001231625s : 10000 calls. qps=99.9987683901688
15:45:35 I periodic.go:693> T042 ended after 1m40.001231958s : 10000 calls. qps=99.99876805717702
15:45:35 I periodic.go:693> T083 ended after 1m40.00123575s : 10000 calls. qps=99.99876426527058
15:45:35 I periodic.go:693> T000 ended after 1m40.001237833s : 10000 calls. qps=99.99876218232211
15:45:35 I periodic.go:693> T098 ended after 1m40.00124275s : 10000 calls. qps=99.99875726544408
15:45:35 I periodic.go:693> T036 ended after 1m40.001242708s : 10000 calls. qps=99.99875730744303
15:45:35 I periodic.go:693> T037 ended after 1m40.0012465s : 10000 calls. qps=99.99875351553743
15:45:35 I periodic.go:693> T031 ended after 1m40.001248875s : 10000 calls. qps=99.9987511405967
15:45:35 I periodic.go:693> T090 ended after 1m40.001250917s : 10000 calls. qps=99.99874909864775
15:45:35 I periodic.go:693> T069 ended after 1m40.001253584s : 10000 calls. qps=99.99874643171454
15:45:35 I periodic.go:693> T056 ended after 1m40.001257375s : 10000 calls. qps=99.99874264080972
15:45:35 I periodic.go:693> T046 ended after 1m40.0012615s : 10000 calls. qps=99.99873851591363
15:45:35 I periodic.go:693> T093 ended after 1m40.001265542s : 10000 calls. qps=99.99873447401576
15:45:35 I periodic.go:693> T092 ended after 1m40.001385833s : 10000 calls. qps=99.99861418620506
15:45:35 I periodic.go:693> T001 ended after 1m40.001269s : 10000 calls. qps=99.9987310161034
15:45:35 I periodic.go:693> T032 ended after 1m40.001272917s : 10000 calls. qps=99.99872709920298
15:45:35 I periodic.go:693> T061 ended after 1m40.001276667s : 10000 calls. qps=99.99872334929857
15:45:35 I periodic.go:693> T086 ended after 1m40.00128025s : 10000 calls. qps=99.9987197663902
15:45:35 I periodic.go:693> T065 ended after 1m40.001283917s : 10000 calls. qps=99.99871609948423
15:45:35 I periodic.go:693> T005 ended after 1m40.001287667s : 10000 calls. qps=99.99871234958064
15:45:35 I periodic.go:693> T014 ended after 1m40.00139025s : 10000 calls. qps=99.99860976932769
15:45:35 I periodic.go:693> T007 ended after 1m40.001291292s : 10000 calls. qps=99.99870872467413
15:45:35 I periodic.go:693> T097 ended after 1m40.001295292s : 10000 calls. qps=99.9987047247776
15:45:35 I periodic.go:693> T068 ended after 1m40.001304583s : 10000 calls. qps=99.99869543401914
15:45:35 I periodic.go:693> T028 ended after 1m40.001309s : 10000 calls. qps=99.99869101713458
15:45:35 I periodic.go:693> T074 ended after 1m40.001396292s : 10000 calls. qps=99.99860372749605
15:45:35 I periodic.go:693> T059 ended after 1m40.001314042s : 10000 calls. qps=99.99868597526684
15:45:35 I periodic.go:693> T089 ended after 1m40.001317709s : 10000 calls. qps=99.99868230836334
15:45:35 I periodic.go:693> T010 ended after 1m40.001322208s : 10000 calls. qps=99.9986778094821
15:45:35 I periodic.go:693> T029 ended after 1m40.001325917s : 10000 calls. qps=99.99867410058032
15:45:35 I periodic.go:693> T043 ended after 1m40.001330125s : 10000 calls. qps=99.99866989269209
15:45:35 I periodic.go:693> T034 ended after 1m40.001468s : 10000 calls. qps=99.99853202154992
15:45:35 I periodic.go:693> T062 ended after 1m40.001333792s : 10000 calls. qps=99.99866622578978
15:45:35 I periodic.go:693> T073 ended after 1m40.001337959s : 10000 calls. qps=99.9986620589011
15:45:35 I periodic.go:693> T025 ended after 1m40.001342s : 10000 calls. qps=99.99865801800941
15:45:35 I periodic.go:693> T030 ended after 1m40.001350584s : 10000 calls. qps=99.99864943424053
15:45:35 I periodic.go:693> T076 ended after 1m40.00135525s : 10000 calls. qps=99.99864476836677
15:45:35 I periodic.go:693> T019 ended after 1m40.00136025s : 10000 calls. qps=99.99863976850254
15:45:35 I periodic.go:693> T054 ended after 1m40.001371s : 10000 calls. qps=99.99862901879615
15:45:35 I periodic.go:693> T045 ended after 1m40.001374875s : 10000 calls. qps=99.99862514390256
15:45:35 I periodic.go:693> T016 ended after 1m40.001378625s : 10000 calls. qps=99.99862139400581
15:45:35 I periodic.go:693> T087 ended after 1m40.001382292s : 10000 calls. qps=99.99861772710705
15:45:35 I periodic.go:693> T088 ended after 1m40.001400375s : 10000 calls. qps=99.99859964461022
15:45:35 I periodic.go:693> T011 ended after 1m40.001478667s : 10000 calls. qps=99.99852135486424
15:45:35 I periodic.go:693> T085 ended after 1m40.001404625s : 10000 calls. qps=99.99859539472943
15:45:35 I periodic.go:693> T009 ended after 1m40.001408667s : 10000 calls. qps=99.99859135284314
15:45:35 I periodic.go:693> T053 ended after 1m40.00141275s : 10000 calls. qps=99.99858726995835
15:45:35 I periodic.go:693> T060 ended after 1m40.001482917s : 10000 calls. qps=99.9985171049901
15:45:35 I periodic.go:693> T018 ended after 1m40.001416917s : 10000 calls. qps=99.99858310307626
15:45:35 I periodic.go:693> T022 ended after 1m40.001422042s : 10000 calls. qps=99.99857797822175
15:45:35 I periodic.go:693> T078 ended after 1m40.001425625s : 10000 calls. qps=99.99857439532379
15:45:35 I periodic.go:693> T015 ended after 1m40.001429292s : 10000 calls. qps=99.99857072842846
15:45:35 I periodic.go:693> T051 ended after 1m40.001433042s : 10000 calls. qps=99.99856697853579
15:45:35 I periodic.go:693> T081 ended after 1m40.001436667s : 10000 calls. qps=99.99856335363984
15:45:35 I periodic.go:693> T055 ended after 1m40.001440333s : 10000 calls. qps=99.99855968774528
15:45:35 I periodic.go:693> T094 ended after 1m40.001444334s : 10000 calls. qps=99.99855568686071
15:45:35 I periodic.go:693> T020 ended after 1m40.001447792s : 10000 calls. qps=99.99855222896072
15:45:35 I periodic.go:693> T040 ended after 1m40.001451667s : 10000 calls. qps=99.99854835407307
15:45:35 I periodic.go:693> T077 ended after 1m40.00145525s : 10000 calls. qps=99.99854477117721
15:45:35 I periodic.go:693> T071 ended after 1m40.001459042s : 10000 calls. qps=99.99854097928772
15:45:35 I periodic.go:693> T024 ended after 1m40.001463125s : 10000 calls. qps=99.99853689640703
15:45:35 I periodic.go:693> T072 ended after 1m40.001547917s : 10000 calls. qps=99.9984521069601
15:45:35 I periodic.go:693> T035 ended after 1m40.001487125s : 10000 calls. qps=99.99851289711508
15:45:35 I periodic.go:693> T026 ended after 1m40.001490959s : 10000 calls. qps=99.99850906322926
15:45:35 I periodic.go:693> T023 ended after 1m40.001494917s : 10000 calls. qps=99.99850510534743
15:45:35 I periodic.go:693> T041 ended after 1m40.0014985s : 10000 calls. qps=99.99850152245469
15:45:35 I periodic.go:693> T008 ended after 1m40.001510292s : 10000 calls. qps=99.99848973080947
15:45:35 I periodic.go:693> T004 ended after 1m40.001514458s : 10000 calls. qps=99.99848556493548
15:45:35 I periodic.go:693> T017 ended after 1m40.001518042s : 10000 calls. qps=99.99848198104416
15:45:35 I periodic.go:693> T066 ended after 1m40.0015215s : 10000 calls. qps=99.99847852314927
15:45:35 I periodic.go:693> T012 ended after 1m40.001525083s : 10000 calls. qps=99.99847494025842
15:45:35 I periodic.go:693> T084 ended after 1m40.001528958s : 10000 calls. qps=99.99847106537678
15:45:35 I periodic.go:693> T027 ended after 1m40.001533667s : 10000 calls. qps=99.99846635652098
15:45:35 I periodic.go:693> T057 ended after 1m40.00160025s : 10000 calls. qps=99.9983997756076
15:45:35 I periodic.go:693> T075 ended after 1m40.001537208s : 10000 calls. qps=99.99846281562972
15:45:35 I periodic.go:693> T044 ended after 1m40.00154075s : 10000 calls. qps=99.99845927373873
15:45:35 I periodic.go:693> T067 ended after 1m40.001544417s : 10000 calls. qps=99.99845560685186
15:45:35 I periodic.go:693> T064 ended after 1m40.001473s : 10000 calls. qps=99.99852702169697
15:45:35 I periodic.go:693> T033 ended after 1m40.001554292s : 10000 calls. qps=99.99844573215786
15:45:35 I periodic.go:693> T052 ended after 1m40.001559709s : 10000 calls. qps=99.99844031532653
15:45:35 I periodic.go:693> T047 ended after 1m40.001564208s : 10000 calls. qps=99.99843581646708
15:45:35 I periodic.go:693> T050 ended after 1m40.001568042s : 10000 calls. qps=99.99843198258716
15:45:35 I periodic.go:693> T049 ended after 1m40.001571917s : 10000 calls. qps=99.99842810770883
15:45:35 I periodic.go:693> T099 ended after 1m40.001575792s : 10000 calls. qps=99.99842423283081
15:45:35 I periodic.go:693> T038 ended after 1m40.0015835s : 10000 calls. qps=99.99841652507433
15:45:35 I periodic.go:693> T003 ended after 1m40.001587834s : 10000 calls. qps=99.99841219121176
15:45:35 I periodic.go:693> T096 ended after 1m40.001591417s : 10000 calls. qps=99.99840860832568
15:45:35 I periodic.go:693> T048 ended after 1m40.001596292s : 10000 calls. qps=99.99840373348107
Ended after 1m40.001635209s : 1000000 calls. qps=9999.8
Sleep times : count 999900 avg 0.0088994515 +/- 0.000329 min -0.00543475 max 0.009866375 sum 8898.56159
Aggregated Function Time : count 1000000 avg 0.00064461236 +/- 0.0002207 min 1.2542e-05 max 0.012724125 sum 644.612364
# range, mid point, percentile, count
>= 1.2542e-05 <= 0.001 , 0.000506271 , 95.87, 958723
> 0.001 <= 0.002 , 0.0015 , 99.91, 40413
> 0.002 <= 0.003 , 0.0025 , 99.97, 576
> 0.003 <= 0.004 , 0.0035 , 99.99, 193
> 0.004 <= 0.005 , 0.0045 , 99.99, 31
> 0.005 <= 0.006 , 0.0055 , 99.99, 5
> 0.006 <= 0.007 , 0.0065 , 99.99, 5
> 0.007 <= 0.008 , 0.0075 , 99.99, 1
> 0.008 <= 0.009 , 0.0085 , 100.00, 4
> 0.009 <= 0.01 , 0.0095 , 100.00, 7
> 0.01 <= 0.011 , 0.0105 , 100.00, 39
> 0.012 <= 0.0127241 , 0.0123621 , 100.00, 3
# target 50% 0.000527528
# target 75% 0.000785021
# target 90% 0.000939517
# target 99% 0.00177393
# target 99.9% 0.00199663
Sockets used: 100 (for perfect keepalive, would be 100)
Jitter: false
Uniform: false
Code 200 : 1000000 (100.0 %)
Response Header Sizes : count 1000000 avg 152 +/- 0 min 152 max 152 sum 152000000
Response Body/Total Sizes : count 1000000 avg 161 +/- 0 min 161 max 161 sum 161000000
All done 1000000 calls (plus 0 warmup) 0.645 ms avg, 9999.8 qps
~~~~

## 18. freebsd13-arm64, fortio test pipy

~~~~bash
root@freebsd13-aa64:~ # fortio load -c 100 -n 1000000 -qps 10000 http://127.0.0.1:8081/
Fortio dev running at 10000 queries per second, 2->2 procs, for 1000000 calls: http://127.0.0.1:8081/
15:49:38 I httprunner.go:87> Starting http test for http://127.0.0.1:8081/ with 100 threads at 10000.0 qps and parallel warmup
Starting at 10000 qps with 100 thread(s) [gomax 2] : exactly 1000000, 10000 calls each (total 1000000 + 0)
15:51:18 I periodic.go:693> T032 ended after 1m40.000338417s : 10000 calls. qps=99.99966158414526
15:51:18 I periodic.go:693> T049 ended after 1m40.00055425s : 10000 calls. qps=99.99944575307192
15:51:18 I periodic.go:693> T026 ended after 1m40.000604959s : 10000 calls. qps=99.99939504465974
15:51:18 I periodic.go:693> T045 ended after 1m40.000610625s : 10000 calls. qps=99.99938937872861
15:51:18 I periodic.go:693> T008 ended after 1m40.00061525s : 10000 calls. qps=99.99938475378531
15:51:18 I periodic.go:693> T061 ended after 1m40.000620584s : 10000 calls. qps=99.99937941985122
15:51:18 I periodic.go:693> T046 ended after 1m40.000624625s : 10000 calls. qps=99.99937537890153
15:51:18 I periodic.go:693> T054 ended after 1m40.00062875s : 10000 calls. qps=99.99937125395324
15:51:18 I periodic.go:693> T087 ended after 1m40.000632875s : 10000 calls. qps=99.9993671290053
15:51:18 I periodic.go:693> T013 ended after 1m40.000637208s : 10000 calls. qps=99.99936279606031
15:51:18 I periodic.go:693> T073 ended after 1m40.000642167s : 10000 calls. qps=99.99935783712377
15:51:18 I periodic.go:693> T047 ended after 1m40.000646292s : 10000 calls. qps=99.99935371217691
15:51:18 I periodic.go:693> T081 ended after 1m40.000654s : 10000 calls. qps=99.99934600427713
15:51:18 I periodic.go:693> T027 ended after 1m40.000662625s : 10000 calls. qps=99.99933737939068
15:51:18 I periodic.go:693> T034 ended after 1m40.000670625s : 10000 calls. qps=99.99932937949735
15:51:18 I periodic.go:693> T019 ended after 1m40.000675042s : 10000 calls. qps=99.99932496255678
15:51:18 I periodic.go:693> T057 ended after 1m40.00067925s : 10000 calls. qps=99.99932075461378
15:51:18 I periodic.go:693> T053 ended after 1m40.000687125s : 10000 calls. qps=99.99931287972137
15:51:18 I periodic.go:693> T076 ended after 1m40.000695167s : 10000 calls. qps=99.99930483783254
15:51:18 I periodic.go:693> T058 ended after 1m40.000703542s : 10000 calls. qps=99.99929646294969
15:51:18 I periodic.go:693> T039 ended after 1m40.000712917s : 10000 calls. qps=99.99928708808247
15:51:18 I periodic.go:693> T055 ended after 1m40.000927542s : 10000 calls. qps=99.99907246660327
15:51:18 I periodic.go:693> T024 ended after 1m40.000727709s : 10000 calls. qps=99.99927229629556
15:51:18 I periodic.go:693> T097 ended after 1m40.001136833s : 10000 calls. qps=99.99886317992375
15:51:18 I periodic.go:693> T014 ended after 1m40.001175292s : 10000 calls. qps=99.99882472181295
15:51:18 I periodic.go:693> T012 ended after 1m40.001153375s : 10000 calls. qps=99.99884663830258
15:51:18 I periodic.go:693> T072 ended after 1m40.001218042s : 10000 calls. qps=99.99878197283607
15:51:18 I periodic.go:693> T065 ended after 1m40.002230417s : 10000 calls. qps=99.99776963274648
15:51:18 I periodic.go:693> T059 ended after 1m40.00223225s : 10000 calls. qps=99.99776779982828
15:51:18 I periodic.go:693> T078 ended after 1m40.002240417s : 10000 calls. qps=99.99775963319357
15:51:18 I periodic.go:693> T085 ended after 1m40.002239875s : 10000 calls. qps=99.99776017516928
15:51:18 I periodic.go:693> T028 ended after 1m40.002243792s : 10000 calls. qps=99.9977562583449
15:51:18 I periodic.go:693> T084 ended after 1m40.002243875s : 10000 calls. qps=99.99775617534861
15:51:18 I periodic.go:693> T036 ended after 1m40.002247167s : 10000 calls. qps=99.99775288349647
15:51:18 I periodic.go:693> T071 ended after 1m40.002247375s : 10000 calls. qps=99.99775267550581
15:51:18 I periodic.go:693> T016 ended after 1m40.002250583s : 10000 calls. qps=99.9977494676501
15:51:18 I periodic.go:693> T002 ended after 1m40.002251042s : 10000 calls. qps=99.99774900867077
15:51:18 I periodic.go:693> T015 ended after 1m40.002253917s : 10000 calls. qps=99.99774613380026
15:51:18 I periodic.go:693> T005 ended after 1m40.002254458s : 10000 calls. qps=99.99774559282467
15:51:18 I periodic.go:693> T092 ended after 1m40.0022575s : 10000 calls. qps=99.99774255096192
15:51:18 I periodic.go:693> T010 ended after 1m40.002257875s : 10000 calls. qps=99.99774217597884
15:51:18 I periodic.go:693> T035 ended after 1m40.002261333s : 10000 calls. qps=99.99773871813511
15:51:18 I periodic.go:693> T098 ended after 1m40.0022615s : 10000 calls. qps=99.99773855114266
15:51:18 I periodic.go:693> T082 ended after 1m40.0022645s : 10000 calls. qps=99.99773555127845
15:51:18 I periodic.go:693> T025 ended after 1m40.002265042s : 10000 calls. qps=99.99773500930299
15:51:18 I periodic.go:693> T048 ended after 1m40.002268042s : 10000 calls. qps=99.99773200943898
15:51:18 I periodic.go:693> T011 ended after 1m40.002268625s : 10000 calls. qps=99.99773142646542
15:51:18 I periodic.go:693> T043 ended after 1m40.002271459s : 10000 calls. qps=99.99772859259409
15:51:18 I periodic.go:693> T022 ended after 1m40.002272084s : 10000 calls. qps=99.99772796762248
15:51:18 I periodic.go:693> T080 ended after 1m40.001214834s : 10000 calls. qps=99.99878518075805
15:51:18 I periodic.go:693> T056 ended after 1m40.0022755s : 10000 calls. qps=99.99772455177782
15:51:18 I periodic.go:693> T030 ended after 1m40.00227925s : 10000 calls. qps=99.99772080194862
15:51:18 I periodic.go:693> T089 ended after 1m40.002282625s : 10000 calls. qps=99.99771742710257
15:51:18 I periodic.go:693> T050 ended after 1m40.002286042s : 10000 calls. qps=99.99771401025869
15:51:18 I periodic.go:693> T038 ended after 1m40.002126125s : 10000 calls. qps=99.9978739202031
15:51:18 I periodic.go:693> T006 ended after 1m40.002338667s : 10000 calls. qps=99.99766138769235
15:51:18 I periodic.go:693> T041 ended after 1m40.002344042s : 10000 calls. qps=99.99765601294403
15:51:18 I periodic.go:693> T079 ended after 1m40.002348s : 10000 calls. qps=99.99765205512975
15:51:18 I periodic.go:693> T086 ended after 1m40.002352167s : 10000 calls. qps=99.9976478883256
15:51:18 I periodic.go:693> T062 ended after 1m40.002356042s : 10000 calls. qps=99.99764401350802
15:51:18 I periodic.go:693> T001 ended after 1m40.002359958s : 10000 calls. qps=99.99764009769271
15:51:18 I periodic.go:693> T033 ended after 1m40.002363708s : 10000 calls. qps=99.99763634786983
15:51:18 I periodic.go:693> T095 ended after 1m40.002367667s : 10000 calls. qps=99.99763238905715
15:51:18 I periodic.go:693> T037 ended after 1m40.0023715s : 10000 calls. qps=99.9976285562388
15:51:18 I periodic.go:693> T093 ended after 1m40.002375375s : 10000 calls. qps=99.99762468142272
15:51:18 I periodic.go:693> T064 ended after 1m40.00237925s : 10000 calls. qps=99.99762080660696
15:51:18 I periodic.go:693> T029 ended after 1m40.002383125s : 10000 calls. qps=99.9976169317915
15:51:18 I periodic.go:693> T088 ended after 1m40.002420042s : 10000 calls. qps=99.99758001656461
15:51:18 I periodic.go:693> T096 ended after 1m40.002425625s : 10000 calls. qps=99.99757443383514
15:51:18 I periodic.go:693> T007 ended after 1m40.002429292s : 10000 calls. qps=99.99757076701316
15:51:18 I periodic.go:693> T018 ended after 1m40.0024335s : 10000 calls. qps=99.99756655921779
15:51:18 I periodic.go:693> T074 ended after 1m40.002437583s : 10000 calls. qps=99.99756247641666
15:51:18 I periodic.go:693> T090 ended after 1m40.002456542s : 10000 calls. qps=99.9975435183445
15:51:18 I periodic.go:693> T068 ended after 1m40.002531875s : 10000 calls. qps=99.99746818910228
15:51:18 I periodic.go:693> T067 ended after 1m40.002560167s : 10000 calls. qps=99.99743989854288
15:51:18 I periodic.go:693> T060 ended after 1m40.002565084s : 10000 calls. qps=99.99743498179487
15:51:18 I periodic.go:693> T017 ended after 1m40.002570292s : 10000 calls. qps=99.99742977406231
15:51:18 I periodic.go:693> T040 ended after 1m40.00257425s : 10000 calls. qps=99.99742581626593
15:51:18 I periodic.go:693> T070 ended after 1m40.002578167s : 10000 calls. qps=99.99742189946774
15:51:18 I periodic.go:693> T069 ended after 1m40.002581708s : 10000 calls. qps=99.99741835865045
15:51:18 I periodic.go:693> T020 ended after 1m40.002585834s : 10000 calls. qps=99.99741423286365
15:51:18 I periodic.go:693> T063 ended after 1m40.00258975s : 10000 calls. qps=99.99741031706631
15:51:18 I periodic.go:693> T044 ended after 1m40.002594s : 10000 calls. qps=99.99740606728662
15:51:18 I periodic.go:693> T021 ended after 1m40.002597667s : 10000 calls. qps=99.99740240047699
15:51:18 I periodic.go:693> T004 ended after 1m40.002696792s : 10000 calls. qps=99.99730328072492
15:51:18 I periodic.go:693> T091 ended after 1m40.002701209s : 10000 calls. qps=99.99729886396334
15:51:18 I periodic.go:693> T003 ended after 1m40.002715417s : 10000 calls. qps=99.99728465673289
15:51:18 I periodic.go:693> T042 ended after 1m40.002719792s : 10000 calls. qps=99.99728028197067
15:51:18 I periodic.go:693> T077 ended after 1m40.002723542s : 10000 calls. qps=99.9972765321748
15:51:18 I periodic.go:693> T052 ended after 1m40.002727459s : 10000 calls. qps=99.9972726153883
15:51:18 I periodic.go:693> T066 ended after 1m40.002731459s : 10000 calls. qps=99.99726861560664
15:51:18 I periodic.go:693> T031 ended after 1m40.0027355s : 10000 calls. qps=99.99726457482755
15:51:18 I periodic.go:693> T023 ended after 1m40.002739792s : 10000 calls. qps=99.99726028306254
15:51:18 I periodic.go:693> T099 ended after 1m40.00276675s : 10000 calls. qps=99.99723332654693
15:51:18 I periodic.go:693> T009 ended after 1m40.002773125s : 10000 calls. qps=99.99722695190009
15:51:18 I periodic.go:693> T083 ended after 1m40.002777084s : 10000 calls. qps=99.9972229931198
15:51:18 I periodic.go:693> T051 ended after 1m40.002781375s : 10000 calls. qps=99.99721870235832
15:51:18 I periodic.go:693> T000 ended after 1m40.002781875s : 10000 calls. qps=99.99721820238614
15:51:18 I periodic.go:693> T075 ended after 1m40.002785375s : 10000 calls. qps=99.99721470258098
15:51:18 I periodic.go:693> T094 ended after 1m40.002789958s : 10000 calls. qps=99.9972101198365
Ended after 1m40.002811459s : 1000000 calls. qps=9999.7
Sleep times : count 999900 avg 0.0091806549 +/- 0.0004065 min -0.011972253 max 0.009958824 sum 9179.73683
Aggregated Function Time : count 1000000 avg 0.00032903507 +/- 0.0001963 min 1.0666e-05 max 0.01108425 sum 329.035073
# range, mid point, percentile, count
>= 1.0666e-05 <= 0.001 , 0.000505333 , 99.81, 998150
> 0.001 <= 0.002 , 0.0015 , 99.93, 1156
> 0.002 <= 0.003 , 0.0025 , 99.96, 259
> 0.003 <= 0.004 , 0.0035 , 99.96, 74
> 0.004 <= 0.005 , 0.0045 , 99.97, 73
> 0.005 <= 0.006 , 0.0055 , 99.97, 5
> 0.006 <= 0.007 , 0.0065 , 99.98, 99
> 0.007 <= 0.008 , 0.0075 , 99.98, 18
> 0.008 <= 0.009 , 0.0085 , 99.98, 1
> 0.009 <= 0.01 , 0.0095 , 99.98, 6
> 0.01 <= 0.011 , 0.0105 , 100.00, 147
> 0.011 <= 0.0110843 , 0.0110421 , 100.00, 12
# target 50% 0.000506249
# target 75% 0.000754041
# target 90% 0.000902717
# target 99% 0.000991922
# target 99.9% 0.00173529
Sockets used: 100 (for perfect keepalive, would be 100)
Jitter: false
Uniform: false
Code 200 : 1000000 (100.0 %)
Response Header Sizes : count 1000000 avg 62 +/- 0 min 62 max 62 sum 62000000
Response Body/Total Sizes : count 1000000 avg 62 +/- 0 min 62 max 62 sum 62000000
All done 1000000 calls (plus 0 warmup) 0.329 ms avg, 9999.7 qps
~~~~
