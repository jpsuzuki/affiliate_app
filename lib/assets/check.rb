require "pstore"

def plus(num)
  offset = num+1
  a = nil
  db = PStore.new("/tmp/try_num")
  db.transaction do 
    db["try_num"] = offset
    a = db["try_num"]
  end
  return a
end