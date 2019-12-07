#!/usr/bin/env python3

import sys

text = sys.stdin.read()

nums = text.split(",")
nums = list(map(lambda s: s.strip(), nums))
nums = list(map(int, nums))

for n in nums:
    print(hex(n)[2:], "//", n)

