#!/usr/bin/env python3
"""Fails if any requirement is missing from the platform plan, or is in two stages.

Sources: the convention spec, docs/guide/GAPS.md, and sections 6 and 7 of the plan.
"""
import re
import subprocess
import sys
from collections import Counter

PLAN = 'ai_specs/event-platform-plan.md'
SPEC = 'docs/testing/CREWPOINT_CONVENTION_TEST_v3.md'

plan = open(PLAN, encoding='utf-8').read()
try:
    spec = open(SPEC, encoding='utf-8').read()
except FileNotFoundError:
    # The spec is on an unmerged branch until PR #42 lands.
    spec = subprocess.check_output(
        ['git', 'show', f'origin/test/derod-convention-v2:{SPEC}'], text=True
    )
gaps = open('docs/guide/GAPS.md', encoding='utf-8').read()

want = set(re.findall(r'^- \*\*([A-Z]-\d\d)\*\* ', spec, re.M))
want |= set(re.findall(r'^\| \*\*(N-\d\d)\*\* \|', spec, re.M))
want |= set(re.findall(r'^### (GAP-[A-Z]+-\d+) ', gaps, re.M))
want |= set(re.findall(r'^- \*\*((?:GE|PA|WE|SP|FND)-\d\d)\*\* ', plan, re.M))

planned = []
stages = {}
for name, ids in re.findall(
    r'^### (Stage \d+|Already built)[^\n]*\n.*?^\*\*Covers:\*\* ([^\n]+)',
    plan,
    re.M | re.S,
):
    expanded = []
    for token in ids.split(', '):
        m = re.fullmatch(r'([A-Z])-(\d\d)…[A-Z]-(\d\d)', token)
        if m:
            expanded += [
                f'{m[1]}-{n:02}' for n in range(int(m[2]), int(m[3]) + 1)
            ]
        else:
            expanded.append(token)
    stages[name] = len(expanded)
    planned += expanded

duplicated = sorted(i for i, c in Counter(planned).items() if c > 1)
missing = sorted(want - set(planned))
unknown = sorted(set(planned) - want)

print(f'requirements: {len(want)}, planned: {len(planned)}')
for name, count in stages.items():
    print(f'  {name}: {count}')
print('missing:', missing)
print('duplicated:', duplicated)
print('unknown:', unknown)
sys.exit(1 if missing or duplicated or unknown else 0)
