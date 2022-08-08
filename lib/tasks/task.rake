require "/sample_mv_bot/lib/assets/p_info.rb"
require "/sample_mv_bot/lib/assets/tweet.rb"
require "pstore"

db = PStore.new("/tmp/try_num")
offset = nil
db.transaction do
  unless offset = db["try_num"]
    offset = db["try_num"] = 1
  end
end

namespace :task do
  desc "変数の利用テスト"
  task :tweet do
    `rm -rf /sample_mv_bot/sampleMV`
    item = get_item(offset)
    get_sample(item)

    # upload
    mp4 = "/sample_mv_bot/sampleMV/cutMV.mp4"
    mp4_id = upload_video(mp4)
    img = "/sample_mv_bot/sampleMV/sampleimg.jpg"
    img_id = upload_img(img)

    tweet_id = mv_tweet(item,mp4_id)
    reply(tweet_id, item, img_id)
  end

  desc "offsetのリセット"
  task :reset do
    db.transaction do
      db["try_num"] = 1
    end
  end
end
