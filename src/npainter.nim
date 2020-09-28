import libs/gl
#import libs/ft2
import gui/[
  window, 
  widget, 
  render, 
  #container, 
  event
  #timer
  ]
import painter/[
  canvas, voxel
]
import times

# LOAD SSE4.1
{.passC: "-msse4.1".}
{.compile: "painter/algebra.c".}

type
  # Voxel Transversal 32x32
  NMatrix = array[9, float32]
  NTracking = object
    cx, cy: float32
    x, y: float32
    s, o: float32
  TrackMode = enum
    mTranslate, mScale, mRotate
  VoxelT = ref object of GUIWidget
    # Test Matrix
    mat, mat_inv: NMatrix
    track, hold: NTracking
    hold_o: float32
    # Quad
    pivot, pivot_inv, quad, quad_inv: NQuad
    dda: NScanline
    # Test Grid
    grid: array[1024, uint8]
    # Hold Point
    mx, my: float32
    mode: TrackMode
  # Test Image Tile
  TTileImage = ref object of GUIWidget
    mx, my: int32
    ox, oy: int32
    canvas: NCanvas
    tex: GLuint
    work: bool
    # Voxel Test
    voxel: VoxelT
  TTMove = object
    x, y: int32
    image: GUITarget


# Matrix Operations
proc mat3_canvas*(mat: var NMatrix, cx, cy, x, y, s, o: float32) {.importc.}
proc mat3_canvas_inv*(mat: var NMatrix, cx, cy, x, y, s, o: float32) {.importc.}
# Vector Operations
proc vec2_mat3*(vec: var NPoint, mat: var NMatrix) {.importc.}

method draw(self: VoxelT, ctx: ptr CTXRender) =
  var # Each Tile
    r: GUIRect
    cursor: int16
  # Define Rect
  r.x = self.rect.x
  r.y = self.rect.y
  r.w = 16; r.h = 16
  # Draw Each Tile
  for y in 0..<32:
    for x in 0..<32:
      ctx.color if self.grid[cursor] == 1:
        0xFF2f2f7f.uint32
      elif self.grid[cursor] > 1:
        0xFF002f00.uint32
      else: 0xFF2F2F2F.uint32
      # Fill Tile
      ctx.fill(r.rect)
      # Next Grid Pos
      inc(cursor); r.x += 16
    r.x = self.rect.x
    r.y += 16 # Next Row
  # Draw Lines of Quad
  let p = point(self.rect.x, self.rect.y)
  ctx.color(high uint32)
  ctx.line(
    point(p.x + self.quad[0].x * 16, p.y + self.quad[0].y * 16),
    point(p.x + self.quad[1].x * 16, p.y + self.quad[1].y * 16)
  )
  ctx.line(
    point(p.x + self.quad[1].x * 16, p.y + self.quad[1].y * 16),
    point(p.x + self.quad[2].x * 16, p.y + self.quad[2].y * 16)
  )
  ctx.line(
    point(p.x + self.quad[2].x * 16, p.y + self.quad[2].y * 16),
    point(p.x + self.quad[3].x * 16, p.y + self.quad[3].y * 16)
  )
  ctx.line(
    point(p.x + self.quad[3].x * 16, p.y + self.quad[3].y * 16),
    point(p.x + self.quad[0].x * 16, p.y + self.quad[0].y * 16)
  )
  # Draw Lines of Quad Inverse
  #let p = point(self.rect.x, self.rect.y)
  ctx.color(0xFF00FFFF'u32)
  var rect = GUIRect(
    x: 0, y: 0,
    w: 16 * 16, h: 16 * 16)
  ctx.push(rect)
  ctx.line(
    point(self.quad_inv[0].x * 16, self.quad_inv[0].y * 16),
    point(self.quad_inv[1].x * 16, self.quad_inv[1].y * 16)
  )
  ctx.line(
    point(self.quad_inv[1].x * 16, self.quad_inv[1].y * 16),
    point(self.quad_inv[2].x * 16, self.quad_inv[2].y * 16)
  )
  ctx.line(
    point(self.quad_inv[2].x * 16, self.quad_inv[2].y * 16),
    point(self.quad_inv[3].x * 16, self.quad_inv[3].y * 16)
  )
  ctx.line(
    point(self.quad_inv[3].x * 16, self.quad_inv[3].y * 16),
    point(self.quad_inv[0].x * 16, self.quad_inv[0].y * 16)
  )
  ctx.pop()

# ------------------
# VOXEL TEST METHODS
# ------------------

#[
method event(self: VoxelT, state: ptr GUIState) =
  state.mx -= self.rect.x
  state.my -= self.rect.y
  if state.eventType == evMouseClick:
    self.x1 = float32(state.mx) / 16
    self.y1 = float32(state.my) / 16
  elif self.test(wGrab):
    self.x2 = float32(state.mx) / 16
    self.y2 = float32(state.my) / 16
    zeroMem(addr self.grid[0], 1024)
]#
proc test_scanline(self: VoxelT) =
  self.dda.scanline(self.quad, 1)
  # Fill Grid
  for x, y in self.dda.voxels:
    self.grid[y shl 5 + x] += 1

