# Dump a person or group's feed to stdout in JSON.
#   $ coffee dump.coffee --token <access token> <person or group id>
# Optionally dump a single object to stdout, including all its comments
#   $ coffee dump.coffee --token <access token> --post <post id>

async = require 'async'
request = require 'request'

FB = "https://graph.facebook.com"
accessToken = ""

requestPosts = (url) ->
  get url, (error, response, body) ->
    response = JSON.parse body.toString()
    if response.error
      console.log inspect response
      return

    tasks = []
    for post in response.data
      if post.comments
        do (post) ->
          tasks.push((callback) -> requestComments(post, callback))

    console.log "fetching comments for #{tasks.length} posts"
    async.series tasks, (err) ->
      if err
        console.log "error in fetching post: #{inspect err}"
        return

      for post in response.data
        if post.comments
          console.log "after: #{post.id} #{post.comments.data.length}"
        console.log inspect post

      if response.paging?.next?
        console.log 'fetching more posts', response.paging.next
        requestPosts(response.paging.next)

requestComments = (post, callback) ->
  # couldn't get other pagination methods (next, after) to work.
  get "#{FB}/#{post.id}/comments?access_token=#{accessToken}&offset=#{post.comments.data.length}", (error, response, body) ->
    response = JSON.parse body.toString()
    if response.error
      callback(response.error)
      return
    if response.data.length
      post.comments.data = post.comments.data.concat(response.data)
      requestComments(post, callback)
    else
      console.log "#{post.id} finally has #{post.comments.data.length} comments"
      callback(null)

requestPost = (id) ->
  get "#{FB}/#{id}?access_token=#{accessToken}", (error, response, body) ->
    response = JSON.parse body.toString()
    if response.error
      console.log inspect response
      return

    requestComments response, (err) ->
      console.log inspect response

wait = (n, callback) ->
  setTimeout(callback, n)

inspect = (x) ->
  require('util').inspect(x, {depth: null})

get = (url, callback) ->
  console.log "requesting #{url}"
  request(url, callback)

skip = false
args = process.argv[2..]
for arg, i in args
  if skip
    skip = false
    continue
  if arg == "--token"
    skip = true
    accessToken = args[i+1]
  else if arg == "--post"
    skip = true
    requestPost args[i+1]
  else
    requestPosts("#{FB}/#{arg}/feed?limit=500&access_token=#{accessToken}")
