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

    tasks = []
    oldest_update = ""
    try
      for post in response.data
        if !post.link and post.caption
          console.log post.actions[0].link
          console.log "link: #{post.link}"
          console.log "caption: #{post.caption}"
        oldest_update = moment(post.updated_time)
        if post.comments
          do (post) ->
            tasks.push((callback) -> requestComments(post, callback))
    catch error
      console.log "== Error 2 in requestPosts:"
      console.log inspect error
      console.log inspect response

#?     if response.data.length > 0
#?       new_url = newUrl(url, oldest_update.unix())
#?       console.log 'fetching more posts', new_url
#?       requestPosts(new_url, dir)

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
          new_url = newUrl(url, oldest_update.unix())
          console.log 'fetching more posts', new_url
          requestPosts(new_url, dir)
      catch error
        console.log "== Error in reading posts; retrying"
        console.log inspect error
        requestPosts(url, dir)
        return

newUrl = (url, update_time) ->
  url.replace(/&until=.*/, "")+"&until=#{update_time}"

requestComments = (post, callback) ->
  # couldn't get other pagination methods (next, after) to work.
  get "#{FB}/v2.3/#{post.id}/comments?access_token=#{accessToken}&offset=#{post.comments.data.length}", (error, response, body) ->
    try
      response = JSON.parse body.toString()
    catch error
      console.log "== Crap response. Retrying"
      requestComments(post, callback)
      return
    if response.error
      console.log "== Error in fetching comments"
      console.log inspect error
      callback(response.error)
      return
    if response.data.length
      post.comments.data = post.comments.data.concat(response.data)
      requestComments(post, callback)
    else
      requestCommentLikes(post, callback)

requestCommentLikes = (post, callback) -> # no pagination for likes
  tasks = []
  for comment in post.comments.data
    if comment.like_count
      do (comment) ->
        tasks.push((callback) -> requestCommentLike(post.id, comment, callback))

  console.log "#{post.updated_time}: fetching likes for #{tasks.length} comments"
  async.series tasks, (err) ->
    if err
      console.log "== Error in fetching comment likes"
      console.log inspect err
      return
    callback(null)

requestCommentLike = (post_id, comment, callback) ->
  get "#{FB}/v2.3/#{post_id}_#{comment.id}/likes?access_token=#{accessToken}", (error, response, body) ->
    if error
      console.log "== Error in fetching comment like; retrying"  # timeout
      console.log inspect error
      requestCommentLike(post_id, comment, callback)
      return
    if !response
      console.log "== No response; retrying"
      requestCommentLike(post_id, comment, callback)
      return
    if response.error
      console.log "== Error in fetching comment like:"
      console.log inspect response
      return

    try
      comment.likes = JSON.parse(body.toString()).data
    catch error
      console.log "== Crap response. Retrying"
      requestCommentLike(post_id, comment, callback)
      return

    callback(null)

requestPost = (id) ->
  get "#{FB}/v2.3/#{id}?access_token=#{accessToken}", (error, response, body) ->
    response = JSON.parse body.toString()
    if response.error
      console.log "== Error in fetching post:"
      console.log inspect response
      return

    requestComments response, (err) ->
      console.log inspect response

save = (post, dir) ->
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
    requestPosts("#{FB}/v2.3/#{arg}/feed?limit=100&access_token=#{accessToken}", dir)
