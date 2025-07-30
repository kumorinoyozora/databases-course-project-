-- Процедура 1. Назначение диспетчера.
-- Процедура получает на вход информацию о новом самолёте,
-- вошедшим в воздушное пространства аэропорта.
-- Из всех авиадиспетчеров компании выбирается наименее загруженный и назначается полёту.

-- можно добавить предельную нагрузку для диспетчера
-- но это уже за рамками задания 

-- транзакция создаётся неявно PostgreSQL для всей процедуры,
-- поэтому нет COMMIT/ROLLBACK

CREATE OR REPLACE PROCEDURE "assign_controller_to_flight"(
  IN act_airliner_id int,
  IN act_airport_id int, -- он может быть и не посадочным, поэтому не найти через airliner_id
  OUT assigner_employee_id int,
  OUT message text
)
LANGUAGE plpgsql
AS 
$$
DECLARE
  act_flight_id int;
  least_busy_controller_id int;
BEGIN

  -- находим flight_id данного самолёта
  SELECT flight_id
  INTO act_flight_id
  FROM flight f
  WHERE airliner_id = act_airliner_id
    AND actual_arrival_time IS NULL
  ORDER BY scheduled_arrival_time DESC
  LIMIT 1;

  IF act_flight_id IS NULL THEN
    message := 'Error: for the aircraft ' || act_airliner_id || ' no active flight found';
    RETURN;
  END IF;

  -- находим наименее загруженного диспетчера данного аэропорта
  WITH controller_workload AS (
    SELECT e.employee_id,
            COUNT(fe.flight_id) AS current_flights
    FROM employee e
    LEFT JOIN flight_employee fe ON e.employee_id = fe.employee_id
      AND fe.flight_id in ( -- это обязательно именно при JOIN
        SELECT flight_id
        FROM flight
        WHERE actual_departure_time IS NULL
        )
    WHERE e.title = 'flight_controller'
      AND e.airport_id = act_airport_id
    GROUP BY e.employee_id
    ORDER BY current_flights ASC
    LIMIT 1
  )
  SELECT employee_id INTO least_busy_controller_id
  FROM controller_workload;

  IF least_busy_controller_id IS NULL THEN
    message := 'Error: There are no available flight controllers at the airport ' || act_airport_id;
    RETURN;
  END IF;

  -- назначаем диспетчера рейсу
  INSERT INTO flight_employee (flight_id, employee_id)
  VALUES (act_flight_id, least_busy_controller_id);

  assigner_employee_id := least_busy_controller_id;
  message := 'Flight controller ' || least_busy_controller_id || 
              ' assigned to flight ' || act_flight_id;

EXCEPTION WHEN OTHERS THEN 
  message := 'Flight controller assignment error: ' || SQLERRM;
  RAISE;
END;
$$;


-- Процедура 2. Назначение полосы для посадки.
-- Процедура получает на вход информацию о полёте,
-- полоса для посадки назначается та, которая приписана наименьшему числу рейсов
-- в интервале +- 30 минут от запланированного времени прибытия данного полёта 

CREATE OR REPLACE PROCEDURE "airstrip_assign"(
  IN act_flight_id int,
  IN dest_airport_id int,
  OUT assigned_airstrip_id int,
  OUT message text
)
LANGUAGE plpgsql
AS
$$
DECLARE
  act_landing_airstrip_id int;
  sch_arrival_time timestamp;
BEGIN
  SELECT airstrip_id INTO act_landing_airstrip_id
  FROM flight_airstrip
  WHERE usage_type = 'landing'
    AND flight_id = act_flight_id;

  IF act_landing_airstrip_id IS NOT NULL THEN
    message := 'Airstrip has already been assigned: ' || act_landing_airstrip_id;
    RETURN;
  END IF;

  SELECT scheduled_arrival_time
  INTO sch_arrival_time
  FROM flight
  WHERE flight_id = act_flight_id;

  IF sch_arrival_time IS NULL THEN
    message := 'Flight with ID ' || act_flight_id || ' not found';
    RETURN;
  END IF;

  -- находим полосу с минимальным количеством рейсов в интервале +-30 минут
  WITH landing_candidates AS (
    SELECT astr.airstrip_id,
            COUNT(f.flight_id) as scheduled_flights
    FROM airstrip astr
    LEFT JOIN flight_airstrip fastr ON fastr.airstrip_id = astr.airstrip_id
    LEFT JOIN flight f ON f.flight_id = fastr.flight_id 
      AND (
        (f.scheduled_arrival_time BETWEEN sch_arrival_time - INTERVAL '30 minutes' AND 
        sch_arrival_time + INTERVAL '30 minutes')
        OR (f.scheduled_departure_time BETWEEN sch_arrival_time - INTERVAL '30 minutes' AND 
        sch_arrival_time + INTERVAL '30 minutes')
      )
    WHERE astr.airport_id = dest_airport_id
    GROUP BY astr.airstrip_id
    ORDER by scheduled_flights ASC
    LIMIT 1
  )
  SELECT airstrip_id INTO act_landing_airstrip_id
  FROM landing_candidates;

  IF act_landing_airstrip_id IS NULL THEN
    message := 'Landing airstrip assignment error';
  RETURN;
  END IF;

  -- назначаем полосу для посадки
  INSERT INTO flight_airstrip (airstrip_id, flight_id, usage_type)
  VALUES (act_landing_airstrip_id, act_flight_id, 'landing');

  assigned_airstrip_id := act_landing_airstrip_id;
  message := 'Landing airstrip assigned: ' || assigned_airstrip_id ||
              ' for flight ' || act_flight_id;

EXCEPTION WHEN OTHERS THEN
  message := 'Landing airstrip assignment error: ' || SQLERRM;
  RAISE;
END;
$$;