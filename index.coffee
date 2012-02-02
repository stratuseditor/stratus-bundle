fs     = require 'fs'
_      = require 'underscore'
_path  = require 'path'
{exec} = require 'child_process'

# Cache bundle objects by the bundle name.
cache = {}

# A list of the bundle's that should be installed when `stratus-bundle setup`
# is run.
DEFAULT_BUNDLES = [
  "Bash"
  "C"
  "C.PlusPlus"
  "CSS"
  "CoffeeScript"
  "HTML"
  "HTML.ERB"
  "Haml"
  "JSON"
  "Jade"
  "Java"
  "JavaScript"
  "Markdown"
  "Python"
  "Ruby"
  "Ruby.RSpec"
  "Ruby.Rails"
  "Ruby.Rails.Controller"
  "Ruby.Rails.Model"
  "Ruby.Rails.View"
  "Sass"
  "Stylus"
  "Text"
  "XML"
  "YAML"
]

# Public: Get the bundle with the given name.
# 
# Examples
# 
#   bundle "Ruby"
#   # => #<Bundle>
# 
# Return an instance of Bundle.
module.exports = bundle = (bundleName) ->
  try
    if _path.existsSync bundleName
      b = new Bundle bundleName
      return cache[b.name] ||= b
    else
      return cache[bundleName] ||= new Bundle "#{bundle.dir}/#{bundleName}"
  catch err
    return null


# Internal: The path to the directory which contains the installed bundles.
bundle.dir = _path.resolve process.env.HOME, ".stratus", "bundles"


# Public: Get a list of the names of installed bundles.
# 
# callback - Receives `(err, bundleNames)`.
# 
bundle.list = list = (callback) ->
  fs.readdir bundle.dir, callback


# Invalidate the bundle's cache when it changes.
list (err, bundleNames) ->
  for bundleName in bundleNames
    do (bundleName) ->
      fs.watchFile "#{bundle.dir}/#{bundleName}/syntax.json", ->
        cache[bundleName] = null


# Public: Install the given bundle.
# 
# name     - One of the following
#            "A bundle name, which is matched against the
#              <https://github.com/stratuseditor> repo.
#            "The path to a local bundle.
#            "A URL to a bundle on github.
# callback - Function called upon completion, which receives
#            an error, if any (optional).
# 
# Examples
# 
#   bundle.install "Ruby", (err) ->
#   bundle.install "git://github.com/stratuseditor/JSON.sebundle.git", (err) ->
#   bundle.install "/path/to/Ruby", (err) ->
# 
bundle.install = install = (name, callback) ->
  unresolvable = -> new Error "Cannot find a bundle at '#{name}'"
  
  # URL
  if /^(git|https?):\/\//.test name
    bundleName = /([^\/]+)\.sebundle/.exec(name)[1]
    gitClone name, "#{bundle.dir}/#{bundleName}", (err) ->
      return callback? err
  # Local path
  else if name.indexOf("/") != -1
    return callback? new Error "Unknown source format"
  # From github organization
  else if typeof name == "string"
    list (err, names) ->
      if ~names.indexOf(name)
        return callback? new Error "Bundle '#{name}' is already installed."
      else
        install "git://github.com/stratuseditor/#{name}.sebundle.git", callback
  return


# Public: Install the `DEFAULT_BUNDLES`.
# 
# callback - A function called on completion, with `(err)`.
# 
# Returns nothing.
bundle.setup = (callback) ->
  i = 0
  next = ->
    install DEFAULT_BUNDLES[i], (err) ->
      return callback err if err
      console.log "Installed #{DEFAULT_BUNDLES[i]}"
      if DEFAULT_BUNDLES[++i]
        next()
      else
        return callback null
  next()


# Internal: Clone the repo from github.
# 
# url      - The URL to clone.
# toPath   - The path to clone the repo 
# callback - Receives `(err)`.
# 
gitClone = (url, toPath, callback) ->
  exec "git clone #{url} #{toPath}", (error, stdout, stderr) ->
    callback error


