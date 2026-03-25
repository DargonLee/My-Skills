#!/usr/bin/env python3
"""Generate project scaffolds from bundled skill templates."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List


TOKEN_PATTERN = re.compile(r"{{\s*([a-zA-Z0-9_]+)\s*}}")
ACRONYM_BOUNDARY_PATTERN = re.compile(r"([A-Z]+)([A-Z][a-z])")
CAMEL_BOUNDARY_PATTERN = re.compile(r"([a-z0-9])([A-Z])")


@dataclass(frozen=True)
class TemplateManifest:
    id: str
    platform: str
    kind: str
    display_name: str
    description: str
    source_dir: str
    target_dir_template: str
    rename_tokens: Dict[str, str]
    content_tokens: Dict[str, str]
    ignore_names: List[str]
    manifest_path: Path

    @property
    def base_dir(self) -> Path:
        return self.manifest_path.parent

    @property
    def source_path(self) -> Path:
        return self.base_dir / self.source_dir


def skill_root() -> Path:
    return Path(__file__).resolve().parents[1]


def templates_root() -> Path:
    return skill_root() / "assets" / "templates"


def parse_key_value_pairs(pairs: Iterable[str]) -> Dict[str, str]:
    values: Dict[str, str] = {}
    for raw in pairs:
        if "=" not in raw:
            raise ValueError(f"Invalid --var value: {raw!r}. Expected key=value.")
        key, value = raw.split("=", 1)
        key = key.strip()
        if not key:
            raise ValueError(f"Invalid --var value: {raw!r}. Key cannot be empty.")
        values[key] = value
    return values


def word_delimited(value: str, separator: str) -> str:
    normalized = value.replace("-", "_")
    normalized = re.sub(r"[\s_]+", "_", normalized)
    normalized = ACRONYM_BOUNDARY_PATTERN.sub(r"\1_\2", normalized)
    normalized = CAMEL_BOUNDARY_PATTERN.sub(r"\1_\2", normalized)
    normalized = re.sub(r"_+", "_", normalized).strip("_")
    return normalized.replace("_", separator).lower()


def kebab_case(value: str) -> str:
    return word_delimited(value, "-")


def snake_case(value: str) -> str:
    return word_delimited(value, "_")


def build_variables(module_name: str, extra_vars: Dict[str, str]) -> Dict[str, str]:
    variables = {
        "module_name": module_name,
        "module_name_kebab": kebab_case(module_name),
        "module_name_snake": snake_case(module_name),
        "module_name_lower": module_name.lower(),
        "module_name_upper": module_name.upper(),
    }
    variables.update(extra_vars)
    return variables


def render_template(value: str, variables: Dict[str, str]) -> str:
    def replace(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in variables:
            raise KeyError(f"Unknown template variable: {key}")
        return variables[key]

    return TOKEN_PATTERN.sub(replace, value)


def load_manifest(path: Path) -> TemplateManifest:
    raw = json.loads(path.read_text(encoding="utf-8"))
    required_keys = {
        "id",
        "platform",
        "kind",
        "display_name",
        "description",
        "source_dir",
        "target_dir_template",
        "rename_tokens",
        "content_tokens",
    }
    missing = sorted(required_keys - raw.keys())
    if missing:
        raise ValueError(f"Manifest {path} is missing required keys: {', '.join(missing)}")

    return TemplateManifest(
        id=raw["id"],
        platform=raw["platform"],
        kind=raw["kind"],
        display_name=raw["display_name"],
        description=raw["description"],
        source_dir=raw["source_dir"],
        target_dir_template=raw["target_dir_template"],
        rename_tokens=raw["rename_tokens"],
        content_tokens=raw["content_tokens"],
        ignore_names=raw.get("ignore_names", []),
        manifest_path=path,
    )


def discover_manifests() -> List[TemplateManifest]:
    manifests = [
        load_manifest(path)
        for path in sorted(templates_root().glob("*/manifest.json"))
    ]
    return manifests


def manifest_map() -> Dict[str, TemplateManifest]:
    manifests = discover_manifests()
    mapping = {manifest.id: manifest for manifest in manifests}
    if len(mapping) != len(manifests):
        raise ValueError("Duplicate template ids detected in manifest files.")
    return mapping


def render_token_map(token_map: Dict[str, str], variables: Dict[str, str]) -> Dict[str, str]:
    return {
        token: render_template(template_value, variables)
        for token, template_value in token_map.items()
    }


def ensure_manifest_ready(manifest: TemplateManifest) -> None:
    if not manifest.source_path.exists():
        raise FileNotFoundError(
            f"Template source directory does not exist: {manifest.source_path}"
        )


def copy_template_tree(source: Path, destination: Path, ignore_names: List[str]) -> None:
    def ignore(_current_dir: str, names: List[str]) -> List[str]:
        return [name for name in names if name in ignore_names]

    shutil.copytree(source, destination, ignore=ignore)


def rename_paths(root: Path, replacements: Dict[str, str]) -> None:
    items = sorted(root.rglob("*"), key=lambda path: len(path.parts), reverse=True)
    for item in items:
        new_name = item.name
        for old, new in replacements.items():
            new_name = new_name.replace(old, new)
        if new_name == item.name:
            continue
        item.rename(item.with_name(new_name))


def replace_file_content(file_path: Path, replacements: Dict[str, str]) -> None:
    try:
        original_text = file_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        original_bytes = file_path.read_bytes()
        updated_bytes = original_bytes
        for old, new in replacements.items():
            updated_bytes = updated_bytes.replace(old.encode("utf-8"), new.encode("utf-8"))
        if updated_bytes != original_bytes:
            file_path.write_bytes(updated_bytes)
        return

    updated_text = original_text
    for old, new in replacements.items():
        updated_text = updated_text.replace(old, new)
    if updated_text != original_text:
        file_path.write_text(updated_text, encoding="utf-8")


def replace_tree_content(root: Path, replacements: Dict[str, str]) -> None:
    for file_path in root.rglob("*"):
        if file_path.is_file():
            replace_file_content(file_path, replacements)


def list_templates(as_json: bool) -> int:
    manifests = discover_manifests()
    if as_json:
        payload = [
            {
                "id": manifest.id,
                "platform": manifest.platform,
                "kind": manifest.kind,
                "display_name": manifest.display_name,
                "description": manifest.description,
            }
            for manifest in manifests
        ]
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0

    if not manifests:
        print("No bundled templates found.")
        return 1

    for manifest in manifests:
        print(f"{manifest.id}: {manifest.display_name} [{manifest.platform}/{manifest.kind}]")
        print(f"  {manifest.description}")
    return 0


def generate_template(template_id: str, module_name: str, output_dir: Path, extra_vars: Dict[str, str]) -> int:
    manifests = manifest_map()
    if template_id not in manifests:
        available = ", ".join(sorted(manifests))
        print(f"Unknown template id: {template_id}", file=sys.stderr)
        print(f"Available templates: {available or 'none'}", file=sys.stderr)
        return 1

    manifest = manifests[template_id]
    ensure_manifest_ready(manifest)

    variables = build_variables(module_name, extra_vars)
    rename_replacements = render_token_map(manifest.rename_tokens, variables)
    content_replacements = render_token_map(manifest.content_tokens, variables)

    output_dir = output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    target_dir = output_dir / render_template(manifest.target_dir_template, variables)

    if target_dir.exists():
        print(f"Target directory already exists: {target_dir}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix=f"{template_id}-") as temp_dir:
        temp_root = Path(temp_dir) / "project"
        copy_template_tree(manifest.source_path, temp_root, manifest.ignore_names)
        rename_paths(temp_root, rename_replacements)
        replace_tree_content(temp_root, content_replacements)
        shutil.move(str(temp_root), str(target_dir))

    print(f"Generated {manifest.display_name}: {target_dir}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate project scaffolds from bundled skill templates."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List bundled templates")
    list_parser.add_argument("--json", action="store_true", help="Output machine-readable JSON")

    generate_parser = subparsers.add_parser("generate", help="Generate a scaffold from a template")
    generate_parser.add_argument("--template", required=True, help="Template id, for example ios-pod")
    generate_parser.add_argument("--module-name", required=True, help="Module name to inject into the template")
    generate_parser.add_argument("--output", required=True, help="Output directory for the generated scaffold")
    generate_parser.add_argument(
        "--var",
        action="append",
        default=[],
        help="Extra variable in key=value form. Repeat for multiple values.",
    )

    return parser


def main(argv: List[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "list":
        return list_templates(as_json=args.json)

    if args.command == "generate":
        try:
            extra_vars = parse_key_value_pairs(args.var)
            return generate_template(
                template_id=args.template,
                module_name=args.module_name,
                output_dir=Path(args.output),
                extra_vars=extra_vars,
            )
        except (ValueError, KeyError, FileNotFoundError) as exc:
            print(str(exc), file=sys.stderr)
            return 1

    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
