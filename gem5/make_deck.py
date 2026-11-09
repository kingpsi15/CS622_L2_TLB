#!/usr/bin/env python3
"""Generates the mid-review deck from REAL data (results_v2/results.json).
Run inside WSL:  python3 make_deck.py
"""
import json, os, copy
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.chart.data import CategoryChartData
from pptx.enum.chart import XL_CHART_TYPE, XL_LEGEND_POSITION, XL_LABEL_POSITION
from pptx.oxml.ns import qn
from lxml import etree

HERE = os.path.dirname(os.path.abspath(__file__))
RES = json.load(open(os.path.expanduser("~/gem5/results_v2/results.json")))
OUTDIR = os.path.expanduser("~/gem5/presentation")
os.makedirs(OUTDIR, exist_ok=True)

# ------------------------------------------------------------------ theme
BG     = RGBColor(0x0B, 0x10, 0x20)
PANEL  = RGBColor(0x15, 0x1C, 0x30)
PANEL2 = RGBColor(0x1C, 0x25, 0x3D)
CODEBG = RGBColor(0x0D, 0x13, 0x22)
LINE   = RGBColor(0x2A, 0x36, 0x55)
TEXT   = RGBColor(0xE5, 0xE7, 0xEB)
MUTED  = RGBColor(0x94, 0xA3, 0xB8)
CYAN   = RGBColor(0x22, 0xD3, 0xEE)
VIOLET = RGBColor(0xA7, 0x8B, 0xFA)
AMBER  = RGBColor(0xFB, 0xBF, 0x24)
GREEN  = RGBColor(0x34, 0xD3, 0x99)
ROSE   = RGBColor(0xFB, 0x71, 0x85)
BLUE   = RGBColor(0x60, 0xA5, 0xFA)
FONT, MONO = "Segoe UI", "Consolas"

prs = Presentation()
prs.slide_width, prs.slide_height = Inches(13.333), Inches(7.5)
BLANK = prs.slide_layouts[6]
W, H = prs.slide_width, prs.slide_height
_slide_no = [0]


def _fill(shape, color):
    shape.fill.solid(); shape.fill.fore_color.rgb = color


def text(slide, x, y, w, h, content, size=16, color=TEXT, bold=False, align=PP_ALIGN.LEFT,
         font=FONT, anchor=MSO_ANCHOR.TOP, spacing=1.1):
    """content: str or list of paragraphs; each paragraph str or list of (txt, {opts}) runs.
    '**x**' inside a str makes x bold+cyan."""
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame; tf.word_wrap = True
    tf.margin_left = tf.margin_right = Inches(0.05); tf.margin_top = tf.margin_bottom = Inches(0.02)
    tf.vertical_anchor = anchor
    paras = content if isinstance(content, list) else [content]
    for i, p in enumerate(paras):
        para = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        para.alignment = align; para.line_spacing = spacing
        runs = p if isinstance(p, list) else _md(p)
        for t, o in runs:
            r = para.add_run(); r.text = t
            r.font.name = o.get("font", font); r.font.size = Pt(o.get("size", size))
            r.font.bold = o.get("bold", bold); r.font.color.rgb = o.get("color", color)
            r.font.italic = o.get("italic", False)
    return tb


def _md(s):
    out, parts = [], s.split("**")
    for i, part in enumerate(parts):
        if part:
            out.append((part, {"bold": True, "color": CYAN} if i % 2 else {}))
    return out


def bullets(slide, x, y, w, h, items, size=15, color=TEXT, gap=6, bullet_color=CYAN):
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame; tf.word_wrap = True
    for i, it in enumerate(items):
        lvl = 0
        if isinstance(it, tuple): it, lvl = it
        para = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        para.space_after = Pt(gap); para.line_spacing = 1.08
        mark = "▸ " if lvl == 0 else "– "
        r = para.add_run(); r.text = ("      " * lvl) + mark
        r.font.size = Pt(size - 2 * lvl); r.font.color.rgb = bullet_color if lvl == 0 else MUTED
        r.font.name = FONT; r.font.bold = True
        for t, o in _md(it):
            rr = para.add_run(); rr.text = t; rr.font.name = FONT
            rr.font.size = Pt(size - 2 * lvl); rr.font.bold = o.get("bold", False)
            rr.font.color.rgb = o.get("color", color if lvl == 0 else MUTED)
    return tb


