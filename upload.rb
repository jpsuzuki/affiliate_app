require "open3"
require 'dotenv'

consumer_key = ENV['CONSUMER_KEY']
consumer_secret = ENV['CONSUMER_SECRET']

stdout, stderr, status = Open3.capture3("twurl authorize --consumer-key \"#{consumer_key}\" --consumer-secret \"#{consumer_key}\"")
# `twurl authorize --consumer-key "#{consumer_key}" --consumer-secret "#{consumer_secret}"`
init = `twurl -H upload.twitter.com "/1.1/media/upload.json" -d "command=INIT&media_type=video/mp4&total_bytes=4430752"`
p init