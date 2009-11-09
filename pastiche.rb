# vim: set et sw=2 sts=2 fileencoding=utf-8:

#
# Simple pastebin-like application using Sinatra with OpenID authentication
#
# Author: MATSUYAMA Kengo

$KCODE = 'u' if RUBY_VERSION < '1.9'

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
    property :openid,     String,   :nullable => false, :length => 128, :unique_index => :openid
    property :nickname,   String,   :nullable => false, :length => 16, :unique_index => :nickname
    property :fullname,   String,   :length => 128
    property :email,      String,   :length => 128
    property :created_at, DateTime, :nullable => false, :auto_validation => false
    property :updated_at, DateTime, :nullable => false, :auto_validation => false

    has n, :snippets

    validates_is_unique :nickname
    validates_format :nickname, :with => /\A[\w\-]+\z/
    validates_format :email,    :as => :email_address
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

    validates_format :filename, :with => /\A[^\/\r\n]+\z/

    belongs_to :user
  end

  # options
  enable :sessions
  set :path_prefix, ''
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
      session.clear unless @authd_user
    end

    # clear useless sessions
    session.delete_if {|key, value| value.nil? }
  end

  # top page
  get '/' do
    @snippets = Snippet.all(:order => [:updated_at.desc], :limit => 10)
    haml :index
  end

  # show form
  get '/new' do
    if not logged_in?
      session[:return_path] = '/new'
      redirect url_for('/login')
    end
    @snippet = Snippet.new
    haml :new
  end

  # create a snippet
  post '/new' do
    permission_denied if not logged_in?
    props = validate_snippet_parameters
    @snippet = @authd_user.snippets.create(props)
    if @snippet.dirty?
      flash[:error] = @snippet.errors.full_messages.join('. ') + '.'
      haml :new
    else
      flash[:info] = 'Created'
      redirect url_for("/#{@snippet.id}")
    end
  end

  # show a snippet
  get %r{\A/(\d+)\z} do |id|
    @snippet = find_snippet(id)
    haml :snippet
  end

  # download a snippet
  get %r{\A/(\d+)/download\z} do |id|
    @snippet = find_snippet(id)
    content_type 'text/plain'
    attachment @snippet.filename
    @snippet.text
  end

  # show a raw snippet
  get %r{\A/(\d+)/raw(?:\z|/)} do |id|
    @snippet = find_snippet(id)
    content_type 'text/plain'
    @snippet.text
  end

  # edit a snippet
  get %r{\A/(\d+)/edit\z} do |id|
    @snippet = find_snippet(id)
    permission_denied if @authd_user != @snippet.user
    haml :edit
  end

  # update a snippet
  post %r{\A/(\d+)/edit\z} do |id|
    @snippet = find_snippet(id)
    permission_denied if @authd_user != @snippet.user
    redirect url_for("/#{id}") if canceled?
    props = validate_snippet_parameters
    @snippet.update(props)
    if @snippet.dirty?
      flash[:error] = @snippet.errors.full_messages.join('. ') + '.'
      haml :edit
    else
      flash[:info] = 'Updated'
      redirect url_for("/#{id}")
    end
  end

  # confirm snippet deletion
  get %r{\A/(\d+)/delete\z} do |id|
    @snippet = find_snippet(id)
    permission_denied if @authd_user != @snippet.user
    haml :delete
  end

  # delete a snippet
  post %r{\A/(\d+)/delete\z} do |id|
    @snippet = find_snippet(id)
    permission_denied if @authd_user != @snippet.user
    redirect url_for("/#{id}") if canceled?
    @snippet.destroy!
    flash[:info] = 'Deleted'
    redirect url_for('/')
  end

  # show user information
  get '/user/:user' do |user|
    @user = User.first(:nickname => user)
    redirect url_for('/') unless @user
    haml :user
  end

  # show user edit form
  get '/user/:user/edit' do |user|
    @user = @authd_user
    permission_denied if ! logged_in? || @user.nickname != user
    haml :edit_user
  end

  # update user information
  post '/user/:user/edit' do |user|
    @user = @authd_user
    permission_denied if ! logged_in? || @user.nickname != user
    redirect url_for("/user/#{user}") if canceled?
    @user.fullname = params[:fullname].strip
    @user.email    = params[:email].strip
    if @user.save
      flash[:info] = 'Your user information was updated.'
      redirect url_for("/user/#{user}")
    else
      flash[:error] = @user.errors.full_messages.join('. ') + '.'
      haml :edit_user
    end
  end

  # login form
  get '/login' do
    haml :login
  end

  # login
  post '/login' do
    identifier = params[:openid_identifier]

    begin
      checkid_request = openid_consumer.begin(identifier)
      sreg_request = OpenID::SReg::Request.new
      sreg_request.request_fields(%w(nickname fullname email))
      checkid_request.add_extension(sreg_request)
      redirect checkid_request.redirect_url(site_url, url_for('/login/complete'))
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
      if user = User.first(:openid => openid)
        session[:user_id] = user.id
        flash[:info] = 'Login succeeded'
        redirect url_for(session.delete(:return_path) || '/')
      else
        session[:user_props] = {
          :openid   => openid,
          :nickname => params['openid.sreg.nickname'] || '',
          :fullname => params['openid.sreg.fullname'] || '',
          :email    => params['openid.sreg.email'] || '',
        }
        redirect url_for('/new_user')
      end
    end
  end

  # create new user
  get '/new_user' do
    props = session.delete(:user_props)
    redirect url_for('/') unless props
    session[:openid] = props[:openid]
    @user = User.new(props)
    if User.first(:nickname => @user.nickname)
      flash[:error] = "Nickname `#{@user.nickname}' is already used by another user. Please try other name."
    end
    haml :new_user
  end

  # create new user
  post '/new_user' do
    openid   = session[:openid]
    nickname = params[:nickname].strip
    fullname = params[:fullname].strip
    email    = params[:email].strip
    @user = User.new(:openid => openid, :nickname => nickname, :fullname => fullname, :email => email)
    if User.first(:nickname => nickname)
      flash[:error] = "Nickname `#{nickname}' is already used by another user. Please try other name."
      haml :new_user
    else
      if @user.save
        session.delete(:openid)
        session[:user_id] = @user.id
        flash[:info] = 'Login succeeded'
        redirect url_for(session.delete(:return_path) || '/')
      else
        flash[:error] = @user.errors.full_messages.join('. ') + '.'
        haml :new_user
      end
    end
  end

  # logout
  get '/logout' do
    session.clear
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
    get '/login/:user_id' do |id|
      if user = User.get(id)
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

  def canceled?
    if not params[:cancel].blank?
      flash[:info] = 'Canceled'
      true
    else
      false
    end
  end

  def permission_denied
    status 403
    halt(haml(:permission_denied))
  end

  def find_snippet(id)
    snippet = Snippet.get(id)
    redirect url_for('/') unless snippet
    snippet
  end

  def validate_snippet_parameters
    params[:filename].strip!
    params[:type].strip!
    params[:comment].strip!
    params[:text].gsub!(/\r\n/, "\n")

    if not syntaxes.include?(params[:type])
      flash[:error] = "Unknown type: #{params[:type]}"
      redirect url_for('/new')
    end

    [:filename, :type, :comment, :text].inject({}) {|hash, key| hash[key] = params[key]; hash}
  end

  def openid_consumer
    storage = OpenID::Store::Filesystem.new(File.join(self.class.root, 'tmp'))
    OpenID::Consumer.new(session, storage)
  end

  def site_url
    url = "#{request.scheme}://#{request.host}"
    url << ":#{request.port}" if URI.const_get(request.scheme.upcase).default_port != request.port
    url << self.class.path_prefix
    url << '/' unless url[-1] == ?/
    url
  end

  def url_for(path)
    return path if self.class.test?  # relative URL redirection for test environment.
    site_url.chomp('/') << path
  end

  def path_to(path)
    self.class.path_prefix + path
  end

  def flash
    @flash ||= Flash.new(session)
  end

  def syntaxes
    @@syntaxes
  end

  def timezone
    # TODO: support user's timezone
    @timezone ||= Rational(Time.now.utc_offset, 86400)
  end

  def expand_tabs(text, tabstop = 8)
    text.gsub(/([^\n\t]*)\t/) { $1 + ' ' * (tabstop - $1.size % tabstop) }
  end

  helpers do
    def partial(name)
      haml "_#{name}".to_sym, :layout => false
    end

    def render_snippet(snippet, options = {})
      use_anchors = options[:anchors]
      text = snippet.text
      text = text.lines.take(options[:lines]).join if options[:lines]
      text = expand_tabs(text)
      html = Uv.parse(text, 'xhtml', snippet.type, true, self.class.uv_theme)
      html.sub!(/\A(<pre[^>]*>)(.*)<\/pre>/m, '\\2')
      pre = $1
      html.gsub!(/(<span[^>]+line-numbers[^>]+>([ \d]+)<\/span>)(.*)/) do
        n = $2.strip
        span = if use_anchors then "<a name='L#{n}' href='\#L#{n}'>#{$1}</a>" else $1 end
        "#{pre}<div class='L#{n}'>#{span}#{$3}</div></pre>"
      end
      html
    end

    def render_datetime(dt)
      dt.new_offset(timezone).strftime('%F %R')
    end
  end


  class Flash
    def initialize(session)
      @session = session
      @session[:flash] ||= {}
      @cache = {}
    end

    def [](key)
      if value = @session[:flash].delete(key)
        @cache[key] = value
      else
        @cache[key]
      end
    end

    def []=(key, value)
      @cache[key] = @session[:flash][key] = value
    end
  end # Flash

end # Pastiche
