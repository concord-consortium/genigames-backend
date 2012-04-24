httpProxy = require 'http-proxy'
http      = require 'http'
util      = require 'util'
express   = require 'express'

geniverseProxy = new httpProxy.HttpProxy
  target:
    host: 'geniverse.dev.concord.org'
    port: 80
  changeOrigin: true

proxyToGeniverse = (req, res, next) ->
  req.url = req.originalUrl
  geniverseProxy.proxyRequest req, res

app = express.createServer()

app.use '/resources', proxyToGeniverse
app.use '/biologica', proxyToGeniverse

# also proxy CouchDB

app.use '/couchdb', httpProxy.createServer 'localhost', 5984

#
# handle api urls here
#

# A crude way to forward game spec from CouchDB
#
#   1. Requests a document from CouchDB by requesting http://localhost:5984/genigames/game1
#   2. Forwards the contents under the 'gameSpec' key, as-is, to the client
#   3. Calls Express "error middleware" via next(...) if
#        * the CouchDB request errors [ECONNREFUSED or the like]
#        * the CouchDB response contains any non-200 status code (this includes 3xx codes)
#        * the gameSpec key is not found in the response

app.get '/api/game', (req, res, next) ->
  options =
    host: 'localhost'
    port: 5984
    path: '/genigames/game1'

  couch = http.get options, (couchResponse) ->
    val = ""

    if couchResponse.statusCode isnt 200
      next """
           There was a #{couchResponse.statusCode} error reading from the CouchDB server:

           #{util.inspect couchResponse.headers}
           """

    couchResponse.on 'data', (data) -> val += data
    couchResponse.on 'end', ->
      gameSpec = JSON.parse(val).gameSpec
      if !gameSpec then next "gameSpec was empty!"
      res.json gameSpec

  couch.on 'error', (err) ->
    next "There was an error connecting to the CouchDB server:\n\n#{util.inspect err}"


# on a developer's local machine, also proxy the rake-pipeline preview server that builds the Ember
# app
app.configure 'development', ->
   console.log "Development env setup"
   app.use new httpProxy.createServer 'localhost', 9292

# deployed to a server (and here, genigames.dev.concord.org counts as a "production" NODE_ENV)
# serve static assets from the build folder
app.configure 'production', ->
  console.log "Production env setup"
  app.use express.static "#{__dirname}/public/static"

app.listen 3000
