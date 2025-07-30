-- Для процедуры 1 

-- Кейс 1
-- ожидаемый результат: вывод сообщения о назначении одного из диспетчеров

-- создаём рейс Сочи (4) -> Шереметьево (1)
INSERT INTO flight (
    airliner_id, scheduled_departure_time, scheduled_arrival_time
) VALUES (25, NOW(), NOW() + INTERVAL '2 hour');

CALL assign_controller_to_flight(
  act_airliner_id => 25, 
  act_airport_id => 1, 
  assigner_employee_id => NULL, 
  message => NULL
);

-- проверяем назначенного диспетчера
SELECT 
  e.employee_id,
  e.lastname || ' ' || e.firstname AS controller_name,
  COUNT(fe.flight_id) AS current_workload
FROM flight_employee fe
JOIN employee e ON fe.employee_id = e.employee_id
WHERE e.title = 'flight_controller'
GROUP BY e.employee_id, e.lastname, e.firstname;

-- Кейс 2
-- у диспетчеров разная нагрузка
-- ожидаемый результат: назначение наименее загруженного диспетчера (6)

-- Создаём 5 тестовых рейсов
INSERT INTO flight (
  airliner_id, scheduled_departure_time, scheduled_arrival_time
  ) VALUES 
    (24, NOW(), NOW() + INTERVAL '1 hour'),
    (25, NOW(), NOW() + INTERVAL '2 hour'),
    (26, NOW(), NOW() + INTERVAL '3 hour'),
    (27, NOW(), NOW() + INTERVAL '4 hour'),
    (28, NOW(), NOW() + INTERVAL '5 hour'),
    (29, NOW(), NOW() + INTERVAL '6 hour');

-- Назначаем всех диспетчеров
INSERT INTO flight_employee (flight_id, employee_id)
VALUES 
  (1, 4), 
  (2, 4), 
  (3, 5), 
  (4, 5), 
  (5, 6); 

CALL assign_controller_to_flight(
  act_airliner_id => 29, 
  act_airport_id => 1, 
  assigner_employee_id => NULL, 
  message => NULL
);

-- Кейс 3
-- отсутствие активного рейса
-- ожидаемый результат: ошибка

INSERT INTO flight (
  airliner_id, 
  scheduled_departure_time, 
  scheduled_arrival_time,
  actual_departure_time,
  actual_arrival_time 
)
VALUES (24,
		    NOW() - INTERVAL '3 hour',
        NOW() - INTERVAL '1 hour',
		    NOW() - INTERVAL '3 hour',
        NOW() - INTERVAL '1 hour');

CALL assign_controller_to_flight(24, 1, NULL, NULL);

-- TRUNCATE TABLE flight CASCADE;
-- ALTER SEQUENCE flight_flight_id_seq RESTART WITH 1;




-- Для процедуры 2

-- Кейс 1
-- назначение полосы при отсутствии конкурирующих рейсов
-- ожидаемый результат: назначение одной из полос и приписание
-- её к созданному рейсу с типом 'landing'

-- Сочи -> Шереметьево
INSERT INTO flight (airliner_id, scheduled_departure_time, scheduled_arrival_time)
VALUES (24, NOW(), NOW() + INTERVAL '2 hour');

CALL airstrip_assign(
  act_flight_id => 1, 
  dest_airport_id => 1,  -- Шереметьево
  assigned_airstrip_id => NULL, 
  message => NULL
);

-- Проверяем назначенную полосу
SELECT 
  fa.airstrip_id,
  a.airport_id,
  f.flight_id,
  fa.usage_type
FROM flight_airstrip fa
JOIN airstrip a ON fa.airstrip_id = a.airstrip_id
JOIN flight f ON f.flight_id = fa.flight_id
WHERE f.flight_id = 1;

-- TRUNCATE TABLE flight CASCADE;
-- ALTER SEQUENCE flight_flight_id_seq RESTART WITH 1;

-- Кейс 2
-- полосы с разной разнородной загрузкой
-- ожидаемый результат: выбор полосы с наименьшей суммарной загрузкой 

-- в Шереметьево 6 полос и 7 самолётов
INSERT INTO flight (
  airliner_id, scheduled_departure_time, scheduled_arrival_time
  ) VALUES 
  -- рейсы в SVO
  (24, NOW(), NOW() + INTERVAL '1.5 hour'), -- тестовый рейс
  (25, NOW() + INTERVAL '10 minute', NOW() + INTERVAL '1.6 hour'),
  (26, NOW() + INTERVAL '20 minute', NOW() + INTERVAL '1.7 hour'),
  (27, NOW() + INTERVAL '15 minute', NOW() + INTERVAL '1.75 hour'),
  (28, NOW() + INTERVAL '12 minute', NOW() + INTERVAL '1.65 hour'),
  (29, NOW() + INTERVAL '5 minute', NOW() + INTERVAL '1.55 hour'),

  -- рейсы из SVO
  (1, NOW() + INTERVAL '1.55 hour', NOW() + INTERVAL '3 hour'),
  (2, NOW() + INTERVAL '1.6 hour', NOW() + INTERVAL '3.55 hour'),
  (3, NOW() + INTERVAL '1.65 hour', NOW() + INTERVAL '3.5 hour'),
  (4, NOW() + INTERVAL '1.7 hour', NOW() + INTERVAL '3.45 hour'),
  (5, NOW() + INTERVAL '1.75 hour', NOW() + INTERVAL '3.35 hour'),
  (6, NOW() + INTERVAL '1.8 hour', NOW() + INTERVAL '3.3 hour'),
  (7, NOW() + INTERVAL '1.85 hour', NOW() + INTERVAL '3.4 hour');

-- распределяем по рейсам полосы 
INSERT INTO flight_airstrip (
  flight_id, airstrip_id, usage_type
) VALUES 
  (7, 3, 'takeoff'),
  (8, 4, 'takeoff'),
  (9, 4, 'takeoff'),
  (10, 5, 'takeoff'),
  (11, 5, 'takeoff'),
  (12, 6, 'takeoff'),
  (13, 6, 'takeoff');

CALL airstrip_assign(
  act_flight_id => 1, -- 1...6 
  dest_airport_id => 1,
  assigned_airstrip_id => NULL, 
  message => NULL
);

SELECT 
  fa.airstrip_id,
  a.airport_id,
  f.flight_id,
  fa.usage_type
FROM flight_airstrip fa
JOIN airstrip a ON fa.airstrip_id = a.airstrip_id
JOIN flight f ON f.flight_id = fa.flight_id;

-- TRUNCATE TABLE flight CASCADE;
-- ALTER SEQUENCE flight_flight_id_seq RESTART WITH 1;