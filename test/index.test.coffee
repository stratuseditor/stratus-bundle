should = require 'should'
bundle = require '../'

ruby       = bundle "Ruby"
rails      = bundle "Ruby.Rails"
railsModel = bundle "Ruby.Rails.Model"

describe "bundle", ->
  describe "()", ->
    describe "normal", ->
      it "returns a bundle", ->
        ruby.should.be.an.instanceof bundle.Bundle
      
      it "with the correct directory", ->
        ruby.path.should.match /\/Ruby$/
    
    describe "invalid bundles", ->
      describe "a nonexistant bundle", ->
        it "returns null", ->
          should.not.exist bundle "DoesNotExists"
      
      describe "a bundle without the name property", ->
        it "returns null", ->
          should.not.exist bundle "./test/cases/NoName"
  
  describe ".dir", ->
    it "is a string", ->
      bundle.dir.should.be.a "string"
  
  
  describe ".list", ->
    it "is a list of string", (done) ->
      bundle.list (err, names) ->
        names.should.be.an.instanceof Array
        names[0].should.be.a "string"
        done()
    
    it "includes valid bundle names", (done) ->
      bundle.list (err, names) ->
        should.doesNotThrow ->
          bundle names[0]
          done()
  
  
  describe ".identify", ->
    describe "a ruby file", ->
      it "is identified as 'Ruby'", (done) ->
        bundle.identify "path/to/file.rb", (err, name) ->
          should.not.exist err
          name.should.eql "Ruby"
          done()
    
    describe "an unidentifiable file", ->
      it "passes an error", (done) ->
        bundle.identify "path/to/file", (err, name) ->
          err.should.be.an.instanceof Error
          should.not.exist name
          done()
  
  
  describe "Bundle", ->
    describe "#constructor", ->
      fields = ["name", "path", "url", "version",
                "author", "require",
                "fileTypes", "firstLine",
                "tab", "indent", "outdent", "syntax"]
      for field in fields
        it "assigns #{field}", ->
          should.exist ruby[field]
      
      it "correctly assigns @path", ->
        ruby.path.should.be.a "string"
      
      it "correctly assigns @name", ->
        ruby.name.should.eql "Ruby"
      
      it "firstLine is a regexp", ->
        ruby.firstLine.should.be.an.instanceof RegExp
      
      for field in ["indent", "outdent"]
        do (field) ->
          it "#{field} is a string", ->
            ruby[field][0].should.be.a "string"
    
    
    describe "#toJSON", ->
      json = null
      before (done) ->
        ruby.toJSON (_json) ->
          json = _json
          done()
      
      it "is an object", ->
        json.should.be.a "object"
      
      it "has a @name property", ->
        json.name.should.eql "Ruby"
      
      props = ["version", "url", "author"
               "tab", "indent", "outdent"]
      for prop in props
        it "has a @#{prop} string property", ->
          json[prop].should.be.a "string"
      
      it "has a @syntax property", ->
        json.syntax.should.be.a "object"
    
    
    describe "#completions", ->
      it "is an array", (done) ->
        ruby.completions (words) ->
          words.should.be.an.instanceof Array
          done()
      
      it "has string elements", (done) ->
        ruby.completions (words) ->
          words[0].should.be.a "string"
          done()
    
    
    describe "#icon", ->
      it "is a string", ->
        ruby.icon().should.be.a "string"
      
      it "is the correct path", ->
        ruby.icon().should.eql "#{ruby.path}/icon.png"
    
    
    describe "#identify", ->
      it "is boolean", ->
        ruby.identify("something").should.be.a "boolean"
      
      describe "Ruby", ->
        describe "by path", ->
          it "file.rb is true", ->
            ruby.identify("file.rb").should.be.true
          
          it "file.py is false", ->
            ruby.identify("file.py").should.be.false
        
        describe "by firstLine", ->
          describe "with a ruby shebang", ->
            it "is true", ->
              ruby.identify("file", "#!/usr/bin/env ruby").should.be.true
            
          describe "without a ruby shebang", ->
            it "is false", ->
              ruby.identify("file", "#!/usr/bin/env python").should.be.false
      
      describe "Ruby.Rails", ->
        describe "by path", ->
          it "file.rb is false", ->
            rails.identify("file.rb").should.be.false
        
        describe "by shebang", ->
          it "is false", ->
            rails.identify("file", "#!/usr/bin/env ruby").should.be.false
    
    
    describe "#indentRegex", ->
      it "is a regexp", ->
        ruby.indentRegex().should.be.an.instanceof RegExp
    
    
    describe "#outdentRegex", ->
      it "is a regexp", ->
        ruby.outdentRegex().should.be.an.instanceof RegExp
      
      it "ends with a '$'", ->
        re = ruby.outdentRegex().source
        re[re.length - 1].should.eql "$"
    
    
    describe "#fileTypesRegex", ->
      it "is a regexp", ->
        ruby.fileTypesRegex().should.be.an.instanceof RegExp
    
    
    describe "Ruby.Rails.Model", ->
      it "@parent is Ruby.Rails", ->
        railsModel.parent.name.should.eql rails.name
      
      it "@extends is 'Ruby.Rails'", ->
        railsModel.extends.should.eql "Ruby.Rails"
      
      it "inherits @tab", ->
        railsModel.tab.should.eql "  "
      
      for field in ["indent", "outdent"]
        do (field) ->
          it "inherits @#{field}", ->
            railsModel[field].should.be.an.instanceof Array
            railsModel[field].length.should.be.above 0
          
          it "@#{field} contains strings", ->
            railsModel[field][0].should.be.a "string"
      
      describe "#syntax", ->
        it "has more than 1 rule", ->
          railsModel.syntax["Ruby.Rails.Model"].length.should.be.above 1
      
      
