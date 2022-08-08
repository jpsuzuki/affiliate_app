require 'json'
require 'typhoeus'
require 'dotenv'
require 'open-uri'
require 'nokogiri'

def get_item(int)
  Dotenv.load('.keys.env')
  api_id = ENV['API_ID']
  affiliate_id = ENV['AFFILIATE_ID']
  api = "https://api.dmm.com/affiliate/v3/ItemList"
  offset = int
  sampleMovieURL = nil
  # mvのあるアイテムになるまで繰り返す（最大5回
  while sampleMovieURL == nil do
    req_params = {
      api_id: api_id, 
      affiliate_id: affiliate_id,
      site: "FANZA",
      service: "digital",
      floor: "videoa",
      hits: 1,
      offset: offset,
      output: "json"
    }
    request = Typhoeus::Request.new(api,params: req_params)
    response = request.run
    item = JSON.parse(response.body)["result"]["items"][0]
    p item["title"]
    # urlがnilで無ければ変数に代入
    unless item["sampleMovieURL"] == nil
      sampleMovieURL = item["sampleMovieURL"]["size_720_480"]
    end
    p sampleMovieURL
    offset += 1
    sleep 1
  end
  return item
end

# mp4url取得
def get_sample(item)
  doc = Nokogiri::HTML5(URI.open(item["sampleMovieURL"]["size_720_480"]))
  iframe = "https:#{doc.at_css("iframe").attr("src")}"
  iframe_doc = Nokogiri::HTML5(URI.open(iframe))
  script = iframe_doc.at("body script").text
  # rough = script.match(/\"bitrate\"\:1000\,\"src\"\:\".*\.mp4\"\}\,\{\"bitrate\"\:1500/).to_s
  rough = script.match(/\"bitrate\"\:3000\,\"src\"\:\".*\.mp4\"\}\]\,\"affiliate/).to_s
  shave = rough.match(/cc3001.*mp4/).to_s
  mp4url = "https://#{shave}".gsub(/\\/) { '' }
  `mkdir ./sampleMV`
  mp4file = "./sampleMV/sampleMV.mp4"
  open(mp4file, "wb") do |mp4file| 
    mp4file.print open(mp4url).read
  end
  `ffmpeg -i ./sampleMV/sampleMV.mp4  -ss 00:00:05 -to 00:02:25 -acodec copy -vcodec copy ./sampleMV/cutMV.mp4`
  `split -b 4m -d ./sampleMV/cutMV.mp4 ./sampleMV/chunk`
  imgfile = "./sampleMV/sampleimg.jpg"
  img = item["sampleImageURL"]["sample_l"]["image"][0]
  open(imgfile, "wb") do |imgfile| 
    imgfile.print open(img).read
  end
end

# `rm -rf ./sampleMV`
# $item = get_item(2)
# mp4url = get_mp4(item)
# download(mp4url)
# `split -b 4m -d ./sampleMV/sampleMV.mp4 ./sampleMV/chunk`
# p "finish"

# item = get_item(1)
# p "アフィリエイト",item["affiliateURL"]
# p "image l",item["sampleImageURL"]["sample_l"]["image"][0]

