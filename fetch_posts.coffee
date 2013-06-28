moment = require 'moment'
request = require 'request'
cronJob = require('cron').CronJob
util = require 'util'
elastical = require('elastical')
#esclient = new elastical.Client('127.0.0.1', curlDebug: true)
# Establish connection to Elasticsearch on localhost.
esclient = new elastical.Client()
facebook_group = esclient.getIndex('facebook_group')

accessToken = "GET FROM FACEBOOK YO"

# Create index and setup mapping for Elasticsearch index.
esclient.createIndex('facebook_group', null, (err, facebook_group, data) ->
  if facebook_group.putMapping?
    esclient.putMapping('facebook_group', 'post',
      {
        post:
          properties:
            from:
              type: 'object'
              properties:
                name:
                  type: "string"
                  analyzer: "keyword"
            comments:
              type: 'object'
              properties:
                data:
                  type: 'object'
                  properties:
                    from:
                      type: 'object'
                      properties:
                        name:
                          type: "string"
                          analyzer: "keyword"
      }, (err, res) ->
        if err
          console.log 'The elasticSearch mapping failed', err
          console.log util.inspect res, depth: 10
    )
)

# Recursively fetch posts until we get to the end.
requestPosts = (url) ->
  request(url, (error, response, body) ->
    body = body.toString()
    posts = JSON.parse(body)
    console.log '# of posts retrieved', posts?.data?.length

    # If there's previous posts still, keep fetching.
    if posts.paging?.next?
      console.log 'fetching still more posts', posts.paging.next
      requestPosts(posts.paging.next)

    # Stop if there's an error from Facebook error and log.
    if posts.error
      console.log posts.error
      return

    # Index the returned posts.
    for post in posts.data
      # TODO if comments have a pager, do an additional request to grab all comments
      # Index post
      facebook_group.index('post', post, id: post.id, (err, res) ->
        if err
          console.log err, res
      )
  )

# Kick off fetching Facebook posts.
requestPosts("https://graph.facebook.com/338164739567715/feed?limit=500&access_token=#{ accessToken }")


############################################################
## Setup cron to fetch new posts/comments every 30 minutes.
############################################################
lastFetch = moment().subtract('days', 1).unix()

fetchNewPosts = ->
  console.log 'Cron job for fetching new posts.'
  url = "https://graph.facebook.com/338164739567715/feed?since=#{ lastFetch }&limit=500&access_token=#{ accessToken }"
  lastFetch = moment().unix()
  request(url, (error, response, body) ->
    posts = JSON.parse body
    for post in posts.data
      esclient.index('facebook_group', 'post', post, id: post.id, (err, res) ->
        if err
          console.log err, res
      )
  )

CronJob = require('cron').CronJob
job = new CronJob
  cronTime: '0 0,30 * * * *'
  onTick: fetchNewPosts

job.start()
