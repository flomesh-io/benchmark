#!/usr/bin/bash

proxy=pipy
proxy_addr=http://:
thread=2
connection=2048
low_rate=6000
high_rate=18000
rate_step=2000
duration=1m

PLAN="${thread}-${connection}-${low_rate}-${high_rate}-${duration}"
if [ ! -d "throughput-${PLAN}" ]
then
	mkdir "throughput-${PLAN}"
fi

autobench --verbose \
	--threads ${thread} \
	--connections ${connection} \
	--duration ${duration} \
	--warmup_duration 1m \
	--low_rate ${low_rate} \
	--high_rate ${high_rate} \
	--rate_step ${rate_step} \
	--file "throughput-${PLAN}/${proxy}-${PLAN}.json"  \
	${proxy_addr}

# run parse script
./throughput-report.py -f throughput-${PLAN}/${proxy}-${PLAN}.json || exit 1

echo "Result export to: throughput-${PLAN}/${proxy}-${PLAN}.html"
