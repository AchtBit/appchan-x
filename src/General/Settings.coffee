Settings =
  init: ->
    # Appchan X settings link
    el = $.el 'a',
      className:   'settings-link'
      title:       'Appchan X Settings'
      href:        'javascript:;'
      textContent: 'Settings'
    $.on el, 'click', @open

    Header.menu.addEntry
      el: el
      order: 1

    {addSection} = @
    addSection arr[1], Settings[arr[0]] for arr in [
      ['style',    'Style']
      ['themes',   'Themes']
      ['mascots',  'Mascots']
      ['main',     'Script']
      ['filter',   'Filter']
      ['sauce',    'Sauce']
      ['advanced', 'Advanced']
      ['keybinds', 'Keybinds']
    ]

    $.on d, 'OpenSettings', (e) -> Settings.open e.detail

    settings = JSON.parse(localStorage.getItem '4chan-settings') or {}
    unless settings.disableAll
      settings.disableAll = true
      check = true
    if settings.keyBinds
      # Keybinds persist even with disableAll. Thanks moot.
      settings.keyBinds = false
      check = true
    localStorage.setItem '4chan-settings', JSON.stringify settings if check

  open: (openSection) ->
    if Conf['editMode'] is "theme"
      if confirm "Opening the options dialog will close and discard any theme changes made with the theme editor."
        ThemeTools.close()
      return

    if Conf['editMode'] is "mascot"
      if confirm "Opening the options dialog will close and discard any mascot changes made with the mascot editor."
        MascotTools.close()
      return

    return if Settings.overlay
    $.event 'CloseMenu'

    Settings.dialog = dialog = $.el 'div',
      id:    'appchanx-settings'
      class: 'dialog'
      innerHTML: <%= importHTML('Settings/Settings') %>

    Settings.overlay = overlay = $.el 'div',
      id: 'overlay'

    $.on $('.export', dialog), 'click',  Settings.export
    $.on $('.import', dialog), 'click',  Settings.import
    $.on $('.reset',  dialog), 'click',  Settings.reset
    $.on $('input',   dialog), 'change', Settings.onImport


    links = []
    for section in Settings.sections
      link = $.el 'a',
        className: "tab-#{section.hyphenatedTitle}"
        textContent: section.title
        href: 'javascript:;'
      $.on link, 'click', Settings.openSection.bind section
      links.push link
      sectionToOpen = link if section.title is openSection
    $.add $('.sections-list', dialog), links
    (if sectionToOpen then sectionToOpen else links[0]).click() unless openSection is 'none'

    $.on $('.close', dialog), 'click', Settings.close
    $.on overlay,             'click', Settings.close

    $.add d.body, [overlay, dialog]

    $.event 'OpenSettings', null, dialog

  close: ->
    return unless Settings.dialog
    $.rm Settings.overlay
    $.rm Settings.dialog
    delete Settings.overlay
    delete Settings.dialog

  sections: []

  addSection: (title, open) ->
    hyphenatedTitle = title.toLowerCase().replace /\s+/g, '-'
    Settings.sections.push {title, hyphenatedTitle, open}

  openSection: (mode) ->
    if selected = $ '.tab-selected', Settings.dialog
      $.rmClass selected, 'tab-selected'
    $.addClass $(".tab-#{@hyphenatedTitle}", Settings.dialog), 'tab-selected'
    section = $ 'section', Settings.dialog
    $.rmAll section
    section.className = "section-#{@hyphenatedTitle}"
    @open section, mode
    section.scrollTop = 0
    $.event 'OpenSettings', null, section

  main: (section) ->
    items  = {}
    inputs = {}
    for key, obj of Config.main
      fs = $.el 'fieldset',
        innerHTML: "<legend>#{key}</legend>"
      for key, arr of obj
        description = arr[1]
        div = $.el 'div',
          innerHTML: "<label><input type=checkbox name='#{key}'>#{key}</label><span class=description>#{description}</span>"
        input = $ 'input', div
        $.on $('label', div), 'mouseover', Settings.mouseover
        $.on input, 'change', $.cb.checked
        items[key]  = Conf[key]
        inputs[key] = input
        $.add fs, div
      Rice.nodes fs
      $.add section, fs

    $.get items, (items) ->
      for key, val of items
        inputs[key].checked = val
      return

    div = $.el 'div',
      innerHTML: "<button></button><span class=description>: Clear manually-hidden threads and posts on all boards. Reload the page to apply."
    button = $ 'button', div
    $.get 'hiddenPosts', {}, ({hiddenPosts}) ->
      hiddenNum = 0
      for ID, board of hiddenPosts.boards
        for ID, thread of board
          hiddenNum += Object.keys(thread).length
      button.textContent = "Hidden: #{hiddenNum}"
    $.on button, 'click', ->
      @textContent = 'Hidden: 0'
      $.delete 'hiddenPosts'
    $.after $('input[name="Recursive Hiding"]', section).parentNode.parentNode, div

  export: ->
    # Make sure to export the most recent data.
    $.get Conf, (Conf) ->
      # XXX don't export archives.
      delete Conf['archives']
      Settings.downloadExport 'Settings', {version: g.VERSION, date: Date.now(), Conf}

  downloadExport: (title, data) ->
    a = $.el 'a',
      download: "<%= meta.name %> v#{g.VERSION} #{title}.#{data.date}.json"
      href: "data:application/json;base64,#{btoa unescape encodeURIComponent JSON.stringify data, null, 2}"
    <% if (type === 'userscript') { %>$.add d.body, a<% } %>
    a.click()
    <% if (type === 'userscript') { %>$.rm a<% } %>
  import: ->
    $('input[type=file]', @parentNode).click()

  onImport: ->
    return unless file = @files[0]
    return unless confirm 'Your current settings will be entirely overwritten, are you sure?'

    reader = new FileReader()
    reader.onload = (e) ->
      try
        Settings.loadSettings JSON.parse e.target.result
      catch err
        alert 'Import failed due to an error.'
        c.error err.stack
        return
      if confirm 'Import successful. Reload now?'
        window.location.reload()
    reader.readAsText file

  loadSettings: (data) ->
    if data.Conf['WatchedThreads']
      data.Conf['watchedThreads'] = boards: ThreadWatcher.convert data.Conf['WatchedThreads']
      delete data.Conf['WatchedThreads']
    $.clear -> $.set data.Conf

  reset: ->
    if confirm 'Your current settings will be entirely wiped, are you sure?'
      $.clear -> window.location.reload() if confirm 'Reset successful. Reload now?'

  filter: (section) ->
    section.innerHTML = <%= importHTML('Settings/Filter-select') %>
    select = $ 'select', section
    $.on select, 'change', Settings.selectFilter
    Settings.selectFilter.call select

  selectFilter: ->
    div = @nextElementSibling
    if (name = @value) isnt 'guide'
      $.rmAll div
      ta = $.el 'textarea',
        name: name
        className: 'field'
        spellcheck: false
      $.get name, Conf[name], (item) ->
        ta.value = item[name]
      $.on ta, 'change', $.cb.value
      $.add div, ta
      return
    div.innerHTML = <%= importHTML('Settings/Filter-guide') %>

  sauce: (section) ->
    section.innerHTML = <%= importHTML('Settings/Sauce') %>
    ta = $ 'textarea', section
    $.get 'sauces', Conf['sauces'], (item) ->
      # XXX remove .replace func after 31-7-2013 (v1 transitioning)
      ta.value = item['sauces'].replace /\$\d/g, (c) ->
        switch c
          when '$1'
            '%TURL'
          when '$2'
            '%URL'
          when '$3'
            '%MD5'
          when '$4'
            '%board'
          else
            c
    $.on ta, 'change', $.cb.value

  advanced: (section) ->
    section.innerHTML = <%= importHTML('Settings/Advanced') %>
    items = {}
    inputs = {}
    for name in ['boardnav', 'time', 'backlink', 'fileInfo', 'favicon', 'usercss', 'additionalCooldown']
      input = $ "[name='#{name}']", section
      items[name]  = Conf[name]
      inputs[name] = input
      event = if name in ['favicon', 'usercss']
        'change'
      else
        'input'
      $.on input, event, $.cb.value

    # Quick Reply Personas
    ta = $ '.personafield', section
    $.get 'QR.personas', Conf['QR.personas'], (item) ->
      ta.value = item['QR.personas']
    $.on ta, 'change', $.cb.value

    $.get items, (items) ->
      for key, val of items
        input = inputs[key]
        input.value = val
        continue if key is 'usercss' or 'additionalCooldown'
        $.on input, event, Settings[key]
        Settings[key].call input
      Rice.nodes section

    $.on $('input[name=Interval]', section), 'change', ThreadUpdater.cb.interval
    $.on $('input[name="Custom CSS"]', section), 'change', Settings.togglecss
    $.on $.id('apply-css'), 'click', Settings.usercss

    archBoards = {}
    for {name, boards, files, software, withCredentials} in Redirect.archives
      for boardID in boards
        o = archBoards[boardID] or=
          thread: [[], []]
          post:   [[], []]
          file:   [[], []]
        i = +!!withCredentials
        o.thread[i].push name
        o.post[i].push   name if software is 'foolfuuka'
        o.file[i].push   name if boardID in files
    for boardID, o of archBoards
      for item in ['thread', 'post', 'file']
        if o[item][0].length is 0 and o[item][1].length isnt 0
          o[item][0].push 'disabled'
        o[item] = o[item][0].concat(o[item][1])

    rows = []
    boardOptions = []
    for boardID in Object.keys(archBoards).sort() # Alphabetical order
      row = $.el 'tr',
        className: "board-#{boardID}"
      row.hidden = boardID isnt g.BOARD.ID

      boardOptions.push $.el 'option',
        textContent: "/#{boardID}/"
        value:       "board-#{boardID}"
        selected:    boardID is g.BOARD.ID

      o = archBoards[boardID]
      $.add row, Settings.addArchiveCell boardID, o, item for item in ['thread', 'post', 'file']
      rows.push row

    $.add $('tbody', section), rows

    boardSelect = $('#archive-board-select', section)
    $.add boardSelect, boardOptions
    table = $.id 'archive-table'
    $.on boardSelect, 'change', ->
      $('tbody > :not([hidden])', table).hidden = true
      $("tbody > .#{@value}", table).hidden = false

    $.get 'selectedArchives', Conf['selectedArchives'], ({selectedArchives}) ->
      for boardID, data of selectedArchives
        for type, name of data
          if option = $ "select[data-boardid='#{boardID}'][data-type='#{type}'] > option[value='#{name}']", section
            option.selected = true
      return
    return

  addArchiveCell: (boardID, data, type) ->
    {length} = data[type]
    td = $.el 'td',
      className: 'archive-cell'

    unless length
      td.textContent = '--'
      return td

    options = []
    i = 0
    while i < length
      archive = data[type][i++]
      options.push $.el 'option',
        textContent: archive
        value: archive

    td.innerHTML = '<select></select>'
    select = td.firstElementChild
    unless select.disabled = length is 1
      # XXX GM can't into datasets
      select.setAttribute 'data-boardid', boardID
      select.setAttribute 'data-type', type
      $.on select, 'change', Settings.saveSelectedArchive
    $.add select, options

    td

  saveSelectedArchive: ->
    $.get 'selectedArchives', Conf['selectedArchives'], ({selectedArchives}) =>
      (selectedArchives[@dataset.boardid] or= {})[@dataset.type] = @value
      $.set 'selectedArchives', selectedArchives

  boardnav: ->
    Header.generateBoardList @value

  time: ->
    @nextElementSibling.textContent = Time.format @value, new Date()

  backlink: ->
    @nextElementSibling.textContent = @value.replace /%id/g, '123456789'

  fileInfo: ->
    data =
      isReply: true
      file:
        URL: '//i.4cdn.org/g/1334437723720.jpg'
        name: 'd9bb2efc98dd0df141a94399ff5880b7.jpg'
        size: '276 KB'
        sizeInBytes: 276 * 1024
        dimensions: '1280x720'
        isImage: true
        isVideo: false
        isSpoiler: true
    @nextElementSibling.innerHTML = FileInfo.format @value, data

  favicon: ->
    Favicon.init()
    Unread.update() if g.VIEW is 'thread' and Conf['Unread Favicon']
    $.id('favicon-preview').innerHTML = """
      <img src=#{Favicon.default}>
      <img src=#{Favicon.unreadSFW}>
      <img src=#{Favicon.unreadNSFW}>
      <img src=#{Favicon.unreadDead}>
      """

  togglecss: ->
    if $('textarea', @parentNode.parentNode).disabled = !@checked
      CustomCSS.rmStyle()
    else
      CustomCSS.addStyle()
    $.cb.checked.call @

  usercss: ->
    CustomCSS.update()

  keybinds: (section) ->
    section.innerHTML = <%= importHTML('Settings/Keybinds') %>

    tbody  = $ 'tbody', section
    items  = {}
    inputs = {}
    for key, arr of Config.hotkeys
      tr = $.el 'tr',
        innerHTML: "<td>#{arr[1]}</td><td><input class=field></td>"
      input = $ 'input', tr
      input.name = key
      input.spellcheck = false
      items[key]  = Conf[key]
      inputs[key] = input
      $.on input, 'keydown', Settings.keybind
      Rice.nodes tr
      $.add tbody, tr

    $.get items, (items) ->
      for key, val of items
        inputs[key].value = val
      return

  keybind: (e) ->
    return if e.keyCode is 9 # tab
    e.preventDefault()
    e.stopPropagation()
    return unless (key = Keybinds.keyCode e)?
    @value = key
    $.cb.value.call @

  style: (section) ->
    nodes  = $.frag()
    items  = {}
    inputs = {}

    for key, obj of Config.style

      fs = $.el 'fieldset',
        innerHTML: "<legend>#{key}</legend>"

      for key, arr of obj
        [value, description, type] = arr

        div = $.el 'div',
          className: 'styleoption'

        if type

          if type is 'text'

            div.innerHTML = "<div class=option><span class=optionlabel>#{key}</span></div><div class=description>#{description}</div><div class=option><input name='#{key}' style=width: 100%></div>"
            input = $ "input", div

          else

            html = "<div class=option><span class=optionlabel>#{key}</span></div><div class=description>#{description}</div><div class=option><select name='#{key}'>"
            for name in type
              html += "<option value='#{name}'>#{name}</option>"
            html += "</select></div>"
            div.innerHTML = html
            input = $ "select", div

        else

          div.innerHTML = "<div class=option><label><input type=checkbox name='#{key}'>#{key}</label></div><span style='display:none;'>#{description}</span>"
          input = $ 'input', div

        items[key]  = Conf[key]
        inputs[key] = input

        $.on $('.option', div), 'mouseover', Settings.mouseover

        $.add fs, div
      $.add nodes, fs

    $.get items, (items) ->
      cb = Settings.cb.style
      for key, val of items
        input = inputs[key]
        if input.type is 'checkbox'
          input.checked = val
          $.on input, 'change', cb.checked
        else if input.nodeName is 'SELECT'
          input.value = val
          $.on input, 'change', cb.select
        else
          input.value = val
          $.on input, 'change', cb.value

      Rice.nodes nodes
      $.add section, nodes

  themes: (section, mode) ->
    if typeof mode isnt 'string'
      mode = 'default'

    parentdiv  = $.el 'div',
      id:        "themeContainer"

    suboptions = $.el 'div',
      className: "suboptions"
      id:        "themes"

    keys = Object.keys(Themes)
    keys.sort()

    cb = Settings.cb.theme
    mouseover = -> @style.color = "#{@dataset.hover}"
    mouseout  = -> @style.color = "#{@dataset.color}"

    if mode is "default"

      for name in keys
        theme = Themes[name]

        continue if theme["Deleted"]

        div = $.el 'div',
          className: "theme #{if name is Conf[g.THEMESTRING] then 'selectedtheme' else ''}"
          id:        name
          innerHTML: """<%= grunt.file.read('src/General/html/Settings/Theme.html').replace(/>\s+</g, '><').trim() %>"""

        div.style.backgroundColor = theme['Background Color']

        for a in $$ 'a[data-color]', div
          a.style.color = "#{a.dataset.color}"
          $.on a, 'mouseover', mouseover
          $.on a, 'mouseout',  mouseout

        $.on $('a.edit',   div), 'click', cb.edit
        $.on $('a.export', div), 'click', cb.export
        $.on $('a.delete', div), 'click', cb.delete

        $.on div, 'click', cb.select

        $.add suboptions, div

      div = $.el 'div',
        id:        'addthemes'
        innerHTML: """<%= grunt.file.read('src/General/html/Settings/Batch-Theme.html').replace(/>\s+</g, '><').trim() %>"""

      $.on $("#newtheme", div), 'click', ->
        ThemeTools.init "untitled"
        Settings.close()

      $.on $("#import", div), 'click', ->
        @nextSibling.click()

      $.on $("#importbutton", div), 'change', ThemeTools.importtheme

      $.on $('#tUndelete', div), 'click', ->
        $.rm $.id "themeContainer"

        themes =
          open:            Settings.themes
          hyphenatedTitle: 'themes'

        Settings.openSection.apply themes, ['undelete']

    else

      for name in keys
        theme = Themes[name]

        continue unless theme["Deleted"]

        div = $.el 'div',
          id:        name
          className: theme
          innerHTML: """<%= grunt.file.read('src/General/html/Settings/Deleted-Theme.html').replace(/>\s+</g, '><').trim() %>"""

        $.on div, 'click', cb.restore

        $.add suboptions, div

      div = $.el 'div',
        id:        'addthemes'
        innerHTML: "<a href='javascript:;'>Return</a>"

      $.on $('a', div), 'click', ->
        themes =
          open:            Settings.themes
          hyphenatedTitle: 'themes'

        $.rm $.id "themeContainer"
        Settings.openSection.call themes

    $.add parentdiv, suboptions
    $.add parentdiv, div
    $.add section, parentdiv

  mouseover: (e) ->
    mouseover = $.el 'div',
      id:        'mouseover'
      className: 'dialog'

    $.add Header.hover, mouseover

    mouseover.innerHTML = @nextElementSibling.innerHTML

    UI.hover
      root:        @
      el:          mouseover
      latestEvent: e
      endEvents:   'mouseout'
      asapTest: -> true
      offsetX: 15
      offsetY: -5

    return

  mascots: (section, mode) ->
    categories = {}
    cb         = Settings.cb.mascot

    if typeof mode isnt 'string'
      mode = 'default'

    suboptions = $.el "div",
      className: "suboptions"

    mascotHide = $.el "div",
      id: "mascot_hide"
      className: "reply"
      innerHTML: "Hide Categories <span class=drop-marker></span><div></div>"

    keys = Object.keys Mascots
    keys.sort()

    if mode is 'default'
      mascotoptions = $.el 'div',
        id: 'mascot-options'
        innerHTML: """<a class=edit href='javascript:;'>Edit</a><a class=delete href='javascript:;'>Delete</a><a class=export href='javascript:;'>Export</a>"""

      $.on $('.edit',   mascotoptions), 'click', cb.edit
      $.on $('.delete', mascotoptions), 'click', cb.delete
      $.on $('.export', mascotoptions), 'click', cb.export

      addoptions = ->
        return if mascotoptions.parentElement is @
        $.add @, mascotoptions

      # Create a keyed Unordered List Element and hide option for each mascot category.
      for name in MascotTools.categories
        menu = $ 'div', mascotHide
        categories[name] = div = $.el "div",
          id:        name
          className: "mascots-container"
          innerHTML: "<h3 class=mascotHeader>#{name}</h3>"
          hidden:    name in Conf["Hidden Categories"]

        option = $.el "label",
          name: name
          innerHTML: "<input name='#{name}' type=checkbox #{if name in Conf["Hidden Categories"] then 'checked' else ''}>#{name}"

        $.on $('input', option), 'change', cb.category

        $.add suboptions, div
        $.add menu, option

      for name in keys
        continue if name in Conf["Deleted Mascots"]
        mascot = Mascots[name]
        mascotEl = $.el 'div',
          id:        name
          className: if name in Conf[g.MASCOTSTRING] then 'mascot enabled' else 'mascot'
          innerHTML: "<%= grunt.file.read('src/General/html/Settings/Mascot.html') %>"

        $.on mascotEl, 'click', cb.select
        $.on mascotEl, 'mouseover', addoptions

        $.add (categories[mascot.category] or categories[MascotTools.categories[0]]), mascotEl

      batchmascots = $.el 'div',
        id: "mascots_batch"
        innerHTML: """<%= grunt.file.read('src/General/html/Settings/Batch-Mascot.html') %>"""

      $.on $('#clear', batchmascots), 'click', ->
        enabledMascots = JSON.parse(JSON.stringify(Conf[g.MASCOTSTRING]))
        for name in enabledMascots
          $.rmClass $.id(name), 'enabled'
        $.set g.MASCOTSTRING, Conf[g.MASCOTSTRING] = []

      $.on $('#selectAll', batchmascots), 'click', ->
        for name, mascot of Mascots
          unless mascot.category in Conf["Hidden Categories"] or name in Conf[g.MASCOTSTRING] or name in Conf["Deleted Mascots"]
            $.addClass $.id(name), 'enabled'
            Conf[g.MASCOTSTRING].push name
        $.set g.MASCOTSTRING, Conf[g.MASCOTSTRING]

      $.on $('#createNew', batchmascots), 'click', ->
        MascotTools.dialog()
        Settings.close()

      $.on $("#importMascot", batchmascots), 'click', ->
        @nextSibling.click()

      $.on $("#importMascotButton", batchmascots), 'change', MascotTools.importMascot

      $.on $('#undelete', batchmascots), 'click', ->
        unless Conf["Deleted Mascots"].length > 0
          alert "No mascots have been deleted."
          return
        mascots =
          open:            Settings.mascots
          hyphenatedTitle: 'mascots'
        Settings.openSection.apply mascots, ['restore']

    else
      container = $.el "div",
        className: "mascots"

      for name in keys when name in Conf["Deleted Mascots"]
        mascot = Mascots[name]
        mascotEl = $.el 'div',
          className: 'mascot' 
          id: name
          innerHTML: "
