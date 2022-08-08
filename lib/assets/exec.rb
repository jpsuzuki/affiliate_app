require "./p_info.rb"
require "./tweet.rb"

# get item
`rm -rf ../../sampleMV`
item = get_item(5)
get_sample(item)

# upload
mp4 = "../../sampleMV/cutMV.mp4"
mp4_id = upload_video(mp4)
img = "../../sampleMV/sampleimg.jpg"
img_id = upload_img(img)

tweet_id = mv_tweet(item,mp4_id)
reply(tweet_id, item, img_id)



