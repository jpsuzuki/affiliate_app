require 'oauth'
require 'json'
require 'typhoeus'
require 'dotenv'
require 'oauth/request_proxy/typhoeus_request'
require 'pstore'


# メソッドの定義
def get_request_token(consumer)
  request_token = consumer.get_request_token()
  return request_token
end
 
def get_user_authorization(request_token)
  puts "Follow this URL to have a user authorize your app: #{request_token.authorize_url()}"
  puts "Enter PIN: "
  pin = gets.strip

  return pin
end
 
def obtain_access_token(consumer, request_token, pin)
  token = request_token.token
  token_secret = request_token.secret
  hash = { :oauth_token => token, :oauth_token_secret => token_secret }
  request_token = OAuth::RequestToken.from_hash(consumer, hash)
  # Get access token
  access_token = request_token.get_access_token({:oauth_verifier => pin})
  return access_token
end
 
def request(url, oauth_params, options)
  request = Typhoeus::Request.new(url, options)
  oauth_helper = OAuth::Client::Helper.new(request, oauth_params.merge(:request_uri => url))
  request.options[:headers].merge!({"Authorization" => oauth_helper.header}) # Signs the request
  response = request.run
  return response
end

def parallel(url, oauth_params, hash)
  hydra = Typhoeus::Hydra.new
  requests = hash.map do |options|
    # パラメータの確認
    p options[:params][:segment_index]
    request = Typhoeus::Request.new(url, options)
    # oauth_helper = OAuth::Client::Helper.new(request, oauth_params.merge(:request_uri => url))
    # # ここからが問題
    # p "helper", oauth_helper.class
    # p "header class", oauth_helper.header
    
    # request.options[:headers].merge!({"Authorization" => oauth_helper.header})
    hydra.queue(request)
    request
  end
  # 認証を挟まなければここまで来れる
  p requests.class
  hydra.run
  responses = requests.map { |request|
    request.response.body
  }
  return responses
end

def tweet_options(tweet)
  options = {
  :method => :post,
  headers: {
  "User-Agent": "v2CreateTweetRuby",
  "content-type": "application/json"
  },
  body: JSON.dump(tweet)
  }
  return options
end
 
# oauth一連の処理
def run_oauth(consumer)
  # 無ければ以下実行
  request_token = get_request_token(consumer)
  # 認証urlの表示、pin入力
  pin = get_user_authorization(request_token)
  # これまでの素材をもとに、アクセストークンの生成
  access_token = obtain_access_token(consumer, request_token, pin)
end

# INIT
def init_options(mp4size)
  options = {
    :method => :post,
    headers: {
      "ContentType": "multipart/form-data"
    },
    params:{
      command: "INIT",
      total_bytes: mp4size,
      media_type: "video/mp4",
      media_category: "TWEET_VIDEO"
    }
  }
  return options
end

# APPEND
def append_options(media_id, mp4size)
  total = 0
  segment = 0
  options_array = []
  until total == mp4size
    if segment < 10 
      chunk = "/sample_mv_bot/sampleMV/chunk0#{segment}"
    else
      chunk = "/sample_mv_bot/sampleMV/chunk#{segment}"
    end
    options = {
      :method => :post,
      headers: {
        "ContentType": "multipart/form-data"
      },
      params:{
        command: "APPEND",
        media_id: media_id,
        media: chunk,
        segment_index: segment
      },
      body:{
        media: File.open(chunk,"r")
      }
    }
    options_array.push(options)
    total+=File.size(chunk)
    segment += 1
  end
  return options_array
end

# FINALIZE
def finalize_options(media_id)
  options = {
    :method => :post,
    headers: {
      "ContentType": "multipart/form-data"
    },
    params:{
      command: "FINALIZE",
      media_id: media_id
    }
  }
  return options
end

# STATUS
def status_options(media_id)
  options = {
    params:{
      command: "STATUS",
      media_id: media_id
    }
  }
  return options