proc test_mat(self: VoxelT) =
  mat3_canvas(self.mat, 
    self.track.cx, self.track.cy,
    self.track.x, self.track.y,
    self.track.s, self.track.o)
  mat3_canvas_inv(self.mat_inv,
    self.track.cx, self.track.cy,
    self.track.x, self.track.y, 
    self.track.s, self.track.o)
  # Perform Quad Transform
  self.quad = self.pivot
  for p in mitems(self.quad):
    p.vec2_mat3(self.mat)
  # Perform Quad Inverse Transfrom
  self.quad_inv = self.pivot
  for p in mitems(self.quad_inv):
    p.vec2_mat3(self.mat_inv)

proc newVoxelT(): VoxelT =
  new result # Alloc
  result.flags = wMouse
  result.kind = wgFrame
  result.minimum(256, 256)
  # ! Scale Allways 1
  result.track.s = 1
  # Left Side
  result.pivot[0].x = 0
  result.pivot[0].y = 0
  # Top Side
  result.pivot[1].x = 16
  result.pivot[1].y = 0
  # Right Side
  result.pivot[2].x = 16
  result.pivot[2].y = 16
  # Bottom Side
  result.pivot[3].x = 0
  result.pivot[3].y = 16
  # Inverted Quad
  # Left Side
  result.pivot_inv[0].x = 0
  result.pivot_inv[0].y = 0
  # Top Side
  result.pivot_inv[1].x = 16
  result.pivot_inv[1].y = 0
  # Right Side
  result.pivot_inv[2].x = 16
  result.pivot_inv[2].y = 16
  # Bottom Side
  result.pivot_inv[3].x = 0
  result.pivot_inv[3].y = 16
  # Scale
  result.track.cx = 8
  result.track.cy = 8
  # 1 - Perform Scanline
  result.quad = result.pivot
  result.quad_inv = result.pivot_inv
  result.dda.dimensions(32, 32)
  result.test_scanline()

#proc sum(a: NQuad, x, y: float32): NQuad =
#  for i in 0..3:
#    result[i].x = a[i].x + x
#    result[i].y = a[i].y + y

proc translate(self: VoxelT, x, y: float32) =
  self.track.x = self.hold.x + x
  self.track.y = self.hold.y + y

proc scale(self: VoxelT, s: float32) =
  self.track.s = self.hold.s - (s / 10)
  if self.track.s < 0.1:
    self.track.s = 0.1

proc rotate(self: VoxelT, o: float32) =
  self.track.o = self.hold.o + o
  echo "raw rotation: ", o
  echo "rotation: ", self.track.o

