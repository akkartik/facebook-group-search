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
#       $ coffee dump.coffee --extend $APP_ID $SECRET $TOKEN
#   c) Use the new access token as before.

async = require 'async'
request = require 'request'
fs = require 'fs'

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

    tasks = []
    try
      for post in response.data
        if !post.link and post.caption
          console.log post.actions[0].link
          console.log "link: #{post.link}"
          console.log "caption: #{post.caption}"
        do (post) ->
          tasks.push((callback) -> requestComments(post, "", callback))
        break
    catch error
      console.log "== Error 2 in requestPosts:"
      console.log inspect error
      console.log inspect response

    async.series tasks, (err) ->
      if err
        console.log "== Error in fetching all posts:"
        console.log inspect err
        return

      if !response
        console.log "== No response when fetching comments for posts; retrying"
        requestPosts(url, dir)
        return

      try
        for post in response.data
          save post, dir

        if response.data.length > 0
          console.log 'fetching more posts', response.paging.next
          requestPosts(response.paging.next, dir)
      catch error
        console.log "== Error in reading posts; retrying"
        console.log inspect error
        requestPosts(url, dir)
        return

requestComments = (post, after, callback) ->
  console.log "comments: #{FB}/v2.9/#{post.id}/comments?access_token=#{accessToken}&fields=from,created_time,updated_time,message&after=#{after}"
  get "#{FB}/v2.9/#{post.id}/comments?access_token=#{accessToken}&fields=from,created_time,updated_time,message&after=#{after}", (error, response, body) ->
    try
      response = JSON.parse body.toString()
    catch error
      console.log "== Crap response. Retrying"
      requestComments(post, after, callback)
      return
    if response.error
      console.log "== Error in fetching comments"
      console.log inspect error
      console.log "== for post"
      console.log inspect post
      callback(response.error)
      return
#?     console.log inspect response
    if not post.comments
      post.comments = []
    if response.data.length
      post.comments = post.comments.concat(response.data)
      requestComments(post, response.paging.cursors.after, callback)
    else
#?       console.log "final comments: #{inspect post.comments}"
      requestCommentLikes(post, callback)

requestCommentLikes = (post, callback) -> # no pagination for likes
  tasks = []
  for comment in post.comments
    do (comment) ->
      tasks.push((callback) -> requestCommentLike(post.id, comment, "", callback))

  console.log "#{post.updated_time}: fetching likes for #{tasks.length} comments"
  async.series tasks, (err) ->
    if err
      console.log "== Error in fetching comment likes"
      console.log inspect err
      return
    callback(null)

requestCommentLike = (post_id, comment, after, callback) ->
  console.log "comment likes: #{FB}/v2.9/#{post_id}_#{comment.id}/likes?limit=100&access_token=#{accessToken}"
  get "#{FB}/v2.9/#{post_id}_#{comment.id}/likes?limit=100&access_token=#{accessToken}", (error, response, body) ->
    if error
      console.log "== Error in fetching comment like; retrying"  # timeout
      console.log inspect error
      requestCommentLike(post_id, comment, after, callback)
      return
    if !response
      console.log "== No response; retrying"
      requestCommentLike(post_id, comment, after, callback)
      return
    try
      response = JSON.parse body.toString()
    catch error
      console.log "== Crap response. Retrying"
      requestCommentLike(post_id, comment, after, callback)
      return
    if response.error
      console.log "== Error in fetching comment like:"
      console.log inspect response
      return
#?     console.log inspect response
    if not comment.likes
      comment.likes = []
    if response.paging and after != response.paging.cursors.after
      comment.likes = comment.likes.concat(response.data)
      requestCommentLike(post_id, comment, response.paging.cursors.after, callback)
    else
#?       console.log "final likes: #{inspect comment.likes}"
      callback(null)

requestPost = (id) ->
  get "#{FB}/v2.9/#{id}?limit=100&access_token=#{accessToken}&fields=from,message,link,created_time,updated_time,actions", (error, response, body) ->
    response = JSON.parse body.toString()
    if response.error
      console.log "== Error in fetching post:"
      console.log inspect response
      return

    requestComments response, "", (err) ->
      console.log inspect response

save = (post, dir) ->
  fs.open "#{dir}/#{post.created_time.slice(0, -5).replace('T', '_').replace(/[:-]/g, '')}-#{post.from.name.replace(/\s/g, '_')}", 'w', (err, fd) ->
    if err
      console.log "error in save"
      console.log inspect err
      return
    fs.write fd, inspect(post), (err, fd) ->
      if err
        console.log inspect err
      else
        fs.close fd, (err) ->
          return
#?           if err
#?             console.log inspect err

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
    skip -= 1
    continue
  if arg == "--token"
    accessToken = args[i+1]
    skip = 1
  else if arg == "--dir"
    dir = args[i+1]
    skip = 1
  else if arg == "--post"
    skip = 1
    requestPost args[i+1]
  else if arg == "--extend"
    console.log "#{FB}/oauth/access_token?client_id=#{args[i+1]}&client_secret=#{args[i+2]}&grant_type=fb_exchange_token&fb_exchange_token=#{args[i+3]}"
    get "#{FB}/oauth/access_token?client_id=#{args[i+1]}&client_secret=#{args[i+2]}&grant_type=fb_exchange_token&fb_exchange_token=#{args[i+3]}", (error, response, body) ->
      console.log body.toString()
      process.exit(0)
    skip = 3
  else
    if !dir
      console.log "--dir required"
      process.exit(1)
    try
      fs.mkdirSync(dir, 0o755)
    catch e
      if e.code != 'EEXIST'
        throw e
    requestPosts("#{FB}/v2.9/#{arg}/feed?limit=100&access_token=#{accessToken}&fields=from,message,link,created_time,updated_time,actions", dir)
