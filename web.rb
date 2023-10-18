$stdout.sync = true # https://stackoverflow.com/a/42344140

require 'bundler'
Bundler.setup(:default, ENV['APP_ENV'])
Bundler.require(:default, ENV['APP_ENV'])
require 'zeitwerk'
require 'logger'

module Termin; end
loader = Zeitwerk::Loader.new
loader.push_dir('lib', namespace: Termin)
loader.setup

db = Termin::Data::Connection.instance
db.connect
db.migrate

web_instance = Termin::Web::Server.new(db:)
