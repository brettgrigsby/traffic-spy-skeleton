require 'uri'
module TrafficSpy
  class Server < Sinatra::Base

    helpers do
      def protected!
        return if authorized?
        headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
        halt 401, "Not authorized\n"
      end

      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [@client.identifier, @client.identifier + 'pass']
      end

    end

    get '/' do
      erb :index
    end

    not_found do
      @error = "404 : Page not found"
      erb :error
    end

    post '/sources' do
      result = TrafficSpy::ClientCreator.new(params)
      status  result.status
      body    result.body
    end

    post '/sources/:id/data' do |id|
      get_client(id)
      result = TrafficSpy::PayloadCreator.new(params[:payload], @client)
      status  result.status
      body    result.body
    end

    get '/sources/:id' do |id|
      get_client(id)
      if @client
        protected!
        erb :dashboard
      else
        @error = "The Identifier '#{id}' does not exist."
        erb :error
      end
    end

    get '/sources/:id/urls/*' do |id, splat|
      get_client(id)
      @client.take_path(splat) if @client
      if @client && @client.path_exists?
        protected!
        erb :url
      elsif @client
        @error = "The path '/#{splat}' has not been requested"
        erb :error
      else
        @error = "The Identifier '#{id}' does not exist."
        erb :error
      end
    end

    get '/sources/:id/events/:event' do |id, event|
      get_client(id)
      @client.take_event(event) if @client
      if @client && @client.event_exists?
        protected!
        erb :event
      elsif @client
        @error = "The event '#{event}' has not been defined"
        @event_link = "/sources/#{id}/events"
        erb :error
      else
        @error = "The Identifier '#{id}' does not exist."
        erb :error
      end
    end

    get '/sources/:id/events' do |id|
      get_client(id)
      if @client
        protected!
        erb :events
      else
        @error = "The Identifier '#{id}' does not exist."
        erb :error
      end
    end

    private

    def get_client(id)
      @client = TrafficSpy::Client.find_by(identifier: id)
    end
  end
end
