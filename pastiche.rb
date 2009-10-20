# vim: set et sw=2 sts=2 fileencoding=utf-8:

#
# Simple pastebin-like application using Sinatra with OpenID authentication
#

require 'rubygems'
require 'sinatra/base'
require 'openid'
require 'openid/store/filesystem'
require 'openid/extensions/sreg'
require 'haml'
require 'dm-core'
require 'dm-validations'
require 'dm-timestamps'

class Pastiche < Sinatra::Base

  class User
    include DataMapper::Resource
    property :id,         Serial
    property :openid,     String,   :nullable => false, :length => 256, :unique_index => :openid
    property :nickname,   String,   :nullable => false, :length => 16, :unique_index => :nickname
    property :email,      String,   :length => 64
    property :created_at, DateTime, :nullable => false, :auto_validation => false
    property :updated_at, DateTime, :nullable => false, :auto_validation => false

    has n, :snippets
  end

  class Snippet
    include DataMapper::Resource
    property :id,         Serial
    property :user_id,    Integer,  :nullable => false
    property :created_at, DateTime, :nullable => false, :auto_validation => false
    property :updated_at, DateTime, :nullable => false, :auto_validation => false
    property :type,       String,   :nullable => false, :length => 16
    property :title,      String,   :nullable => false, :length => 256
    property :comment,    String,   :nullable => false, :length => 512
    property :text,       Text,     :nullable => false, :length => 65536

    belongs_to :user
  end

  # options
  enable :sessions
  set :path_prefix, nil
  set :haml, :escape_html => true

  # top page
  get '/' do
    @info_message = session.delete(:info_message)
    @snippets = Snippet.all(:order => [:updated_at.desc], :limit => 10)
    haml :index
  end

  # post form
  get '/new' do
    permission_denied if not logged_in?
    haml :new
  end

  # create a snippet
  post '/new' do
    permission_denied if not logged_in?
    text    = params[:text]
    title   = params[:title].strip
    type    = params[:type].strip
    comment = params[:comment].strip
    snippet = session[:user].snippets.create(:title => title, :type => type, :comment => comment, :text => text)
    raise 'something wrong' if snippet.dirty?
    redirect "/#{snippet.id}"
  end

  # show a snippet
  get %r{\A/(\d+)\z} do |snippet_id|
    @snippet = Snippet.get(snippet_id)
    haml :snippet
  end

  # show user information
  get '/user/:user' do |user|
    @user = User.first(:nickname => user)
    haml :user
  end

  # show user configuration form
  get '/user/:user/config' do |user|
    permission_denied if !user[:session] || user[:session].nickname != user
    @user = session[:user]
    haml :user_config
  end

  # login form
  get '/login' do
    @error_message = session.delete(:error_message)
    haml :login
  end

  # login
  post '/login' do
    url = site_url
    identifier = params[:openid_identifier]

    checkid_request = openid_consumer.begin(identifier)
    sreg_request = OpenID::SReg::Request.new
    sreg_request.request_fields(%w(nickname email))
    checkid_request.add_extension(sreg_request)
    redirect checkid_request.redirect_url(url, url_for('/login/complete'))
  end

  # login (post process)
  get '/login/complete' do
    openid_response = openid_consumer.complete(params, request.url)

    case openid_response.status
    when :failure
      session[:error_message] = 'Login failure'
      redirect url_for('/login')
    when :setup_needed
      session[:error_message] = 'Setup needed'
      redirect url_for('/login')
    when :cancel
      session[:error_message] = 'Login canceled'
      redirect url_for('/login')
    when :success
      openid = openid_response.display_identifier
      nickname = params['openid.sreg.nickname']
      nickname ||= File.basename(openid)  # XXX: ad-hoc
      email = params['openid.sreg.email']

      if not user = User.first(:openid => openid)
        user = User.new(:openid => openid, :nickname => nickname, :email => email)
        unless user.save
          raise user.errors.full_messages.join
        end
      end
      session[:user] = user
      session[:info_message] = 'Login succeeded'
      redirect url_for('/')
    end
  end

  # login (test only)
  get '/login/:user_id' do |user_id|
    # works on test environment only
    pass unless self.class.test?
    session[:user] = User.get(user_id.to_i)
    session[:user].openid
  end

  # logout
  get '/logout' do
    session.delete(:user)
    session[:info_message] = 'Logged out'
    redirect url_for('/')
  end

  private

  def logged_in?
    !! session[:user]
  end

  def permission_denied
    halt(haml(:permission_denied))
  end

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

  def url_for(path)
    url = site_url
    url = site_url.chop if path[0] == ?/
    url + path
  end

end # Pastiche
