#!/usr/bin/env python3

# ref: https://github.com/MaartenSmeets/db_perftest/blob/master/test_scripts/wrk_parser.py

import os
import re
import subprocess
import argparse
import json

from string import Template

wrkcmd = '/home/maarten/projects/wrk/wrk'

def wrk_data(wrk_output):
    return str(wrk_output.get('lat_avg')) + ',' + str(wrk_output.get('lat_stdev')) + ',' + str(
        wrk_output.get('lat_max')) + ',' + str(wrk_output.get('req_avg')) + ',' + str(
        wrk_output.get('req_stdev')) + ',' + str(wrk_output.get('req_max')) + ',' + str(
        wrk_output.get('tot_requests')) + ',' + str(wrk_output.get('tot_duration')) + ',' + str(
        wrk_output.get('read')) + ',' + str(wrk_output.get('err_connect')) + ',' + str(
        wrk_output.get('err_read')) + ',' + str(wrk_output.get('err_write')) + ',' + str(
        wrk_output.get('err_timeout')) + ',' + str(wrk_output.get('req_sec_tot')) + ',' + str(
        wrk_output.get('read_tot'))


def get_bytes(size_str):
    x = re.search("^(\d+\.*\d*)(\w+)$", size_str)
    if x is not None:
        size = float(x.group(1))
        suffix = (x.group(2)).lower()
    else:
        return size_str

    if suffix == 'b':
        return size
    elif suffix == 'kb' or suffix == 'kib':
        return size * 1024
    elif suffix == 'mb' or suffix == 'mib':
        return size * 1024 ** 2
    elif suffix == 'gb' or suffix == 'gib':
        return size * 1024 ** 3
    elif suffix == 'tb' or suffix == 'tib':
        return size * 1024 ** 3
    elif suffix == 'pb' or suffix == 'pib':
        return size * 1024 ** 4

    return False


def get_number(number_str):
    x = re.search("^(\d+\.*\d*)(\w*)$", number_str)
    if x is not None:
        size = float(x.group(1))
        suffix = (x.group(2)).lower()
    else:
        return number_str

    if suffix == 'k':
        return size * 1000
    elif suffix == 'm':
        return size * 1000 ** 2
    elif suffix == 'g':
        return size * 1000 ** 3
    elif suffix == 't':
        return size * 1000 ** 4
    elif suffix == 'p':
        return size * 1000 ** 5
    else:
        return size

    return False


def get_ms(time_str):
    x = re.search("^(\d+\.*\d*)(\w*)$", time_str)
    if x is not None:
        size = float(x.group(1))
        suffix = (x.group(2)).lower()
    else:
        return time_str

    if suffix == 'us':
        return size / 1000
    elif suffix == 'ms':
        return size
    elif suffix == 's':
        return size * 1000
    elif suffix == 'm':
        return size * 1000 * 60
    elif suffix == 'h':
        return size * 1000 * 60 * 60
    else:
        return size

    return False


