"""Tests for check_finished.py. Run: python3 -m unittest discover test_acceptance"""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_finished import check


def flutter_lines(tests, load_error=False):
    """tests: (group, name, result, skipped). Builds flutter's JSON event stream."""
    lines = []
    groups = {}
    for i, (group, name, result, skipped) in enumerate(tests):
        group_ids = []
        full = name
        if group:
            if group not in groups:
                groups[group] = 1000 + len(groups)
                lines.append({'type': 'group', 'group': {'id': groups[group], 'name': group}})
            group_ids = [groups[group]]
            full = f'{group} {name}'
        lines.append({'type': 'testStart', 'test': {'id': i, 'name': full, 'groupIDs': group_ids}})
        lines.append({'type': 'testDone', 'testID': i, 'result': result, 'skipped': skipped, 'hidden': False})
    if load_error:
        lines.append({'type': 'testStart', 'test': {'id': 900, 'name': 'loading a_test.dart', 'groupIDs': []}})
        lines.append({'type': 'testDone', 'testID': 900, 'result': 'error', 'skipped': False, 'hidden': False})
    return lines


def jest_results(tests, broken_suite=False):
    suites = [{'status': 'passed', 'assertionResults': [{'title': t, 'status': s} for t, s in tests]}]
    if broken_suite:
        suites.append({'status': 'failed', 'assertionResults': [], 'message': 'cannot compile'})
    return {'testResults': suites}


class CheckFinishedTest(unittest.TestCase):
    def run_check(self, finished, flutter=(), jest=(), load_error=False, broken_suite=False):
        with tempfile.TemporaryDirectory() as d:
            f = os.path.join(d, 'flutter.json')
            j = os.path.join(d, 'jest.json')
            with open(f, 'w') as out:
                out.write('\n'.join(['not json'] + [json.dumps(x) for x in flutter_lines(flutter, load_error)]))
            with open(j, 'w') as out:
                json.dump(jest_results(jest, broken_suite), out)
            return check(finished, f, j)

    def test_finished_passing_in_jest_is_clean(self):
        self.assertEqual(self.run_check(['H-07'], jest=[('H-07 removed member', 'passed')]), [])

    def test_finished_passing_in_flutter_is_clean(self):
        self.assertEqual(self.run_check(['A-01'], flutter=[(None, 'A-01 stores title', 'success', False)]), [])

    def test_finished_failing_is_reported(self):
        errors = self.run_check(['H-07'], jest=[('H-07 one', 'passed'), ('H-07 two', 'failed')])
        self.assertEqual(len(errors), 1)
        self.assertIn('H-07', errors[0])

    def test_flutter_error_is_a_failure(self):
        errors = self.run_check(['A-01'], flutter=[(None, 'A-01 x', 'error', False)])
        self.assertIn('A-01', errors[0])

    def test_unfinished_scenario_may_fail(self):
        self.assertEqual(
            self.run_check(['H-07'], jest=[('H-07 ok', 'passed'), ('H-05 planned gap', 'failed')]),
            [],
        )

    def test_finished_with_no_test_is_reported(self):
        errors = self.run_check(['GE-05'], jest=[('H-07 ok', 'passed')])
        self.assertIn('GE-05', errors[0])

    def test_finished_with_only_skipped_tests_is_reported(self):
        errors = self.run_check(['A-02'], flutter=[(None, 'A-02 schedule', 'success', True)])
        self.assertIn('A-02', errors[0])

    def test_group_name_does_not_claim_the_test(self):
        # The group mentions A-01, but this test belongs to H-02 alone.
        errors = self.run_check(
            ['A-01'],
            flutter=[('A-01 setup', 'H-02 tasks', 'error', False), ('A-01 setup', 'A-01 ok', 'success', False)],
        )
        self.assertEqual(errors, [])

    def test_all_leading_ids_count(self):
        errors = self.run_check(['U-02'], flutter=[(None, 'U-01 U-02 dashboard', 'error', False)])
        self.assertIn('U-02', errors[0])

    def test_id_later_in_the_name_does_not_count(self):
        errors = self.run_check(['H-05'], jest=[('H-07 unlike H-05', 'passed')])
        self.assertIn('H-05', errors[0])

    def test_longer_id_forms_are_recognised(self):
        finished = ['FND-01', 'GAP-CON-01']
        tests = [('FND-01 money', 'passed'), ('GAP-CON-01 invite', 'passed')]
        self.assertEqual(self.run_check(finished, jest=tests), [])

    def test_flutter_file_that_fails_to_load_is_reported(self):
        errors = self.run_check(['H-07'], jest=[('H-07 ok', 'passed')], load_error=True)
        self.assertTrue(any('loading' in e for e in errors))

    def test_jest_suite_that_fails_to_run_is_reported(self):
        errors = self.run_check(['H-07'], jest=[('H-07 ok', 'passed')], broken_suite=True)
        self.assertTrue(any('cannot compile' in e for e in errors))

    def test_missing_results_file_is_reported(self):
        errors = check(['H-07'], '/nonexistent/flutter.json', '/nonexistent/jest.json')
        self.assertTrue(errors)


if __name__ == '__main__':
    unittest.main()