# Public: Uninstall the bundle.
# 
# name     - The name of the bundle to uninstall.
# callback - Called upon completion (optional).
# 
# Examples
# 
#   bundle.uninstall "Ruby", (err) ->
# 
bundle.uninstall = uninstall = (name, callback) ->
  callback  ?= ->
  bundlePath = "#{bundle.dir}/#{name}"
  if !_path.existsSync(bundlePath)
    return callback new Error "Cannot uninstall '#{name}'; no bundle matches."
  
  exec "rm -rf #{bundlePath}", (error, stdout, stderr) ->
    callback error


# Public: Update the bundle.
# 
# name     - The name of the bundle to update.
# callback - Called upon completion (optional).
# 
# Examples
# 
#   bundle.update "Ruby", (err) ->
# 
bundle.update = update = (name, callback) ->
  url = bundle(name).url
  if /^https:\/\/github\.com/.test(url) && !/\.git/.test(url)
    url += ".git"
  uninstall name, (err) ->
    callback? err if err
    install url, (err2) ->
      callback? err2


# Public: Identify the language by its path.
# 
# path      - The path to file file to be identified.
# firstLine - The first line of the file.
# callback  - Receives `(err, bundleName)`.
# 
# Examples
# 
#   bundle.identify "path/to/file.rb", (err, name) ->
#     name # => "Ruby"
#   
#   bundle.identify "path/to/file.py", (err, name) ->
#     name # => "Python"
# 
bundle.identify = identify = (path, firstLine, callback) ->
  [firstLine, callback] = [callback, firstLine] if !callback
  list (err, bundleNames) ->
    throw err if err
    for bundleName in bundleNames
      b = bundle bundleName
      continue unless b
      if b.identify(path, firstLine)
        return callback null, bundleName
    return callback new Error "Path '#{path}' does not match any bundles"


# Public: Test whether or not the bundle is valid.
# 
# path - The path to the bundle.
# 
# Returns Error or null.
bundle.test = (path) ->
  # Required files.
  for file in [path, "#{path}/syntax.json", "#{path}/icon.png"]
    if !_path.existsSync file
      return new Error "'#{file}' is a required file."
  
  # Valid JSON.
  try
    syntax = JSON.parse fs.readFileSync("#{path}/syntax.json").toString()
  catch err
    return new Error "Invalid JSON in '#{path}/syntax.json'" if err
  
  # syntax.json : required properties.
  for prop in ["name", "author", "version"]
    if !syntax[prop]
      return new Error "'#{prop}' is a required field in syntax.json"
  
  if syntax.syntax && !syntax.syntax.$
    return new Error "The syntax option must have a `$` property"
  
  return null


