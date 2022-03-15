#!/usr/bin/env python3

# ref: https://github.com/MaartenSmeets/db_perftest/blob/master/test_scripts/wrk_parser.py

import os
import argparse
import json

from string import Template

def main():
    cmd_parser = argparse.ArgumentParser(description='autobench json to html')
    cmd_parser.add_argument('-f','--file', help='<Required> autobench output file', required=True, dest='report_file')

    args =  cmd_parser.parse_args()

    report_file_name = os.path.basename(args.report_file).replace(".json", "")
    fields = report_file_name.split("-")

    proxy = fields[0]
    thread = fields[1]
    connection = fields[2]
    low_rate = fields[3]
    high_rate = fields[4]
    duration = fields[5]

    with open(args.report_file) as report_file:
        report_json_data = json.load(report_file)

    with open('throughput-graph.html.tmpl') as tmpl:
        tmpl_string = Template(tmpl.read())

    html = tmpl_string.substitute(report_json_data=json.dumps(report_json_data))

    report_html = open("throughput-{thread}-{connection}-{low_rate}-{high_rate}-{duration}/{proxy}-{thread}-{connection}-{low_rate}-{high_rate}-{duration}.html".format(
        proxy=proxy,
        thread=thread,
        connection=connection,
        low_rate=low_rate,
        high_rate=high_rate,
        duration=duration), 'w'
        )

    report_html.write(html)
    report_html.flush()
    report_html.close()

if __name__ == '__main__':
    main()
