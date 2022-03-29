---
BENCHMARK : Pipy代理SpringBoot
---

# 基线测试：Pipy代理SpringBoot REST服务

在这个测试里，我们使用Pipy作为SpringBoot REST服务的代理。我们采用最简单的sidecar proxy模式，也就是proxy(pipy)和upstream(SpringBoot)采用1:1部署，之间通过localhost通信。

我们选择SpringBoot REST作为测试目标，主要原因是SpringBoot是我们实际工作中遇到最多的REST开发堆栈。当SpringBoot提供REST服务时候，HTTP服务器有多个选项，如Tomcat、undertow等。在这个测试里，我们采用默认的配置，也就是Tomcat作为web容器。

测试工具我们依旧采用ab、wrk和fortio；运行平台我们采用ubuntu21-server arm64版，配置为4C4G虚拟机，操作系统没有做任何优化。测试所使用的SpringBoot REST是最简单的Hello World输出，Java工程在这里：https://github.com/flomesh-io/spring-helloworld 。JDK采用的是操作系统软件仓库默认的openjdk11。


ab的测试命令是：
~~~~bash
ab -c100 -n300000 -l URL
~~~~

wrk的测试命令是：
~~~~bash
wrk -c100 -t1 -d20 --latency URL
~~~~

fortio的测试命令是：
~~~~bash
fortio load -c 100 -n 300000 -qps 0 URL
~~~~

测试用的这个Java工程的编译和运行大概如下：
~~~~bash
root@ubuntu21-arm64:~/spring-helloworld# git clone https://github.com/flomesh-io/spring-helloworld.git
root@ubuntu21-arm64:~/spring-helloworld# cd spring-helloworld
root@ubuntu21-arm64:~/spring-helloworld# mvn -DSkipTest clean package install
root@ubuntu21-arm64:~/spring-helloworld# java -jar target/spring-helloworld-0.0.1.jar

  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::               (v2.5.11)

2022-03-29 13:06:56.095  INFO 3544 --- [           main] c.e.spring.SpringHelloworldApplication   : Starting SpringHelloworldApplication v0.0.1 using Java 11.0.14 on ubuntu21-arm64 with PID 3544 (/root/spring-helloworld/target/spring-helloworld-0.0.1.jar started by root in /root/spring-helloworld)
2022-03-29 13:06:56.097  INFO 3544 --- [           main] c.e.spring.SpringHelloworldApplication   : No active profile set, falling back to 1 default profile: "default"
2022-03-29 13:06:56.546  INFO 3544 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8080 (http)
2022-03-29 13:06:56.554  INFO 3544 --- [           main] o.apache.catalina.core.StandardService   : Starting service [Tomcat]
2022-03-29 13:06:56.555  INFO 3544 --- [           main] org.apache.catalina.core.StandardEngine  : Starting Servlet engine: [Apache Tomcat/9.0.60]
2022-03-29 13:06:56.588  INFO 3544 --- [           main] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring embedded WebApplicationContext
2022-03-29 13:06:56.588  INFO 3544 --- [           main] w.s.c.ServletWebServerApplicationContext : Root WebApplicationContext: initialization completed in 466 ms
2022-03-29 13:06:56.783  INFO 3544 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8080 (http) with context path ''
2022-03-29 13:06:56.790  INFO 3544 --- [           main] c.e.spring.SpringHelloworldApplication   : Started SpringHelloworldApplication in 0.92 seconds (JVM running for 1.124)
2022-03-29 13:07:16.760  INFO 3544 --- [nio-8080-exec-1] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring DispatcherServlet 'dispatcherServlet'
2022-03-29 13:07:16.761  INFO 3544 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2022-03-29 13:07:16.761  INFO 3544 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Completed initialization in 0 ms
~~~~

测试中，我们对比测试工具直接访问SpringBoot和经过pipy代理的差异，观测了qps和letency指标。pipy采用的脚本我们采用了pipy自带的tutorial/03-proxy/proxy.js。SpringBoot监听在8080端口；pipy监听在8000端口，经过demux/mux以后，代理到8080端口。PipyJS代码如下：

~~~~javascript
pipy()

.listen(8000)
  .demuxHTTP('forward')

.pipeline('forward')
  .muxHTTP('connection', '')

.pipeline('connection')
  .connect('localhost:8080')
~~~~

测试结果数据如下表：

