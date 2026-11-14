"""Index isolated figures without changing image pixels (Pillow, NumPy, SciPy).

Generated sheets have uneven row spacing. Find complete connected silhouettes
instead of cutting a fixed grid through feet, party hats, or the following head.
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = {
    "owner_walk": (4, 4), "hosts_walk": (4, 8),
    "guests_a_walk": (4, 9), "guests_b_walk": (4, 9),
    "guests_a_emotions": (3, 9), "guests_b_emotions": (3, 9),
    "hosts_a_emotions": (3, 4), "hosts_b_emotions": (3, 4),
    "new_men_walk": (4, 9), "new_hosts_emotions": (3, 3),
    "middle_men_emotions": (3, 3), "young_men_emotions": (3, 3),
}


def index_sheet(name, columns, rows):
    im = Image.open(ROOT / "assets" / "characters" / "motion" / f"{name}.webp")
    alpha = np.array(im.getchannel("A"))
    figures, masks = [], []
    for col in range(columns):
        x0, x1 = round(col * im.width / columns), round((col + 1) * im.width / columns)
        mask = alpha[:, x0:x1] >= 100
        masks.append((x0, mask))
        labels, _ = ndimage.label(mask)
        sizes = np.bincount(labels.ravel())
        sizes[0] = 0
        objects = ndimage.find_objects(labels)
        largest = np.argsort(sizes)[-rows:]
        if not all(sizes[i] > 1000 for i in largest):
            figures.append(None)
            continue
        boxes = []
        for i in largest:
            yy, xx = objects[i - 1]
            boxes.append((x0 + xx.start, yy.start, xx.stop - xx.start, yy.stop - yy.start))
        figures.append(sorted(boxes, key=lambda box: box[1]))
    # If two silhouettes touch, use a clean column's row gaps and split only
    # that column at the narrowest alpha section near each expected gap.
    reference = next((boxes for boxes in figures if boxes is not None), None)
    assert reference is not None, (name, "No clean column")
    for col, boxes in enumerate(figures):
        if boxes is not None:
            continue
        x0, mask = masks[col]
        cuts = [0]
        projection = mask.sum(axis=1)
        for previous, following in zip(reference, reference[1:]):
            target = (previous[1] + previous[3] + following[1]) // 2
            candidates = range(max(cuts[-1] + 1, target - 8), min(im.height, target + 9))
            cuts.append(min(candidates, key=lambda y: projection[y] + abs(y - target) * 0.5))
        cuts.append(im.height)
        boxes = []
        for y0, y1 in zip(cuts, cuts[1:]):
            labels, _ = ndimage.label(mask[y0:y1])
            sizes = np.bincount(labels.ravel())
            sizes[0] = 0
            yy, xx = ndimage.find_objects(labels)[int(sizes.argmax()) - 1]
            boxes.append((x0 + xx.start, y0 + yy.start, xx.stop - xx.start, yy.stop - yy.start))
        figures[col] = boxes
    regions, canvases = [], []
    for row in range(rows):
        boxes = [figures[col][row] for col in range(columns)]
        canvases.append(f"Vector2({max(b[2] for b in boxes)}, {max(b[3] for b in boxes)})")
        regions.extend("Rect2(%d, %d, %d, %d)" % box for box in boxes)
    return regions, canvases


if __name__ == "__main__":
    regions, canvases = [], []
    for name, (columns, rows) in LAYOUT.items():
        rr, cc = index_sheet(name, columns, rows)
        regions.append(f'\t"{name}": [{", ".join(rr)}],')
        canvases.append(f'\t"{name}": [{", ".join(cc)}],')
    target = ROOT / "scripts" / "ui" / "character_motion.gd"
    source = target.read_text()
    start = source.index("const REGIONS:")
    end = source.index("static var _cache:")
    constants = "const REGIONS: Dictionary = {\n" + "\n".join(regions) + "\n}\n\n"
    constants += "const CANVAS_SIZES: Dictionary = {\n" + "\n".join(canvases) + "\n}\n\n"
    target.write_text(source[:start] + constants + source[end:])
    print("Indexed", sum(c * r for c, r in LAYOUT.values()), "complete animation and expression figures")
