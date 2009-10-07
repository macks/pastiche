# vim: set et sw=2 sts=2:

require 'rubygems'
require 'sinatra'
require 'openid'
#require 'haml'

# options
enable :sessions

get '/' do
  ':top'
end

get %r{/(\d+)} do |snippet_id|
  ":snippet/#{snippet_id}"
end

get '/login' do
  ':login_form'
end

get '/user/:user' do |user|
  ":user/#{user}"
end
