def db
  Swift.db
end

def run
  ins = db.prepare("insert into users(name, created_at) values(?, now())")
  %w(arthur james dennise jarow sharma).each {|name| ins.execute(name)}
end