proc cb_move_voxel(g: pointer, w: ptr GUITarget) =
  let self = cast[VoxelT](w[])
  zeroMem(addr self.grid, sizeof(self.grid))
  self.test_mat()
  self.test_scanline()
  #sort(self.quad, self.quad.aabb)
  #self.scanline()

from math import arctan2

method event(self: VoxelT, state: ptr GUIState) =
  if state.kind == evMouseClick:
    self.mx = float32 state.mx
    self.my = float32 state.my
    self.hold = self.track
    # Track Mode
    if (state.mods and ShiftMod) == ShiftMod:
      self.mode = mScale
    elif (state.mods and CtrlMod) == CtrlMod:
      self.mode = mRotate
      let # Obviusly will be cleaned
        c = point(self.rect.w shr 1, self.rect.h shr 1)
        p = point(state.mx - self.rect.x, state.my - self.rect.y)
      self.hold_o = arctan2(c.y - p.y, c.x - p.x)
    else: self.mode = mTranslate
  if state.kind == evMouseRelease: discard
  elif self.test(wGrab):
    case self.mode
    of mTranslate:
      translate(self,
        (float32(state.mx) - self.mx) / 16, 
        (float32(state.my) - self.my) / 16)
    of mScale:
      scale(self, (float32(state.my) - self.my) / 16)
    of mRotate:
      let # Obviusly will be cleaned
        c = point(self.rect.w shr 1, self.rect.h shr 1)
        p = point(state.mx - self.rect.x, state.my - self.rect.y)
      rotate(self, arctan2(c.y - p.y, c.x - p.x) - self.hold_o)
    var t = self.target
    pushCallback(cb_move_voxel, t)

# -----------------
# TEST TILED CANVAS
# -----------------

method draw(self: TTileImage, ctx: ptr CTXRender) =
  ctx.color(high uint32)
  var r = rect(self.rect.x, self.rect.y, 
    self.canvas.w + self.canvas.rw, 
    self.canvas.h + self.canvas.rh)
  # Draw Rect
  ctx.fill(r)
  ctx.texture(r, self.tex)
  # Division Lines
  discard """
  ctx.color(0xFF000000'u32)
  let
    tw = self.canvas.tw - 1
    th = self.canvas.th - 1
  var s: int16
  # Horizontal
  for x in 0..tw:
    s = cast[int16](x) shl 8
    ctx.fill rect(r.x + s, r.y, 1, r.h)
    #ctx.fill rect(r)
  # Vertical
  for x in 0..th:
    s = cast[int16](x) shl 8
    ctx.fill rect(r.x, r.y + s, r.w, 1)
    #ctx.fill rect(r)
  """

proc newTTileImage(w, h: int16): TTileImage =
  new result # Alloc Widget
  result.flags = wMouse
  result.canvas = newCanvas(w, h)
  glGenTextures(1, addr result.tex)
  glBindTexture(GL_TEXTURE_2D, result.tex)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, cast[GLint](GL_NEAREST))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, cast[GLint](GL_NEAREST))
  glTexImage2D(GL_TEXTURE_2D, 0, cast[GLint](GL_RGBA8), 
    result.canvas.cw, result.canvas.ch, 0, GL_RGBA, 
    GL_UNSIGNED_BYTE, nil)
  glBindTexture(GL_TEXTURE_2D, 0)
  # Create new voxel
  result.voxel = newVoxelT()
  result.voxel.geometry(0, 0, 512, 512)

proc refresh(self: TTileImage) =
  glBindTexture(GL_TEXTURE_2D, self.tex)
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 
    self.canvas.cw, self.canvas.ch, GL_RGBA, 
    GL_UNSIGNED_BYTE, addr self.canvas.buffer[0])
  glBindTexture(GL_TEXTURE_2D, 0)

