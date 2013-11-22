# Dump a person or group's feed to stdout in JSON.
#   $ coffee dump.coffee --token <access token> <person or group id>
# Optionally dump a single object to stdout, including all its comments
#   $ coffee dump.coffee --token <access token> --post <post id>

async = require 'async'
request = require 'request'

FB = "https://graph.facebook.com"
accessToken = ""

requestPosts = (url) ->
  console.log "requesting #{url}"
  request url, (error, response, body) ->
    response = JSON.parse body.toString()
    if response.error
      console.log inspect response
      return

    tasks = []
    for post in response.data
      if post.comments
        console.log "before: #{post.id} #{post.comments.data.length}"
        do (post) ->
          tasks.push((callback) -> requestComments(post, post.id, post.comments.data.length, callback))

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

requestComments = (post, id, n, callback) ->
  console.log "comments for #{id}: #{n}"
  # couldn't get other pagination methods (next, after) to work.
  request "#{FB}/#{id}/comments?access_token=#{accessToken}&offset=#{n}", (error, response, body) ->
    response = JSON.parse body.toString()
    if response.error
      callback(response.error)
      return
    if response.data.length
      post.comments.data = post.comments.data.concat(response.data)
      requestComments(post, id, n+response.data.length, callback)
    else
      callback(null)

requestPost = (id) ->
  request "#{FB}/#{id}?access_token=#{accessToken}", (error, response, body) ->
    response = JSON.parse body.toString()
    if response.error
      console.log inspect response
      return

    console.log "Initially #{response.comments.data.length} comments"
    requestComments response, response.id, response.comments.data.length, (err) ->
      console.log "#{response.comments.data.length} comments"
      console.log inspect response

wait = (n, callback) ->
  setTimeout(callback, n)

inspect = (x) ->
  require('util').inspect(x, {depth: null})

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
