#!/usr/bin/env python3
"""
Pick a color scheme based on the colorfulness of an image.

CREDITS: END 4 DOTFILES
"""

import argparse
import sys
import cv2
import numpy as np
from pathlib import Path
from typing import Optional

# Allowed scheme types
SCHEMES: list[str] = [
    "scheme-content",
    "scheme-expressive",
    "scheme-fidelity",
    "scheme-fruit-salad",
    "scheme-monochrome",
    "scheme-neutral",
    "scheme-rainbow",
    "scheme-tonal-spot",
]

# Colorfulness thresholds
LOW_COLORFULNESS = 10
MEDIUM_COLORFULNESS = 20
HIGH_COLORFULNESS = 40


def image_colorfulness(image: np.ndarray) -> float:
    """
    Calculate the colorfulness of an image using Hasler and Süsstrunk's metric.
    """
    B, G, R = cv2.split(image.astype("float"))
    rg = np.abs(R - G)
    yb = np.abs(0.5 * (R + G) - B)

    std_rg, std_yb = np.std(rg), np.std(yb)
    mean_rg, mean_yb = np.mean(rg), np.mean(yb)

    return np.sqrt(std_rg**2 + std_yb**2) + (0.3 * np.sqrt(mean_rg**2 + mean_yb**2))


def pick_scheme(colorfulness: float) -> str:
    """
    scheme-content respects the image's colors very well, but it might
    look too saturated, so we only use it for not very colorful images to be safe
    """
    if colorfulness < LOW_COLORFULNESS:
        return "scheme-content"
    elif colorfulness < MEDIUM_COLORFULNESS:
        return "scheme-content"
    elif colorfulness < HIGH_COLORFULNESS:
        return "scheme-neutral"
    else:
        return "scheme-tonal-spot"


def load_image(path: Path, max_size: int = 800) -> Optional[np.ndarray]:
    """
    Load an image from the given path.
    Optionally resize it so the largest dimension is <= max_size to speed up processing.
    """
    img = cv2.imread(str(path))
    if img is None:
        return None
    h, w = img.shape[:2]
    if max(h, w) > max_size:
        scale = max_size / max(h, w)
        img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    return img


def main() -> None:
    parser = argparse.ArgumentParser(description="Pick a color scheme based on image colorfulness.")
    parser.add_argument("image", type=Path, help="Path to the image file.")
    parser.add_argument(
        "--colorfulness",
        action="store_true",
        help="Output only the numeric colorfulness value.",
    )

    args = parser.parse_args()

    if not args.image.is_file():
        print("scheme-tonal-spot", file=sys.stderr)
        sys.exit(1)

    img = load_image(args.image)
    if img is None:
        print("scheme-tonal-spot", file=sys.stderr)
        sys.exit(1)

    colorfulness = image_colorfulness(img)

    if args.colorfulness:
        print(f"{colorfulness:.2f}")
    else:
        scheme = pick_scheme(colorfulness)
        if scheme not in SCHEMES:
            print("scheme-tonal-spot", file=sys.stderr)
            sys.exit(1)
        print(scheme)


if __name__ == "__main__":
    main()
