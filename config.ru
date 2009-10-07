# vim: set et sw=2 sts=2 ft=ruby:

require 'pastiche'

Sinatra::Application.instance_eval do
  set :environment, :production
end

use Rack::Reloader

run Sinatra::Application
