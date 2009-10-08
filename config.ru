# vim: set et sw=2 sts=2 ft=ruby:

require 'pastiche'

Pastiche.instance_eval do
  # You should change the secret.
  disable :sessions
  use Rack::Session::Cookie, :secret => '__secret__'
end

use Rack::Reloader
run Pastiche
