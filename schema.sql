CREATE TABLE exercises (
  id serial PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  description text,
  date_added timestamp DEFAULT NOW(),
  active boolean DEFAULT true
);

CREATE TABLE exercises_completed (
  exercise_id integer references exercises(id) NOT NULL,
  session_id integer NOT NULL,
  reps integer CHECK (reps > 0),
  date_completed timestamp DEFAULT NOW()
);

CREATE SEQUENCE session_id_seq;

