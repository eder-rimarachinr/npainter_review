from event import GUIState, GUIEvent, GUISignal
import widget, context

const
  wDrawDirty = 0x0400'u16
  # Combinations
  wReactive = 0x000F'u16
  wFocusCheck* = 0x0070'u16

type
  # GUIContainer, GUILayout and Decorator
  GUILayout* = ref object of RootObj
  GUIContainer* = ref object of GUIWidget
    first, last: GUIWidget  # Iterating / Inserting
    focus, hover: GUIWidget # Cache Pointers
    layout*: GUILayout
    color*: GUIColor

# LAYOUT ABSTRACT METHOD
method layout*(self: GUILayout, container: GUIContainer) {.base.} = discard

# CONTAINER PROCS
proc newGUIContainer*(layout: GUILayout, color: GUIColor): GUIContainer =
  new result
  # GUILayout
  result.layout = layout
  result.color = color
  # GUIWidget Default Flags
  result.flags = 0x0638

proc add*(self: GUIContainer, widget: GUIWidget) =
  if self.first.isNil:
    self.first = widget
    self.last = widget
  else:
    widget.prev = self.last
    self.last.next = widget

  self.last = widget

# CONTAINER PROCS PRIVATE
iterator items(self: GUIContainer): GUIWidget =
  var widget: GUIWidget = self.first
  while widget != nil:
    yield widget
    widget = widget.next

proc stepWidget(self: GUIContainer, back: bool): bool =
  if back:
    if self.focus.isNil:
      self.focus = self.last
    else:
      self.focus = self.focus.prev
  else:
    if self.focus.isNil:
      self.focus = self.first
    else:
      self.focus = self.focus.next

  result = not self.focus.isNil

proc checkFocus(self: GUIContainer) =
  var aux: GUIWidget = self.focus
  if aux != nil and (aux.flags and wFocusCheck) != wFocusCheck:
    aux.focusOut()
    aux.flags.clearMask(wFocus)

    self.flags =
      (self.flags and not wFocus.uint16) or (aux.flags and wReactive)
    self.focus = nil

# CONTAINER METHODS
method draw(self: GUIContainer, ctx: ptr GUIContext) =
  var count = 0;

  # Push Clipping and Color Level
  ctx.push(addr self.rect, addr self.color)
  # Clear color if it was dirty
  if testMask(self.flags, wDrawDirty):
    clear(ctx)
    clearMask(self.flags, wDrawDirty)
  # Draw Widgets
  for widget in self:
    if (widget.flags and wDraw) == wDraw:
      widget.draw(ctx)
      inc(count)
  # Pop Clipping and Color Level
  ctx.pop()

  if count == 0:
    self.flags.clearMask(wDraw)

method update(self: GUIContainer) =
  var count = 0;

  for widget in self:
    if (widget.flags and wUpdate) == wUpdate:
      widget.update()
      inc(count)

  self.checkFocus()

  if count == 0:
    self.flags.clearMask(wUpdate)

method event(self: GUIContainer, state: ptr GUIState) =
  var aux: GUIWidget = nil

  case state.eventType
  of evMouseMove, evMouseClick, evMouseRelease, evMouseAxis:
    aux = self.hover

    if (self.flags and wGrab) == wGrab:
      if aux != nil and (aux.flags and wGrab) == wGrab:
        if pointOnArea(self.rect, state.mx, state.my):
          aux.flags.setMask(wHover)
        else:
          aux.flags.clearMask(wHover)
      else:
        self.flags.clearMask(wGrab)
    elif aux.isNil or not pointOnArea(aux.rect, state.mx, state.my):
      if aux != nil:
        aux.hoverOut()
        aux.flags.clearMask(wHover)
        self.flags.setMask(aux.flags and wReactive)

      aux = nil
      for widget in self:
        if (widget.flags and wVisible) == wVisible and
            pointOnArea(widget.rect, state.mx, state.my):
          widget.flags.setMask(wHover)
          self.flags.setMask(wHover)

          aux = widget
          break

      if aux.isNil:
        self.flags.clearMask(wHover)

      self.hover = aux

      if state.eventType == evMouseClick:
        self.flags.setMask(wGrab)
  of evKeyDown, evKeyUp:
    if (self.flags and wFocus) == wFocus:
      aux = self.focus

  if aux != nil:
    aux.event(state)
    if state.eventType < evKeyDown:
      self.flags = (self.flags and not wGrab.uint16) or (
          aux.flags and wGrab)

    var focusAux: GUIWidget = self.focus
    let focusCheck = (aux.flags and wFocusCheck) xor 0x0030'u16

    if focusCheck == wFocus:
      if aux != focusAux and focusAux != nil:
        focusAux.focusOut()
        focusAux.flags.clearMask(wFocus)

        self.flags.setMask(aux.flags and wReactive)
        self.focus = self.hover
      elif focusAux.isNil:
        self.focus = self.hover
        self.flags.setMask(wFocus)
    elif (focusCheck and wFocus) == wFocus or aux != focusAux:
      aux.focusOut()
      aux.flags.clearMask(wFocus)

      if (aux == focusAux):
        self.focus = nil
        self.flags.clearMask(wFocus)

    self.flags.setMask(aux.flags and wReactive)

