every 10.minute do
  rake "task:tweet"
end

every 10.days do 
  rake "task:reset"
end