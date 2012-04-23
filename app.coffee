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
app.get '/*', (req, res) ->
  res.send "Hello World at #{req.url}"

app.listen 3000
