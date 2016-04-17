# Like fetch_posts.coffee, but:
#   a) simply dumps JSON for each post to a separate file
#   b) is a little more thorough, grabbing all comments of each story, and all likes for each story and comment

# Dump a person or group's feed:
#   $ coffee dump.coffee --token <access token> <person or group id>
# Optionally dump a single object, including all its comments:
#   $ coffee dump.coffee --token <access token> --post <post id>

# The readme describes how to get a disposable token.
# If the crawl takes longer than the hour or so your token is valid for,
# you'll need to:
#   a) Create a facebook app id and secret
#   b) Extend the debug token as described in https://developers.facebook.com/docs/facebook-login/access-tokens:
#       $ coffee dump.coffee --extend "https://graph.facebook.com/oauth/access_token?client_id=$APP_ID&client_secret=$SECRET&grant_type=fb_exchange_token&fb_exchange_token=$TOKEN"
#   c) Use the new access token as before.

async = require 'async'
request = require 'request'
fs = require 'fs'
moment = require 'moment'

FB = "https://graph.facebook.com"
accessToken = ""
dir = null

requestPosts = (url, dir) ->
  get url, (error, response, body) ->
    try
      response = JSON.parse body.toString()
    catch error
      console.log "== Crap response. Retrying"
      requestPosts(url, dir)
      return

    if response.error
      console.log "== Error in requestPosts:"
      console.log inspect response
      return

    if response.data.length > 0
      new_url = response.paging.next
      console.log 'fetching more posts', new_url
      requestPosts(new_url, dir)

    try
      for post in response.data
        save post, dir

    catch error
      console.log "== Error in reading posts; retrying"
      console.log inspect error
      requestPosts(url, dir)
      return

requestPost = (id) ->
  get "#{FB}/#{id}?access_token=#{accessToken}", (error, response, body) ->
    response = JSON.parse body.toString()
    if response.error
      console.log "== Error in fetching post:"
      console.log inspect response
      return

    requestComments response, (err) ->
      console.log inspect response

save = (post, dir) ->
  if post.from == undefined
    post.from = {}
    post.from.name = "BANNED"
  fs.open "#{dir}/#{post.created_time.slice(0, -5).replace('T', '_').replace(/[:-]/g, '')}-#{post.from.name.replace(/\s/g, '_')}", 'w', (err, fd) ->
    if err
      console.log "error in save"
      console.log inspect err
      return
    fs.write fd, inspect post

get = (url, callback) ->
  request(url, callback)

wait = (n, callback) ->
  setTimeout(callback, n)

inspect = (x) ->
  JSON.stringify x, null, 2 # spaces per indent

empty = (x) ->
  !x || x.length == 0

skip = false
args = process.argv[2..]
for arg, i in args
  if skip
    skip = false
    continue
  if arg == "--token"
    skip = true
    accessToken = args[i+1]
  else if arg == "--dir"
    skip = true
    dir = args[i+1]
  else if arg == "--post"
    skip = true
    requestPost args[i+1]
  else if arg == "--extend"
    skip = true
    get args[i+1], (error, response, body) ->
      console.log body.toString()
  else
    if !dir
      console.log "--dir required"
      process.exit(1)
    try
      fs.mkdirSync(dir, 0o755)
    catch e
      if e.code != 'EEXIST'
        throw e
    requestPosts("#{FB}/#{arg}/feed?fields=id,from,created_time,updated_time,message,likes,attachments,story,comments{id,from,created_time,message,like_count,likes,comments{id,from,message,like_count,likes}}&access_token=#{accessToken}", dir)
