-- Триггер 1:
-- Переводить самолет в состоянии «готов к посадке»,
-- когда до аэропорта-назначения остается меньше 20 км 

-- расчёт дистанции по координатам на сфере
CREATE FUNCTION "geodist"(
  src_lat numeric(8,6), src_lon numeric(9,6),
  dst_lat numeric(8,6), dst_lon numeric(9,6)
) RETURNS numeric
LANGUAGE plpgsql
AS
$$
DECLARE
  earth_radius numeric := 6371;
  dif_lat numeric;
  dif_lon numeric;
  a numeric;
  c numeric;
BEGIN
  dif_lat := RADIANS(dst_lat - src_lat);
  dif_lon := RADIANS(dst_lon - src_lon);

  a := SIN(dif_lat / 2) * SIN(dif_lat / 2) +
    COS(RADIANS(src_lat)) * COS(RADIANS(dst_lat)) *
    SIN(dif_lon / 2) * SIN(dif_lon / 2);
    
  c := 2 * ATAN2(SQRT(a), SQRT(1 - a));
    
  RETURN earth_radius * c;
END;
$$;

-- проверка на то, нужно ли менять статус самолёта перед новой записи в "airliner_position"
CREATE OR REPLACE FUNCTION "update_airliner_status_on_approach"()
RETURNS TRIGGER
LANGUAGE plpgsql
AS 
$$
DECLARE
	distance_to_airport numeric;
  target_airport_id int;
BEGIN
	SELECT 
	ap.airport_id,
    "geodist"(NEW.latitude, NEW.longitude, ap.latitude, ap.longitude) 
  INTO target_airport_id, distance_to_airport
	FROM airport ap 
	JOIN airstrip astr ON ap.airport_id = astr.airport_id
	JOIN flight_airstrip as fastr ON fastr.airstrip_id = astr.airstrip_id
	WHERE fastr.flight_id = (
		SELECT flight_id FROM flight
		WHERE airliner_id = NEW.airliner_id 
		AND actual_arrival_time IS NULL
		ORDER BY scheduled_departure_time DESC -- защита от случая отсутствия записи в прошлых flight
		LIMIT 1
	) 
  AND fastr.usage_type = 'landing'; -- полосы назначаются перед вылетом

	-- Если рейс или полоса не найдены
  IF target_airport_id IS NULL THEN
    RETURN NEW;
  END IF;

	IF distance_to_airport <= 20 AND NEW.status <> 'ready_to_land' THEN
		NEW.status := 'ready_to_land';
    -- Для логирования (опционально):
    RAISE NOTICE 'The airliner % has been upgraded to the "ready to land" status', NEW.airliner_id;
	END IF;
	RETURN NEW;
END; 
$$;

CREATE TRIGGER "airliner_status_change" 
BEFORE INSERT ON "airliner_position"
FOR EACH ROW
EXECUTE FUNCTION "update_airliner_status_on_approach"();


-- Триггер 2:
-- Проверять условие “Полоса становится свободной” если самолет,
-- занимавший ее последним, наберет высоту 100 метров или самолет,
-- садившийся на нее последним, завершит полет

-- 1: При наборе высоты 100 метров самолёт меняет статус 'ready_for_takeoff' -> 'in_flight' 
-- а взлётная полоса данного полёта 'not_free' -> 'free'
-- 2: высоту определяем относительно высоты местности (аэропорта взлёта), но
-- altitude аэропорта может быть отрицательной (ниже уровня моря), поэтому вычитаем её

-- как будто логичнее оформить это внутри в виде транзакции, учитывая количество действий
-- и необходимось, к примеру, одовременного измененения статуса самолёта и фиксации временни
-- хотя в триггере и не требуется время фиксировать и статус самолёта менять

CREATE OR REPLACE FUNCTION "update_airstrip_and_airliner_status"()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE
	airport_altitude smallint;
	current_airstrip_id int;
	current_airstrip_status airstrip.status;
	current_flight_id int;
BEGIN
	-- скорость взлёта 200 - 300 km/h, на 100 метрах высоты точно больше
	IF NEW.status = 'ready_for_takeoff' AND NEW.velocity > 400 THEN
		SELECT ap.altitude,
						fastr.airstrip_id,
						astr.current_status,
						fastr.flight_id
		INTO airport_altitude,
					current_airstrip_id,
					current_airstrip_status, 
					current_flight_id
		FROM airport ap 
		JOIN airstrip astr ON ap.airport_id = astr.airport_id
		JOIN flight_airstrip fastr ON fastr.airstrip_id = astr.airstrip_id
		JOIN flight f ON f.flight_id = fastr.flight_id
		WHERE f.airliner_id = NEW.airliner_id
			AND f.actual_arrival_time IS NULL
			AND fastr.usage_type = 'takeoff'
		ORDER BY f.scheduled_departure_time DESC 
		LIMIT 1;

		IF (NEW.altitude - airport_altitude) >= 100 THEN
			-- меняем статус самолёта
			NEW.status := 'in_flight';

			-- фиксируем время вылета
			UPDATE flight
			SET actual_departure_time = CURRENT_TIMESTAMP
			WHERE flight_id = current_flight_id;

			-- освобождаем полосу, если она занята
			IF current_airstrip_status = 'not_free' THEN
				UPDATE airstrip 
				SET current_status = 'free'
				WHERE airstrip_id = current_airstrip_id;
			END IF;
		END IF;

  IF current_airstrip_id IS NULL THEN 
    RETURN NEW; 
  END IF;

	-- посадка: скорость < 10 км/ч
	ELSIF NEW.status = 'ready_to_land' AND NEW.velocity < 10 THEN
		SELECT fastr.airstrip_id,
						astr.current_status,
						fastr.flight_id
		INTO current_airstrip_id, 
					current_airstrip_status, 
					current_flight_id
		FROM airstrip astr 
		JOIN flight_airstrip fastr ON fastr.airstrip_id = astr.airstrip_id
		JOIN flight f ON f.flight_id = fastr.flight_id
		WHERE f.airliner_id = NEW.airliner_id 
			AND actual_arrival_time IS NULL
			AND fastr.usage_type = 'landing'
		ORDER BY scheduled_arrival_time DESC 
		LIMIT 1;

		-- на такой скорости он точно на земле, меняем статус самолёта
		NEW.status := 'waiting_to_be_checked_by_a_mechanic';

		-- фиксируем время прибытия
		UPDATE flight
		SET actual_arrival_time = CURRENT_TIMESTAMP
		WHERE flight_id = current_flight_id;
		
		-- освобождаем полосу, если она занята
		IF (current_airstrip_status = 'not_free') THEN	
			UPDATE airstrip 
			SET current_status = 'free'
			WHERE airstrip_id = current_airstrip_id;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;

CREATE TRIGGER "airstrip_status_change"
BEFORE INSERT ON "airliner_position"
FOR EACH ROW
EXECUTE FUNCTION "update_airstrip_and_airliner_status"();