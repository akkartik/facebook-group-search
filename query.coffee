elastical = require('elastical')
moment = require('moment')
esclient = new elastical.Client()
face_group = esclient.getIndex('facebook_group')
util = require 'util'

face_group.search(
  {
    query:
      query_string:
        fields: ['message', 'name', 'comments.data.message']
        default_operator: 'AND'
        query: process.argv.slice(2).join(' ')
    #sort: [
      #created_time:
        #order: 'desc'
    #]
    size: 10
    facets:
      poster:
        terms:
          field: "from.name"
      commenters:
        terms:
          field: "comments.data.from.name"
  }, (err, results, res) ->
    console.log ''
    console.log ''
    console.log "================ Number of hits ===================="
    console.log ''
    console.log res.hits.total
    console.log ''
    console.log ''
    console.log "================ Facets ===================="
    console.log ''
    console.log util.inspect res.facets, depth: 10
    console.log ''
    console.log ''
    console.log "================ Post messages ===================="
    console.log ''
    for hit in res.hits.hits
      console.log '==='
      console.log moment(hit._source.created_time).format('MMMM Do YYYY, h:mm:ss a')
      console.log hit._source.message
      console.log ''
      if hit._source.comments
        for comment in hit._source.comments.data
          console.log comment.from.name, ': ', comment.message
    #console.log util.inspect res.hits.hits[0], depth: 10
    #console.log util.inspect res, depth: 10
)
