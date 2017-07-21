require "pg"

require 'pry'

class DatabasePersistence
  def initialize
    @db = if Sinatra::Base.production?
             PG.connect(ENV['DATABASE_URL'])
          else
             PG.connect(dbname: "pttracker")
          end
  end

  def query(statement, *params)
    @db.exec_params(statement, params)
  end

# Exercises/view/all -------------------------------------------------
  def determine_exercise_list_query(status)
    if status == "active"
      <<~SQL 
        SELECT exercises.id, exercises.name, exercises.active,
          COUNT(exercise_id) AS exercise_completed_count 
        FROM exercises
          LEFT JOIN exercises_completed e ON (exercises.id = e.exercise_id)
        GROUP BY exercises.id
        HAVING active = 't';
      SQL

    elsif status == "inactive"
      <<~SQL
        SELECT exercises.id, exercises.name, exercises.active,
          COUNT(exercise_id) AS exercise_completed_count 
        FROM exercises
          LEFT JOIN exercises_completed e ON (exercises.id = e.exercise_id)
        GROUP BY exercises.id
        HAVING active = 'f';
      SQL
    else
      <<~SQL
        SELECT exercises.id, exercises.name, exercises.active,
          COUNT(exercise_id) AS exercise_completed_count 
        FROM exercises
          LEFT JOIN exercises_completed e ON (exercises.id = e.exercise_id)
        GROUP BY exercises.id;
      SQL
    end
  end

  def exercise_list(status)
    sql = determine_exercise_list_query(status)
    result = query(sql)
    
    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

# exercise/add------------------------------------------------------
# checking for duplicate names when adding
  def exercise_names
    sql = "SELECT name FROM exercises;"
    query(sql).field_values('name')
  end

# insert data for new exercise
  def add_exercise(name, description)
    sql = "INSERT INTO exercises (name, description) VALUES ($1, $2);"
    query(sql, name, description)
  end

# Get id and name for new workout session list -------------------------
  def session_exercise_list
    sql = "SELECT id, name FROM exercises WHERE active = true ORDER BY name;"
    result = query(sql)
    
    result.map do |tuple|
      {id: tuple["id"].to_i,
       name: tuple["name"],
       completed: tuple["completed"] = 'f'}
    end
  end

# Get next session id
  def next_session_id
    sql = "SELECT nextval('session_id_seq');"
    result = query(sql)
    result.field_values("nextval").first.to_i
  end

# Insert new data into exercises_completed when session complete
  def save_workout_session(list, session_id)
    list.each do |exercise_id|
      sql = "INSERT INTO exercises_completed (exercise_id, session_id) VALUES ($1, $2)"
      query(sql, exercise_id, session_id)
    end
  end

# Get all data for single exercise page --------------------------------------
  def single_exercise_information(id)
    sql = "SELECT * FROM exercises WHERE id = $1"
    result = query(sql, id)

    result.map do |tuple| 
      tuple_to_list_hash(tuple)
    end
  end

  def single_exercise_completed_count(id)
    sql = "SELECT COUNT(exercise_id) FROM exercises_completed WHERE exercise_id = $1"
    query(sql, id).values[0][0].to_i
  end


  private

# Format result for exercise_list for exercises/view
  def tuple_to_list_hash(tuple)
    { id: tuple["id"].to_i,
      name: tuple["name"],
      completed_count: tuple["exercise_completed_count"],
      active: tuple["active"]
    }
  end

end