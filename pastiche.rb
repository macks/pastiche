# vim: set et sw=2 sts=2:

require 'rubygems'
require 'sinatra/base'
require 'openid'
require 'haml'

class Pastiche < Sinatra::Base
  # options
  enable :sessions

  get '/' do
    haml :index
  end

  get %r{/(\d+)} do |snippet_id|
    ":snippet/#{snippet_id}"
  end

  get '/user/:user' do |user|
    ":user/#{user}"
  end

  get '/login' do
    ':login_form'
  end

end # Pastiche
