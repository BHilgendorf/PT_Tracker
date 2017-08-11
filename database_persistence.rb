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
        HAVING active = 't'
        ORDER BY name;
      SQL

    elsif status == "inactive"
      <<~SQL
        SELECT exercises.id, exercises.name, exercises.active,
          COUNT(exercise_id) AS exercise_completed_count 
        FROM exercises
          LEFT JOIN exercises_completed e ON (exercises.id = e.exercise_id)
        GROUP BY exercises.id
        HAVING active = 'f'
        ORDER BY name;
      SQL
    else
      <<~SQL
        SELECT exercises.id, exercises.name, exercises.active,
          COUNT(exercise_id) AS exercise_completed_count 
        FROM exercises
          LEFT JOIN exercises_completed e ON (exercises.id = e.exercise_id)
        GROUP BY exercises.id
        ORDER BY active DESC, name;
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
# checking for duplicate names when adding or editing
  def exercise_names(id)
    if id.nil?
      query("SELECT name FROM exercises;").field_values('name')
    else
      sql = "SELECT id, name FROM exercises WHERE id != $1;"
      query(sql, id).field_values('name')
    end
  end

# insert data for new exercise
  def add_exercise(name, description)
    sql = "INSERT INTO exercises (name, description) VALUES ($1, $2);"
    query(sql, name, description)
  end


  # toggle active status
  def update_exercise_status(new_status, id)

    sql = "UPDATE exercises SET active = $1 WHERE id = $2;"
    query(sql, new_status, id)
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
      { id: tuple["id"].to_i,
        name: tuple["name"],
        description: tuple["description"],
        date_added: tuple["date_added"],
        active: tuple["active"] }
    end
  end

# count number of times exercise has been completed
  def single_exercise_completed_count(id)
    sql = "SELECT COUNT(exercise_id) FROM exercises_completed WHERE exercise_id = $1"
    query(sql, id).values[0][0].to_i
  end

# get list of existing exercise id's
  def exercise_id_list
    query("SELECT id FROM exercises;").field_values('id')
  end

# Delete single exercise -----------------------------------
  def delete_exercise(id)
    sql = "DELETE FROM exercises WHERE id = $1"
    query(sql, id)
  end

# Update exercise information ---------------------------
  def update_exercise_data(id, name, description)
    sql = "UPDATE exercises SET name = $1, description = $2 WHERE id = $3"
    query(sql, name, description, id )
  end

  # Home page
  # Get total exercises completed cout

  def total_exercise_count
    sql = "SELECT COUNT(exercise_id) FROM exercises_completed;"
    result = query(sql)
    result.field_values('count').first
  end

  def total_session_count
    sql = "SELECT COUNT(DISTINCT(session_id)) FROM exercises_completed;"
    result = query(sql)
    result.field_values('count').first
  end

# Get Session History Information --------------------
  def session_history
    sql = <<~SQL
      SELECT session_id, date_completed::date, COUNT(exercise_id) FROM exercises_completed
        GROUP BY date_completed::date, session_id
        ORDER BY session_id;
    SQL
    result = query(sql)

    result.map do |tuple| 
      { id: tuple["session_id"].to_i,
        date_completed: tuple["date_completed"],
        completed_count: tuple["count"].to_i
      }
    end
  end


  def single_session(id)
    sql = <<~SQL
      SELECT exercises.name, exercises.id FROM exercises_completed
        INNER JOIN exercises ON (exercises_completed.exercise_id = exercises.id)
        WHERE session_id = $1
        ORDER BY exercises.name;
    SQL

    result = query(sql, id)
    result.map do |tuple|
      { id: tuple["id"].to_i,
        name: tuple["name"]
      }
    end
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