# Like fetch_posts.coffee, but:
#   a) simply dumps JSON to stdout, without going through or needing elastic_search
#   b) is a little more thorough, grabbing all comments of each story, and likes for each comment

# Dump a person or group's feed:
#   $ coffee dump.coffee --token <access token> <person or group id>
# Optionally dump a single object, including all its comments:
#   $ coffee dump.coffee --token <access token> --post <post id>

# If the crawl takes longer than the hour or so your debug token is valid for,
# you'll need to:
#   a) Create a facebook app id and secret
#   b) Extend the debug token as described in https://developers.facebook.com/docs/facebook-login/access-tokens:
#       $ coffee dump.coffee --extend "https://graph.facebook.com/oauth/access_token?client_id=$APP_ID&client_secret=$SECRET&grant_type=fb_exchange_token&fb_exchange_token=$TOKEN"
#   c) Use the new access token as before.

async = require 'async'
request = require 'request'

FB = "https://graph.facebook.com"
accessToken = ""

requestPosts = (url) ->
  get url, (error, response, body) ->
    try
      response = JSON.parse body.toString()
    catch error
      console.log "== Crap response. Retrying"
      requestPosts(url)
      return

    if response.error
      console.log "== Error in requestPosts:"
      console.log inspect response
      return

    tasks = []
    try
      for post in response.data
        if post.comments
          do (post) ->
            tasks.push((callback) -> requestComments(post, callback))
    catch error
      console.log "== Error 2 in requestPosts:"
      console.log inspect response

    console.log "fetching comments for #{tasks.length} posts"
    async.series tasks, (err) ->
      if err
        console.log "== Error in fetching all posts:"
        console.log inspect err
        return

      if !response
        console.log "== No response when fetching comments for posts; retrying"
        requestPosts(url)
        return

      try
        for post in response.data
          if post.comments
            console.log "after: #{post.id} #{post.comments.data.length}"
          console.log inspect post

        if response.paging?.next?
          console.log 'fetching more posts', response.paging.next
          requestPosts(response.paging.next)
      catch error
        console.log "== Error in reading posts; retrying"
        console.log inspect error
        requestPosts(url)
        return

requestComments = (post, callback) ->
  # couldn't get other pagination methods (next, after) to work.
  get "#{FB}/#{post.id}/comments?access_token=#{accessToken}&offset=#{post.comments.data.length}", (error, response, body) ->
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
      console.log "#{post.id} finally has #{post.comments.data.length} comments"
      requestCommentLikes(post, callback)

requestCommentLikes = (post, callback) -> # no pagination for likes
  tasks = []
  for comment in post.comments.data
    if comment.like_count
      do (comment) ->
        tasks.push((callback) -> requestCommentLike(post.id, comment, callback))

  console.log "fetching likes for #{tasks.length} comments"
  async.series tasks, (err) ->
    if err
      console.log "== Error in fetching comment likes"
      console.log inspect err
      return
    callback(null)

requestCommentLike = (post_id, comment, callback) ->
  get "https://graph.facebook.com/#{post_id}_#{comment.id}/likes?access_token=#{accessToken}", (error, response, body) ->
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
  get "#{FB}/#{id}?access_token=#{accessToken}", (error, response, body) ->
    response = JSON.parse body.toString()
    if response.error
      console.log "== Error in fetching post:"
      console.log inspect response
      return

    requestComments response, (err) ->
      console.log inspect response

get = (url, callback) ->
  console.log "requesting #{url}"
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
  else if arg == "--post"
    skip = true
    requestPost args[i+1]
  else if arg == "--extend"
    skip = true
    get args[i+1], (error, response, body) ->
      console.log body.toString()
  else
    requestPosts("#{FB}/#{arg}/feed?limit=500&access_token=#{accessToken}")
