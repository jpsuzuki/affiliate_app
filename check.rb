# require "open3"
# stdout, stderr, status = Open3.capture3("split -b 4m -d ./sampleMV/sampleMV.mp4 ./sampleMV/chunk")
total = 0
for num in 0..3 do 
  chunk = "./sampleMV/chunk0#{num}"
  size = File.size(chunk)
  p size 
  total+=size
end
mp4 = File.size("./sampleMV/sampleMV.mp4")
p "mp4",mp4,mp4==total