$stdout.sync = true # https://stackoverflow.com/a/42344140

env = ENV['APP_ENV'].to_s

require 'bundler'
require 'logger'
Bundler.setup(:default, ENV['APP_ENV'])
Bundler.require(:default, ENV['APP_ENV'])

Dotenv.load(".env.#{env}.local", ".env.#{env}")

module Termin; end
module Termin::Runner; end
module Termin::Session; end
module Termin::Web; end
loader = Zeitwerk::Loader.new

{
  'helpers' => Termin,
  'runner' => Termin::Runner,
  'web' => Termin::Web,
  'lib' => Termin
}.each { |dir, namespace| loader.push_dir(dir, namespace:) }

loader.setup
