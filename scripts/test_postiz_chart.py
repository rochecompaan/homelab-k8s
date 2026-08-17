import re
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHART = ROOT / "argocd/homelab/postiz/chart"


class PostizChartTest(unittest.TestCase):
    def render(self, *values: str) -> str:
        command = [
            "helm",
            "template",
            "postiz",
            str(CHART),
            "--namespace",
            "postiz",
        ]
        for value in values:
            command.extend(["--set", value])
        return subprocess.run(
            command,
            check=True,
            cwd=ROOT,
            text=True,
            capture_output=True,
        ).stdout

    def documents(self, rendered: str) -> list[str]:
        return [
            document
            for document in re.split(r"^---\s*$", rendered, flags=re.MULTILINE)
            if document.strip()
        ]

    def manifest(self, rendered: str, kind: str, name: str) -> str:
        for document in self.documents(rendered):
            if re.search(rf"^kind: {re.escape(kind)}$", document, re.MULTILINE):
                if re.search(rf"^  name: {re.escape(name)}$", document, re.MULTILINE):
                    return document
        self.fail(f"missing {kind} {name}")

    def test_default_render_is_postiz_only_and_pinned(self) -> None:
        rendered = self.render()
        deployment = self.manifest(rendered, "Deployment", "postiz-postiz-app")
        self.assertIn("ghcr.io/gitroomhq/postiz-app:v2.23.0", deployment)
        self.assertNotIn("bitnami/", rendered)
        self.assertNotIn("bitnamilegacy/", rendered)
        self.assertFalse(
            any(
                re.search(r"^kind: StatefulSet$", document, re.MULTILINE)
                for document in self.documents(rendered)
            )
        )

    def test_default_secret_path_remains_available(self) -> None:
        rendered = self.render()
        self.manifest(rendered, "Secret", "postiz-postiz-app-secrets")
        deployment = self.manifest(rendered, "Deployment", "postiz-postiz-app")
        self.assertRegex(
            deployment,
            r"secretRef:\s+name: postiz-postiz-app-secrets",
        )

    def test_external_secret_strategy_and_probes(self) -> None:
        rendered = self.render(
            "existingSecret=postiz-secrets",
            "strategy.type=Recreate",
            "startupProbe.httpGet.path=/",
            "startupProbe.httpGet.port=http",
            "readinessProbe.httpGet.path=/",
            "readinessProbe.httpGet.port=http",
            "livenessProbe.httpGet.path=/",
            "livenessProbe.httpGet.port=http",
        )
        application_secrets = [
            document
            for document in self.documents(rendered)
            if re.search(r"^kind: Secret$", document, re.MULTILINE)
            and re.search(
                r"^  name: postiz-postiz-app-secrets$",
                document,
                re.MULTILINE,
            )
        ]
        self.assertEqual([], application_secrets)

        deployment = self.manifest(rendered, "Deployment", "postiz-postiz-app")
        self.assertRegex(deployment, r"secretRef:\s+name: postiz-secrets")
        self.assertRegex(deployment, r"strategy:\s+type: Recreate")
        self.assertIn("startupProbe:", deployment)
        self.assertIn("readinessProbe:", deployment)
        self.assertIn("livenessProbe:", deployment)


if __name__ == "__main__":
    unittest.main()
