httpProxy = require 'http-proxy'
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

#
# handle api urls here
#

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