def parse_wrk_output(wrk_output):
    retval = {}
    retval['percentiles'] = {}
    for line in wrk_output.splitlines():
        x = re.search("^\s+Latency\s+(\d+\.\d+\w*)\s+(\d+\.\d+\w*)\s+(\d+\.\d+\w*).*$", line)
        if x is not None:
            retval['lat_avg'] = get_ms(x.group(1))
            retval['lat_stdev'] = get_ms(x.group(2))
            retval['lat_max'] = get_ms(x.group(3))
        x = re.search("^\s+Req/Sec\s+(\d+\.\d+\w*)\s+(\d+\.\d+\w*)\s+(\d+\.\d+\w*).*$", line)
        if x is not None:
            retval['req_avg'] = get_number(x.group(1))
            retval['req_stdev'] = get_number(x.group(2))
            retval['req_max'] = get_number(x.group(3))

        x = re.search("^\s+50.000%\s+(\d+\.\d+\w*).*$", line)
        if x is not None:
            retval['percentiles']['p50'] = get_ms(x.group(1))

        x = re.search("^\s+75.000%\s+(\d+\.\d+\w*).*$", line)
        if x is not None:
            retval['percentiles']['p75'] = get_ms(x.group(1))

        x = re.search("^\s+90.000%\s+(\d+\.\d+\w*).*$", line)
        if x is not None:
            retval['percentiles']['p90'] = get_ms(x.group(1))

        x = re.search("^\s+99.000%\s+(\d+\.\d+\w*).*$", line)
        if x is not None:
            retval['percentiles']['p99'] = get_ms(x.group(1))

        x = re.search("^\s+99.900%\s+(\d+\.\d+\w*).*$", line)
        if x is not None:
            retval['percentiles']['p99.9'] = get_ms(x.group(1))

        x = re.search("^\s+99.990%\s+(\d+\.\d+\w*).*$", line)
        if x is not None:
            retval['percentiles']['p99.99'] = get_ms(x.group(1))

        x = re.search("^\s+99.999%\s+(\d+\.\d+\w*).*$", line)
        if x is not None:
            retval['percentiles']['p99.999'] = get_ms(x.group(1))

        x = re.search("^\s*100.000%\s+(\d+\.\d+\w*).*$", line)
        if x is not None:
            retval['percentiles']['p100'] = get_ms(x.group(1))

        x = re.search("^\s+(\d+)\ requests in (\d+\.\d+\w*)\,\ (\d+\.\d+\w*)\ read.*$", line)
        if x is not None:
            retval['tot_requests'] = get_number(x.group(1))
            retval['tot_duration'] = get_ms(x.group(2))
            retval['read'] = get_bytes(x.group(3))
        x = re.search("^Requests\/sec\:\s+(\d+\.*\d*).*$", line)
        if x is not None:
            retval['req_sec_tot'] = get_number(x.group(1))
        x = re.search("^Transfer\/sec\:\s+(\d+\.*\d*\w+).*$", line)
        if x is not None:
            retval['read_tot'] = get_bytes(x.group(1))
        x = re.search(
            "^\s+Socket errors:\ connect (\d+\w*)\,\ read (\d+\w*)\,\ write\ (\d+\w*)\,\ timeout\ (\d+\w*).*$", line)
        if x is not None:
            retval['err_connect'] = get_number(x.group(1))
            retval['err_read'] = get_number(x.group(2))
            retval['err_write'] = get_number(x.group(3))
            retval['err_timeout'] = get_number(x.group(4))
    if 'err_connect' not in retval:
        retval['err_connect'] = 0
    if 'err_read' not in retval:
        retval['err_read'] = 0
    if 'err_write' not in retval:
        retval['err_write'] = 0
    if 'err_timeout' not in retval:
        retval['err_timeout'] = 0
    return retval


def execute_wrk(cpuset, threads, concurrency, duration, timeout, url):
    cmd = 'taskset -c ' + str(cpuset) + ' ' + wrkcmd + ' --timeout ' + str(timeout) + ' -d' + str(
        duration) + 's -c' + str(
        concurrency) + ' -t' + str(threads) + ' ' + url
    process = subprocess.run(cmd.split(' '), check=True, stdout=subprocess.PIPE, universal_newlines=True)
    output = process.stdout
    return output

def latency_graph_data():
    pass

def thoughtput_graph_data():
    pass

def main():
    cmd_parser = argparse.ArgumentParser(description='wrk result parser')
    cmd_parser.add_argument('-l','--list', nargs='+', help='<Required> wrk output file', required=True, dest='file_list')

    args =  cmd_parser.parse_args()

    wrk_report = {}
    full_report = {}

    for report in args.file_list:
        report_file_name = os.path.basename(report).replace(".report", "")
        fields = report_file_name.split("-")
        proxy = fields[0]
        thread = fields[1]
        connection = fields[2]
        rate = fields[3]
        duration = fields[4]
        with open(report) as report_file:
            content = report_file.read()
            output_dict = parse_wrk_output(content)
            wrk_report[proxy] = output_dict

    full_report['plan'] = {
            'thread': thread,
            'connection': connection,
            'rate': rate,
            'duration': duration,
        }
    full_report['result'] = wrk_report

    with open('latency-graph.html.tmpl') as tmpl:
        tmpl_string = Template(tmpl.read())

    html = tmpl_string.substitute(full_report=json.dumps(full_report))

    report_html = open("latency-{thread}-{connection}-{rate}-{duration}/latency-{thread}-{connection}-{rate}-{duration}.html".format(
        thread=full_report['plan']['thread'],
        connection=full_report['plan']['connection'],
        rate=full_report['plan']['rate'],
        duration=full_report['plan']['duration']), 'w'
        )

    report_html.write(html)
    report_html.flush()
    report_html.close()

if __name__ == '__main__':
    main()
