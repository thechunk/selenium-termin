$stdout.sync = true # https://stackoverflow.com/a/42344140

env = ENV['APP_ENV'].to_s

require 'bundler'
Bundler.setup(:default, ENV['APP_ENV'])
Bundler.require(:default, ENV['APP_ENV'])

require 'dotenv'
Dotenv.load(".env.#{env}.local", ".env.#{env}")

require 'zeitwerk'
require 'logger'

module Termin; end
module Termin::Runner; end
module Termin::Session; end
module Termin::Web; end
loader = Zeitwerk::Loader.new
loader.push_dir('helpers', namespace: Termin)
loader.push_dir('runner', namespace: Termin::Runner)
loader.push_dir('web', namespace: Termin::Web)
loader.push_dir('lib', namespace: Termin)
loader.setup
