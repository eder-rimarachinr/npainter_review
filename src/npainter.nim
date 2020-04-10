import libs/gl
import libs/ft2
import gui/[window, widget, render, container, event, timer]
from gui/widgets/button import newButton
from gui/widgets/check import newCheckbox
from gui/widgets/radio import newRadio
from gui/widgets/textbox import newTextBox
from gui/widgets/slider import newSlider
from gui/widgets/scroll import newScroll
from gui/widgets/color import newColorBar
from c_math import Value, interval, lerp, RGBColor
from assets import setIcons
from utf8 import UTF8Input, `text=`

signal Example:
  A
  B

setIcons 16:
  iconBrush = "brush.svg"
  iconClear = "clear.svg"
  iconClose = "close.svg"
  iconReset = "reset.svg"

type
  Counter = object
    clicked, released: int
  GUIBlank = ref object of GUIWidget
    frame: GUIWidget
    t: GUITimer

var coso: UTF8Input
proc helloworld*(g, d: pointer) =
  coso.text = "hello world"
  echo "hello world"

# ------------------
# GUI BLANK METHODS
# ------------------

proc click*(g: ptr Counter, d: pointer) =
  inc(g.clicked)
  pushSignal(ExampleID, msgA, nil, 0)
  echo "Click Count: ", g.clicked

proc release*(g: ptr Counter, d: pointer) =
  inc(g.released)
  pushSignal(ExampleID, msgB, nil, 0)
  echo "Released Count: ", g.clicked

