#!/usr/bin/env python3
"""Tests for the storage benchmark RESULT summarizer."""

import importlib.util
import io
import pathlib
import sys
import unittest


SCRIPT_PATH = pathlib.Path(__file__).with_name("summarize-storage-benchmark.py")


class SummarizeStorageBenchmarkTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("summarize_storage_benchmark", SCRIPT_PATH)
        cls.module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = cls.module
        spec.loader.exec_module(cls.module)

    def test_aggregates_result_rows_by_backend_and_profile(self):
        rows = self.module.parse_result_lines(
            [
                "ignored log line\n",
                "RESULT,mayastor,rand-write-4k,1,100,200,10,20,1,2,3,4,5,6,7,8,0\n",
                "RESULT,mayastor,rand-write-4k,2,300,400,30,40,2,3,4,5,7,9,11,13,2\n",
                "RESULT,piraeus,rand-write-4k,1,50,60,5,6,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1\n",
            ]
        )

        table = self.module.render_markdown_table(rows)

        self.assertIn(
            "| backend | profile | passes | read_iops_avg | write_iops_avg | read_mib_s_avg | write_mib_s_avg | read_p99_ms_avg | write_p99_ms_avg | read_p999_ms_avg | write_p999_ms_avg | errors_total |",
            table,
        )
        self.assertIn(
            "| mayastor | rand-write-4k | 2 | 200.00 | 300.00 | 20.00 | 30.00 | 6.00 | 7.50 | 9.00 | 10.50 | 2 |",
            table,
        )
        self.assertIn(
            "| piraeus | rand-write-4k | 1 | 50.00 | 60.00 | 5.00 | 6.00 | 0.90 | 1.00 | 1.10 | 1.20 | 1 |",
            table,
        )

    def test_rejects_malformed_result_rows(self):
        with self.assertRaisesRegex(ValueError, "wrong number of fields"):
            self.module.parse_result_lines(["RESULT,mayastor,rand-write-4k,1\n"])

    def test_main_reports_missing_log_file_without_traceback(self):
        stdout = io.StringIO()
        stderr = io.StringIO()

        exit_code = self.module.main(["/no/such/storage-benchmark.log"], stdout=stdout, stderr=stderr)

        self.assertEqual(1, exit_code)
        self.assertEqual("", stdout.getvalue())
        self.assertIn("/no/such/storage-benchmark.log", stderr.getvalue())
        self.assertNotIn("Traceback", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
