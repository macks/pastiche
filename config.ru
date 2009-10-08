# vim: set et sw=2 sts=2 ft=ruby:

require 'pastiche'

Pastiche.instance_eval do
  # You should change the secret.
  disable :sessions
  use Rack::Session::Cookie, :secret => '__secret__'

  # Set path_prefix when the app is mounted sub-directory.
  #set :path_prefix, '/pastiche'
end

DataMapper.setup(:default, 'sqlite3:pastiche.db')
DataMapper.auto_upgrade!

run Pastiche
