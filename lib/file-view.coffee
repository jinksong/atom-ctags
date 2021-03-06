{$$} = require 'atom-space-pen-views'
SymbolsView = require './symbols-view'

module.exports =
class FileView extends SymbolsView
  initialize: ->
    super

    @editorsSubscription = atom.workspace.observeTextEditors (editor) =>
      disposable = editor.onDidSave =>
        buffer = editor.getBuffer()
        return unless buffer.isModified()
          f = buffer.getPath()
          return unless atom.project.contains(f)
          @ctagsCache.generateTags(f)

      editor.onDidDestroy -> disposable.dispose()

  destroy: ->
    @editorsSubscription.dispose()
    super

  viewForItem: ({position, name, file, pattern}) ->
    $$ ->
      @li class: 'two-lines', =>
        @div class: 'primary-line', =>
          @span name, class: 'pull-left'
          @span pattern, class: 'pull-right'

        @div class: 'secondary-line', =>
          @span "Line #{position.row + 1}", class: 'pull-left'
          @span file, class: 'pull-right'

  toggle: ->
    if @panel.isVisible()
      @cancel()
    else
      editor = atom.workspace.getActiveTextEditor()
      return unless editor
      filePath = editor.getPath()
      @cancelPosition = editor.getCursorBufferPosition()
      @populate(filePath)
      @attach()

  cancel: ->
    super
    @scrollToPosition(@cancelPosition, false) if @cancelPosition
    @cancelPosition = null

  toggleAll: ->
    if @panel.isVisible()
      @cancel()
    else
      @list.empty()
      @maxItems = 10
      tags = []
      for key, val of @ctagsCache.cachedTags
        tags.push val...
      @setItems(tags)
      @attach()

  getCurSymbol: ->
    editor = atom.workspace.getActiveTextEditor()
    if not editor
      console.error "[atom-ctags:getCurSymbol] failed getActiveTextEditor "
      return

    cursor = editor.getLastCursor()
    if cursor.getScopes().indexOf('source.ruby') isnt -1
      # Include ! and ? in word regular expression for ruby files
      range = cursor.getCurrentWordBufferRange(wordRegex: /[\w!?]*/g)
    else
      range = cursor.getCurrentWordBufferRange()
    return editor.getTextInRange(range)

  rebuild: ->
    projectPaths = atom.project.getPaths()
    if projectPaths.length < 1
      console.error "[atom-ctags:rebuild] cancel rebuild, invalid projectPath: #{projectPath}"
      return
    @ctagsCache.cachedTags = {}
    @ctagsCache.generateTags projectPath for projectPath in projectPaths

  goto: ->
    symbol = @getCurSymbol()
    if not symbol
      console.error "[atom-ctags:goto] failed getCurSymbol"
      return

    tags = @ctagsCache.findTags(symbol)

    if tags.length is 1
      @openTag(tags[0])
    else
      @setItems(tags)
      @attach()

  populate: (filePath) ->
    @list.empty()
    @setLoading('Generating symbols\u2026')

    @ctagsCache.getOrCreateTags filePath, (tags) =>
      @maxItem = Infinity
      @setItems(tags)

  scrollToItemView: (view) ->
    super
    return unless @cancelPosition

    tag = @getSelectedItem()
    @scrollToPosition(tag.position)

  scrollToPosition: (position, select = true)->
    if editor = atom.workspace.getActiveTextEditor()
      editor.scrollToBufferPosition(position, center: true)
      editor.setCursorBufferPosition(position)
      editor.selectWordsContainingCursors() if select
