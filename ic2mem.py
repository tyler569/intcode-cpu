#!/usr/bin/env python3

import sys

text = sys.stdin.read()

nums = text.split(",")
nums = list(map(lambda s: s.strip(), nums))
nums = list(map(int, nums))

for n in nums:
    if n < 0:
        n = 2**32 + n
    print(hex(n)[2:], "//", n)

