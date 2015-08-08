# see http://r.va.gg/2014/06/why-i-dont-use-nodes-core-stream-module.html for
# why we use readable-stream
Readable = require('readable-stream').Readable
cheerio = require 'cheerio'
request = require 'request-promise'
# require('request-promise').debug = true 
ACTIONS = ['reply', 'retweet', 'favorite']

###*
 * Make a request for a Twitter page, parse the response, and get all the tweet
   elements.
 * @param {String} username
 * @param {String} [startingId] The maximum tweet id query for (the lowest one
   from the last request), or undefined if this is the first request.
 * @return {Array} An array of elements.
###
getPostElements = (username, since, till, startingId) ->
  request.get(
    #uri: "https://twitter.com/i/profiles/show/#{username}/timeline"
    uri: "https://twitter.com/i/search/timeline"
    qs:
      #'include_available_features': '1'
      #'include_entities': '1'
      #'max_position': startingId
      'f' : 'tweets'
      'vertical' : 'default'
      'q' : "from:#{username} since:#{since} until:#{till} max_id:#{startingId}"
  )

###*
 * Stream that scrapes as many tweets as possible for a given user.
 * @param {String} options.username
 * @param {Boolean} options.retweets Whether to include retweets.
 * @return {Stream} A stream of tweet objects.
###
class TwitterPosts extends Readable
  _lock: false
  _minPostId: 0
  _count: 0

  constructor: ({@username, @since, @till, @_minPostId, @retweets}) ->
    @retweets ?= true
    # remove the explicit HWM setting when github.com/nodejs/node/commit/e1fec22
    # is merged into readable-stream
    super(highWaterMark: 16, objectMode: true)
    @_readableState.destroyed = false
    @_minPostId = 0

  _read: =>
    # prevent additional requests from being made while one is already running
    if @_lock then return
    @_lock = true

    if @_readableState.destroyed
      @push(null)
      return

    hasMorePosts = undefined

    # we hold one post in a buffer because we need something to send directly
    # after we turn off the lock
    lastPost = undefined
    getPostElements(@username, @since, @till, @_minPostId).then((response) ->
      response = JSON.parse(response)
      # fs = require "fs"
      # fs.writeFile "classification.json", JSON.stringify(response), (error) ->
      #   console.error("Error writing file", error) if error
      html = response['items_html'].trim()
      # response['has_more_items'] is a lie, as of 2015-07-13
      hasMorePosts = html isnt ''

      cheerio.load(html)
    ).then(($) =>
      hasEmitted = false

      # query to get all the tweets out of the DOM
      for element in $('.original-tweet')
        # we get the id & set it as _minPostId before skipping retweets because
        # the lowest id might be a retweet, or all the tweets in this page might
        # be retweets
        @_count = @_count + 1
        id = $(element).attr('data-item-id')
        @_minPostId = id.substr(0,id.length-3) + (parseInt(id.substr(id.length-3,3),10)-1)  # only the last one really matters

        isRetweet = $(element).find('.js-retweet-text').length isnt 0
        if not @retweets and isRetweet
          continue # skip retweet

        post = {
          count : @_count
          id: id
          isRetweet: isRetweet
          username: @username
          text: $(element).find('.tweet-text').first().text()
          time:  +$(element).find('.js-short-timestamp').first().attr('data-time')
          images: []
        }

        for action in ACTIONS
          wrapper = $(element).find(
            ".ProfileTweet-action--#{action} .ProfileTweet-actionCount"
          )
          post[action] = (
            if wrapper.length isnt 0
              +$(wrapper).first().attr('data-tweet-stat-count')
            else
              undefined
          )

        pics = $(element).find(
          '.multi-photos .multi-photo[data-url],
          [data-card-type=photo] [data-url]'
        )
        for pic in pics
          post.images.push $(pic).attr('data-url')

        if lastPost?
          @push(lastPost)
          hasEmitted = true

        lastPost = post

      if hasMorePosts then @_lock = false
      if lastPost?
        @push(lastPost)
        hasEmitted = true
      if not hasMorePosts then @push(null)
      if not hasEmitted and hasMorePosts
        # since we haven't emitted anything, we need to get the next page right
        # now, because there won't be a read call to trigger us
        @_read()
    )

  destroy: =>
    if @_readableState.destroyed then return
    @_readableState.destroyed = true

    @_destroy((err) =>
      if err then @emit('error', err)
      @emit('close')
    )

  _destroy: (cb) ->
    process.nextTick(cb)

module.exports = TwitterPosts
