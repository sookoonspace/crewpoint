#!/usr/bin/env python3
"""Fails CI if a finished scenario is not green in the acceptance results.

Usage: check_finished.py <flutter-json-results> <jest-json-results>

A test belongs to the scenario IDs at the start of its own name. A finished
scenario needs at least one passing test and no failing ones. Scenarios missing
from finished_scenarios.json may fail, because a planned gap must not block work.
A test file that cannot load or run fails the check, since it may hide a test.
"""
import json
import os
import re
import sys

LIST_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'finished_scenarios.json')
SCENARIO_ID = r'(?:GAP-[A-Z]+|[A-Z]{1,3})-\d\d'
LEADING_IDS = re.compile(rf'^(?:{SCENARIO_ID}\b\s*)+')


def ids_in(name):
    match = LEADING_IDS.match(name)
    return re.findall(SCENARIO_ID, match.group(0)) if match else []


def read_flutter(path):
    """Returns (results, errors): results is [(leaf test name, passed, skipped)]."""
    groups, tests, results, errors = {}, {}, [], []
    with open(path, encoding='utf-8') as source:
        for line in source:
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if not isinstance(event, dict):
                continue
            kind = event.get('type')
            if kind == 'group':
                groups[event['group']['id']] = event['group'].get('name') or ''
            elif kind == 'testStart':
                tests[event['test']['id']] = event['test']
            elif kind == 'testDone' and not event.get('hidden'):
                test = tests[event['testID']]
                name = test['name']
                # Flutter puts the group names before the test's own name.
                prefix = max((groups.get(g, '') for g in test.get('groupIDs', [])), key=len, default='')
                if prefix and name.startswith(prefix + ' '):
                    name = name[len(prefix) + 1:]
                passed = event.get('result') == 'success'
                if name.startswith('loading ') and not passed:
                    errors.append(f'Flutter test file failed to load: {name}')
                results.append((name, passed, bool(event.get('skipped'))))
    return results, errors


def read_jest(path):
    results, errors = [], []
    with open(path, encoding='utf-8') as source:
        data = json.load(source)
    for suite in data['testResults']:
        if suite.get('status') == 'failed' and not suite.get('assertionResults'):
            errors.append(f"Jest suite failed to run: {suite.get('message', '')[:500]}")
        for assertion in suite.get('assertionResults', []):
            status = assertion['status']
            results.append((assertion['title'], status == 'passed', status not in ('passed', 'failed')))
    return results, errors


def check(finished, flutter_path, jest_path):
    """Returns a list of problems. An empty list means the gate passes."""
    results, errors = [], []
    for reader, path in ((read_flutter, flutter_path), (read_jest, jest_path)):
        try:
            found, problems = reader(path)
        except (OSError, ValueError, KeyError) as error:
            errors.append(f'Could not read test results from {path}: {error}')
            continue
        results += found
        errors += problems

    for scenario in finished:
        mine = [r for r in results if scenario in ids_in(r[0])]
        failed = [name for name, passed, skipped in mine if not passed and not skipped]
        passed = [name for name, ok, skipped in mine if ok and not skipped]
        if failed:
            errors.append(f'{scenario} is finished but failed: {"; ".join(failed)}')
        elif not passed:
            errors.append(f'{scenario} is finished but has no passing test')
    return errors


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    with open(LIST_PATH, encoding='utf-8') as source:
        finished = json.load(source)['finished']
    errors = check(finished, argv[1], argv[2])
    for error in errors:
        print(f'::error::{error}')
    if errors:
        return 1
    print(f'{len(finished)} finished scenarios are green: {", ".join(finished)}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
