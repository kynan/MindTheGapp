port = process.env.PORT || 3000
host = process.env.HOST || "0.0.0.0"
hostname = process.env.HOSTNAME || "127.0.0.1"

require('zappajs') host, port, ->
  manifest = require './package.json'
  fs = require 'fs'
  mongoose = require 'mongoose'
  passport = require 'passport'
  LinkedInStrategy = require('passport-linkedin').Strategy

  @configure =>
    @use 'logger',
      'cookieParser',
      'bodyParser',
      'methodOverride',
      'session': secret: 'shhhhhhhhhhhhhh!',
      passport.initialize(),
      passport.session(),
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
    console.log 'serializing', user
    done null, user

  passport.deserializeUser (user, done) ->
    console.log 'deserializing', user
    done null, user

  passport.use new LinkedInStrategy
      consumerKey: LINKEDIN_API_KEY
      consumerSecret: LINKEDIN_SECRET_KEY
      callbackURL: "http://#{hostname}:#{port}/auth/linkedin/callback"
    , (token, tokenSecret, profile, done) ->
      console.log 'passport authentication', token, tokenSecret, profile
      done null, profile

  ensureAuthenticated = (req, res, next) ->
    if req.isAuthenticated()
      return next()
    req.session.redirect_to = req.path
    res.redirect '/auth/linkedin'

  @get '/': ->
    @response.redirect '/home'

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

  @get '/source': ->
    @response.redirect manifest.source

  @get '/auth/linkedin', passport.authenticate 'linkedin'

  @get '/auth/linkedin/callback',
    passport.authenticate('linkedin', { failureRedirect: '/auth/linkedin/failed' }), (req, res) ->
      res.redirect req.session.redirect_to || '/'

  @get '/logout': ->
    @request.logout()
    @response.redirect '/'

  @get '/auth/linkedin/failed': ->
    @response.json 'Authentication failed'

  @get '/profile', ensureAuthenticated, ->
    console.log @request.user
    @render 'profile.jade',
      title: manifest.name
      id: 'profile'
      brand: manifest.name
      user: @request.user
