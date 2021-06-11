import ui, unicode
import color, highlight

type Sidebar* = object
  enable*: bool
  buffer: seq[seq[Rune]]
  highlight: seq[Highlight]
  window: Window
  h: int
  w: int
  y: int
  x: int

proc initSidebar*(): Sidebar =
  const
    h = 1
    w = 1
    y = 0
    x = 0
    color = EditorColorPair.defaultChar
  result.window = initWindow(h, w , y, x, color)
  result.h = h
  result.w = h
  result.y = y
  result.x = x
  result.enable = true

proc maxLen(buffer: seq[seq[Rune]]): int =
  for line in buffer:
    if line.len > result:
      result = line.len

proc write(sidebar: var Sidebar,
           y, x: int,
           buffer: seq[Rune],
           color: EditorColorPair) =

  sidebar.window.write(y, x, buffer, color)

# Refresh Sidebar window
proc refresh(sidebar: Sidebar) =
  sidebar.window.refresh

proc resize*(sidebar: var Sidebar, y, x, h: int) =
  let width = maxLen(sidebar.buffer)

  sidebar.h = h
  sidebar.w = width
  sidebar.y = y
  sidebar.x = x

  sidebar.window.resize(h, width, y, x)

proc write*(sidebar: var Sidebar, sidebarIndex: int) =
  let
    buffer = sidebar.buffer
    y = sidebar.y
    x = sidebar.x

  for i, line in buffer:
    let color = EditorColorPair.defaultChar
    sidebar.window.write(y, x, line, color)

  sidebar.refresh

proc updateBuffer*(sidebar: var Sidebar, buffer: seq[seq[Rune]]) =
  sidebar.buffer = buffer

proc getWidth*(sidebar: Sidebar): int =
  result = sidebar.w