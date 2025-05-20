#!/usr/bin/python3

import datetime
import sys

if len(sys.argv) != 2:
    sys.exit("Expected a year")
if not sys.argv[1].isdigit():
    sys.exit(f"Invalid year {sys.argv[1]}")

year_num = int(sys.argv[1])
monday = datetime.date(year_num, 1, 1)
to_sunday = datetime.timedelta(days=6)
to_next_week = datetime.timedelta(days=7)
week_idx=1

if monday.weekday() != 0:
    # move to closest next monday
    monday += datetime.timedelta(days=7-monday.weekday())

while monday.year == year_num:
    sunday = monday + to_sunday
    to_print=f"Week {week_idx:02} ({monday.day:02}.{monday.month:02} - {sunday.day:02}.{sunday.month:02})"
    print(to_print)
    print('=' * len(to_print))
    week_idx += 1
    monday += to_next_week
