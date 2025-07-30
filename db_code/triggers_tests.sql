-- Для триггера 1 

-- Кейс 1
-- ожидаемый результат: ready_to_land

-- рейс из Сочи (airport_id=4) в Шереметьево (airport_id=1)
INSERT INTO flight (airliner_id, scheduled_departure_time, scheduled_arrival_time)
VALUES (18, NOW(), NOW() + INTERVAL '2 hour');  -- Самолёт airliner_id=18 (привязан к Сочи)

-- назначаем полосу для посадки в Шереметьево (airstrip_id=1)
INSERT INTO flight_airstrip (airstrip_id, flight_id, usage_type)
VALUES (1, currval('flight_flight_id_seq'), 'landing');

-- какое-то начальное положение уже после взлёта
INSERT INTO airliner_position (
  airliner_id, altitude, latitude, longitude,
  time, direction, velocity, status
) VALUES (
  18, 1000, 43.552406,  39.981640, 
  NOW() + INTERVAL '5 minute', 180.0, 450.0, 'in_flight'
);

UPDATE flight
SET actual_departure_time = NOW() + INTERVAL '1 minute'
WHERE flight_id = currval('flight_flight_id_seq');

-- координаты: 55.972778 (Шереметьево) + 0.135 ≈ 56.107778 (~15 км севернее)
INSERT INTO airliner_position (
  airliner_id, altitude, latitude, longitude,
  time, direction, velocity, status
) VALUES (
  18, 5000, 56.107778,  37.414722, 
  NOW(), 180.0, 800.0, 'in_flight'
);


SELECT *
FROM airliner_position
WHERE airliner_id = 18
ORDER BY time DESC;

-- Кейс 2
-- во втором INSERT координаты 55.437170, 37.767994
-- ожидаемый результат: in_flight (расстояние >20 км)

-- Кейс 3
-- делаем тот же 2-ой INSERT без предварительного создания рейсов
-- ожидаемый результат: in_flight (триггер игнорирует самолёты без рейсов)

-- Чистим таблицы после тестов
-- TRUNCATE TABLE flight CASCADE;
-- ALTER SEQUENCE flight_flight_id_seq RESTART WITH 1;
-- TRUNCATE TABLE airliner_position, flight_airstrip;




-- Для триггера 2

-- Кейс 1
-- ожидаемый результат:
-- status = 'in_flight'
-- current_status = 'free'
-- actual_departure_time IS NOT NULL

-- рейс для самолёта airliner_id=24 (Сочи)
INSERT INTO flight (airliner_id, scheduled_departure_time, scheduled_arrival_time)
VALUES (24, NOW(), NOW() + INTERVAL '2 hour');

-- назначаем полосу для посадки в Шереметьево (airstrip_id=1)
INSERT INTO flight_airstrip (airstrip_id, flight_id, usage_type)
VALUES (1, currval('flight_flight_id_seq'), 'landing');

-- назначаем взлётную полосу в Сочи (airstrip_id=18)
INSERT INTO flight_airstrip (airstrip_id, flight_id, usage_type)
VALUES (18, currval('flight_flight_id_seq'), 'takeoff');

-- полоса взлёта должна быть помечена как занятая (для теста)
UPDATE airstrip SET current_status = 'not_free' WHERE airstrip_id = 18;

-- значения до взлёта
INSERT INTO airliner_position (
  airliner_id, altitude, latitude, longitude,
  time, direction, velocity, status
) VALUES (
  24, 30, 43.450000, 39.956667, 
  NOW() + INTERVAL '1 minute', 90.0, 250.0, 'ready_for_takeoff'
);

-- значения взлёта
-- координаты аэропорта Сочи: 43.450000, 39.956667, altitude=27
-- высота самолёта: 27 + 100 = 127 м
INSERT INTO airliner_position (
  airliner_id, altitude, latitude, longitude,
  time, direction, velocity, status
) VALUES (
  24, 127, 43.450000, 39.956667, 
  NOW() + INTERVAL '3 minute', 90.0, 401.0, 'ready_for_takeoff'
);

-- Кейс 2 (совмещённый)
-- status = 'to_be_checked_by_a_mechanic'
-- current_status = 'free'
-- actual_arrival_time IS NOT NULL

-- полоса посадки должна быть помечена как занятая (для теста)
UPDATE airstrip SET current_status = 'not_free' WHERE airstrip_id = 1;

-- значения посадки
INSERT INTO airliner_position (
  airliner_id, altitude, latitude, longitude, time, direction, velocity, status
) VALUES (
  24, 193, 55.972778, 37.414722, 
  NOW() + INTERVAL '2 hour' + INTERVAL '10 minute', 270.0, 5.0, 'ready_to_land'
);

-- этот блок выполняется после каждого из INSERT выше
-- т.к. статус полосы и времена во flight не логируются
SELECT DISTINCT alp.time,
		    f.airliner_id,
        astr.airstrip_id,
        astr.current_status as airstrip_status,
        alp.status as airliner_status,
        f.actual_departure_time,
        f.actual_arrival_time
FROM flight f 
JOIN airliner al on f.airliner_id = al.airliner_id
JOIN airliner_position alp on alp.airliner_id = al.airliner_id
JOIN flight_airstrip fastr on f.flight_id = fastr.flight_id
JOIN airstrip astr on astr.airstrip_id = fastr.airstrip_id
WHERE f.flight_id = currval('flight_flight_id_seq')
ORDER BY alp.time DESC;

-- Чистим таблицы после тестов
-- TRUNCATE TABLE flight CASCADE;
-- ALTER SEQUENCE flight_flight_id_seq RESTART WITH 1;
-- TRUNCATE TABLE airliner_position, flight_airstrip;