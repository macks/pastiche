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
require 'sass'
require 'dm-core'
require 'dm-validations'
require 'dm-timestamps'
require 'uv'

class Pastiche < Sinatra::Base

  class User
    include DataMapper::Resource
    property :id,         Serial
    property :openid,     String,   :nullable => false, :length => 256, :unique_index => :openid
    property :nickname,   String,   :nullable => false, :length => 16, :unique_index => :nickname
    property :email,      String,   :length => 128
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
    property :type,       String,   :nullable => false, :length => 40
    property :filename,   String,   :nullable => false, :length => 128
    property :comment,    String,   :length => 512
    property :text,       Text,     :nullable => false, :length => 65536

    belongs_to :user
  end

  # options
  enable :sessions
  set :path_prefix, nil
  set :haml, :escape_html => true
  set :sass, :style => :expanded
  set :root, '.'
  set :static, true

  set :uv_theme, 'iplastic'

  # initialize Ultraviolet
  @@syntaxes = Uv.syntaxes.sort.freeze

  before do
    # load sessions
    if session[:user_id]
      @authd_user = User.get(session[:user_id])
      session.delete(:user_id) unless @authd_user
    end

    # clear useless sessions
    session.delete_if {|key, value| value.nil? }
  end

  # top page
  get '/' do
    @snippets = Snippet.all(:order => [:updated_at.desc], :limit => 10)
    haml :index
  end

  # post form
  get '/new' do
    if not logged_in?
      session[:return_path] = '/new'
      redirect url_for('/login')
    end
    @syntaxes = @@syntaxes
    haml :new
  end

  # create a snippet
  post '/new' do
    permission_denied if not logged_in?
    text     = params[:text].gsub(/\r\n/, "\n")
    filename = params[:filename].strip
    type     = params[:type].strip
    comment  = params[:comment].strip
    if not @@syntaxes.include?(type)
      flash[:error] = "Unknown type: #{type}"
      redirect url_for('/new')
    end
    begin
      text.unpack('U*')
    rescue
      flash[:error] = 'Unknown character(s) in snippet.'
      redirect url_for('/new')
    end
    snippet = @authd_user.snippets.create(:filename => filename, :type => type, :comment => comment, :text => text)
    if snippet.dirty?
      flash[:error] = snippet.errors.full_messages.join('. ') + '.'
      redirect url_for('/new')
    else
      redirect url_for("/#{snippet.id}")
    end
  end

  # show a snippet
  get %r{\A/(\d+)\z} do |snippet_id|
    @snippet = Snippet.get(snippet_id)
    redirect url_for('/') unless @snippet
    haml :snippet
  end

  # download a snippet
  get %r{\A/(\d+)/download\z} do |snippet_id|
    @snippet = Snippet.get(snippet_id)
    redirect url_for('/') unless @snippet
    content_type 'text/plain'
    attachment @snippet.filename
    @snippet.text
  end

  # show a raw snippet
  get %r{\A/(\d+)/raw(?:\z|/)} do |snippet_id|
    @snippet = Snippet.get(snippet_id)
    redirect url_for('/') unless @snippet
    content_type 'text/plain'
    @snippet.text
  end

  # edit a snippet
  get %r{\A/(\d+)/edit\z} do |snippet_id|
    redirect url_for('/')  # TODO: not implemented
    @snippet = Snippet.get(snippet_id)
    redirect url_for('/') unless @snippet
    haml :edit
  end

  # show user information
  get '/user/:user' do |user|
    @user = User.first(:nickname => user)
    haml :user
  end

  # show user configuration form
  get '/user/:user/config' do |user|
    permission_denied if !user[:session] || user[:session].nickname != user
    @user = @authd_user
    haml :user_config
  end

  # login form
  get '/login' do
    haml :login
  end

  # login
  post '/login' do
    url = site_url
    identifier = params[:openid_identifier]

    begin
      checkid_request = openid_consumer.begin(identifier)
      sreg_request = OpenID::SReg::Request.new
      sreg_request.request_fields(%w(nickname email))
      checkid_request.add_extension(sreg_request)
      redirect checkid_request.redirect_url(url, url_for('/login/complete'))
    rescue
      flash[:error] = $!.to_s
      redirect url_for('/login')
    end
  end

  # login (post process)
  get '/login/complete' do
    openid_response = openid_consumer.complete(params, request.url)

    case openid_response.status
    when :failure
      flash[:error] = 'Login failure'
      redirect url_for('/login')
    when :setup_needed
      flash[:error] = 'Setup needed'
      redirect url_for('/login')
    when :cancel
      flash[:error] = 'Login canceled'
      redirect url_for('/login')
    when :success
      openid = openid_response.identity_url
      nickname = params['openid.sreg.nickname']
      nickname ||= File.basename(openid)  # XXX: ad-hoc
      email = params['openid.sreg.email']

      if not user = User.first(:openid => openid)
        user = User.new(:openid => openid, :nickname => nickname, :email => email)
        unless user.save
          flash[:error] = user.errors.full_messages.join('. ') + '.'
          redirect url_for('/login')
        end
      end
      session[:user_id] = user.id
      flash[:info] = 'Login succeeded'
      redirect url_for(session.delete(:return_path) || '/')
    end
  end

  # logout
  get '/logout' do
    session.delete(:user_id)
    flash[:info] = 'Logged out'
    redirect url_for('/')
  end

  # stylesheet
  get '/stylesheets/application.css' do
    content_type 'text/css'
    sass :application
  end

  # for test environment only
  configure :test do
    get '/login/:user_id' do |user_id|
      if user = User.get(user_id.to_i)
        session[:user_id] = user.id
        redirect url_for('/')
      else
        flash[:error] = 'Login failed'
        redirect url_for('/login')
      end
    end
  end


  private

  def logged_in?
    !! @authd_user
  end

  def permission_denied
    status 403
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
    return path if self.class.test?  # relative URL redirection for test environment.
    url = site_url
    url = site_url.chomp('/')
    url + path
  end

  def path_to(path)
    if self.class.path_prefix
      self.class.path_prefix + path
    else
      path
    end
  end

  def flash
    @flash ||= Flash.new(session)
  end

  helpers do
    def partial(name)
      haml "_#{name}".to_sym, :layout => false
    end

    def render_snippet(snippet, options = {})
      line_numbers = true
      line_numbers = options[:line_numbers] if options.has_key?(:line_numbers)
      text = snippet.text
      text = text.lines.take(options[:lines]).join if options[:lines]
      Uv.parse(text, 'xhtml', snippet.type, line_numbers, self.class.uv_theme)
    end
  end


  class Flash
    def initialize(session)
      @session = session
      @session[:flash] ||= {}
      @cache = {}
    end

    def [](key)
      @cache[key] ||= @session[:flash].delete(key)
    end

    def []=(key, value)
      @cache[key] = @session[:flash][key] = value
    end
  end # Flash

end # Pastiche
