facebook-group-search
=====================

Export your Facebook group to a file system.

1. Install Coffeescript:

```
npm install -g coffee-script
```

2. Install node modules for project:

```
npm install
```

3. Get OAuth token from Facebook and add to fetch_posts.coffee. Simplest way I've found is from
https://developers.facebook.com/tools/explorer?method=GET&path=338164739567715%2Ffeed

4. Create an output directory:

```
mkdir output
```

5. Start crawling:

```
coffee dump.coffee --token [oauth token from Facebook] --dir output [facebook id for your group]
```

If you find your credential expires before you're done crawling, run this
command at the start to create a longer-lived oauth token:

```bash
APP_ID=...
APP_SECRET=...
OAUTH_TOKEN=...  # your short-lived token
coffee dump.coffee --extend "https://graph.facebook.com/oauth/access_token?client_id=$APP_ID&client_secret=$APP_SECRET&grant_type=fb_exchange_token&fb_exchange_token=$OAUTH_TOKEN"
```

It should print out a long-lived oauth token you can use instead.
