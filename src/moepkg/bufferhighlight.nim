#[###################### GNU General Public License 3.0 ######################]#
#                                                                              #
#  Copyright (C) 2017─2023 Shuhei Nogawa                                       #
#                                                                              #
#  This program is free software: you can redistribute it and/or modify        #
#  it under the terms of the GNU General Public License as published by        #
#  the Free Software Foundation, either version 3 of the License, or           #
#  (at your option) any later version.                                         #
#                                                                              #
#  This program is distributed in the hope that it will be useful,             #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of              #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
#  GNU General Public License for more details.                                #
#                                                                              #
#  You should have received a copy of the GNU General Public License           #
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.      #
#                                                                              #
#[############################################################################]#

import independentutils, bufferstatus, highlight, color, window, gapbuffer,
       unicodeext, editorview, searchutils, settings

proc initBufferPosition(
  n: WindowNode): BufferPosition {.inline.} =
    BufferPosition(line: n.currentLine, column: n.currentColumn)

proc highlightSelectedArea(
  highlight: var Highlight,
  bufStatus: BufferStatus,
  position: BufferPosition) =

    let area = bufStatus.selectedArea

    var colorSegment = initSelectedAreaColorSegment(
      position,
      EditorColorPair.visualMode)

    if area.startLine == area.endLine:
      colorSegment.firstRow = area.startLine
      colorSegment.lastRow = area.endLine
      if area.startColumn < area.endColumn:
        colorSegment.firstColumn = area.startColumn
        colorSegment.lastColumn = area.endColumn
      else:
        colorSegment.firstColumn = area.endColumn
        colorSegment.lastColumn = area.startColumn
    elif area.startLine < area.endLine:
      colorSegment.firstRow = area.startLine
      colorSegment.lastRow = area.endLine
      colorSegment.firstColumn = area.startColumn
      colorSegment.lastColumn = area.endColumn
    else:
      colorSegment.firstRow = area.endLine
      colorSegment.lastRow = area.startLine
      colorSegment.firstColumn = area.endColumn
      colorSegment.lastColumn = area.startColumn

    if bufStatus.isVisualBlockMode:
      highlight.overwriteColorSegmentBlock(
        bufStatus.selectedArea,
        bufStatus.buffer)
    elif bufStatus.isVisualMode:
      highlight.overwrite(colorSegment)

proc highlightPairOfParen(
  highlight: var Highlight,
  bufStatus: BufferStatus,
  windowNode: WindowNode) =

    let
      buffer = bufStatus.buffer
      currentLine = windowNode.currentLine
      currentColumn =
        if windowNode.currentColumn > buffer[currentLine].high:
          buffer[currentLine].high
        else:
          windowNode.currentColumn

    if buffer[currentLine].len < 1 or
       (buffer[currentLine][currentColumn] == ru'"') or
       (buffer[currentLine][currentColumn] == ru'\''): return

    if isOpenParen(buffer[currentLine][currentColumn]):
      var depth = 0
      let
        openParen = buffer[currentLine][currentColumn]
        closeParen = correspondingCloseParen(openParen)
      for i in currentLine ..< buffer.len:
        let startColumn = if i == currentLine: currentColumn else: 0
        for j in startColumn ..< buffer[i].len:
          if buffer[i][j] == openParen: inc(depth)
          elif buffer[i][j] == closeParen: dec(depth)
          if depth == 0:
            let colorSegment = ColorSegment(
              firstRow: i,
              firstColumn: j,
              lastRow: i,
              lastColumn: j,
              color: EditorColorPair.parenText)
            highlight.overwrite(colorSegment)
            return

    elif isCloseParen(buffer[currentLine][currentColumn]):
      var depth = 0
      let
        closeParen = buffer[currentLine][currentColumn]
        openParen = correspondingOpenParen(closeParen)
      for i in countdown(currentLine, 0):
        let startColumn = if i == currentLine: currentColumn else: buffer[i].high
        for j in countdown(startColumn, 0):
          if buffer[i].len < 1: break
          if buffer[i][j] == closeParen: inc(depth)
          elif buffer[i][j] == openParen: dec(depth)
          if depth == 0:
            let colorSegment = ColorSegment(
              firstRow: i,
              firstColumn: j,
              lastRow: i,
              lastColumn: j,
              color: EditorColorPair.parenText)
            highlight.overwrite(colorSegment)
            return