def box(slide, x, y, w, h, fill=PANEL, line=LINE, radius=0.08, shape=MSO_SHAPE.ROUNDED_RECTANGLE):
    s = slide.shapes.add_shape(shape, x, y, w, h)
    _fill(s, fill)
    if line is None: s.line.fill.background()
    else: s.line.color.rgb = line; s.line.width = Pt(1)
    if shape == MSO_SHAPE.ROUNDED_RECTANGLE:
        s.adjustments[0] = radius
    s.shadow.inherit = False
    s.text_frame.text = ""
    return s


def label_box(slide, x, y, w, h, title, body=None, fill=PANEL, accent=CYAN, tsize=15, bsize=12,
              align=PP_ALIGN.CENTER):
    b = box(slide, x, y, w, h, fill=fill, line=accent)
    tf = b.text_frame; tf.word_wrap = True; tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf.margin_left = tf.margin_right = Inches(0.08)
    p = tf.paragraphs[0]; p.alignment = align
    r = p.add_run(); r.text = title; r.font.size = Pt(tsize); r.font.bold = True
    r.font.color.rgb = accent; r.font.name = FONT
    if body:
        for line in body.split("\n"):
            p2 = tf.add_paragraph(); p2.alignment = align
            r2 = p2.add_run(); r2.text = line; r2.font.size = Pt(bsize)
            r2.font.color.rgb = TEXT; r2.font.name = FONT
    return b


def arrow(slide, x1, y1, x2, y2, color=MUTED, width=2):
    c = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, x1, y1, x2, y2)
    c.line.color.rgb = color; c.line.width = Pt(width)
    ln = c.line._get_or_add_ln()
    tail = etree.SubElement(ln, qn("a:tailEnd")); tail.set("type", "triangle")
    tail.set("w", "med"); tail.set("len", "med")
    return c


def code(slide, x, y, w, h, src, title=None, size=10.5):
    b = box(slide, x, y, w, h, fill=CODEBG, line=LINE, radius=0.03)
    top = y
    if title:
        bar = box(slide, x, y, w, Inches(0.32), fill=PANEL2, line=LINE, radius=0.15)
        for i, c in enumerate([ROSE, AMBER, GREEN]):
            d = slide.shapes.add_shape(MSO_SHAPE.OVAL, x + Inches(0.12 + 0.18 * i), y + Inches(0.1),
                                       Inches(0.11), Inches(0.11))
            _fill(d, c); d.line.fill.background()
        text(slide, x + Inches(0.7), y + Inches(0.02), w - Inches(0.8), Inches(0.3), title,
             size=10.5, color=MUTED, font=MONO)
        top = y + Inches(0.34)
    tb = slide.shapes.add_textbox(x + Inches(0.1), top + Inches(0.04), w - Inches(0.2), h - (top - y) - Inches(0.08))
    tf = tb.text_frame; tf.word_wrap = True
    for i, line in enumerate(src.strip("\n").split("\n")):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.line_spacing = 1.0
        stripped = line.strip()
        col = TEXT
        if stripped.startswith("//") or stripped.startswith("#"): col = RGBColor(0x6B, 0x7F, 0x99)
        r = p.add_run(); r.text = line if line else " "
        r.font.name = MONO; r.font.size = Pt(size); r.font.color.rgb = col
        # highlight markers
        if "// <<" in line:
            r.text = line.replace("// <<", "//")
            r.font.color.rgb = AMBER; r.font.bold = True
    return b


def new_slide(title, kicker=None, subtitle=None):
    s = prs.slides.add_slide(BLANK)
    bg = s.background.fill; bg.solid(); bg.fore_color.rgb = BG
    # soft glow accents
    g = s.shapes.add_shape(MSO_SHAPE.OVAL, W - Inches(3.2), Inches(-1.8), Inches(5), Inches(4))
    _fill(g, RGBColor(0x12, 0x1D, 0x3A)); g.line.fill.background()
    _slide_no[0] += 1
    if kicker:
        text(s, Inches(0.6), Inches(0.28), Inches(8), Inches(0.3), kicker.upper(), size=11,
             color=CYAN, bold=True)
    text(s, Inches(0.6), Inches(0.52), Inches(12), Inches(0.7), title, size=28, bold=True)
    bar = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.62), Inches(1.2), Inches(0.9), Inches(0.05))
    _fill(bar, CYAN); bar.line.fill.background()
    bar2 = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(1.52), Inches(1.2), Inches(0.5), Inches(0.05))
    _fill(bar2, VIOLET); bar2.line.fill.background()
    if subtitle:
        text(s, Inches(2.2), Inches(1.08), Inches(10.5), Inches(0.3), subtitle, size=12, color=MUTED)
    text(s, Inches(0.6), H - Inches(0.42), Inches(8), Inches(0.3),
         "L2 TLB Support for Sparse Huge Pages  ·  Mid-Term Review", size=9.5, color=MUTED)
    text(s, W - Inches(1.2), H - Inches(0.42), Inches(0.7), Inches(0.3), str(_slide_no[0]),
         size=10, color=MUTED, align=PP_ALIGN.RIGHT)
    return s


