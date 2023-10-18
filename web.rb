require './bootstrap.rb'

db = Termin::Data::Connection.instance
db.connect
db.migrate

web_instance = Termin::Web::Server.new(db:)
