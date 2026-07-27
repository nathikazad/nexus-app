#!/usr/bin/env python3
"""Command-line interface for compiling and importing book summaries."""

from __future__ import annotations

import argparse
from dataclasses import asdict
import json
from pathlib import Path
import sys

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    from importer.book_importer import (  # type: ignore
        BookImporter,
        BookPackageCompiler,
        DEFAULT_BACKUP_SCRIPT,
        DEFAULT_BACKUP_TARGET,
        DEFAULT_DOMAIN_ID,
        DEFAULT_GRAPHQL_URL,
        DEFAULT_NEXUS_MOBILE,
        DEFAULT_USER_ID,
        FlutterMarkdownConverter,
        GraphQLKgqlClient,
        ImporterError,
        SubprocessBackupRunner,
    )
else:
    from .book_importer import (
        BookImporter,
        BookPackageCompiler,
        DEFAULT_BACKUP_SCRIPT,
        DEFAULT_BACKUP_TARGET,
        DEFAULT_DOMAIN_ID,
        DEFAULT_GRAPHQL_URL,
        DEFAULT_NEXUS_MOBILE,
        DEFAULT_USER_ID,
        FlutterMarkdownConverter,
        GraphQLKgqlClient,
        ImporterError,
        SubprocessBackupRunner,
    )


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="book-summaries")
    subcommands = parser.add_subparsers(dest="command", required=True)

    compile_parser = subcommands.add_parser(
        "compile",
        help="Compile book.json and chapter Markdown into kgql-import.json.",
    )
    compile_parser.add_argument("package_directory", type=Path)
    compile_parser.add_argument("--output-directory", type=Path)
    compile_parser.add_argument(
        "--nexus-mobile", type=Path, default=DEFAULT_NEXUS_MOBILE
    )
    compile_parser.add_argument("--flutter", type=Path)

    import_parser = subcommands.add_parser(
        "import",
        help="Dry-run or execute a compiled KGQL import manifest.",
    )
    import_parser.add_argument("manifest", type=Path)
    mode = import_parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--execute", action="store_true")
    import_parser.add_argument("--resume", action="store_true")
    import_parser.add_argument("--receipt", type=Path)
    import_parser.add_argument("--graphql-url", default=DEFAULT_GRAPHQL_URL)
    import_parser.add_argument("--user-id", default=DEFAULT_USER_ID)
    import_parser.add_argument("--domain-id", type=int, default=DEFAULT_DOMAIN_ID)
    import_parser.add_argument(
        "--backup-script", type=Path, default=DEFAULT_BACKUP_SCRIPT
    )
    import_parser.add_argument("--backup-target", default=DEFAULT_BACKUP_TARGET)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.command == "compile":
        compiler = BookPackageCompiler(
            FlutterMarkdownConverter(
                nexus_mobile=args.nexus_mobile,
                flutter=args.flutter,
            )
        )
        manifest = compiler.compile(
            args.package_directory,
            args.output_directory,
        )
        print(manifest)
        return 0

    client = GraphQLKgqlClient(
        url=args.graphql_url,
        user_id=args.user_id,
        domain_id=args.domain_id,
    )
    manifest_path = args.manifest.expanduser().resolve()
    manifest = BookImporter.load_manifest(manifest_path)
    if args.dry_run:
        plan = BookImporter(client).plan(manifest)
        print(json.dumps(asdict(plan), ensure_ascii=False, indent=2))
        return 0
    receipt = args.receipt or manifest_path.with_name("kgql-import.receipt.json")
    importer = BookImporter(
        client,
        SubprocessBackupRunner(
            script=args.backup_script,
            target=args.backup_target,
        ),
    )
    result = importer.execute(
        manifest,
        receipt.expanduser().resolve(),
        resume=args.resume,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ImporterError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
