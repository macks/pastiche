# vim: set et sw=2 sts=2 ft=ruby:

#ENV['RACK_ENV'] = 'production'

require 'pastiche'

Pastiche.instance_eval do
  # You should change the secret.
  disable :sessions
  use Rack::Session::Cookie, :secret => '__secret__'

  # Set path_prefix when the app is mounted sub-directory.
  #set :path_prefix, '/pastiche'

  # Set application root directory.
  #set :root, '/path/to/app_root'
end

DataMapper::Logger.new(STDERR, :debug)
DataMapper.setup(:default, 'sqlite3:pastiche.db')
#DataMapper.setup(:default, 'mysql://user:password@hostname/database_name?encoding=UTF-8')
DataMapper.auto_upgrade!

run Pastiche
