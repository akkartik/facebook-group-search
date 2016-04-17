facebook-group-search
=====================

Export and make searchable your Facebook group

## Installation

Install Coffeescript:

     npm install -g coffee-script

Install node modules for project:

     npm install

Get OAuth token from Facebook and add to fetch_posts.coffee. Simplest way I've found is from
https://developers.facebook.com/tools/explorer?method=GET&path=338164739567715%2Ffeed

Setup Elasticsearch locally

## Do initial fetch / indexing of Facebook group posts
Run ````coffee fetch_posts.coffee````

As long as you leave the program running, it'll fetch new posts/comments every
30 minutes.

## Run queries.
    coffee query.coffee # all additional parameters become the search query.
