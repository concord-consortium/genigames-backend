express = require 'express'
app = express.createServer();

app.get '/*', (req, res) ->
  res.send "Hello World at #{req.url}"

app.listen 3000