| # | OS    | Client | Mode              | QPS   | Latency P50 | P90      | P99      | P99.9    |
|---|-------|--------|-------------------|-------|-------------|----------|----------|----------|
| 1 |ubuntu | ab     | springboot        | 46102 |             |          |          |          |
| 2 |ubuntu | ab     | pipy-->springboot | 50303 |             |          |          |          |
| 3 |ubuntu | wrk    | springboot        | 71840 |       1.30ms|    2.04ms|    4.27ms|          |
| 4 |ubuntu | wrk    | pipy-->springboot | 73055 |       1.35ms|    2.09ms|    2.49ms|          |
| 5 |ubuntu | fortio | springboot        | 62249 |    0.0015217|0.00293947|0.00428543|0.00777612|
| 6 |ubuntu | fortio | pipy-->springboot | 69233 |    0.0014350|0.00249741|0.00296226|0.00362949|

* 从测试结果中我们可以观察到一个特殊现象：在相同的测试中，经过pipy proxy访问springboot时候，和直接访问springboot相比，拥有更高的qps，更低的latency均值；也就是说，在增加了proxy之后，latency均值没有增加反而降低了。这个看起来违背逻辑的事情，我们初步分析是因为pipy的”长尾“控制的非常好，因此latency的均值要优于直接访问SpringBoot。如果有读者感兴趣进一步分析原因，可以联系我们，大家一起探讨这种现象的根本原因。

# 附录：测试结果详情

## Test Case 1 , ubuntu / ab / springboot

~~~~bash
root@ubuntu21-arm64:~# ab -c100 -n300000 -l http://127.0.0.1:8080/
This is ApacheBench, Version 2.3 <$Revision: 1879490 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 127.0.0.1 (be patient)
Completed 30000 requests
Completed 60000 requests
Completed 90000 requests
Completed 120000 requests
Completed 150000 requests
Completed 180000 requests
Completed 210000 requests
Completed 240000 requests
Completed 270000 requests
Completed 300000 requests
Finished 300000 requests


Server Software:        
Server Hostname:        127.0.0.1
Server Port:            8080

Document Path:          /
Document Length:        Variable

