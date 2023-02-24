# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2023 Cristian Camilo Ruiz <mrgaturus>
import canvas, canvas/render, canvas/matrix

type
  NCanvasView* = object
    canvas: ptr NCanvas
    affine*: NCanvasAffine
    # Canvas OpenGL Renderer
    viewport: NCanvasViewport

# --------------------
# Canvas View Creation
# --------------------

proc createCanvasView*(canvas: var NCanvas, ctx: var NCanvasRenderer): NCanvasView =
  result.canvas = addr canvas
  # Create Canvas Viewport
  result.viewport = ctx.createViewport(canvas.w, canvas.h)

# ----------------------------
# Canvas View Affine Transform
# ----------------------------


# ----------------------------
# Canvas View Update Transform
# ----------------------------