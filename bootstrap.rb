$stdout.sync = true # https://stackoverflow.com/a/42344140

env = ENV['APP_ENV'].to_s || :production
env = :development unless [:development, :production].include?(env)

require 'bundler'
Bundler.setup(:default, ENV['APP_ENV'])
Bundler.require(:default, ENV['APP_ENV'])

require 'dotenv'
Dotenv.load(".env.#{env}")

require 'zeitwerk'
require 'logger'

module Termin; end
loader = Zeitwerk::Loader.new
loader.push_dir('lib', namespace: Termin)
loader.setup