# Highlighting other uses of the current word under the cursor
proc highlightOtherUsesCurrentWord(
  highlight: var Highlight,
  bufStatus: BufferStatus,
  windowNode: WindowNode,
  theme: colorTheme) =

    let line = bufStatus.buffer[windowNode.currentLine]

    if line.len < 1 or
       windowNode.currentColumn > line.high or
       (line[windowNode.currentColumn] != '_' and
       unicodeext.isPunct(line[windowNode.currentColumn])) or
       line[windowNode.currentColumn].isSpace: return
    var
      startCol = windowNode.currentColumn
      endCol = windowNode.currentColumn

    # Set start col
    for i in countdown(windowNode.currentColumn - 1, 0):
      if (line[i] != '_' and unicodeext.isPunct(line[i])) or line[i].isSpace:
        break
      else: startCol.dec

    # Set end col
    for i in windowNode.currentColumn ..< line.len:
      if (line[i] != '_' and unicodeext.isPunct(line[i])) or line[i].isSpace:
        break
      else: endCol.inc

    let highlightWord = line[startCol ..< endCol]

    let
      range = windowNode.view.rangeOfOriginalLineInView
      startLine = range.start
      endLine = if bufStatus.buffer.len > range.end + 1: range.end + 2
                elif bufStatus.buffer.len > range.end: range.end + 1
                else: range.end

    # TODO: Remove
    proc isWordAtCursor(currentLine, i, j: int): bool =
      i == currentLine and (j >= startCol and j <= endCol)

    for i in startLine ..< endLine:
      let line = bufStatus.buffer[i]
      for j in 0 .. (line.len - highlightWord.len):
        let endCol = j + highlightWord.len
        if line[j ..< endCol] == highlightWord:
          ## TODO: Refactor
          if j == 0 or
             (j > 0 and
             ((line[j - 1] != '_' and
             unicodeext.isPunct(line[j - 1])) or
             line[j - 1].isSpace)):
            if (j == (line.len - highlightWord.len)) or
               ((line[j + highlightWord.len] != '_' and
               unicodeext.isPunct(line[j + highlightWord.len])) or
               line[j + highlightWord.len].isSpace):

              # Do not highlight current word on the cursor
              if not isWordAtCursor(windowNode.currentLine, i, j):
                # Set color
                let
                  originalColorPair =
                    highlight.getColorPair(i, j)
                  colors = theme.getColorFromEditorColorPair(originalColorPair)
                setColorPair(EditorColorPair.currentWord,
                             colors[0],
                             colorThemeTable[theme].currentWordBg)

                let
                  color = EditorColorPair.currentWord
                  colorSegment = ColorSegment(firstRow: i,
                                              firstColumn: j,
                                              lastRow: i,
                                              lastColumn: j + highlightWord.high,
                                              color: color)
                highlight.overwrite(colorSegment)

