# -*- coding: utf-8 -*-
"""Yuvarlak siluetleri elle ASCII yazmak yerine geometriyle uret."""

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [['.'] * w for _ in range(h)]

    def put(self, x, y, ch):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return '.'

    def ellipse(self, cx, cy, rx, ry, ch='b', only_empty=False):
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    if only_empty and self.g[y][x] != '.':
                        continue
                    self.put(x, y, ch)

    def rect(self, x0, y0, x1, y1, ch='b'):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, ch)

    def tri_ear(self, x, y, w=3, h=3, fill='b', inner='p'):
        """Ucgen kulak: taban (x..x+w-1, y+h-1), tepe ortada."""
        for i in range(h):
            half = max(1, int(round(w * (i + 1) / h)))
            x0 = x + (w - half) // 2
            for dx in range(half):
                self.put(x0 + dx, y + i, fill)
        if h >= 3 and w >= 3:
            self.put(x + w // 2, y + h - 1, inner)
            self.put(x + w // 2, y + h - 2, inner)

    def arc_band(self, cx, cy, rx, ry, thick=2, ch='d', y_min=None):
        """Halka dilimi: kuyruk bandi icin."""
        for y in range(self.h):
            for x in range(self.w):
                if y_min is not None and y < y_min:
                    continue
                d1 = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                d2 = ((x - cx) / (rx - thick)) ** 2 + ((y - cy) / max(0.5, ry - thick)) ** 2
                if d1 <= 1.0 and d2 > 1.0:
                    self.put(x, y, ch)

    def outline(self, ch='o'):
        """Dolu piksellerin dis kenarina kontur cek (siluetin disina)."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.g[y][x] != '.':
                    continue
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    if self.get(x + dx, y + dy) not in ('.', ch):
                        add.append((x, y)); break
        for x, y in add:
            self.put(x, y, ch)

    def rows(self):
        return [''.join(r) for r in self.g]
