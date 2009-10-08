# vim: set et sw=2 sts=2:

require 'rubygems'
require 'sinatra/base'
require 'openid'
require 'openid/store/filesystem'
require 'openid/extensions/sreg'
require 'haml'

class Pastiche < Sinatra::Base
  # options
  enable :sessions
  set :path_prefix, nil

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
    haml :login
  end

  post '/login' do
    url = site_url
    identifier = params[:openid_identifier]

    checkid_request = openid_consumer.begin(identifier)
    sreg_request = OpenID::SReg::Request.new
    sreg_request.request_fields(%w(nickname email fullname))
    checkid_request.add_extension(sreg_request)
    redirect checkid_request.redirect_url(url, "#{url}login/complete")
  end

  get '/login/complete' do
    openid_response = openid_consumer.complete(params, request.url)

    case openid_response.status
    when :failure
      # TODO
      "failure"
    when :setup_needed
      # TODO
      "setup needed"
    when :cancel
      # TODO
      "cancel"
    when :success
      openid = openid_response.display_identifier
      nickname = params['openid.sreg.nickname']
      fullname = params['openid.sreg.fullname']
      email = params['openid.sreg.email']

      #session[:user] = User.first(:openid => openid)

      # TODO
      "success: #{params.inspect}"
    end
  end

  private

  def openid_consumer
    rootdir = self.class.root || '.'
    storage = OpenID::Store::Filesystem.new(File.join(rootdir, 'tmp'))
    OpenID::Consumer.new(session, storage)
  end

  STANDARD_PORTNUMBER = {
    'http'  => 80,
    'https' => 443,
  }

  def site_url
    url = request.scheme + '://'
    url << request.host
    url << ":#{request.port}" if STANDARD_PORTNUMBER[request.scheme] != request.port
    url << self.class.path_prefix if self.class.path_prefix
    url << '/' unless url[-1] == ?/
    url
  end

end # Pastiche