Concurrency Level:      100
Time taken for tests:   6.507 seconds
Complete requests:      300000
Failed requests:        0
Total transferred:      43200000 bytes
HTML transferred:       3300000 bytes
Requests per second:    46102.93 [#/sec] (mean)
Time per request:       2.169 [ms] (mean)
Time per request:       0.022 [ms] (mean, across all concurrent requests)
Transfer rate:          6483.23 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   0.3      1       6
Processing:     0    2   0.7      1      20
Waiting:        0    1   0.7      1      16
Total:          0    2   0.7      2      20
WARNING: The median and mean for the processing time are not within a normal deviation
        These results are probably not that reliable.

Percentage of the requests served within a certain time (ms)
  50%      2
  66%      2
  75%      2
  80%      2
  90%      3
  95%      4
  98%      5
  99%      5
 100%     20 (longest request)
~~~~

## Test Case 2 , ubuntu / ab / pipy-->springboot

~~~~bash
root@ubuntu21-arm64:~# ab -c100 -n300000 -l http://127.0.0.1:8000/
This is ApacheBench, Version 2.3 <$Revision: 1879490 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 127.0.0.1 (be patient)
Completed 30000 requests
Completed 60000 requests
Completed 90000 requests
Completed 120000 requests
Completed 150000 requests
Completed 180000 requests
Completed 210000 requests
Completed 240000 requests
Completed 270000 requests
Completed 300000 requests
Finished 300000 requests


Server Software:        
Server Hostname:        127.0.0.1
Server Port:            8000

Document Path:          /
Document Length:        Variable

Concurrency Level:      100
Time taken for tests:   5.964 seconds
Complete requests:      300000
Failed requests:        0
Total transferred:      38471115 bytes
HTML transferred:       2702095 bytes
Requests per second:    50303.65 [#/sec] (mean)
Time per request:       1.988 [ms] (mean)
Time per request:       0.020 [ms] (mean, across all concurrent requests)
Transfer rate:          6299.60 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.2      0       7
Processing:     1    2   0.3      2      10
Waiting:        0    2   0.3      2       6
Total:          1    2   0.3      2      10

Percentage of the requests served within a certain time (ms)
  50%      2
  66%      2
  75%      2
  80%      2
  90%      2
  95%      2
  98%      2
  99%      3
 100%     10 (longest request)
~~~~

## Test Case 3 , ubuntu / wrk / springboot

~~~~bash
root@ubuntu21-arm64:~# wrk -c100 -t1 -d20 --latency http://127.0.0.1:8080/
Running 20s test @ http://127.0.0.1:8080/
  1 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.43ms    0.88ms  32.07ms   87.05%
    Req/Sec    72.23k     4.70k   88.32k    77.50%
  Latency Distribution
     50%    1.30ms
     75%    1.43ms
     90%    2.04ms
     99%    4.27ms
  1437268 requests in 20.01s, 171.60MB read
Requests/sec:  71840.38
Transfer/sec:      8.58MB
~~~~

## Test Case 4 , ubuntu / wrk / pipy-->springboot

~~~~bash
root@ubuntu21-arm64:~# wrk -c100 -t1 -d20 --latency http://127.0.0.1:8000/
Running 20s test @ http://127.0.0.1:8000/
  1 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.36ms  559.33us  10.29ms   62.92%
    Req/Sec    73.47k     1.36k   75.67k    91.00%
  Latency Distribution
     50%    1.35ms
     75%    1.79ms
     90%    2.09ms
     99%    2.49ms
  1461547 requests in 20.01s, 147.77MB read
Requests/sec:  73055.35
Transfer/sec:      7.39MB
~~~~


## Test Case 5 , ubuntu / fortio / springboot

~~~~bash
root@ubuntu21-arm64:~# fortio load -c 100 -n 300000 -qps 0 http://127.0.0.1:8080/
Fortio 1.22.0 running at 0 queries per second, 4->4 procs, for 300000 calls: http://127.0.0.1:8080/
14:37:01 I httprunner.go:87> Starting http test for http://127.0.0.1:8080/ with 100 threads at -1.0 qps and parallel warmup
Starting at max qps with 100 thread(s) [gomax 4] for exactly 300000 calls (3000 per thread + 0)
14:37:01 I http_client.go:778> Closing dead socket &{{0x4000077800}} (err EOF at first read)
......
Ended after 4.819328656s : 300000 calls. qps=62249
Aggregated Function Time : count 300000 avg 0.0015938249 +/- 0.0009048 min 1.8123e-05 max 0.030373813 sum 478.147481
# range, mid point, percentile, count
>= 1.8123e-05 <= 0.001 , 0.000509062 , 20.86, 62582
> 0.001 <= 0.002 , 0.0015 , 76.72, 167563
> 0.002 <= 0.003 , 0.0025 , 90.86, 42423
> 0.003 <= 0.004 , 0.0035 , 98.76, 23705
> 0.004 <= 0.005 , 0.0045 , 99.61, 2547
> 0.005 <= 0.006 , 0.0055 , 99.80, 583
> 0.006 <= 0.007 , 0.0065 , 99.87, 193
> 0.007 <= 0.008 , 0.0075 , 99.91, 134
> 0.008 <= 0.009 , 0.0085 , 99.94, 78
> 0.009 <= 0.01 , 0.0095 , 99.96, 72
> 0.01 <= 0.011 , 0.0105 , 99.97, 33
> 0.011 <= 0.012 , 0.0115 , 99.98, 23
> 0.012 <= 0.014 , 0.013 , 99.99, 21
> 0.014 <= 0.016 , 0.015 , 99.99, 19
> 0.016 <= 0.018 , 0.017 , 99.99, 6
> 0.018 <= 0.02 , 0.019 , 100.00, 8
> 0.02 <= 0.025 , 0.0225 , 100.00, 5
> 0.025 <= 0.03 , 0.0275 , 100.00, 4
> 0.03 <= 0.0303738 , 0.0301869 , 100.00, 1
# target 50% 0.0015217
# target 75% 0.0019693
# target 90% 0.00293947
# target 99% 0.00428543
# target 99.9% 0.00777612
Sockets used: 3000 (for perfect keepalive, would be 100)
Uniform: false, Jitter: false
Code 200 : 300000 (100.0 %)
Response Header Sizes : count 300000 avg 114.19 +/- 1.89 min 114 max 133 sum 34257000
Response Body/Total Sizes : count 300000 avg 125.19 +/- 1.89 min 125 max 144 sum 37557000
All done 300000 calls (plus 0 warmup) 1.594 ms avg, 62249.3 qps
~~~~

## Test Case 6 , ubuntu / fortio / pipy-->springboot

~~~~bash
root@ubuntu21-arm64:~# fortio load -c 100 -n 300000 -qps 0 http://127.0.0.1:8000/
Fortio 1.22.0 running at 0 queries per second, 4->4 procs, for 300000 calls: http://127.0.0.1:8000/
14:42:36 I httprunner.go:87> Starting http test for http://127.0.0.1:8000/ with 100 threads at -1.0 qps and parallel warmup
Starting at max qps with 100 thread(s) [gomax 4] for exactly 300000 calls (3000 per thread + 0)
14:42:40 I periodic.go:693> T046 ended after 4.310576876s : 3000 calls. qps=695.9625326955891
14:42:40 I periodic.go:693> T007 ended after 4.314851111s : 3000 calls. qps=695.2731213255529
14:42:40 I periodic.go:693> T060 ended after 4.317850758s : 3000 calls. qps=694.7901092787145
14:42:40 I periodic.go:693> T093 ended after 4.317971292s : 3000 calls. qps=694.7707145617586
14:42:40 I periodic.go:693> T087 ended after 4.317992249s : 3000 calls. qps=694.7673425524948
14:42:40 I periodic.go:693> T075 ended after 4.318018748s : 3000 calls. qps=694.7630788748951
14:42:40 I periodic.go:693> T083 ended after 4.31811845s : 3000 calls. qps=694.7470373352079
14:42:40 I periodic.go:693> T014 ended after 4.31929321s : 3000 calls. qps=694.5580802559131
14:42:40 I periodic.go:693> T091 ended after 4.31988034s : 3000 calls. qps=694.4636804453709
14:42:40 I periodic.go:693> T082 ended after 4.320237235s : 3000 calls. qps=694.4063107682557
14:42:40 I periodic.go:693> T020 ended after 4.320752161s : 3000 calls. qps=694.323554838118
14:42:40 I periodic.go:693> T086 ended after 4.320884486s : 3000 calls. qps=694.302291514673
14:42:40 I periodic.go:693> T024 ended after 4.320877779s : 3000 calls. qps=694.3033692321433
14:42:40 I periodic.go:693> T090 ended after 4.320903319s : 3000 calls. qps=694.2992653430392
14:42:40 I periodic.go:693> T010 ended after 4.320916901s : 3000 calls. qps=694.2970829422113
14:42:40 I periodic.go:693> T040 ended after 4.320953899s : 3000 calls. qps=694.2911380503947
14:42:40 I periodic.go:693> T059 ended after 4.320969398s : 3000 calls. qps=694.288647679055
14:42:40 I periodic.go:693> T032 ended after 4.321581402s : 3000 calls. qps=694.1903254701207
14:42:40 I periodic.go:693> T088 ended after 4.321863759s : 3000 calls. qps=694.1449724676525
14:42:40 I periodic.go:693> T076 ended after 4.322039457s : 3000 calls. qps=694.1167543348506
14:42:40 I periodic.go:693> T030 ended after 4.322193905s : 3000 calls. qps=694.0919509718294
14:42:40 I periodic.go:693> T069 ended after 4.32220003s : 3000 calls. qps=694.0909673724656
14:42:40 I periodic.go:693> T015 ended after 4.322411392s : 3000 calls. qps=694.0570269531623
14:42:40 I periodic.go:693> T035 ended after 4.322457472s : 3000 calls. qps=694.0496278872354
14:42:40 I periodic.go:693> T063 ended after 4.322589964s : 3000 calls. qps=694.0283545247227
14:42:40 I periodic.go:693> T051 ended after 4.322850198s : 3000 calls. qps=693.9865742717554
14:42:40 I periodic.go:693> T055 ended after 4.322871363s : 3000 calls. qps=693.9831764778794
14:42:40 I periodic.go:693> T047 ended after 4.322925277s : 3000 calls. qps=693.9745213643672
14:42:40 I periodic.go:693> T018 ended after 4.322935984s : 3000 calls. qps=693.9728025359535
14:42:40 I periodic.go:693> T008 ended after 4.323130097s : 3000 calls. qps=693.9416424413934
14:42:40 I periodic.go:693> T070 ended after 4.323425996s : 3000 calls. qps=693.8941484775214
14:42:40 I periodic.go:693> T022 ended after 4.323690188s : 3000 calls. qps=693.851749213258
14:42:40 I periodic.go:693> T002 ended after 4.323710645s : 3000 calls. qps=693.8484663559163
14:42:40 I periodic.go:693> T038 ended after 4.323721769s : 3000 calls. qps=693.8466812340348
14:42:40 I periodic.go:693> T094 ended after 4.323737143s : 3000 calls. qps=693.8442141092943
14:42:40 I periodic.go:693> T036 ended after 4.323741476s : 3000 calls. qps=693.8435187793359
14:42:40 I periodic.go:693> T009 ended after 4.323770308s : 3000 calls. qps=693.8388920543001
14:42:40 I periodic.go:693> T013 ended after 4.323787057s : 3000 calls. qps=693.836204339237
14:42:40 I periodic.go:693> T019 ended after 4.323789723s : 3000 calls. qps=693.8357765276552
14:42:40 I periodic.go:693> T061 ended after 4.323800472s : 3000 calls. qps=693.8340516467754
14:42:40 I periodic.go:693> T041 ended after 4.324439683s : 3000 calls. qps=693.7314935374022
14:42:40 I periodic.go:693> T054 ended after 4.324717207s : 3000 calls. qps=693.6869756811361
14:42:40 I periodic.go:693> T048 ended after 4.3255042s : 3000 calls. qps=693.5607645462464
14:42:40 I periodic.go:693> T043 ended after 4.325547364s : 3000 calls. qps=693.5538436055373
14:42:40 I periodic.go:693> T052 ended after 4.325635567s : 3000 calls. qps=693.5397015150352
14:42:40 I periodic.go:693> T000 ended after 4.325655399s : 3000 calls. qps=693.5365218166792
14:42:40 I periodic.go:693> T062 ended after 4.325821597s : 3000 calls. qps=693.5098761540535
14:42:40 I periodic.go:693> T096 ended after 4.325888301s : 3000 calls. qps=693.4991824237582
14:42:40 I periodic.go:693> T037 ended after 4.326088164s : 3000 calls. qps=693.4671431259347
14:42:40 I periodic.go:693> T078 ended after 4.326587591s : 3000 calls. qps=693.3870947719824
14:42:40 I periodic.go:693> T073 ended after 4.326597632s : 3000 calls. qps=693.3854855861022
14:42:40 I periodic.go:693> T016 ended after 4.326602882s : 3000 calls. qps=693.3846442161179
14:42:40 I periodic.go:693> T001 ended after 4.326860741s : 3000 calls. qps=693.3433220008501
14:42:40 I periodic.go:693> T068 ended after 4.327202095s : 3000 calls. qps=693.2886271862466
14:42:40 I periodic.go:693> T028 ended after 4.327446955s : 3000 calls. qps=693.249398824809
14:42:40 I periodic.go:693> T005 ended after 4.327553323s : 3000 calls. qps=693.232359276928
14:42:40 I periodic.go:693> T023 ended after 4.327567364s : 3000 calls. qps=693.230110051269
14:42:40 I periodic.go:693> T081 ended after 4.32757328s : 3000 calls. qps=693.2291623724971
14:42:40 I periodic.go:693> T067 ended after 4.327697564s : 3000 calls. qps=693.2092540281773
14:42:40 I periodic.go:693> T033 ended after 4.327912509s : 3000 calls. qps=693.1748259146706
14:42:40 I periodic.go:693> T072 ended after 4.328331775s : 3000 calls. qps=693.1076811920224
14:42:40 I periodic.go:693> T044 ended after 4.328359148s : 3000 calls. qps=693.1032979059066
14:42:40 I periodic.go:693> T079 ended after 4.328365231s : 3000 calls. qps=693.102323832062
14:42:40 I periodic.go:693> T017 ended after 4.328374105s : 3000 calls. qps=693.1009028388963
14:42:40 I periodic.go:693> T031 ended after 4.328385105s : 3000 calls. qps=693.0991414175472
14:42:40 I periodic.go:693> T039 ended after 4.328781122s : 3000 calls. qps=693.035733489322
14:42:40 I periodic.go:693> T025 ended after 4.328960736s : 3000 calls. qps=693.0069785691861
14:42:40 I periodic.go:693> T066 ended after 4.329157474s : 3000 calls. qps=692.9754849569143
14:42:40 I periodic.go:693> T065 ended after 4.329286507s : 3000 calls. qps=692.9548310441724
14:42:40 I periodic.go:693> T098 ended after 4.329384668s : 3000 calls. qps=692.93911954141
14:42:40 I periodic.go:693> T092 ended after 4.329395459s : 3000 calls. qps=692.9373923935647
14:42:40 I periodic.go:693> T064 ended after 4.329464788s : 3000 calls. qps=692.9262961821784
14:42:40 I periodic.go:693> T045 ended after 4.329487995s : 3000 calls. qps=692.9225819460898
14:42:40 I periodic.go:693> T084 ended after 4.329644027s : 3000 calls. qps=692.8976103559011
14:42:40 I periodic.go:693> T050 ended after 4.329693274s : 3000 calls. qps=692.8897291674523
14:42:40 I periodic.go:693> T029 ended after 4.330081833s : 3000 calls. qps=692.8275528505467
14:42:40 I periodic.go:693> T003 ended after 4.330095582s : 3000 calls. qps=692.8253529716194
14:42:40 I periodic.go:693> T099 ended after 4.330178785s : 3000 calls. qps=692.8120405541176
14:42:40 I periodic.go:693> T080 ended after 4.330258822s : 3000 calls. qps=692.7992351769868
14:42:40 I periodic.go:693> T074 ended after 4.330270488s : 3000 calls. qps=692.7973687356409
14:42:40 I periodic.go:693> T097 ended after 4.330302153s : 3000 calls. qps=692.7923027083972
14:42:40 I periodic.go:693> T057 ended after 4.330459434s : 3000 calls. qps=692.7671406978016
14:42:40 I periodic.go:693> T027 ended after 4.330482183s : 3000 calls. qps=692.7635014357014
14:42:40 I periodic.go:693> T056 ended after 4.33050414s : 3000 calls. qps=692.7599889097438
14:42:40 I periodic.go:693> T077 ended after 4.331027774s : 3000 calls. qps=692.6762321889465
14:42:40 I periodic.go:693> T011 ended after 4.331040482s : 3000 calls. qps=692.6741997605739
14:42:40 I periodic.go:693> T004 ended after 4.33104344s : 3000 calls. qps=692.6737266805155
14:42:40 I periodic.go:693> T095 ended after 4.331050023s : 3000 calls. qps=692.6726738478033
14:42:40 I periodic.go:693> T034 ended after 4.331051564s : 3000 calls. qps=692.6724273929702
14:42:40 I periodic.go:693> T042 ended after 4.331054398s : 3000 calls. qps=692.6719741468369
14:42:40 I periodic.go:693> T012 ended after 4.331468664s : 3000 calls. qps=692.6057263056769
14:42:40 I periodic.go:693> T089 ended after 4.331494329s : 3000 calls. qps=692.6016224734622
14:42:40 I periodic.go:693> T058 ended after 4.331511953s : 3000 calls. qps=692.5988044249084
14:42:40 I periodic.go:693> T049 ended after 4.331471288s : 3000 calls. qps=692.6053067259763
14:42:40 I periodic.go:693> T053 ended after 4.332068585s : 3000 calls. qps=692.5098116838794
14:42:40 I periodic.go:693> T085 ended after 4.332098416s : 3000 calls. qps=692.5050430340916
14:42:40 I periodic.go:693> T071 ended after 4.3322282s : 3000 calls. qps=692.4842971106647
14:42:40 I periodic.go:693> T006 ended after 4.33224749s : 3000 calls. qps=692.4812137175477
14:42:40 I periodic.go:693> T026 ended after 4.332263948s : 3000 calls. qps=692.4785830246925
14:42:40 I periodic.go:693> T021 ended after 4.332934073s : 3000 calls. qps=692.3714853392371
Ended after 4.333138977s : 300000 calls. qps=69234
Aggregated Function Time : count 300000 avg 0.001441618 +/- 0.0005929 min 0.000118784 max 0.006255693 sum 432.485388
# range, mid point, percentile, count
>= 0.000118784 <= 0.001 , 0.000559392 , 26.61, 79839
> 0.001 <= 0.002 , 0.0015 , 80.37, 161270
> 0.002 <= 0.003 , 0.0025 , 99.73, 58083
> 0.003 <= 0.004 , 0.0035 , 100.00, 807
> 0.006 <= 0.00625569 , 0.00612785 , 100.00, 1
# target 50% 0.00143505
# target 75% 0.00190011
# target 90% 0.00249741
# target 99% 0.00296226
# target 99.9% 0.00362949
Sockets used: 100 (for perfect keepalive, would be 100)
Uniform: false, Jitter: false
Code 200 : 300000 (100.0 %)
Response Header Sizes : count 300000 avg 100.56341 +/- 38 min 62 max 138 sum 30169024
Response Body/Total Sizes : count 300000 avg 106.14496 +/- 43.5 min 62 max 149 sum 31843488
All done 300000 calls (plus 0 warmup) 1.442 ms avg, 69233.9 qps
~~~~
