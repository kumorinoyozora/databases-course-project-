-- Запрос 1. Вывести топ 5 диспетчеров по загруженности за последний месяц

SELECT employee_id, e.lastname, e.name, e.patronymic, count(flight_id) as flight_num
FROM flight_employee fe
JOIN employee e ON fe.employee_id = e.employee_id
WHERE e.title = 'flight_controller'
	AND fe.flight_id in (
		SELECT flight_id
		FROM flight
		WHERE scheduled_departure_time between (SELECT max(time) FROM airliner_position) - INTERVAL '1 month'
			and (SELECT max(time) FROM airliner_position)
		)
GROUP BY employee_id
ORDER BY flight_num DESC, employee_id
LIMIT 5

-- Запрос 2. Требуется выбрать самолёты, находящиеся в состоянии «В полете», 
-- и определить, какие из них приближаются к зоне назначения.
-- Для каждого самолёта из таблицы Airplanes с текущим статусом «В полете» вычисляется расстояние 
-- между его текущими координатами и координатами аэропорта назначения. 
-- Выбираются только те самолёты, для которых рассчитанное расстояние оказывается меньше 20 км. 
-- Итоговый результат должен содержать идентификатор самолёта, его координаты и рассчитанное 
-- расстояние до аэропорта назначения.

-- Запрос 3. Необходимо вывести взлетно-посадочные полосы с наименьшей загрузкой 
-- по всем аэропортам за последнюю неделю.

WITH subq AS (
	SELECT airport_id, airstrip_id, count(flight_id) as flight_num
	FROM flight_airstrip
	WHERE flight_id in (
			SELECT flight_id
			FROM flight
			WHERE scheduled_departure_time between (SELECT max(time) FROM airliner_position) - INTERVAL '1 week'
				and (SELECT max(time) FROM airliner_position)
			)
	GROUP BY airstrip_id, airport_id
)
SELECT airport_id, airstrip_id, flight_num 
FROM subq
WHERE flight_num = (
	SELECT min(flight_num)
	FROM subq
)
ORDER BY airport_id, airstrip_id

-- Запрос 4. Требуется сформировать отчёт о самолётах, находящихся в состоянии 
-- «ждет проверки механиком». (Добавить условие по временным рамкам, чтобы выявить самолёты, 
-- находящиеся в этом состоянии длительное время.) Итоговый отчёт должен включать идентификатор 
-- самолёта, время фиксации данного статуса, а при наличии – идентификатор связанного рейса.

SELECT airliner_id, status_fixation_time, flight_id
FROM (
SELECT 
	ap.airliner_id as airliner_id,
	f.flight_id as flight_id, 
	min(time) as status_fixation_time,
	max(time) - min(time) as status_duration
FROM airliner_position ap
LEFT JOIN flight f ON ap.airliner_id = f.airliner_id
WHERE status is 'waiting_to_be_checked_by_a_mechanic'
GROUP BY ap.airliner_id
)
WHERE status_fixation_time > INTERVAL '12 hour'
ORDER BY status_fixation_time DESC, airliner_id

-- Запрос 5. Необходимо сформировать отчёт по топ 10 по продажам билетов для каждого рейса 
-- за последний месяц. Итоговый результат должен содержать идентификатор рейса, 
-- общее число проданных билетов, место вылета и место назначения. 

WITH sales AS (
	SELECT flight_id, count(passenger_id) as sales_num
	FROM flight f
	JOIN flight_ticket ft USING (flight_id)
	GROUP BY flight_id
	ORDER BY sales_num DESC
	LIMIT 10
),
airstrip_airport AS (
	SELECT airstrip.airstrip_id, airport.name, airport.country, flight_airstrip.flight_id
	FROM airstrip
	JOIN airport USING (airport_id)
	JOIN flight_airstrip USING (airstrip_id)
)
SELECT s.flight_id, sales_num
FROM sales s

-- Для 5го запроса вывести план выполнения запроса.