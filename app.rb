require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'pry'

require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload "database_persistence.rb"
end

before do
  @storage = DatabasePersistence.new
end


def valid_status?(status)
  ["active", "inactive", "all"].include?(status)
end

def valid_name?(name)
  name.length > 0 && name.length < 255
end

def valid_session?(params)
  params.has_value?('t')
end


# -----------------------------------------------

get "/" do
 erb :home
end


# View list of all exercises --------------------
get "/exercises/view/:status" do

  if valid_status?(params[:status])
    @list = @storage.exercises(params[:status])
    erb :all_exercises
  else
    @list = @storage.exercises("active")
    redirect "/exercises/view/active"
  end
end

post "/exercises/view" do

  status = params[:status]
  redirect "/exercises/view/#{status}"
end

# Add new exercise -----------------------------
get "/exercise/new" do

  erb :add_exercise
end

post "/exercise/new" do
  name = params[:name]
  description = params[:description]

  if valid_name?(name)
    @storage.add_exercise(name, description)
    session[:success] = "New exercise added"
    redirect "/exercises/view/active"
  else
    session[:error] = "Name must be between 1 and 255 characters."
    erb :add_exercise
  end
end

# Start PT Session -------------------------------

get "/session/new" do
  
  @session_list = @storage.session_exercises
  erb :new_session
end

post "/session/completed" do

  # session_id = @storage.next_session_id
  if valid_session?(params)
    session[:success] = "Session logged. Good work!"
    redirect "/"
  else
    message = "You must check off at least 1 exercise to save a workout session."
    session[:error] =  message
    redirect "/session/new"
  end
end

# Reports ------------------------------------------

get "/reports" do
  "data goes here"
end