<div class='mascotname'>#{name.replace /_/g, " "}</span>
<div class='mascotcontainer #{mascot.category} #{if mascot.silhouette then 'silhouette' else ''}'><img class=mascotimg src='#{mascot.image}'></div>
"

        $.on mascotEl, 'click', cb.restore

        $.add container, mascotEl

      $.add suboptions, container

      batchmascots = $.el 'div',
        id: "mascots_batch"
        innerHTML: """<a href="javascript:;" id="return">Return</a>"""

      $.on $('#return', batchmascots), 'click', ->
        mascots =
          open:            Settings.mascots
          hyphenatedTitle: 'mascots'
        Settings.openSection.apply mascots

    for node in [suboptions, batchmascots, mascotHide]
      Rice.nodes node

    $.add section, [suboptions, batchmascots, mascotHide]

  cb:
    style:
      checked: ->
        $.cb.checked.call @
        return if @name in ['NSFW/SFW Themes', 'NSFW/SFW Mascots']
        hyphenated = @name.toLowerCase().replace(/^4/, 'four').replace /\s+/g, '-'
        (if @checked then $.addClass else $.rmClass) doc, hyphenated

      value: ->
        $.cb.value.call @
        Style.sheets.dynamic.textContent = Style.dynamic()

      select: ->
        $.cb.value.call @
        for option in @options
          hyphenated = "#{@name} #{option.value}".toLowerCase().replace(/^4/, 'four').replace /\s+/g, '-'
          (if option.value is @value then $.addClass else $.rmClass) doc, hyphenated
        return

    mascot:
      category: ->
        if $.id(@name).hidden = @checked
          Conf["Hidden Categories"].push @name

          # Gather all names of enabled mascots in the hidden category in every context it could be enabled.
          for type in ["Enabled Mascots", "Enabled Mascots sfw", "Enabled Mascots nsfw"]
            setting = Conf[type]
            i = setting.length

            while i--
              name = setting[i]
              continue unless Mascots[name].category is @name
              setting.splice i, 1
              continue unless type is g.MASCOTSTRING
              $.rmClass $.id(name), 'enabled'
              if Conf['mascot'] is name
                cb = MascotTools.toggle
            $.set type, setting

        else
          $.remove Conf["Hidden Categories"], @name

        $.set "Hidden Categories", Conf["Hidden Categories"]

        cb() if cb

      edit: (e) ->
        e.stopPropagation()
        MascotTools.dialog @parentElement.parentElement.id
        Settings.close()

      delete: (e) ->
        e.stopPropagation()
        name = @parentElement.parentElement.id
        if confirm "Are you sure you want to delete \"#{name}\"?"
          if Conf['mascot'] is name
            MascotTools.toggle()
          for type in ["Enabled Mascots", "Enabled Mascots sfw", "Enabled Mascots nsfw"]
            $.remove Conf[type], name
            $.set type, Conf[type]
          Conf["Deleted Mascots"].push name
          $.set "Deleted Mascots", Conf["Deleted Mascots"]
          $.rm $.id name

      export: (e) ->
        e.stopPropagation()
        name = @parentElement.parentElement.id
        data = Mascots[name]
        data['Mascot'] = name

        a = $.el 'a',
          className: 'export-button'
          textContent: 'Save me!'
          download: "#{name}-#{Date.now()}.json"
          href: "data:application/json;base64,#{btoa unescape encodeURIComponent JSON.stringify data, null, 2}"
          target: '_blank'
        <% if (type !== 'userscript') { %>
        a.click()
        <% } else { %>
        # XXX Firefox won't let us download automatically.
        $.on a, 'click', (e) ->
          e.stopPropagation()
        $.add @parentElement.parentElement, a
        <% } %>

      restore: ->
        if confirm "Are you sure you want to restore \"#{@id}\"?"
          $.remove Conf["Deleted Mascots"], @id
          $.set "Deleted Mascots", Conf["Deleted Mascots"]
          $.rm @

      select: ->
        string = g.MASCOTSTRING
        if $.remove Conf[string], @id
          if Conf['mascot'] is @id
            MascotTools.toggle()
        else
          Conf['mascot'] = @id
          Conf[string].push @id
          MascotTools.change Mascots[@id]
        $.toggleClass @, 'enabled'
        $.set string, Conf[string]
        $.set string, Conf[string]

    theme:
      select: ->
        if current = $.id(Conf[g.THEMESTRING])
          $.rmClass current, 'selectedtheme'

        $.set g.THEMESTRING, Conf[g.THEMESTRING] = @id
        $.addClass @, 'selectedtheme'
        Style.setTheme Themes[@id]

      edit: (e) ->
        e.preventDefault()
        e.stopPropagation()
        ThemeTools.init @name
        Settings.close()

      export: (e) ->
        e.preventDefault()
        e.stopPropagation()
        data = Themes[@name]
        data['Theme'] = @name

        a = $.el 'a',
          textContent: '>>Save me!'
          download: "#{@name}-#{Date.now()}.json"
          href: "data:application/json;base64,#{btoa unescape encodeURIComponent JSON.stringify data, null, 2}"
          target: '_blank'
        <% if (type !== 'userscript') { %>
        a.click()
        <% } else { %>
        # XXX Firefox won't let us download automatically.
        $.on a, 'click', (e) ->
          e.stopPropagation()
        $.replace @, a
        <% } %>

      delete: (e) ->
        e.preventDefault()
        e.stopPropagation()
        container = $.id @name

        unless container.previousSibling or container.nextSibling
          alert "Cannot delete theme (No other themes available)."
          return

        if confirm "Are you sure you want to delete \"#{@name}\"?"
          if @name is Conf[g.THEMESTRING]
            if settheme = container.previousSibling or container.nextSibling
              Conf[g.THEMESTRING] = settheme.id
              $.addClass settheme, 'selectedtheme'
              $.set g.THEMESTRING, Conf[g.THEMESTRING]
          Themes[@name]["Deleted"] = true

          $.get "userThemes", {}, ({userThemes}) =>
            userThemes[@name] = Themes[@name]
            $.set 'userThemes', userThemes
            $.rm container

      restore: ->
        if confirm "Are you sure you want to restore \"#{@id}\"?"
          Themes[@id]["Deleted"] = false

          $.get "userThemes", {}, ({userThemes}) =>
            userThemes[@id] = Themes[@id]
            $.set 'userThemes', userThemes
            $.rm @