def bar_chart(slide, x, y, w, h, categories, series, colors, title=None, number_format='#,##0',
              legend=True, labels=True, font_size=11, gap=60, overlap=-10):
    cd = CategoryChartData(); cd.categories = categories
    for name, vals in series:
        cd.add_series(name, vals)
    gf = slide.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, x, y, w, h, cd)
    ch = gf.chart
    ch.font.size = Pt(font_size); ch.font.color.rgb = TEXT; ch.font.name = FONT
    ch.has_title = bool(title)
    if title:
        ch.chart_title.text_frame.text = title
        tp = ch.chart_title.text_frame.paragraphs[0]
        tp.runs[0].font.size = Pt(13); tp.runs[0].font.bold = True; tp.runs[0].font.color.rgb = TEXT
    ch.has_legend = legend
    if legend:
        ch.legend.position = XL_LEGEND_POSITION.TOP; ch.legend.include_in_layout = False
        ch.legend.font.color.rgb = TEXT; ch.legend.font.size = Pt(font_size)
    va = ch.value_axis
    va.has_major_gridlines = True
    va.major_gridlines.format.line.color.rgb = LINE
    va.format.line.fill.background()
    va.tick_labels.font.color.rgb = MUTED; va.tick_labels.number_format = number_format
    va.tick_labels.number_format_is_linked = False
    ca = ch.category_axis
    ca.format.line.color.rgb = LINE; ca.tick_labels.font.color.rgb = TEXT
    plot = ch.plots[0]; plot.gap_width = gap; plot.overlap = overlap
    if labels:
        plot.has_data_labels = True
        dl = plot.data_labels; dl.font.size = Pt(font_size - 1); dl.font.color.rgb = TEXT
        dl.number_format = number_format; dl.number_format_is_linked = False
        dl.position = XL_LABEL_POSITION.OUTSIDE_END
    for s, c in zip(plot.series, colors):
        s.format.fill.solid(); s.format.fill.fore_color.rgb = c
    return ch


def table(slide, x, y, w, h, rows, col_w=None, size=12, header_color=CYAN, highlight=None):
    nr, nc = len(rows), len(rows[0])
    t = slide.shapes.add_table(nr, nc, x, y, w, h).table
    if col_w:
        for i, cw in enumerate(col_w): t.columns[i].width = Inches(cw)
    for r in range(nr):
        for c in range(nc):
            cell = t.cell(r, c); cell.text = ""
            cell.fill.solid()
            cell.fill.fore_color.rgb = PANEL2 if r == 0 else (PANEL if r % 2 else CODEBG)
            if highlight and (r, c) in highlight:
                cell.fill.fore_color.rgb = RGBColor(0x3B, 0x2A, 0x10)
            cell.margin_left = cell.margin_right = Inches(0.06)
            cell.margin_top = cell.margin_bottom = Inches(0.03)
            p = cell.text_frame.paragraphs[0]
            p.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
            run = p.add_run(); run.text = str(rows[r][c]); run.font.name = FONT
            run.font.size = Pt(size); run.font.bold = (r == 0)
            run.font.color.rgb = header_color if r == 0 else TEXT
    return t


def notes(slide, s):
    slide.notes_slide.notes_text_frame.text = s


def walks(cfg, wl):
    return RES.get(cfg, {}).get(wl, {}).get("dtbWalks")


def pct(a, b):
    return 100.0 * (a - b) / a if a else 0.0


exec(open(os.path.join(HERE, "deck_slides.py")).read())

out = os.path.join(OUTDIR, "MidReview_L2TLB_SparseHugePages.pptx")
prs.save(out)
print("saved", out, "slides:", len(prs.slides))