bundle.Bundle = class Bundle
  constructor: (@path) ->
    err = bundle.test @path
    throw err if err
    
    syntaxData = JSON.parse fs.readFileSync("#{@path}/syntax.json").toString()
    {@name, @version, @extends} = syntaxData
    
    @defaults()
    
    { @url, @author, require,
      @fileTypes, firstLine, syntax,
      preferences } = syntaxData
    {tab, indent, outdent, pairs} = preferences || {}
    
    # Override defaults.
    @require     = _.union @require, (require || [])
    @fileTypes ||= []
    @tab         = tab if tab
    @pairs       = _.extend @pairs, (pairs || {})
    
    # Indent/outdent
    if indent
      @indent = _.union @indent,  indent  
    if outdent
      @outdent = _.union @outdent, outdent
    
    # Syntax inheritance
    # Extend the syntax rules and contexts.
    if syntax
      syntax[@name] = syntax.$
      delete syntax.$
    for context, rules of (syntax || {})
      if rules instanceof Array
        @syntax[context] ||= []
        for rule in rules
          # Ignore comments in the syntax
          @syntax[context].push rule unless typeof rule == "string"
      else
        @syntax[context] = rules
    
    # Default values
    @firstLine = new RegExp firstLine if firstLine
  
  
  # Public: Convert to an object ready to be sent to the client.
  # 
  # Return nothing.
  toJSON: (callback) ->
    data = @toJSONSync()
    @completions (words) =>
      data.completions = words
      return callback data
  
  # Public: Same as `toJSON`, but synchronous, and doesn't include
  # the completions.
  # 
  # Returns an Object.
  toJSONSync: ->
    { @name, @version, @url, @author
    , @extends, @require
    , @tab, @pairs
    , indent:  @indentRegex()?.source
    , outdent: @outdentRegex()?.source
    , @syntax}
  
  # Internal: Copy properties from the parent bundle.
  # 
  # Returns nothing.
  defaults: ->
    if @extends
      @parent        = bundle @extends
      {@tab}         = @parent
      @require       = @parent.require.slice()
      @indent        = @parent.indent.slice()
      @outdent       = @parent.outdent.slice()
      @pairs         = @parent.pairs
      @syntax        = _.clone @parent.syntax
      @syntax[@name] = @syntax[@extends]
      delete @syntax[@extends]
    else
      @require = []
      @tab     = "    "
      @syntax  = {}
      @indent  = []
      @outdent = []
      @pairs   = {}
  
  
  # Public: Get a list of the words to auto-complete.
  # 
  # callback - Receives the array of string words.
  # 
  completions: (callback) ->
    completionPath = "#{@path}/completions.txt"
    return callback [] if !_path.existsSync completionPath
    fs.readFile completionPath, (err, data) ->
      throw err if err
      words = data.toString().split("\n")
      words = _.reject words, ((w)-> w == "")
      return callback words.sort()
  
  
  # Public: Get the path to the icon.png file.
  # 
  # Return the string path.
  icon: -> "#{@path}/icon.png"
  
  
  # Public: Return whether or not the bundle applies to the given file.
  # 
  # path      - The path of the file to check.
  # firstLine - The first line of the file (optional). Used to check for
  #             shebangs.
  # 
  # Examples
  # 
  #   bundle("Ruby").identify "path/to/file.rb"
  #   # => true
  # 
  #   bundle("Ruby").identify "path/to/file.py"
  #   # => false
  # 
  #   bundle("Ruby").identify "path/to/file", "#!/usr/bin/env ruby"
  #   # => true
  # 
  # Return boolean.
  identify: (path, firstLine=null) ->
    if @fileTypes.length && @fileTypesRegex().test path
      return true
    else if firstLine && @firstLine?.test(firstLine)
      return true
    else
      return false
  
  
  # Public: If a line matches the returned RegExp, the following line
  # should be indented.
  # 
  # Return a RegExp, or null if there are no indent rules.
  indentRegex: ->
    return null unless @indent.length
    return new RegExp @arrayToRegexString @indent
  
  # Public: If a line matches the returned RegExp, the line
  # should be outdented.
  # 
  # All of the regexps are automatically matched against
  # the end of the string.
  # 
  # Return a RegExp, or null if there are no outdent rules.
  outdentRegex: ->
    return null unless @outdent.length
    return new RegExp "(?:#{ @arrayToRegexString(@outdent) })$"
  
  # Public: If a path matches this regexp, the bundle applies.
  # 
  # Return a RegExp.
  fileTypesRegex: ->
    @_fileTypesRegex ||= new RegExp "(?:#{@arrayToRegexString(@fileTypes)})$"
    return @_fileTypesRegex
  
  # Internal: Convert a list of strings into a string ready to be
  # RegExpified.
  # 
  # Examples
  # 
  #   @arrayToRegexString ["if\\s", "else\\s"]
  #   # => "(?:if\\s)|(?:else\\s)"
  # 
  # Returns String.
  arrayToRegexString: (arr) ->
    return "(?:#{ arr.join(")|(?:") })"