method draw*(widget: GUIBlank, ctx: ptr CTXRender) =
  if widget.test(wHover):
    let state = # Test Color
      if widget.test(wHover): 0xAA252525'u32
      elif widget.test(wGrab): 0xAAFF00FF'u32
      elif widget.test(wFocus): 0xAAFFFF00'u32
      else: 0xAAFFFFFF'u32
    ctx.color(state)
    ctx.fill rect(widget.rect)
    ctx.color(high uint32)
    #drawAtlas(ctx, widget.rect)
    ctx.color(0xAACCCCCC'u32)
    #triangle(ctx, widget.rect, toDown)
  else:
    ctx.color(0xFF000000'u32)
    ctx.fill rect(widget.rect)
    ctx.color(high uint32)
    #drawAtlas(ctx, widget.rect)
    #ctx.texture(widget.rect, 0)
    ctx.text(widget.rect.x, widget.rect.y, "Hello World")
    ctx.icon(widget.rect.x + 40, widget.rect.y - 40, iconClear)
    ctx.icon(widget.rect.x + 60, widget.rect.y - 40, iconClose)
    ctx.color(0xFFAABBCC'u32)
    ctx.triangle(
      point(widget.rect.x, widget.rect.y + widget.rect.h),
      point(widget.rect.x + widget.rect.w, widget.rect.y + widget.rect.h shr 1),
      point(widget.rect.x + widget.rect.w shr 2, widget.rect.y))
    ctx.color(0xFFCCBBAA'u32)
    ctx.circle(point(widget.rect.x, widget.rect.y), float32 widget.rect.h shr 1)
method event*(widget: GUIBlank, state: ptr GUIState) =
  #echo "cursor mx: ", state.mx, " cursor my: ", state.my
  if state.eventType == evMouseClick:
    if not isNil(widget.frame) and test(widget.frame, wVisible):
      echo "true"
      widget.clear(wHold)
    else:
      widget.t = newTimer(250)
      widget.set(wFocus or wUpdate)
  elif state.eventType == evMouseRelease:
    if not checkTimer(widget.t):
      widget.clear(wUpdate)
  if widget.test(wGrab) and not isNil(widget.frame):
    move(widget.frame, state.mx + 5, state.my + 5)

method trigger*(widget: GUIWidget, signal: GUISignal) =
  case ExampleMsg(signal.msg)
  of msgA: echo "Recived A"
  of msgB: echo "Recived B"

method update*(widget: GUIBlank) =
  if checkTimer(widget.t):
    if widget.frame != nil:
      open(widget.frame)
      widget.set(wHold)
    widget.clear(wUpdate)

method handle*(widget: GUIBlank, kind: GUIHandle) =
  #echo "handle done: ", kind.repr
  #echo "by: ", cast[uint](widget)
  if kind == outHold: close(widget.frame)

when isMainModule:
  var ft: FT2Library
  var bolo, bala: bool
  var equisde: byte
  var val: Value
  var val2: Value
  var col = RGBColor(r: 50 / 255, g: 50 / 255, b: 50 / 255)
  val2.interval(0, 100)
  val.interval(0, 5)
  val.lerp(0.5, true)
  
  # Initialize Freetype2
  if ft2_init(addr ft) != 0:
    echo "ERROR: failed initialize FT2"
  # Create Counter
  var counter = Counter(
    clicked: 0, 
    released: 0
  )
  # Create a new Window
  var win = newGUIWindow(1024, 600, addr counter)
  let root = new GUIContainer
  block: # Create Widgets
    # Create two blanks
    var
      sub, blank: GUIBlank
      con: GUIContainer
    # Initialize Root
    root.color = 0xFF000000'u32
    root.flags = wStandard or wOpaque
    # --- Blank #1 ---
    blank = new GUIBlank
    blank.flags = wStandard
    blank.geometry(300,150,512,256)
    root.add(blank)
    # --- Blank #2 ---
    blank = new GUIBlank
    blank.flags = wStandard
    blank.geometry(20,20,100,100)
    block: # Menu Blank #2
      con = new GUIContainer
      con.color = 0xAA637a90'u32
      con.flags = wPopup
      con.rect.w = 200
      con.rect.h = 100
      # Sub-Blank #1
      sub = new GUIBlank
      sub.flags = wStandard
      sub.geometry(10,10,20,20)
      con.add(sub)
      # Sub-Blank #2
      sub = new GUIBlank
      sub.flags = wStandard
      sub.geometry(40,10,20,20)
      block: # Sub Menu #1
        let subcon = new GUIContainer
        subcon.color = 0xFFbdb88f'u32
        subcon.flags = wEnabled
        subcon.rect.w = 200
        subcon.rect.h = 80
        # Sub-sub blank 1#
        var subsub = new GUIBlank
        subsub.flags = wStandard
        subsub.geometry(10,10,180,20)
        subcon.add(subsub)
        # Sub-sub blank 2#
        subsub = new GUIBlank
        subsub.flags = wStandard
        subsub.geometry(10,40,180,20)
        subcon.add(subsub)
        # Add to Sub
        sub.frame = subcon
      con.add(sub)
      # Add Blank 2
      blank.frame = con
    root.add(blank)
    # Add a GUI Button
    let button = newButton("Test Button CB", helloworld)
    button.geometry(20, 200, 200, button.hint.h)
    block: # Add Checkboxes
      var check = newCheckbox("Check B", addr bolo)
      check.geometry(20, 250, 100, check.hint.h)
      root.add(check)
      check = newCheckbox("Check A", addr bala)
      check.geometry(120, 250, 100, check.hint.h)
      root.add(check)
    block: # Add Radio Buttons
      var radio = newRadio("Radio B", 1, addr equisde)
      radio.geometry(20, 300, 100, radio.hint.h)
      root.add(radio)
      radio = newRadio("Radio A", 2, addr equisde)
      radio.geometry(120, 300, 100, radio.hint.h)
      root.add(radio)
    block: # Add TextBox
      var textbox = newTextBox(addr coso)
      textbox.geometry(20, 350, 200, textbox.hint.h)
      root.add(textbox)
    block: # Add Slider
      var slider = newSlider(addr val)
      slider.geometry(20, 400, 200, slider.hint.h)
      root.add(slider)
    block: # Add Scroll
      var scroll = newScroll(addr val)
      scroll.geometry(20, 450, 200, scroll.hint.h)
      root.add(scroll)
    block: # Add Scroll
      var scroll = newScroll(addr val, true)
      scroll.geometry(20, 480, scroll.hint.h, 200)
      root.add(scroll)
    block: # Add Scroll
      var color = newColorBar(addr col)
      color.geometry(50, 500, color.hint.w * 2, color.hint.h * 2)
      root.add(color)
      color = newColorBar(addr col)
      color.geometry(300, 500, color.hint.w * 2, color.hint.h * 2)
      root.add(color)
    root.add(button)
    # Creates new Window
    
  # MAIN LOOP
  var running = win.open(root)

  while running:
    # Render Main Program
    glClearColor(col.r, col.g, col.b, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
    # Render GUI
    running = win.tick()
  # Close Window and Dispose Resources
  win.close()
