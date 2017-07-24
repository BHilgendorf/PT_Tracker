require 'sinatra'
require 'tilt/erubis'
require 'pry'

require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistence.rb'
end

before do
  @storage = DatabasePersistence.new
end

helpers do
  def completed_count(id)
    @storage.single_exercise_completed_count(id)
  end

  def sort_exercies(exercise_list)
    exercise_list.sort_by { |exercise| exercise[:active] }.reverse
  end

  def button_status_class(current_status)
    current_status == 't' ? 'current-status-active' : 'current-status-inactive'
  end
end

# ---------------------------------------------------------
def valid_exercise_status?(status)
  %w(active inactive all).include?(status)
end

def invalid_exercise_name_length?(name)
  name.length <= 0 || name.length > 255
end

def duplicate_exercise_name?(name)
  existing_names = @storage.exercise_names
  existing_names.map(&:downcase).include?(name.downcase)
end

def non_empty_workout?(params)
  params.value?('t')
end

def completed_exercises(params)
  list = params.keys.map(&:to_i)
  list.delete(0)
  list
end

def save_workout_session(params)
  list = completed_exercises(params)
  session_id = @storage.next_session_id
  @storage.save_workout_session(list, session_id)
end

def toggle(current_status, id)
  if current_status == 't'
    @storage.update_exercise(false, id)
  else
    @storage.update_exercise(true, id)
  end
end

# -----------------------------------------------

get '/' do
  erb :home
end

# View list of all exercises --------------------
get '/exercises/view/:status' do
  if valid_exercise_status?(params[:status])
    @list = @storage.exercise_list(params[:status])
    erb :all_exercises
  else
    @list = @storage.exercise_list('active')
    redirect '/exercises/view/active'
  end
end

# Add new exercise -----------------------------
get '/exercise/new' do
  erb :add_exercise
end

post '/exercise/new' do
  name = params[:name]
  description = params[:description]

  if invalid_exercise_name_length?(name)
    session[:error] = 'Name must be between 1 and 255 characters.'
    erb :add_exercise
  elsif duplicate_exercise_name?(name)
    session[:error] = 'That exercise name is already in the system.'
    erb :add_exercise
  else
    @storage.add_exercise(name, description)
    session[:success] = 'New exercise added'
    redirect '/exercises/view/active'
  end
end

# Toggle exercises status ---------------------
post '/exercise/:id/status' do
  current_status = params[:current_status]
  id = params[:id].to_i
  toggle(current_status, id)

  redirect "exercises/view/#{params[:page_status]}"
end

# View Single Exercise --------------------------
get '/exercise/:id' do
  @exercise = @storage.single_exercise_information(params[:id]).first
  erb :single_exercise
end

# Update Single Exercise

get '/exercise/update/:id' do
  @exercise = @storage.single_exercise_information(params[:id]).first
  erb :edit_exercise
end

post '/exercise/update/:id' do
  id = params[:id]
  name = params[:name]
  description = params[:description]
  exercise = @storage.single_exercise_information(params[:id]).first

  if invalid_exercise_name_length?(name)
    session[:error] = 'Name must be between 1 and 255 characters.'
    redirect "/exercise/update/#{params[:id]}"

  elsif exercise[:name] != name
    @storage.update_exercise_name(name, id)
    redirect "/exercise/#{id}"
  
  end
    redirect '/exercises/view/active'

end

# Start PT Session -------------------------------

get '/session/new' do
  @session_list = @storage.session_exercise_list
  erb :new_session
end

post '/session/completed' do
  if non_empty_workout?(params)
    save_workout_session(params)
    number_completed = completed_exercises(params).size
    session[:success] = 'Session logged. #{number_completed} exercises done. Good work!'
    redirect '/'
  else
    message = 'You must check off at least 1 exercise to save a workout session.'
    session[:error] = message
    redirect '/session/new'
  end
end

# Reports ------------------------------------------

get '/reports' do
  'data goes here'
end

