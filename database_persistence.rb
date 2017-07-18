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

  def determine_list_query(status)
    if status == "active"
      "SELECT * FROM exercises WHERE active = true ORDER BY date_added DESC;"
    elsif status == "inactive"
      "SELECT * FROM exercises WHERE active = false ORDER BY date_added DESC;"
    else
      "SELECT * FROM exercises"
    end
  end

  def query(statement, *params)
    @db.exec_params(statement, params)
  end

  def exercises(status)
    sql = determine_list_query(status)
    result = query(sql)
    
    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def add_exercise(name, description)
    sql = "INSERT INTO exercises (name, description) VALUES ($1, $2);"
    query(sql, name, description)
  end

  def session_exercises
    sql = "SELECT id, name FROM exercises WHERE active = true;"
    result = query(sql)
    
    result.map do |tuple|
      {exercise_id: tuple["id"].to_i,
       name: tuple["name"],
       completed: tuple["completed"] = 'f'}
    end
  end

  def next_session_id
    sql = "SELECT nextval('session_id_seq');"
    result = query(sql)
    result.field_values("nextval").first.to_i
  end


  private

  def tuple_to_list_hash(tuple)
    { exercise_id: tuple["id"].to_i,
      name: tuple["name"],
      description: tuple["description"],
      date_added: tuple["date_added"],
      active: tuple["active"]
    }
  end

end