proc cb_point(g: pointer, data: ptr TTMove) =
  let self = cast[TTileImage](data.image)
  var b, c, d: float32
  self.canvas[4].x = data.x
  self.canvas[4].y = data.y
  self.canvas.stencil(self.canvas[4][])
  b = cpuTime()
  self.canvas.composite()
  c = cpuTime()
  self.refresh()
  d = cpuTime()
  echo "composite: ", c - b, "  upload: ", d - c
  self.work = false

method event(self: TTileImage, state: ptr GUIState) =
  if state.kind == evMouseClick:
    if (state.mods and ShiftMod) == 0:
      self.mx = state.mx; self.my = state.my
      self.ox = self.canvas[4].x
      self.oy = self.canvas[4].y
    elif self.voxel.test(wVisible):
      self.voxel.close()
    else: # Open On Cursor Position
      self.voxel.open()
      self.voxel.move(state.mx, state.my)
  elif self.test(wGrab):
    if not self.work:
      var t = TTMove(
        x: self.ox + state.mx - self.mx,
        y: self.oy + state.my - self.my,
        image: self.target)
      pushCallback(cb_point, t)
      self.work = true

proc clear(tile: NTile, col: NPixel) =
  var i: int32
  while i < 4096:
    tile[i] = col; inc(i)

proc fill(canvas: var NCanvas, idx: int32, color: uint32) =
  let layer = canvas[idx]
  var i: int32
  for y in 0..<canvas.ch shr 6:
    for x in 0..<canvas.cw shr 6:
      layer[].add(x.int16, y.int16)
      clear(layer.tiles[i].buffer, color)
      inc(i) # Next Tile

#[
proc fill(canvas: var NCanvas, idx, w, h: int32, color: uint32) =
  let layer = canvas[idx]
  var i: int32
  #for y in 0..<w:
  #  for x in 0..<h:
  layer[].add(w.int16, h.int16)
  clear(layer.tiles[i].buffer, color)
  inc(i) # Next Tile
]#

when isMainModule:
  var # Create Window and GUI
    win = newGUIWindow(1024, 600, nil)
    root = newTTileImage(1024, 1024)
  # Reload Canvas Texture
  #root.clear(0xFF0000FF'u32)
  root.canvas.add()
  root.canvas.add()
  root.canvas.add()
  root.canvas.add()
  root.canvas.add()
  #let layer = root.canvas[0]
  #layer[].add(1, 1)
  #layer[].add(0, 0)
  #layer[].add(2, 2)
  #layer[].add(3, 3)
  #layer[].add(3, 1)
  #clear(layer.tiles[0].buffer, 0xBB00FF00'u32)
  #clear(layer.tiles[1].buffer, 0xBBFFFF00'u32)
  #clear(layer.tiles[2].buffer, 0xBB00FFFF'u32)
  #clear(layer.tiles[3].buffer, 0xBB0000FF'u32)
  #clear(layer.tiles[4].buffer, 0xBBFF00FF'u32)
  root.canvas.fill(0, 0xFF00FF00'u32)
  let layer = root.canvas[1]
  layer.x = 64
  layer.y = 64
  root.canvas.fill(1, 0xFF0000FF'u32)
  root.canvas.fill(2, 0xFF00FFFF'u32)
  root.canvas.fill(3, 0xFFFFF0FF'u32)
  root.canvas[3].x = 128
  root.canvas[3].y = 128
  root.canvas.fill(4, 0xBB000000'u32)
  #root.canvas[0][].add(0, 0)
  #root.canvas[0][].add(1, 1)
  #clear(root.canvas[0].tiles[0].buffer, 0xBB000000'u32)
  #clear(root.canvas[0].tiles[1].buffer, 0xBB000000'u32)
  root.canvas.composite()
  root.refresh()
  # Run GUI Program
  if win.open(root):
    while true:
      win.handleEvents() # Input
      if win.handleSignals(): break
      win.handleTimers() # Timers
      # Render Main Program
      glClearColor(0.6, 0.6, 0.6, 1.0)
      glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
      # Render GUI
      win.render()
  # Close Window
  win.close()