proc highlightTrailingSpaces(
  highlight: var Highlight,
  bufStatus: BufferStatus,
  windowNode: WindowNode) =

    # TODO: Fix condition
    if isConfigMode(bufStatus.mode, bufStatus.prevMode) or
       isDebugMode(bufStatus.mode, bufStatus.prevMode): return

    let
      currentLine = windowNode.currentLine
      range = windowNode.view.rangeOfOriginalLineInView
      buffer = bufStatus.buffer
      startLine = range.start
      endLine =
        if buffer.len > range.end + 1: range.end + 2
        elif buffer.len > range.end: range.end + 1
        else: range.end

    var colorSegments: seq[ColorSegment] = @[]
    for i in startLine ..< endLine:
      let line = buffer[i]
      if line.len > 0 and i != currentLine:
        var countSpaces = 0
        for j in countdown(line.high, 0):
          if line[j] == ru' ': inc countSpaces
          else: break

        if countSpaces > 0:
          let firstColumn = line.len - countSpaces
          colorSegments.add(ColorSegment(
            firstRow: i,
            firstColumn: firstColumn,
            lastRow: i,
            lastColumn: line.high,
            color: EditorColorPair.highlightTrailingSpaces))

    for colorSegment in colorSegments:
      highlight.overwrite(colorSegment)

proc highlightFullWidthSpace(
  highlight: var Highlight,
  windowNode: WindowNode,
  bufferInView: GapBuffer[seq[Rune]],
  range: Range) =

    const
      fullWidthSpace = ru"　"
      ignorecase = false
      smartcase = false
    let allOccurrence = bufferInView.searchAllOccurrence(
      fullWidthSpace,
      ignorecase,
      smartcase)

    for pos in allOccurrence:
      let colorSegment = ColorSegment(
        firstRow: range.start + pos.line,
        firstColumn: pos.column,
        lastRow: range.start + pos.line,
        lastColumn: pos.column,
        color: EditorColorPair.highlightFullWidthSpace)
      highlight.overwrite(colorSegment)

proc highlightSearchResults(
  highlight: var Highlight,
  bufStatus: BufferStatus,
  bufferInView: GapBuffer[seq[Rune]],
  range: Range,
  keyword: seq[Rune],
  settings: EditorSettings,
  isSearchHighlight: bool) =

  let
    ignorecase = settings.ignorecase
    smartcase = settings.smartcase
    allOccurrence = searchAllOccurrence(
      bufferInView,
      keyword,
      ignorecase,
      smartcase)

    color =
      if isSearchHighlight: EditorColorPair.searchResult
      else: EditorColorPair.replaceText

  for pos in allOccurrence:
    let colorSegment = ColorSegment(
      firstRow: range.start + pos.line,
      firstColumn: pos.column,
      lastRow: range.start + pos.line,
      lastColumn: pos.column + keyword.high,
      color: color)
    highlight.overwrite(colorSegment)

proc updateHighlight*(
  highlight: var Highlight,
  bufStatus: BufferStatus,
  windowNode: var WindowNode,
  isSearchHighlight: bool,
  searchHistory: seq[seq[Rune]],
  settings: EditorSettings) =

    if settings.highlight.currentWord:
      highlight.highlightOtherUsesCurrentWord(
        bufStatus,
        windowNode,
        settings.editorColorTheme)

    if isVisualMode(bufStatus.mode):
      highlight.highlightSelectedArea(bufStatus, windowNode.initBufferPosition)

    if settings.highlight.pairOfParen:
      highlight.highlightPairOfParen(bufStatus, windowNode)

    let
      range = windowNode.view.rangeOfOriginalLineInView
      startLine = range.start
      endLine = if bufStatus.buffer.len > range.end + 1: range.end + 2
                elif bufStatus.buffer.len > range.end: range.end + 1
                else: range.end

    var bufferInView = initGapBuffer[seq[Rune]]()
    for i in startLine ..< endLine: bufferInView.add(bufStatus.buffer[i])

    # highlight trailing spaces
    if settings.highlight.trailingSpaces:
      highlight.highlightTrailingSpaces(bufStatus, windowNode)

    # highlight full width space
    if settings.highlight.fullWidthSpace:
      highlight.highlightFullWidthSpace(windowNode, bufferInView, range)

    # highlight search results
    if isSearchHighlight and searchHistory.len > 0:
      highlight.highlightSearchResults(
        bufStatus,
        bufferInView,
        range,
        searchHistory[^1],
        settings,
        isSearchHighlight)