end

# img 
def img_options(img)
  options = {
    :method => :post,
    params:{media: img },
    body:{
      media: File.open(img,"r")
    }
  }
  return options
end

# 変数
# oauth
consumer_key = ENV['CONSUMER_KEY']
consumer_secret = ENV['CONSUMER_SECRET']
consumer = OAuth::Consumer.new(consumer_key, consumer_secret,
:site => 'https://api.twitter.com',
:authorize_path => '/oauth/authenticate',
:debug_output => false)
db = PStore.new("/tmp/access_token")
$oauth_params = nil
db.transaction do 
  # トークン代入、失敗したらトークンを取得し保存
  unless access_token = db["token"]
    access_token = run_oauth(consumer)
    db["token"] = access_token
  end
  $oauth_params = {:consumer => consumer, :token => access_token}
end

def upload_video(mp4)
  upload_url = "https://upload.twitter.com/1.1/media/upload.json"
  mp4size = File.size(mp4)
  p mp4size
  # # upload mp4
  init_options = init_options(mp4size)
  init_response = request(upload_url, $oauth_params, init_options)
  puts JSON.pretty_generate(JSON.parse(init_response.body)),init_response.return_message
  media_id = JSON.parse(init_response.body)["media_id_string"]
  p "media id" , media_id

  append_array = append_options(media_id, mp4size)
  append_array.map do |options|
    response = request(upload_url, $oauth_params, options)
    p response.code, response.return_message
  end
  p "uploaded"

  finalize_options = finalize_options(media_id)
  p "finalize"
  finalize_response = request(upload_url, $oauth_params, finalize_options)
  puts JSON.pretty_generate(JSON.parse(finalize_response.body)), finalize_response.return_message

  status_options = status_options(media_id)
  state = nil
  until state == "succeeded"
    response = request(upload_url, $oauth_params, status_options)
    state = JSON.parse(response.body)["processing_info"]["state"]
    p state 
    break if state == "failed"
    sleep 1 unless state == "succeeded"
  end
  return media_id
end

def upload_img(img)
  upload_url = "https://upload.twitter.com/1.1/media/upload.json"
  options = img_options(img)
  response = request(upload_url, $oauth_params, options)
  puts JSON.pretty_generate(JSON.parse(response.body)),response.return_message
  media_id = JSON.parse(response.body)["media_id_string"]
  return media_id
end


def mv_tweet(item,media_id)
  create_tweet_url = "https://api.twitter.com/2/tweets"
  tags = ""
  genre = item["iteminfo"]["genre"]
  if genre.count < 3 && genre.count > 0
    genre.each do |genre|
      tag = "##{genre["name"]} "
      tags += tag
    end
  else 
    for num in 0..2 do 
      tag = "##{genre[num]["name"]} "
      tags += tag
    end
  end
  unless item["iteminfo"]["actress"] == nil
    actress = item["iteminfo"]["actress"][0]
    tag = "##{actress["name"]} "
    tags += tag
  end
  tweet = {"text": tags ,"media": {"media_ids":[media_id]}}
  tweet_options= tweet_options(tweet)
  tweet_res = request(create_tweet_url, $oauth_params, tweet_options)
  puts JSON.pretty_generate(JSON.parse(tweet_res.body))
  tweet_id = JSON.parse(tweet_res.body)["data"]["id"]
  return tweet_id
end

def reply(tweet_id, item, img_id)
  create_tweet_url = "https://api.twitter.com/2/tweets"
  url = item["affiliateURL"]
  tweet = {
    "text": "こちらの作品です\n#{url}",
    "media": {"media_ids":[img_id]},
    "reply": {"in_reply_to_tweet_id": tweet_id}
  }
  tweet_options= tweet_options(tweet)
  tweet_res = request(create_tweet_url, $oauth_params, tweet_options)
  puts JSON.pretty_generate(JSON.parse(tweet_res.body))
end