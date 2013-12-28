lexicographic_compare = (a, b) ->
  if a > b
    1
  else if a < b
    -1
  else
    0

inspect = (x) ->
  require('util').inspect(x, {depth: null})

post = {}
require('fs').readFile 'x', (err, data) ->
  if err
    throw err
  posts = JSON.parse(data)
  posts.sort((a, b) -> lexicographic_compare(a.id, b.id))
  console.log inspect posts
