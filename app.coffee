port = process.env.PORT || 3000
host = process.env.HOST || "0.0.0.0"
hostname = process.env.HOSTNAME || "127.0.0.1"
baseurl = process.env.BASEURL || "http://#{hostname}:#{port}"

require('zappajs') host, port, ->
  manifest = require './package.json'
  fs = require 'fs'
  md5 = require('blueimp-md5').md5
  flash = require 'connect-flash'
  mongoose = require 'mongoose'
  passport = require 'passport'
  LinkedInStrategy = require('passport-linkedin').Strategy
  Report = require('./models').report

  @configure =>
    @use 'logger',
      'cookieParser',
      'bodyParser',
      'methodOverride',
      'session': secret: 'shhhhhhhhhhhhhh!',
      passport.initialize(),
      passport.session(),
      flash(),
      @app.router,
      'static'
    @set 'view engine', 'jade'

  @configure
    development: =>
      mongoose.connect "mongodb://#{host}/#{manifest.name}-dev"
      @use errorHandler: {dumpExceptions: on, showStack: on}
    production: =>
      mongoose.connect process.env.MONGOHQ_URL || "mongodb://#{host}/#{manifest.name}"
      @use 'errorHandler'

  LINKEDIN_API_KEY = process.env.LINKEDIN_API_KEY
  LINKEDIN_SECRET_KEY = process.env.LINKEDIN_SECRET_KEY

  passport.serializeUser (user, done) ->
    done null, user

  passport.deserializeUser (user, done) ->
    done null, user

  passport.use new LinkedInStrategy
      consumerKey: LINKEDIN_API_KEY
      consumerSecret: LINKEDIN_SECRET_KEY
      callbackURL: "#{baseurl}/auth/linkedin/callback"
      profileFields: ['id', 'first-name', 'last-name', 'formatted-name', 'industry', 'positions', 'picture-url']
    , (token, tokenSecret, profile, done) ->
      console.log 'passport authentication', token, tokenSecret, profile
      done null, profile

  ensureAuthenticated = (req, res, next) ->
    if req.isAuthenticated()
      return next()
    req.session.redirect_to = req.path
    res.redirect '/auth/linkedin'

  @get '/': ->
    @render 'landing.jade'

  @get '/home': ->
    md = require('node-markdown').Markdown
    fs.readFile 'README.md', 'utf-8', (err, data) =>
      @render 'markdown.jade',
        md: md
        markdownContent: data
        title: manifest.name
        id: 'home'
        brand: manifest.name
        user: @request.user
        info: @request.flash 'info' || []

  @get '/source': ->
    @response.redirect manifest.source

  @get '/responses': ->
    Report.find (err, reports) =>
      @response.json reports

  @get '/auth/linkedin', passport.authenticate 'linkedin', {scope: ['r_basicprofile', 'r_fullprofile']}

  @get '/auth/linkedin/callback',
    passport.authenticate('linkedin', { failureRedirect: '/auth/linkedin/failed' }), (req, res) ->
      target = req.session.redirect_to || '/profile'
      delete req.session.redirect_to
      res.redirect target

  @get '/logout': ->
    @request.logout()
    @response.redirect '/home'

  @get '/auth/linkedin/failed': ->
    @response.json 'Authentication failed'

  @get '/profile', ensureAuthenticated, ->
    console.log @request.user
    console.log @request.user._json.positions.values
    @render 'profile.jade',
      title: manifest.name
      id: 'profile'
      brand: manifest.name
      user: @request.user
      positions: @request.user._json.positions.values
      info: @request.flash 'info' || []

  @get '/companies/:id/rate', ensureAuthenticated, ->
    position = null
    for pos in @request.user._json.positions.values
      if pos.company.id == parseInt @params.id
        position = pos
        break
    return @response.redirect '/profile' unless position
    format = (date) ->
      if date.month then "#{date.month}/#{date.year}" else date.year
    # We take a hash over the user id, the position id and the company id
    hashstring = "#{@request.user.id}#{position.id}#{position.company.id}"
    console.log "hashing #{hashstring}: #{md5(hashstring)}"
    @render 'rate.jade',
      hash: md5(hashstring)
      title: manifest.name
      id: 'rate'
      brand: manifest.name
      user: @request.user
      position: position
      startDate: if position.startDate then format position.startDate else 'today'
      endDate: if position.endDate then format position.endDate else 'today'
      cultures: ['dog eat dog', 'hyper aggressive', 'egalitarian', 'super fun', 'easy going']
      questions:
        suit_personality: 'Does the culture suite your personality?'
        promotion: 'Did you receive a promotion at the company?'
        raise: 'Did you receive a raise at the company?'
      info: @request.flash 'info' || []

  @post '/companies/rate', ensureAuthenticated, ->
    report = @body
    Report.findOneAndUpdate {hash: report.hash}, report, upsert: true, (err, report) =>
      console.log 'Received report', report
      #@response.json err if err?
      @request.flash 'info', ['Thanks for your report, your response was recorded!']
      @response.redirect '/profile'
