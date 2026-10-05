#!/usr/bin/env python3
"""Generate an image through the public Hugging Face FLUX.1-schnell Space."""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

USER_SITE = Path.home() / "AppData" / "Roaming" / "Python" / "Python312" / "site-packages"
if USER_SITE.exists() and str(USER_SITE) not in sys.path:
    sys.path.insert(0, str(USER_SITE))

try:
    from gradio_client import Client
except ImportError as exc:
    raise SystemExit("需要 gradio_client：python -m pip install gradio_client") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate via HF FLUX.1-schnell Space")
    parser.add_argument("--prompt-file", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=1024)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--steps", type=int, default=4)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    prompt = Path(args.prompt_file).read_text(encoding="utf-8").strip()
    if not prompt:
        raise SystemExit("prompt file is empty")
    if args.width < 256 or args.width > 2048 or args.height < 256 or args.height > 2048:
        raise SystemExit("FLUX Space 尺寸范围为 256-2048")
    if args.dry_run:
        print({"prompt_file": args.prompt_file, "out": args.out, "size": [args.width, args.height], "seed": args.seed, "steps": args.steps})
        return 0

    client = Client("black-forest-labs/FLUX.1-schnell", verbose=False)
    result, _seed = client.predict(
        prompt=prompt,
        seed=args.seed,
        randomize_seed=False,
        width=args.width,
        height=args.height,
        num_inference_steps=args.steps,
        api_name="/infer",
    )
    source_value = result.get("path") if isinstance(result, dict) else result
    if not source_value:
        raise SystemExit(f"FLUX Space 未返回图片：{result}")
    source = Path(source_value)
    target = Path(args.out)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    print(f"FLUX_SAVED={target.resolve()}")
    print(f"FLUX_SIZE={args.width}x{args.height} seed={args.seed} steps={args.steps}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