method trigger(self: GUIContainer, signal: GUISignal) =
  var focusAux = self.focus
  for widget in self:
    if (widget.flags and wSignal) == wSignal and
        (widget.id == signal.id or widget.id == 0):
      widget.trigger(signal)

      let focusCheck = (widget.flags and wFocusCheck) xor 0x0030'u16
      if (focusCheck and wFocus) == wFocus and widget != focusAux:
        if focusCheck == wFocus:
          if focusAux != nil:
            focusAux.focusOut()
            focusAux.flags.clearMask(wFocus)

            self.flags.setMask(focusAux.flags and wReactive)
          focusAux = widget
        else:
          widget.focusOut()
          widget.flags.clearMask(wFocus)

      self.flags.setMask(widget.flags and wReactive)

  if focusAux != self.focus:
    self.focus = focusAux
    self.flags.setMask(wFocus)
  else:
    self.checkFocus()

method step(self: GUIContainer, back: bool) =
  var widget: GUIWidget = self.focus

  if widget != nil:
    widget.step(back)
    self.flags.setMask(widget.flags and wReactive)

    if (widget.flags and wFocusCheck) == wFocusCheck: return
    else:
      widget.focusOut()
      widget.flags.clearMask(wFocus)

      self.flags.setMask(widget.flags and wReactive)

  while self.stepWidget(back):
    widget = self.focus
    if (widget.flags and 0x0030) == 0x0030:
      widget.step(back)
      self.flags.setMask(widget.flags and wReactive)

      if (widget.flags and wFocus) == wFocus:
        self.flags.setMask(wFocus)
        return

  self.focus = nil
  self.flags.clearMask(wFocus)

method layout(self: GUIContainer) =
  if (self.flags and wDirty) == wDirty:
    self.layout.layout(self)
    self.flags.setMask(wDrawDirty)

  for widget in self:
    widget.flags.setMask(self.flags and wDirty)
    if (widget.flags and 0x000C) != 0:
      widget.layout()
      widget.flags.clearMask(0x000D)

      if (widget.flags and wVisible) == wVisible:
        widget.flags.setMask(wDraw)
      else:
        zeroMem(addr widget.rect, sizeof(GUIRect))

      self.flags.setMask(widget.flags and wReactive)

  self.checkFocus()
  self.flags.clearMask(0x000C)

method hoverOut(self: GUIContainer) =
  var aux: GUIWidget = self.hover
  if aux != nil:
    aux.hoverOut()
    aux.flags.clearMask(wHover)
    # if is focused check focus
    if aux == self.focus and
        (aux.flags and wFocusCheck) != wFocusCheck:
      aux.focusOut()
      aux.flags.clearMask(wFocus)
      self.focus = nil

    self.hover = nil
    self.flags.setMask(aux.flags and wReactive)


method focusOut(self: GUIContainer) =
  var aux: GUIWidget = self.focus
  if aux != nil:
    aux.focusOut()
    aux.flags.clearMask(wFocus)

    self.focus = nil
    self.flags.setMask(aux.flags and wReactive)
