#!/usr/bin/env python3

#
# Copyright 2019, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the GNU General Public License version 2. Note that NO WARRANTY is provided.
# See "LICENSE_GPLv2.txt" for details.
#
# @TAG(DATA61_GPL)
#

import sys, json
from statistics import mean, median

#
# Usage: Take the output log generated by mk_ttsplit_tacs_final in cogent/isa/CogentHelper.thy
#        and use it as input to this file (usually ~/TypeProofTactic.json)
#
# Then run: ./generate_tactic_statistics.py TypeProofTactic.json [outfile]
#
# Optionally include outfile to have statistics logged in json format.
#


def make_stats_obj(num_list):
    obj = {}
    obj['average'] = mean(num_list)
    obj['min']     = min(num_list)
    obj['max']     = max(num_list)
    obj['median']  = median(num_list)
    obj['total']   = sum(num_list)
    obj['amount']   = len(num_list)

    return obj

if len(sys.argv) < 2:
    print("Usage: " + sys.argv[0] + " filename [outfile_name]")
    exit(1)

try:
    f = open(sys.argv[1], 'r')
    content = f.readlines()

    tactic_times = {}

    for line in content:
        data = json.loads(line)
        if not data['tacticName'] in tactic_times:
            tactic_times[data['tacticName']] = [data['time']]
        else:
            tactic_times[data['tacticName']].append(data['time'])

    final_stats = {}

    # print stats
    for key in sorted(tactic_times.keys()):
        cpu     = [d['cpu']     for d in tactic_times[key]]
        elapsed = [d['elapsed'] for d in tactic_times[key]]
        gc      = [d['gc']      for d in tactic_times[key]]

        final_stats[key] = {
                "cpu":      make_stats_obj(cpu),
                "elapsed":  make_stats_obj(elapsed),
                "gc":       make_stats_obj(gc),
            }

        print("tactic '{}':".format(key))
        row_format ="{:>15}" * 7
        print(row_format.format("Type", *sorted(["Min","Average","Median","Max", "Total", "Amount"])))
        for t in ["Elapsed", "CPU", "GC"]:
            stat_obj = final_stats[key][t.lower()]
            nums = [str(round(x,6)) for x in [stat_obj[key] for key in sorted(stat_obj.keys())]]
            print(row_format.format(t, *nums))

    # Log stats if outfile present
    if (len(sys.argv) > 2):
        with open(sys.argv[2], 'w') as out:
            stat_str = json.dumps(final_stats)
            out.write(stat_str)

except FileNotFoundError:
    print("File '" + sys.argv[1] + "' not found.")
