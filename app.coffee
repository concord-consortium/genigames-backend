httpProxy = require 'http-proxy'
http      = require 'http'
util      = require 'util'
express   = require 'express'
io        = require 'socket.io'

port = if process.env.NODE_PORT then parseInt(process.env.NODE_PORT, 10) else 3000
console.log "about to listen on port #{port}"
app = express.createServer()
server = app.listen port

# see https://github.com/LearnBoost/socket.io/issues/843
io = io.listen server

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
    path: '/genigames/_design/show/_view/all'

  couch = http.get options, (couchResponse) ->
    val = ""

    if couchResponse.statusCode isnt 200
      next """
           There was a #{couchResponse.statusCode} error reading from the CouchDB server:

           #{util.inspect couchResponse.headers}
           """

    couchResponse.on 'data', (data) -> val += data
    couchResponse.on 'end', ->
      res.json JSON.parse(val)

  couch.on 'error', (err) ->
    next "There was an error connecting to the CouchDB server:\n\n#{util.inspect err}"

#
# handle client-side logging here
#

io.sockets.on 'connection', (socket) ->
  socket.emit 'news', hello: 'world'
  socket.on 'my other event', (data) ->
    console.log(data)

  socket.on 'log', (logData) ->
    console.log "log from client: \n#{util.inspect logData}\n"

# to post log item to couchdb note the following:
# curl -vX POST http://localhost:5984/genigames-logs/ -H "Content-Type: application/json" -d "{ \"newdata\": 2 }

#
# proxies here
#

localhostProxy = new httpProxy.HttpProxy
  target:
    host: 'localhost'
    port: 8080
  changeOrigin: true

proxyToLocalApache = (req, res, next) ->
  req.url = req.originalUrl
  localhostProxy.proxyRequest req, res

geniverseProxy = new httpProxy.HttpProxy
  target:
    host: 'geniverse.dev.concord.org'
    port: 80
  changeOrigin: true

proxyToGeniverse = (req, res, next) ->
  # do this to avoid stripping the leading part of the url
  req.url = req.originalUrl
  geniverseProxy.proxyRequest req, res

# proxied urls
app.use '/resources', proxyToGeniverse
app.use '/biologica', proxyToGeniverse
app.use '/couchdb', httpProxy.createServer 'localhost', 5984
app.use '/portal', proxyToLocalApache

# on a developer's local machine, also proxy the rake-pipeline preview server that builds the Ember
# app
app.configure 'development', ->
   console.log "Development env starting"
   app.use new httpProxy.createServer 'localhost', 9292

# deployed to a server (and here, genigames.dev.concord.org counts as a "production" NODE_ENV)
# serve static assets from the build folder
app.configure 'production', ->
  console.log "Production env starting"
  app.use express.static "#{__dirname}/public/static"
