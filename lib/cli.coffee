TwitterPosts = require './'
packageInfo = require '../package'
ArgumentParser = require('argparse').ArgumentParser
JSONStream = require 'JSONStream'

argparser = new ArgumentParser(
  version: packageInfo.version
  addHelp: true
  description: packageInfo.description
)
argparser.addArgument(
  ['-u']
  type: 'string'
  help: 'Username or hashtag query to scrape'
  required: true
  dest: 'username'
)
argparser.addArgument(
  ['--since', '-s']
  type: 'string'
  help: 'Since date (YYYY-MM-DD)'
  required: true
  dest: 'since'
)
argparser.addArgument(
  ['--till', '-t']
  type: 'string'
  help: 'Until date (YYYY-MM-DD)'
  required: true
  dest: 'till'
)
argparser.addArgument(
  ['--type']
  type: 'string'
  help: 'By username, mentions or hashtags'
  defaultValue: 'username'
  required: false
  dest: 'type'
)
argparser.addArgument(
  ['--no-retweets']
  action: 'storeFalse'
  help: 'Ignore retweets'
  defaultValue: true
  dest: 'retweets'
)

argv = argparser.parseArgs()
stream = new TwitterPosts(argv)
stream.pipe(JSONStream.stringify('[', ',\n', ']\n')).pipe(process.stdout)
