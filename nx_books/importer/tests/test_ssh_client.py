from __future__ import annotations

import json
import subprocess
import unittest
from unittest.mock import patch

from importer.book_importer import ImporterError, SshGraphQLKgqlClient


class SshGraphQLKgqlClientTest(unittest.TestCase):
    def test_defaults_relay_as_user_one_in_domain_one(self) -> None:
        response = {"data": {"getKgqlModelType": [{"name": "Book"}]}}
        with patch("importer.book_importer.subprocess.run") as run:
            run.return_value = subprocess.CompletedProcess(
                args=[], returncode=0, stdout=json.dumps(response), stderr=""
            )
            client = SshGraphQLKgqlClient()
            result = client.get_model_type("Book")

        self.assertEqual(result, [{"name": "Book"}])
        self.assertEqual(client.domain_id, 1)
        argv = run.call_args.args[0]
        self.assertIn("hetzner-personal", argv)
        self.assertTrue(argv[-1].endswith(" 1"))
        self.assertNotIn("x-nexus-internal-secret", argv[:-1])
        request = json.loads(run.call_args.kwargs["input"])
        self.assertEqual(request["variables"]["input"], {"model_types": ["Book"]})

    def test_rejects_option_like_ssh_target(self) -> None:
        with self.assertRaisesRegex(ImporterError, "Invalid SSH target"):
            SshGraphQLKgqlClient(ssh_target="-oProxyCommand=bad")

    def test_reports_ssh_failure_without_parsing_output(self) -> None:
        with patch("importer.book_importer.subprocess.run") as run:
            run.return_value = subprocess.CompletedProcess(
                args=[], returncode=255, stdout="", stderr="connection failed"
            )
            with self.assertRaisesRegex(ImporterError, "connection failed"):
                SshGraphQLKgqlClient().get_model_type("Book")

    def test_reports_timeout_as_importer_error(self) -> None:
        with patch(
            "importer.book_importer.subprocess.run",
            side_effect=subprocess.TimeoutExpired("ssh", 45),
        ):
            with self.assertRaisesRegex(ImporterError, "timed out"):
                SshGraphQLKgqlClient().get_model_type("Book")


if __name__ == "__main__":
    unittest.main()
