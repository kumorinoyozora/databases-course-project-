-- задаём связи добавлением внешних ключей

ALTER TABLE "airliner"
ADD FOREIGN KEY ("airport_id") REFERENCES "airport" ("airport_id")
ON DELETE CASCADE; -- удаление аэропорта -> удаление привязанных самолётов

ALTER TABLE "airliner_position"
ADD FOREIGN KEY ("airliner_id") REFERENCES "airliner" ("airliner_id")
ON DELETE CASCADE; -- удаление самолёта -> нет смысла в истории статусов неизвестного самолёта

ALTER TABLE "flight" 
ADD FOREIGN KEY ("airliner_id") REFERENCES "airliner" ("airliner_id") 
ON DELETE CASCADE; -- удаление самолёта -> удаление информации о полёте

ALTER TABLE "employee" 
ADD FOREIGN KEY ("airport_id") REFERENCES "airport" ("airport_id") 
ON DELETE SET NULL; -- удаление аэропорта -> оставляем остальную инфу (в т.ч. из-за связей с flight)

ALTER TABLE "employee" 
ADD FOREIGN KEY ("title") REFERENCES "employees_position" ("title") 
ON DELETE NO ACTION; -- удаляем должность -> оставляем сотрудника (SET NULL)
										-- а как тогда понять что он был, к примеру, пилотом? -> не удаляем 
										-- или придумываем обработку

ALTER TABLE "flight_ticket" 
ADD FOREIGN KEY ("flight_id") REFERENCES "flight" ("flight_id") 
ON DELETE CASCADE; -- удаляем полёт -> удаляем информацию о билетах (логично)

ALTER TABLE "flight_ticket" 
ADD FOREIGN KEY ("passenger_id") REFERENCES "passenger" ("passenger_id")
ON DELETE SET NULL; -- очевидно (куплен/не куплен определяется наличием строки в принципе,
										-- если генерировать записи только при оформлении билета)

ALTER TABLE "airstrip" 
ADD FOREIGN KEY ("airport_id") REFERENCES "airport" ("airport_id") 
ON DELETE CASCADE; -- да, но каскадно лишаемся информации о полосах взлёта/посадки для flight

ALTER TABLE "hangar" 
ADD FOREIGN KEY ("airport_id") REFERENCES "airport" ("airport_id")
ON DELETE CASCADE; -- очевидно

ALTER TABLE "flight_airstrip" 
ADD FOREIGN KEY ("airstrip_id") REFERENCES "airstrip" ("airstrip_id") 
ON DELETE CASCADE; -- запись в таблице не имеет смысла для flight без идентификатора полосы 
									-- (если только мы не хотим знать, на какую полосу садился самолёт в закрытом аэропорту (
									-- а в случае взлёта из закрытого нам всё равно, так как мы не будем знать самолёт))

ALTER TABLE "flight_airstrip" 
ADD FOREIGN KEY ("flight_id") REFERENCES "flight" ("flight_id") 
ON DELETE CASCADE; -- очевидно

ALTER TABLE "flight_employee" 
ADD FOREIGN KEY ("employee_id") REFERENCES "employee" ("employee_id")
ON DELETE NO ACTION; -- там составной PK

ALTER TABLE "flight_employee" 
ADD FOREIGN KEY ("flight_id") REFERENCES "flight" ("flight_id") 
ON DELETE NO ACTION; -- логичнее было бы удалить, но там составной PK

-- проверки значений широты и долготы

ALTER TABLE "airport" 
ADD CONSTRAINT "valid_coordinates" 
CHECK (("latitude" BETWEEN -90 AND 90) AND ("longitude" BETWEEN -180 AND 180));

ALTER TABLE "airliner_position" 
ADD CONSTRAINT "valid_coordinates" 
CHECK (("latitude" BETWEEN -90 AND 90) AND ("longitude" BETWEEN -180 AND 180));

ALTER TABLE "airstrip" 
ADD CONSTRAINT "valid_coordinates" 
CHECK (("latitude" BETWEEN -90 AND 90) AND ("longitude" BETWEEN -180 AND 180));

ALTER TABLE "hangar" 
ADD CONSTRAINT "valid_coordinates" 
CHECK (("latitude" BETWEEN -90 AND 90) AND ("longitude" BETWEEN -180 AND 180));