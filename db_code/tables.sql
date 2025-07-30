CREATE SCHEMA "airliner";

CREATE SCHEMA "airstrip";

CREATE TYPE "airliner"."status" AS ENUM 
(
  'in_flight',
  'ready_for_takeoff',
  'ready_to_land',
  'faulty',
  'to_be_checked_by_a_mechanic',
  'waiting_to_be_checked_by_a_mechanic'
);

CREATE TYPE "airstrip"."status" AS ENUM 
(
  'free',
  'not_free'
);

CREATE TYPE "airstrip"."usage_type" AS ENUM 
(
  'takeoff',
  'landing'
);

CREATE TABLE "airport" 
(
  "airport_id" serial PRIMARY KEY,
  "latitude" numeric(8,6) NOT NULL,
  "longitude" numeric(9,6) NOT NULL,
  "altitude" smallint CHECK ("altitude" < 2000) NOT NULL,
  "airspace_radius" int, -- 100 - 150 km
  "city" varchar NOT NULL,
  "country" varchar NOT NULL,
  "name" varchar
);

CREATE TABLE "airliner" 
(
  "airliner_id" serial PRIMARY KEY,
  "airport_id" int NOT NULL,
  "length" float,
  "width" float,
  "height" float
);

CREATE TABLE "airliner_position" 
(
  "airliner_id" int NOT NULL,
  "altitude" smallint CHECK ("altitude" < 20000),
  "latitude" numeric(8,6) NOT NULL,
  "longitude" numeric(9,6) NOT NULL,
  "time" timestamp NOT NULL,
  "direction" float,
  "pitch" float,
  "velocity" numeric(6, 2) NOT NULL,
  "status" airliner.status NOT NULL,
  PRIMARY KEY ("airliner_id", "time")
);

CREATE TABLE "flight" 
(
  "flight_id" serial PRIMARY KEY,
  "airliner_id" int NOT NULL,
  "scheduled_departure_time" timestamp NOT NULL,
  "scheduled_arrival_time" timestamp NOT NULL,
  "actual_departure_time" timestamp,
  "actual_arrival_time" timestamp,
  CHECK ("actual_arrival_time" IS NULL OR
    (
      "actual_departure_time" IS NOT NULL AND
      "actual_arrival_time" IS NOT NULL AND
      "actual_arrival_time" > "actual_departure_time"
    )
  )
);

CREATE TABLE "employee" 
(
  "employee_id" serial PRIMARY KEY,
  "airport_id" int,
  "title" varchar(50) CHECK (LENGTH("title") > 1) NOT NULL,
  "lastname" varchar NOT NULL,
  "firstname" varchar NOT NULL,
  "patronymic" varchar,
  "age" smallint CHECK ("age" > 18 AND "age" < 80) NOT NULL
);

CREATE TABLE "employees_position" 
(
  "title" varchar(50) CHECK (LENGTH("title") > 1) PRIMARY KEY,
  "work_responsibilities_list" varchar[]
);

CREATE TABLE "passenger" 
(
  "passenger_id" serial PRIMARY KEY,
  "lastname" varchar NOT NULL,
  "firstname" varchar NOT NULL,
  "patronymic" varchar,
  "passport_number" varchar(20) UNIQUE NOT NULL,
  "citizenship" varchar NOT NULL
);

CREATE TABLE "flight_ticket" 
(
  "ticket_number" serial PRIMARY KEY,
  "flight_id" int NOT NULL,
  "passenger_id" int
);

ALTER SEQUENCE flight_ticket_ticket_number_seq RESTART WITH 100000000;

CREATE TABLE "airstrip" 
(
  "airstrip_id" serial PRIMARY KEY,
  "airport_id" int NOT NULL,
  "current_status" airstrip.status NOT NULL,
  "latitude" numeric(8,6) NOT NULL,
  "longitude" numeric(9,6) NOT NULL,
  "length" float,
  "direction" float
);

CREATE TABLE "hangar" 
(
  "hangar_id" serial PRIMARY KEY,
  "airport_id" int NOT NULL,
  "latitude" numeric(8,6) NOT NULL,
  "longitude" numeric(9,6) NOT NULL,
  "width" float,
  "length" float,
  "height" float
);

CREATE TABLE "flight_airstrip" 
(
  "airstrip_id" int NOT NULL,
  "flight_id" int NOT NULL,
  "usage_type" airstrip.usage_type,
  PRIMARY KEY ("flight_id", "airstrip_id")
);

CREATE TABLE "flight_employee" 
(
  "employee_id" int NOT NULL,
  "flight_id" int NOT NULL,
  PRIMARY KEY ("flight_id", "employee_id")
);