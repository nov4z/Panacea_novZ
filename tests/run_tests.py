#!/usr/bin/env python3
"""Master Test Runner for panacea-antigravity-notch E2E Test Suite.

Supports:
  --tier {1,2,3,4,all}: Select specific test tier(s)
  -v, --verbose: Detailed verbose test reporting
  --json: Output JSON formatted summary to stdout
  -k, --filter: Filter test methods by substring
  --report FILE: Write JSON report to file

Exit Codes:
  0: All executed tests passed or skipped
  1: One or more test failures or errors occurred
  2: Invalid command-line arguments
"""

import sys
import os
import argparse
import unittest
import time
import json
from pathlib import Path

# Add project root to sys.path so tests.* can be imported cleanly
PROJECT_ROOT = Path("/home/nova/.config/panacea")
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


TIER_MODULE_MAP = {
    1: "tests.test_tier1_feature",
    2: "tests.test_tier2_boundary",
    3: "tests.test_tier3_combinations",
    4: "tests.test_tier4_scenarios",
}


class JsonTestResult(unittest.TextTestResult):
    """Custom TestResult that captures structured test metrics."""

    def __init__(self, stream=None, descriptions=None, verbosity=None, *args, **kwargs):
        super().__init__(stream, descriptions, verbosity, *args, **kwargs)
        self.test_details = []
        self.start_times = {}

    def startTest(self, test):
        super().startTest(test)
        self.start_times[test.id()] = time.perf_counter()

    def addSuccess(self, test):
        super().addSuccess(test)
        elapsed = time.perf_counter() - self.start_times.get(test.id(), time.perf_counter())
        self.test_details.append({
            "id": test.id(),
            "name": test._testMethodName,
            "status": "PASS",
            "duration": round(elapsed, 4),
            "reason": None,
        })

    def addSkip(self, test, reason):
        super().addSkip(test, reason)
        elapsed = time.perf_counter() - self.start_times.get(test.id(), time.perf_counter())
        self.test_details.append({
            "id": test.id(),
            "name": test._testMethodName,
            "status": "SKIP",
            "duration": round(elapsed, 4),
            "reason": str(reason),
        })

    def addFailure(self, test, err):
        super().addFailure(test, err)
        elapsed = time.perf_counter() - self.start_times.get(test.id(), time.perf_counter())
        self.test_details.append({
            "id": test.id(),
            "name": test._testMethodName,
            "status": "FAIL",
            "duration": round(elapsed, 4),
            "reason": self._exc_info_to_string(err, test),
        })

    def addError(self, test, err):
        super().addError(test, err)
        elapsed = time.perf_counter() - self.start_times.get(test.id(), time.perf_counter())
        self.test_details.append({
            "id": test.id(),
            "name": test._testMethodName,
            "status": "ERROR",
            "duration": round(elapsed, 4),
            "reason": self._exc_info_to_string(err, test),
        })


def filter_suite(suite: unittest.TestSuite, filter_str: str) -> unittest.TestSuite:
    """Recursively filter test suite by test name substring."""
    filtered = unittest.TestSuite()
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            sub = filter_suite(item, filter_str)
            if sub.countTestCases() > 0:
                filtered.addTest(sub)
        elif isinstance(item, unittest.TestCase):
            if filter_str.lower() in item.id().lower():
                filtered.addTest(item)
    return filtered


def run_tests():
    parser = argparse.ArgumentParser(
        description="E2E Test Runner for panacea-antigravity-notch",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--tier",
        type=str,
        default="all",
        choices=["1", "2", "3", "4", "all"],
        help="Select which tier of tests to execute",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output test execution summary in JSON format",
    )
    parser.add_argument(
        "-k", "--filter",
        type=str,
        default="",
        help="Filter tests by substring in test identifier",
    )
    parser.add_argument(
        "--report",
        type=str,
        default="",
        help="Optional file path to write JSON test report",
    )

    args = parser.parse_args()

    # Determine which tiers to run
    if args.tier == "all":
        tiers_to_run = [1, 2, 3, 4]
    else:
        tiers_to_run = [int(args.tier)]

    loader = unittest.TestLoader()
    combined_suite = unittest.TestSuite()
    tier_counts = {}

    for t in tiers_to_run:
        mod_name = TIER_MODULE_MAP[t]
        try:
            tier_suite = loader.loadTestsFromName(mod_name)
            if args.filter:
                tier_suite = filter_suite(tier_suite, args.filter)
            tier_counts[f"Tier {t}"] = tier_suite.countTestCases()
            combined_suite.addTest(tier_suite)
        except Exception as e:
            print(f"Error loading {mod_name}: {e}", file=sys.stderr)
            sys.exit(1)

    total_tests = combined_suite.countTestCases()

    if not args.json:
        print("======================================================================")
        print(" panacea-antigravity-notch E2E Test Suite Runner")
        print("======================================================================")
        print(f"Target: Tiers {tiers_to_run}")
        for tier_name, count in tier_counts.items():
            print(f"  {tier_name}: {count} tests")
        print(f"Total Discovered: {total_tests} tests")
        print("----------------------------------------------------------------------")

    devnull_stream = open(os.devnull, "w")
    json_result = JsonTestResult(stream=devnull_stream, descriptions=True, verbosity=0)
    start_time = time.perf_counter()

    # Run tests with TextTestRunner for formatted terminal output if not in json-only mode
    if not args.json:
        runner = unittest.TextTestRunner(
            verbosity=2 if args.verbose else 1,
            resultclass=JsonTestResult,
        )
        res = runner.run(combined_suite)
    else:
        # In json mode, run quietly through JsonTestResult
        combined_suite.run(json_result)
        res = json_result

    duration = time.perf_counter() - start_time

    pass_count = len([t for t in res.test_details if t["status"] == "PASS"])
    skip_count = len(res.skipped)
    fail_count = len(res.failures)
    error_count = len(res.errors)

    summary_data = {
        "status": "SUCCESS" if (fail_count == 0 and error_count == 0) else "FAILURE",
        "total": total_tests,
        "passed": pass_count,
        "skipped": skip_count,
        "failed": fail_count,
        "errors": error_count,
        "duration_seconds": round(duration, 3),
        "tiers": tier_counts,
        "tests": res.test_details if args.verbose else [],
    }

    if args.report:
        report_path = Path(args.report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(summary_data, indent=2), encoding="utf-8")
        if not args.json:
            print(f"Saved test report to: {report_path}")

    if args.json:
        print(json.dumps(summary_data, indent=2))
    else:
        print("======================================================================")
        print(" Test Execution Summary")
        print("======================================================================")
        print(f" Status:   {summary_data['status']}")
        print(f" Total:    {total_tests}")
        print(f" Passed:   {pass_count}")
        print(f" Skipped:  {skip_count}")
        print(f" Failed:   {fail_count}")
        print(f" Errors:   {error_count}")
        print(f" Duration: {duration:.3f}s")
        print("======================================================================")

    exit_code = 0 if (fail_count == 0 and error_count == 0) else 1
    sys.exit(exit_code)


def load_tests(loader, standard_tests, pattern):
    """Standard unittest load_tests protocol hook for unittest discovery."""
    suite = unittest.TestSuite()
    for t in [1, 2, 3, 4]:
        mod_name = TIER_MODULE_MAP[t]
        suite.addTest(loader.loadTestsFromName(mod_name))
    return suite


if __name__ == "__main__":
    run_tests()
