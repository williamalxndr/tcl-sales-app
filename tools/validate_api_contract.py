"""Validate OpenAPI, example schemas, documentation parity and backend route coverage."""

import ast
import json
import re
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator, FormatChecker
from openapi_spec_validator import validate_spec

ROOT = Path(__file__).resolve().parents[1]
spec = yaml.safe_load((ROOT / "docs/openapi.yaml").read_text())
validate_spec(spec)
document = (ROOT / "docs/API_DESIGN.md").read_text()
md_examples = [
    json.loads(body) for body in re.findall(r"```json\n(.*?)\n```", document, re.S)
]
examples = 0


def validate(value, schema, require_document=True):
    global examples
    combined = {**schema, "components": spec["components"]}
    Draft202012Validator(combined, format_checker=FormatChecker()).validate(value)
    if require_document:
        assert value in md_examples, "OpenAPI example missing from API_DESIGN.md"
    examples += 1


operations = set()
for path, item in spec["paths"].items():
    operations.add(path)
    for method, operation in item.items():
        assert f"`{method.upper()} /api/v1{path}`" in document
        for status, response in operation["responses"].items():
            if "$ref" in response:
                continue
            for body in response.get("content", {}).values():
                if "example" in body:
                    validate(body["example"], body["schema"], status.startswith("2"))
                for example in body.get("examples", {}).values():
                    validate(example["value"], body["schema"])
        for body in operation.get("requestBody", {}).get("content", {}).values():
            if "example" in body:
                validate(body["example"], body["schema"])

urls = ast.parse((ROOT / "backend/config/urls.py").read_text())
routes = set()
for node in ast.walk(urls):
    if (
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id == "path"
    ):
        route = ast.literal_eval(node.args[0])
        if route.startswith("api/v1/"):
            routes.add(
                "/" + re.sub(r"<str:(\w+)>", r"{\1}", route.removeprefix("api/v1/"))
            )
assert routes == operations, f"Route/spec mismatch: {routes ^ operations}"
print(
    f"Validated {sum(len(item) for item in spec['paths'].values())} operations, {examples} examples, documentation and route coverage."
)
