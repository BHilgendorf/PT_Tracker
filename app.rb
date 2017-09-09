require 'sinatra'
require 'tilt/erubis'
require 'date'
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
  def button_status_class(current_status)
    current_status == 't' ? 'current-status-active' : 'current-status-inactive'
  end
end

# Validation Checks-----------------------------------------------------
def valid_exercise_status?(status)
  %w(active inactive all).include?(status)
end

def duplicate_exercise_name?(name, *id)
  existing_names = @storage.exercise_names(id.first)
  existing_names.map(&:downcase).include?(name.downcase)
end

def valid_workout_session?(params)
  params.value?('t')
end

def existing_exercise_id?(id)
  id_list = @storage.exercise_id_list
  id_list.include?(id)
end

# Validation check with error message setting --------------
def error_for_exercise_name(name, id)
  if name.length <= 0 || name.length > 255
    'Name must be between 1 and 255 characters.'
  elsif duplicate_exercise_name?(name, id)
    "The name '#{name}' is already in the system."
  end
end

def error_for_no_exercise_id(id)
  "Exercise with id '#{id}' does not exist." if existing_exercise_id?(id) == 'f'
end

def error_for_exercise_completed(id)
  in_use = <<~MESSAGE
    Exercise has been marked completed as part of a session and
     connot be deleted.
  MESSAGE

  in_use if completed_count(id) > 0
end

# Accessing completed exercise information ------------------
def completed_exercises(params)
  list = params.keys.map(&:to_i)
  list.delete(0)
  list
end

def completed_count(id)
  @storage.single_exercise_completed_count(id)
end

# Data updates-----------------------------------------------
def save_workout_session(params)
  list = completed_exercises(params)
  session_id = @storage.next_session_id
  @storage.save_workout_session(list, session_id)
end

def toggle_active_status(current_status, id)
  if current_status == 't'
    @storage.update_exercise_status(false, id)
  else
    @storage.update_exercise_status(true, id)
  end
end

def delete_exercise(id)
  @storage.delete_exercise(id)
end

# Routes
# Home Page --------------------------------------------
get '/' do
  @total_exercises_completed = @storage.total_exercise_count
  @total_workout_sessions = @storage.total_session_count

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
  error = error_for_exercise_name(name, nil)

  if error
    session[:error] = error
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
  id = params[:id]
  toggle_active_status(current_status, id) if existing_exercise_id?(id)

  redirect "exercises/view/#{params[:page_status]}"
end

# View Single Exercise --------------------------
get '/exercise/:id' do
  id = params[:id]
  error = error_for_no_exercise_id(id)

  if error
    session[:error] = error
    redirect '/exercises/view/active'
  else
    @exercise = @storage.single_exercise_information(id).first
    erb :single_exercise
  end
end

# Update Single Exercise-----------------------------
get '/exercise/update/:id' do
  id = params[:id]
  error = error_for_no_exercise_id(id)

  if error
    session[:error] = error
    redirect '/exercises/view/active'
  else
    @exercise = @storage.single_exercise_information(id).first
    erb :edit_exercise
  end
end

post '/exercise/update/:id' do
  id = params[:id]
  name = params[:name]
  description = params[:description]

  error = error_for_no_exercise_id(id)
  if error
    session[:error] = error
    redirect '/exercises/view/active'
  end

  error = error_for_exercise_name(name, id)
  if error
    session[:error] = error
    redirect "/exercise/update/#{id}"
  else
    @storage.update_exercise_data(id, name, description)
    redirect "/exercise/#{id}"
  end
end

# Delete Single Exercise -------------------------
post '/exercise/delete/:id' do
  id = params[:id]
  error = error_for_exercise_completed(id)

  if error
    session[:error] = error
    redirect "/exercise/#{id}"
  end

  error = error_for_no_exercise_id(id)
  if error
    session[:error] = error
  else
    delete_exercise(id)
    session[:success] = "Exercise '#{params[:name]}' has been deleted."
  end

  redirect '/exercises/view/active'
end

# Start PT Session -------------------------------

get '/session/new' do
  @active_exercise_list = @storage.session_exercise_list
  erb :new_session
end

post '/session/completed' do
  if valid_workout_session?(params)
    save_workout_session(params)
    number_completed = completed_exercises(params).size
    message = "Session logged. #{number_completed} exercises done. Good work!"
    session[:success] = message
    redirect '/'
  else
    message = 'You must check off at least 1 exercise to save a workout session.'
    session[:error] = message
    redirect '/session/new'
  end
end

# Session Data------------------------------------------

get '/session/history' do
  # need to handle no session data
  @sessions_completed = @storage.session_history
  erb :sessions
end

get '/session/:id' do
  # need to handle invalid session id
  id = params[:id]

  @single_session_data = @storage.single_session(id)
  erb :session
end
