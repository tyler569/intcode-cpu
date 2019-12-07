#!/usr/bin/env python3

import sys

text = ""
for line in sys.stdin:
    if "//" in line:
        ix = line.find("//")
        line = line[:ix]
    text += line

cmds = text.split(",")
cmds = list(map(lambda s: s.strip(), cmds))

names = {}

for i in range(len(cmds)):
    c = cmds[i]
    if ":" in c:
        name, value = c.split(":")
        names[name] = i
        cmds[i] = value

for i in range(len(cmds)):
    c = cmds[i]
    if c[0] == "$":
        v = names[c[1:]]
        cmds[i] = str(v)

print(",".join(cmds))

