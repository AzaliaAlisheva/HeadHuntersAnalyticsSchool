-- ============================================================
-- Домашнее задание к лекции «SQL»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Алишева Азалия Равилевна

SET search_path TO hh_school;


-- ============================================================
-- БЛОК А. Качество и подготовка данных
-- ============================================================               

-- ЗАДАНИЕ 1
-- 1. Eсть ли значения, заметно отличающиеся от основной массы наблюдений?
-- Категориальные признаки:
SELECT sender_role, COUNT(*) 
FROM messages
GROUP BY sender_role;
SELECT status, COUNT(*) 
FROM calls
GROUP BY status;
SELECT caller_role, COUNT(*) 
FROM calls
GROUP BY caller_role;

-- Остальные
SELECT sent_at,
LEAD(sent_at) OVER (ORDER BY sent_at) - sent_at AS time_to_next
FROM messages
ORDER BY sent_at
LIMIT 10;

SELECT sent_at,
sent_at - LAG(sent_at) OVER (ORDER BY sent_at) AS time_from_prev
FROM messages
ORDER BY sent_at DESC
LIMIT 10;

SELECT call_at,
LEAD(call_at) OVER (ORDER BY call_at) - call_at AS time_to_next
FROM calls
ORDER BY call_at
LIMIT 10;

SELECT call_at,
call_at - LAG(call_at) OVER (ORDER BY call_at) AS time_from_prev
FROM calls
ORDER BY call_at DESC
LIMIT 10;

SELECT call_duration
FROM calls
ORDER BY call_duration
LIMIT 10;

SELECT call_duration
FROM calls
ORDER BY call_duration DESC
NULLS LAST
LIMIT 10;

-- Вывод: 
-- Проблема: Всего 1 звонок имеет статус 'error' с call_id = 700163. 
-- Ошибка влияет на факт коммуникации.
-- 
-- Остальные признаки сильно не выделяются. Как звонки, так и сообщения 
-- собраны в период с января по начало сентября. sent_at, call_at 
-- и call_duration плавно изменяются на хвостах распределения.

-- 2. Eсть ли пропуски в данных, которые понадобятся дальше?
SELECT COUNT(*) as total,
COUNT(*) - COUNT(response_id) AS response_id_nulls,
COUNT(*) - COUNT(vacancy_id) AS vacancy_id_nulls,
COUNT(*) - COUNT(employer_id) AS employer_id_nulls,
COUNT(*) - COUNT(applicant_id) AS applicant_id_nulls,
COUNT(*) - COUNT(sent_at) AS sent_at_nulls,
COUNT(*) - COUNT(sender_role) AS sender_role_nulls,
COUNT(*) - COUNT(message_text) AS message_text_nulls,
COUNT(*) - COUNT(message_meta) AS message_meta_nulls
FROM messages;

SELECT MIN(LENGTH(message_text)) FROM messages;

SELECT COUNT(*) as total,
COUNT(*) - COUNT(response_id) AS response_id_nulls,
COUNT(*) - COUNT(employer_id) AS employer_id_nulls,
COUNT(*) - COUNT(applicant_id) AS applicant_id_nulls,
COUNT(*) - COUNT(vacancy_id) AS vacancy_id_nulls,
COUNT(*) - COUNT(caller_role) AS caller_role_nulls,
COUNT(*) - COUNT(call_duration) AS call_duration_nulls,
COUNT(*) - COUNT(status) AS status_nulls,
COUNT(*) - COUNT(call_at) AS call_at_nulls,
COUNT(*) - COUNT(call_tags) AS call_tags_nulls
FROM calls;

SELECT COUNT(*) AS total,
COUNT(call_duration) AS with_call_duration
FROM calls WHERE status = 'unsuccessful' OR status = 'error';

SELECT * FROM calls WHERE response_id IS NULL;

-- Вывод: 
-- В таблице messages пустых значений нет и длина каждого сообщения 
-- минимум 22 символа.
-- Единственные столбцы с пустыми значениями - call_duration и response_id
-- в таблице calls. call_duration пропущен ровно в 70 строках, где статус 
-- 'unsuccessful' или 'error'. Когда звонка не было, в столбце 
-- call_duration будет NULL.
-- 
-- Проблема: 8 звонков без response_id. 
-- сall_id: 
-- 700244
-- 700245
-- 700246
-- 700247
-- 700248
-- 700249
-- 700250
-- 700251
-- Проблема затрагивает сам факт коммуникации (см. п.4).

-- 3. Cогласуются ли значения внутри одной строки между собой?
SELECT call_id
FROM calls
WHERE CARDINALITY(call_tags) != 4;

SELECT DISTINCT(call_tags[1]) FROM calls;

SELECT DISTINCT(call_tags[2]) FROM calls;

SELECT DISTINCT(call_tags[3]) FROM calls;

SELECT DISTINCT(call_tags[4]) FROM calls;

-- All call statuses fit the call tags
SELECT call_id, response_id, status, call_tags[2]
FROM calls
WHERE 
(status = 'successful' AND call_tags[2] != 'connected')
OR
(status = 'error' AND call_tags[2] != 'technical_error')
OR 
(status = 'unsuccessful' AND call_tags[2] != 'no_answer');

-- All outbound calls are from employer and inbound from applicant
SELECT call_id, response_id, caller_role, call_tags[3]
FROM calls
WHERE 
(caller_role = 'employer' AND call_tags[3] != 'outbound')
OR
(caller_role = 'applicant' AND call_tags[3] != 'inbound');

--
-- Вывод:
-- У каждого звонка по 4 тега, идущих по порядку: 'voice', результат звонка,
-- входящий/исходящий, цель звонка. Результаты звонка соотносятся 
-- со статусами звонков. Все исходящие звонки от работодателя, 
-- а значит и все входящие от претендента. Значения внутри одной строки
-- в таблицах согласуются.

-- 4. Можно ли корректно связать событие с откликом? 
-- Согласуются ли между собой идентификаторы в связанных таблицах?
-- Может ли событие находиться в указанной точке времени относительно отклика?
SELECT message_id, m.response_id, m.vacancy_id, m.sent_at,
r.response_id, r.vacancy_id, r.created_at
FROM messages m
LEFT JOIN responses r
USING(response_id)
WHERE r.response_id IS NULL
OR m.vacancy_id != r.vacancy_id
OR m.sent_at <= r.created_at
OR m.applicant_id != r.resume_id
LIMIT 10;

SELECT call_id, c.response_id, c.vacancy_id, c.call_at,
r.response_id, r.vacancy_id, r.created_at
FROM calls c
LEFT JOIN responses r
USING(response_id)
WHERE (c.response_id IS NOT NULL AND r.response_id IS NULL)
OR c.vacancy_id != r.vacancy_id
OR c.call_at <= r.created_at
OR c.applicant_id != r.resume_id
LIMIT 10;

-- Check the employer_id in messages
SELECT m.message_id, 
m.employer_id AS employer_in_message, 
v.employer_id AS employer_in_vacancy
FROM messages m
JOIN vacancies v 
ON m.vacancy_id = v.vacancy_id
WHERE m.employer_id IS DISTINCT FROM v.employer_id;

-- Check the employer_id in calls
SELECT c.call_id, 
c.employer_id AS employer_in_call, 
v.employer_id AS employer_in_vacancy
FROM calls c
JOIN vacancies v 
ON c.vacancy_id = v.vacancy_id
WHERE c.employer_id IS DISTINCT FROM v.employer_id;

-- Imputing missing response_id
WITH with_missing_response AS (
	SELECT call_id, applicant_id, vacancy_id, call_at
	FROM calls 
	WHERE response_id IS NULL
)
SELECT r.*, m.call_id, m.call_at,
r.created_at < m.call_at AS call_after_response
FROM responses r
JOIN with_missing_response m
ON r.vacancy_id = m.vacancy_id
AND r.resume_id = m.applicant_id;

-- Вывод: 
-- Сообщений и звонков ссылающихся на несуществующие отклики нет.
-- vacancy_id и resume_id в таблице откликов соотносятся с vacancy_id
-- и applicant_id в таблице звонков и сообщений. Employer_id в таблице
-- звонков и сообщений соотносится с employer_id в таблице вакансий. 
-- Отклики созданы раньше, чем совершены звонки или сообщения по ним.
-- 
-- Если попытаться найти соответствующие звонкам отклики по 
-- вакансии и претенденту, действительно находится ровно один 
-- такой отклик. Однако время его создания позже, чем совершен
-- звонок/отправлено сообщение, поэтому тип пропуска 
-- Missing At Random: когда условие с порядком не выполняется.

-- 5. Исследование call_duration
WITH stats AS (
	SELECT AVG(call_duration) AS mean,
	PERCENTILE_CONT(0.5) WITHIN GROUP (
	ORDER BY call_duration
	) AS median,
	PERCENTILE_CONT(0.99) WITHIN GROUP (
	ORDER BY call_duration
	) AS p99
	FROM calls
	WHERE status = 'successful'
)
SELECT s.*,
	(SELECT COUNT(*) 
	FROM calls c
	WHERE status = 'successful'
	AND c.call_duration > s.p99) AS cnt_above_p99,
	(SELECT AVG(call_duration) 
	FROM calls c
	WHERE status = 'successful'
	AND c.call_duration <= s.p99) AS mean_without_outliers
FROM stats s;

-- Вывод: 
-- Считаем значения выше 99 персентиля, длительность звонков выше
-- 890.4, допустимыми значениями, так как как было замечено в п.1, 
-- значения на хвосте очень близки - Топ-5: 899, 892, 890, 885, 882.
-- Добавим, что максимальное значение (899) всего на 1% выше 99 персентиля
-- и среднее после отбрасывания 2 самых высоких значений почти не
-- меняется: учитывая выбросы среднее - 467.28, без них - 462.49.


-- ============================================================
-- БЛОК Б. История коммуникаций
-- ============================================================

-- ЗАДАНИЕ 2
WITH successful_events AS (
	SELECT call_id AS event_id,
	response_id, employer_id,
	call_at AS event_at,
	'call' AS event_type
	FROM calls
	WHERE status = 'successful'
	AND response_id IS NOT NULL
	UNION ALL
	SELECT message_id AS event_id,
	response_id, employer_id,
	sent_at AS event_at,
	'message' AS event_type
	FROM messages
	ORDER BY event_at
),
fast_tracked AS(
	SELECT * FROM 
	successful_events e
	WHERE EXISTS (
		SELECT 1
		FROM responses r
		WHERE e.response_id = r.response_id
		AND e.event_at <= r.created_at + INTERVAL '7 days'
	)
)
SELECT COUNT(*) AS total_events,
COUNT(DISTINCT response_id) AS responses,
COUNT(*) FILTER (WHERE event_type = 'call') AS calls,
COUNT(*) FILTER (WHERE event_type = 'message') AS messages
FROM fast_tracked;
-- Вывод:
-- Будем использовать только состоявшиеся звонки, у которых указан отклик.
-- Объединяем сообщения со звонками и фильтруем события, которые произошли
-- не позднее, чем через 7 дней после соответствующего отклика.
-- Всего:
-- 2095 событий
-- 385 различных откликов с коммуникацией в первые 7 дней
-- 119 звонков
-- 1976 сообщений

-- ЗАДАНИЕ 3
WITH successful_events AS (
	SELECT call_id AS event_id,
	response_id, employer_id,
	call_at AS event_at,
	'call' AS event_type
	FROM calls
	WHERE status = 'successful'
	AND response_id IS NOT NULL
	UNION ALL
	SELECT message_id AS event_id,
	response_id, employer_id,
	sent_at AS event_at,
	'message' AS event_type
	FROM messages
	ORDER BY event_at
),
fast_tracked AS(
	SELECT * FROM 
	successful_events e
	WHERE EXISTS (
		SELECT 1
		FROM responses r
		WHERE e.response_id = r.response_id
		AND e.event_at <= r.created_at + INTERVAL '7 days'
	)
),
event_level AS (
	SELECT 
	event_id, response_id, event_at,
	ROW_NUMBER() OVER partitioned_w AS rn,
	LAG(event_at) OVER partitioned_w AS previous_event_at,
	LEAD(event_type) OVER partitioned_w AS next_event_type,
	FIRST_VALUE(event_type) OVER partitioned_w AS first_event_type,
	LAST_VALUE(event_type) OVER partitioned_w AS last_event_type
	FROM fast_tracked
	WINDOW partitioned_w AS (PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
),
grouped_event_level AS (
	SELECT response_id,
	MIN(event_at) AS first_event_at,
	FLOOR(EXTRACT(EPOCH FROM MAX(event_at - previous_event_at)) / 3600)::integer AS max_diff_hours,
	MIN(first_event_type) AS first_event_type,
	MIN(next_event_type) FILTER (WHERE rn = 1) AS second_event_type,
	MIN(last_event_type) AS last_event_type
	FROM event_level
	GROUP BY response_id
),
responses_with_events_stats AS (
	SELECT response_id,
	COUNT(*) AS events,
	COUNT(*) FILTER (WHERE event_type = 'call') AS calls,
	COUNT(*) FILTER (WHERE event_type = 'message') AS messages
	FROM fast_tracked
	GROUP BY response_id
),
responses_with_vacancy_data AS (
	SELECT r.response_id,
	v.employer_id, 
	v.professional_role,
	r.created_at,
	r.status
	FROM responses r
	LEFT JOIN vacancies v
	USING(vacancy_id)
),
dashboard AS (
	SELECT t1.response_id,
	t1.employer_id,
	t1.professional_role,
	t1.status,
	COALESCE(t2.events, 0) AS events,
	COALESCE(t2.calls, 0) AS calls,
	COALESCE(t2.messages, 0) AS messages,
	t3.first_event_at,
	t3.first_event_type,
	t3.second_event_type,
	FLOOR(EXTRACT(EPOCH FROM t3.first_event_at - t1.created_at) / 3600)::integer AS reaction_time_hours,
	t3.max_diff_hours
	FROM responses_with_vacancy_data t1
	LEFT JOIN responses_with_events_stats t2
	USING(response_id)
	LEFT JOIN grouped_event_level t3
	USING(response_id)
)
SELECT COUNT(*) AS total,
COUNT(*) FILTER (WHERE events > 0) AS with_events,
COUNT(*) FILTER (WHERE events = 0) AS without_events,
COUNT(*) FILTER (WHERE first_event_type = 'message') AS starts_with_message,
COUNT(*) FILTER (WHERE first_event_type = 'call') AS starts_with_call
FROM dashboard;
-- Вывод:
-- Всего 628 откликов из них 385 - с коммуникацией в первые 7 дней и 243 - без нее.
-- У 319 откликов коммуникация начинается с сообщения, 66 - со звонка.
-- Чуть больше половины откликов конверсируются в коммуникации. 
-- Коммуникации в 5 раз чаще начинаются с сообщений.


-- ============================================================
-- БЛОК В. Сравнение работодателей
-- ============================================================

-- ЗАДАНИЕ 4
WITH successful_events AS (
	SELECT call_id AS event_id,
	response_id, employer_id,
	call_at AS event_at,
	'call' AS event_type
	FROM calls
	WHERE status = 'successful'
	AND response_id IS NOT NULL
	UNION ALL
	SELECT message_id AS event_id,
	response_id, employer_id,
	sent_at AS event_at,
	'message' AS event_type
	FROM messages
	ORDER BY event_at
),
fast_tracked AS(
	SELECT * FROM 
	successful_events e
	WHERE EXISTS (
		SELECT 1
		FROM responses r
		WHERE e.response_id = r.response_id
		AND e.event_at <= r.created_at + INTERVAL '7 days'
	)
),
event_level AS (
	SELECT 
	event_id, response_id, event_at,
	ROW_NUMBER() OVER partitioned_w AS rn,
	LAG(event_at) OVER partitioned_w AS previous_event_at,
	LEAD(event_type) OVER partitioned_w AS next_event_type,
	FIRST_VALUE(event_type) OVER partitioned_w AS first_event_type,
	LAST_VALUE(event_type) OVER partitioned_w AS last_event_type
	FROM fast_tracked
	WINDOW partitioned_w AS (PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
),
grouped_event_level AS (
	SELECT response_id,
	MIN(event_at) AS first_event_at,
	FLOOR(EXTRACT(EPOCH FROM MAX(event_at - previous_event_at)) / 3600)::integer AS max_diff_hours,
	MIN(first_event_type) AS first_event_type,
	MIN(next_event_type) FILTER (WHERE rn = 1) AS second_event_type,
	MIN(last_event_type) AS last_event_type
	FROM event_level
	GROUP BY response_id
),
responses_with_events_stats AS (
	SELECT response_id,
	COUNT(*) AS events,
	COUNT(*) FILTER (WHERE event_type = 'call') AS calls,
	COUNT(*) FILTER (WHERE event_type = 'message') AS messages
	FROM fast_tracked
	GROUP BY response_id
),
responses_with_vacancy_data AS (
	SELECT r.response_id,
	v.employer_id, 
	v.professional_role,
	r.created_at,
	r.status
	FROM responses r
	LEFT JOIN vacancies v
	USING(vacancy_id)
),
dashboard AS (
	SELECT t1.response_id,
	t1.employer_id,
	t1.professional_role,
	t1.status,
	COALESCE(t2.events, 0) AS events,
	COALESCE(t2.calls, 0) AS calls,
	COALESCE(t2.messages, 0) AS messages,
	t3.first_event_at,
	t3.first_event_type,
	t3.second_event_type,
	FLOOR(EXTRACT(EPOCH FROM t3.first_event_at - t1.created_at) / 3600)::integer AS reaction_time_hours,
	t3.max_diff_hours
	FROM responses_with_vacancy_data t1
	LEFT JOIN responses_with_events_stats t2
	USING(response_id)
	LEFT JOIN grouped_event_level t3
	USING(response_id)
),
grouped_dashboard AS (
	SELECT employer_id, professional_role,
	COUNT(*) AS total_responses,
	COUNT(*) FILTER (WHERE events > 0) AS with_communication_cnt,
	ROUND(100.0 * AVG(CASE WHEN events > 0 THEN 1 ELSE 0 END), 2) AS with_communication_ratio,
	PERCENTILE_CONT(0.5) WITHIN GROUP (
	ORDER BY reaction_time_hours
	) AS reaction_time_median_hours,
	PERCENTILE_CONT(0.9) WITHIN GROUP (
	ORDER BY reaction_time_hours
	)::numeric AS p90_reaction_time_hours,
	ROUND(100.0 * AVG(CASE WHEN status = 'invited' THEN 1 ELSE 0 END), 2) AS conversion_ratio
	FROM dashboard
	GROUP BY employer_id, professional_role
	HAVING COUNT(*) >= 8),
leaderboard AS (
	SELECT *,
	DENSE_RANK() OVER (PARTITION BY professional_role 
						ORDER BY with_communication_ratio DESC,
						reaction_time_median_hours) AS place
	FROM grouped_dashboard)
SELECT employer_id, professional_role, place FROM leaderboard
WHERE place = 1 OR place = 2;

-- Вывод:
-- 103	"Аналитик данных"		1
-- 109	"Аналитик данных"		2
-- 106	"Дата-инженер"			1
-- 101	"Дата-инженер"			2
-- 102	"Продуктовый аналитик"	1
-- 103	"Продуктовый аналитик"	2
-- 112	"Разработчик"			1
-- 104	"Разработчик"			2
-- 107	"Тестировщик"			1
-- 108	"Тестировщик"			2
--
-- Работодатель с id 103 входит в топ-2 активно обрабатывающих отклики сразу
-- по 2-м направлениям "Аналитик данных" и "Продуктовый аналитик". Другие 
-- работодатели лидируют не более, чем в одном направлении.

-- ЗАДАНИЕ 5
WITH fast_tracked_messages AS (
	SELECT * 
	FROM messages m
	WHERE EXISTS (
		SELECT 1
		FROM responses r
		WHERE m.response_id = r.response_id
		AND m.sent_at <= r.created_at + INTERVAL '7 days'
	)
),
messages_with_previous_info AS (
	SELECT *,
	LAG(sent_at) OVER w AS prev_sent_at,
	LAG(sender_role) OVER w prev_sender_role
	FROM fast_tracked_messages
	WINDOW w AS (PARTITION BY response_id ORDER BY sent_at)
),
employer_reactions AS (
	SELECT message_id,
	response_id,
	vacancy_id,
	employer_id,
	applicant_id,
	sent_at - prev_sent_at AS reaction_time
	FROM messages_with_previous_info
	WHERE sender_role = 'employer'
	AND prev_sender_role = 'applicant'
)
SELECT employer_id,
COUNT(*) AS reactions_cnt,
AVG(reaction_time) AS mean_reaction_time,
PERCENTILE_CONT(0.5) WITHIN GROUP (
ORDER BY reaction_time
) AS median_reaction_time,
PERCENTILE_CONT(0.9) WITHIN GROUP (
ORDER BY reaction_time
) AS p90_reaction_time
FROM employer_reactions
GROUP BY employer_id
ORDER BY median_reaction_time;

-- Вывод:
-- У работодателя с employer_id = 107 минимальное медианное время ответа - 
-- 3 часа 56 минут. Однако среднее и 90-ый персентиль его ответов одни из самых
-- долгих. Из 749 ответов работодателей 28 принадлежат этому работадателю.
-- Работодатель с id 103 получил больше всего откликов - 171.

-- ============================================================
-- БЛОК Г. Сложные типы данных
-- ============================================================

-- ЗАДАНИЕ 6.1
-- All call statuses fit the call tags in fast tracked responses
WITH fast_tracked_calls AS (
	SELECT * 
	FROM calls c
	WHERE EXISTS (
		SELECT 1
		FROM responses r
		WHERE c.response_id = r.response_id
		AND c.call_at <= r.created_at + INTERVAL '7 days'
	)
)
SELECT call_id, response_id, status, call_tags[2]
FROM fast_tracked_calls
WHERE 
(status = 'successful' AND call_tags[2] != 'connected')
OR
(status = 'error' AND call_tags[2] != 'technical_error')
OR 
(status = 'unsuccessful' AND call_tags[2] != 'no_answer');

-- Group only valid
WITH fast_tracked_calls AS (
	SELECT * 
	FROM calls c
	WHERE EXISTS (
		SELECT 1
		FROM responses r
		WHERE c.response_id = r.response_id
		AND c.call_at <= r.created_at + INTERVAL '7 days'
	)
),
invalid_calls AS (
	SELECT call_id, response_id, status, call_tags[2]
	FROM fast_tracked_calls
	WHERE 
	(status = 'successful' AND call_tags[2] != 'connected')
	OR
	(status = 'error' AND call_tags[2] != 'technical_error')
	OR 
	(status = 'unsuccessful' AND call_tags[2] != 'no_answer')
)
SELECT call_tags[4], 
COUNT(*) AS cnt
FROM fast_tracked_calls
WHERE call_id NOT IN (SELECT call_id FROM invalid_calls)
GROUP BY call_tags[4];

-- Avg cardinality for valid calls
WITH fast_tracked_calls AS (
	SELECT * 
	FROM calls c
	WHERE EXISTS (
		SELECT 1
		FROM responses r
		WHERE c.response_id = r.response_id
		AND c.call_at <= r.created_at + INTERVAL '7 days'
	)
),
invalid_calls AS (
	SELECT call_id, response_id, status, call_tags[2]
	FROM fast_tracked_calls
	WHERE 
	(status = 'successful' AND call_tags[2] != 'connected')
	OR
	(status = 'error' AND call_tags[2] != 'technical_error')
	OR 
	(status = 'unsuccessful' AND call_tags[2] != 'no_answer')
)
SELECT ROUND(AVG(CARDINALITY(call_tags)), 1) AS mean_tag_cnt
FROM fast_tracked_calls
WHERE call_id NOT IN (SELECT call_id FROM invalid_calls);

WITH fast_tracked_calls AS (
	SELECT * 
	FROM calls c
	WHERE EXISTS (
		SELECT 1
		FROM responses r
		WHERE c.response_id = r.response_id
		AND c.call_at <= r.created_at + INTERVAL '7 days'
	)
),
invalid_calls AS (
	SELECT call_id, response_id, status, call_tags[2]
	FROM fast_tracked_calls
	WHERE 
	(status = 'successful' AND call_tags[2] != 'connected')
	OR
	(status = 'error' AND call_tags[2] != 'technical_error')
	OR 
	(status = 'unsuccessful' AND call_tags[2] != 'no_answer')
)
SELECT COUNT(*) AS total,
COUNT(*) FILTER (WHERE call_tags[4] IN ('screening', 'interview', 
										'follow_up', 'details')) AS with_business_tag
FROM fast_tracked_calls
WHERE call_id NOT IN (SELECT call_id FROM invalid_calls);

-- Вывод:
-- Результаты звонка соотносятся со статусами звонков (в Задании 1 проверяли для всех),
-- тут проверили для быстро обработанных. В задании 1 поняли, что у каждого звонка 
-- по 4 тега, не удивительно, что среднее среди валидных - 4. 168 валидных звонков и 
-- у всех есть бизнесовый тег.
-- Количество звонков с бизнес-тегами:
-- "follow_up"	49
-- "screening"	36
-- "interview"	50
-- "details"	33


-- ЗАДАНИЕ 6.2
WITH fast_tracked_messages AS (
	SELECT * 
	FROM messages m
	WHERE EXISTS (
		SELECT 1
		FROM responses r
		WHERE m.response_id = r.response_id
		AND m.sent_at <= r.created_at + INTERVAL '7 days'
	)
),
unpacked AS (
	SELECT *, 
	message_meta->>'channel' AS channel,
	(message_meta->'is_read')::boolean AS is_read,
	jsonb_array_length(message_meta->'attachments') AS attachments_num
	FROM fast_tracked_messages
)
SELECT channel,
COUNT(*) AS total_cnt,
COUNT(is_read) AS with_read_feature_cnt,
COUNT(*) FILTER (WHERE NOT is_read) AS unread_cnt,
ROUND(1.0 * COUNT(*) FILTER (WHERE NOT is_read) / COUNT(is_read), 3) AS unread_ratio,
COUNT(*) FILTER (WHERE attachments_num > 0) AS with_attachment_cnt,
ROUND(1.0 * COUNT(*) FILTER (WHERE attachments_num > 0) / COUNT(*), 3) AS with_attachment_ratio
FROM unpacked
GROUP BY channel;
-- Вывод:
-- В канале "web" 1288 сообщений, из них все 1288 с признаком прочтения.
-- 110 сообщений в этом канале непрочитано, что составляет 8.5% от всех 
-- сообщений в канале "web". С вложениями всего 50 сообщений - 3.9% от 
-- всех сообщений в канале "web".
--
-- В канале "mobile_app" 688 сообщений, из них все 688 с признаком прочтения.
-- 62 сообщений в этом канале непрочитано, что составляет 9% от всех 
-- сообщений в канале "mobile_app". С вложениями всего 30 сообщений - 4.4% от 
-- всех сообщений в канале "mobile_app".
-- Других каналов нет.

-- ============================================================
-- БЛОК Д. Самостоятельное исследование
-- ============================================================
-- До начала исследования хотелось бы прояснить его цель: как-то отделить
-- коммуникации, заканчивающихся приглашением, от остальных коммуникаций.
-- Это значит, что принимать статус звонка во внимание при рассчете средней 
-- или доли не стоит. Например, то, что среди откликов с приглашениями больше
-- доля тех, в коммуникации которых присутствовал звонок (это кстати правда), 
-- чем в откликах с другими статусами, не значит, что факт наличия звонка 
-- в коммуникации делает приглашение по отклику более вероятным. Среди 
-- коммуникаций со звонком, огромнейшая доля откликов с реджектами.
-- Аналогично со средним: среди откликов с приглашением среднее максимальное 
-- время между коммуникациями минимально, но среди реджектов большое количество 
-- с похожей максимальной разницей. 
-- Так как доля откликов без приглашения велика, нам стоит быть предельно аккуратными
-- и понимать о чем говорит каждая характеристика: среди откликов с плохими звонками
-- меньше всего откликов с приглашениями, значит ли это что наличие плохого звонка - 
-- признак коммуникации без приглашения или это последствия маленькой численности приглашений?

-- ЗАДАНИЕ 7
-- Формирование гипотезы 1:
-- Если и работодатель, и подающийся заинтересованы в общении, приглашение более вероятно.
-- Давайте измерим заинтересованность в виде времени реакции на отклик до первой коммуникации
-- и максимальным промежутком между коммуникацией, которые мы считали в предыдущих заданиях.
-- Гипотеза: Среди откликов, где время реакции на отклик меньше X-персентиля или 
-- максимальная разница между коммуникациями меньше Y-персентиля, доля с приглашениями больше,
-- чем базовая доля приглашенных, а по остальным статусам, доля в персентилях меньше, чем базовая доля.
-- Будем смотреть по всем успешным коммуникациям, не только те, которые произошли в первые 7 дней.
-- Так же посмотрим различные персентили - 0.05, 0.1, 0.5.

-- Запрос:
WITH successful_events AS (
	SELECT call_id AS event_id,
	response_id, employer_id,
	call_at AS event_at,
	'call' AS event_type
	FROM calls
	WHERE status = 'successful'
	AND response_id IS NOT NULL
	UNION ALL
	SELECT message_id AS event_id,
	response_id, employer_id,
	sent_at AS event_at,
	'message' AS event_type
	FROM messages
	ORDER BY event_at
),
event_level AS (
	SELECT event_id, response_id, event_at,
	LAG(event_at) OVER partitioned_w AS previous_event_at
	FROM successful_events
	WINDOW partitioned_w AS (PARTITION BY response_id
    ORDER BY event_at, event_type, event_id)
),
grouped_event_level AS (
	SELECT response_id,
	MIN(event_at) AS first_event_at,
	MAX(event_at - previous_event_at) AS max_diff
	FROM event_level
	GROUP BY response_id
),
dashboard AS (
	SELECT t1.response_id,
	t1.status,
	t3.first_event_at - t1.created_at AS reaction_time,
	t3.max_diff
	FROM responses t1
	JOIN grouped_event_level t3
	USING(response_id)
),
thresholds AS (
	SELECT
	PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY reaction_time) AS react_p5,
	PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY reaction_time) AS react_p10,
	PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY reaction_time) AS react_p50,
	PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY max_diff) AS gap_p5,
	PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY max_diff) AS gap_p10,
	PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY max_diff) AS gap_p50
	FROM dashboard
),
metric_cnts AS (
	SELECT 
	COUNT(*) FILTER (WHERE reaction_time <= (SELECT react_p5 FROM thresholds)) AS react_p5_cnt,
	COUNT(*) FILTER (WHERE reaction_time <= (SELECT react_p10 FROM thresholds)) AS react_p10_cnt,
	COUNT(*) FILTER (WHERE reaction_time <= (SELECT react_p50 FROM thresholds)) AS react_p50_cnt,
	COUNT(*) FILTER (WHERE max_diff <= (SELECT gap_p5 FROM thresholds)) AS gap_p5_cnt,
	COUNT(*) FILTER (WHERE max_diff <= (SELECT gap_p10 FROM thresholds)) AS gap_p10_cnt,
	COUNT(*) FILTER (WHERE max_diff <= (SELECT gap_p50 FROM thresholds)) AS gap_p50_cnt
	FROM dashboard
)
SELECT status,
COUNT(*) AS total,
ROUND(100.0 * COUNT(*)/(SELECT COUNT(*) FROM dashboard), 2) AS total_ratio,
ROUND(100.0 * COUNT(max_diff)/(SELECT COUNT(max_diff) FROM dashboard), 2) AS total_ratio_with_max_diff,
ROUND(100.0 * (COUNT(*) FILTER (WHERE reaction_time <= (SELECT react_p5 FROM thresholds))) 
						/ (SELECT react_p5_cnt FROM metric_cnts), 2) AS p5_fast_reacted_ratio,
ROUND(100.0 * (COUNT(*) FILTER (WHERE reaction_time <= (SELECT react_p10 FROM thresholds))) 
						/ (SELECT react_p10_cnt FROM metric_cnts), 2) AS p10_fast_reacted_ratio,
ROUND(100.0 * (COUNT(*) FILTER (WHERE reaction_time <= (SELECT react_p50 FROM thresholds))) 
						/ (SELECT react_p50_cnt FROM metric_cnts), 2) AS p50_fast_reacted_ratio,
ROUND(100.0 * (COUNT(*) FILTER (WHERE max_diff <= (SELECT gap_p5 FROM thresholds))) 
						/ (SELECT gap_p5_cnt FROM metric_cnts), 2) AS p5_fast_response_ratio,
ROUND(100.0 * (COUNT(*) FILTER (WHERE max_diff <= (SELECT gap_p10 FROM thresholds))) 
						/ (SELECT gap_p10_cnt FROM metric_cnts), 2) AS p10_fast_response_ratio,
ROUND(100.0 * (COUNT(*) FILTER (WHERE max_diff <= (SELECT gap_p50 FROM thresholds))) 
						/ (SELECT gap_p50_cnt FROM metric_cnts), 2) AS p50_fast_response_ratio
FROM dashboard
GROUP BY status;

-- Вывод:
-- Для каждого статуса доля отклоненных откликов от всего персентиля гораздо больше, 
-- чем с приглашениями по всем характеристикам. 
--
-- status		total	total_ratio		total_ratio_with_max_diff	p5_fast_reacted_ratio	p10_fast_reacted_ratio	p50_fast_reacted_ratio
-- viewed		147		29.64			29.77						26.92					28.00					29.84	
-- invited		73		14.72			14.26						19.23					20.00					12.50	
-- rejected		200		40.32			40.67						38.46					38.00					41.13	
-- new			76		15.32			15.30						15.38					14.00					16.53	

-- status		p5_fast_response_ratio	p10_fast_response_ratio	p50_fast_response_ratio
-- viewed		50.00					38.78					31.80
-- invited		12.50					12.24					15.06
-- rejected		29.17					36.73					38.49
-- new			8.33					12.24					14.64

-- Заметно, что в p10_fast_reacted_ratio и p50_fast_response_ratio доля приглашенных больше, 
-- чем доля приглашенных в принципе, а доля отклоненных меньше, чем доля отклоненных в принципе.
-- Однако, количество откликов слишком невелико, чтобы доверять метрикам, как отражению действительности.
-- Таким образом, данных недостаточно, чтобы подтвердить или опровергнуть гипотезу.
--
-- metric_cnts:
-- react_p5_cnt	react_p10_cnt	react_p50_cnt	gap_p5_cnt	gap_p10_cnt		gap_p50_cnt
-- 26				50				248				24			49				239
--
-- Всего отклоненных откликов 200, что почти в 3 раза превышает 
-- отклики с приглашениями (73). Откликов со статусом 'viewed' - 147, со статусом
-- 'new' - 76. Считали только отклики с успешной коммуникацией: всего 496.

-- Формирование гипотезы 2:
-- Интервью - главный параметр отбора кандидата, куда попадают уже отобранные после
-- скриннинга кандидаты. Возможно среди тех, кто проходил интервью или тех, кто уточнял
-- детали большая доля приглашенных.
-- Гипотеза: Среди звонков с каким-то конкретным бизнес-тегом доля откликов с приглашением 
-- будет значимо больше, чем базовая доля.

-- Запрос:
WITH with_tags_cnt AS (
	SELECT response_id,
	COALESCE(COUNT(*) FILTER (WHERE call_tags[4] = 'screening'), 0) AS screening,
	COALESCE(COUNT(*) FILTER (WHERE call_tags[4] = 'follow_up'), 0) AS follow_up,
	COALESCE(COUNT(*) FILTER (WHERE call_tags[4] = 'interview'), 0) AS interview,
	COALESCE(COUNT(*) FILTER (WHERE call_tags[4] = 'details'), 0) AS details
	FROM calls
	WHERE status = 'successful'
	AND response_id IS NOT NULL
	GROUP BY response_id
),
metric_cnt AS (
	SELECT
	COUNT(*) FILTER (WHERE screening > 0) AS screening_total,
	COUNT(*) FILTER (WHERE follow_up > 0) AS follow_up_total,
	COUNT(*) FILTER (WHERE interview > 0) AS interview_total,
	COUNT(*) FILTER (WHERE details > 0) AS details_total
	FROM with_tags_cnt
)
SELECT status,
COUNT(*) AS total,
ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM with_tags_cnt), 2) AS total_ratio,
ROUND(100.0 * (COUNT(*) FILTER (WHERE screening > 0)) / (SELECT screening_total FROM metric_cnt), 2) AS screening,
ROUND(100.0 * (COUNT(*) FILTER (WHERE follow_up > 0)) / (SELECT follow_up_total FROM metric_cnt), 2) AS follow_up,
ROUND(100.0 * (COUNT(*) FILTER (WHERE interview > 0)) / (SELECT interview_total FROM metric_cnt), 2) AS interview,
ROUND(100.0 * (COUNT(*) FILTER (WHERE details > 0)) / (SELECT details_total FROM metric_cnt), 2) AS details
FROM with_tags_cnt
JOIN responses
USING(response_id)
GROUP BY status;

-- Вывод:
-- По каждому статуса по каждому бизнес-тегу доля инвайтов не дает значимого прироста.
-- Так же везде, где доля приглашений увеличилась, доля отклонений тоже увеличилась.
--
-- status		total	total_ratio		screening	follow_up	interview	details
-- viewed		47		28.31			36.59		20.00		29.17		28.57
-- invited		27		16.27			14.63		18.00		20.83		8.57
-- rejected		66		39.76			39.02		46.00		41.67		34.29
-- new			26		15.66			9.76		16.00		8.33		28.57
--
-- Все еще недостаточно данных, для анализа гипотезы, слишком мало откликов со звонками.
-- Всего анализировали 166 откликов с успешными звонками: 
-- из них 47 'viewed', 27 'invited', 66 'rejected', 26 'new'.

-- ЗАДАНИЕ 8
-- У 385 из 628 откликов начинается коммуникация в первые 7 дней после создания. В 5 раз 
-- чаще работодатели начинают коммуникацию с сообщения. Работодатель с employer_id = 107 
-- самый добросовестный у него минимальное медианное время ответа и он обрабатывает большую
-- долю поступающих заявок по направлению "Тестировщик". А работодатель с employer_id = 103
-- самый популярный. Он тоже хорошо обрабатывает заявки - в топе по направлениям "Аналитик данных"
-- и "Продуктовый аналитик".
-- Срезы, в которых доля инвайтов увеличилась, а доля реджектов уменьшилась - p10_fast_reacted_ratio 
-- и p50_fast_response_ratio. Рекомендуется внимательнее использовать именно эти метрики для последующих 
-- задач.
-- Хотелось бы получить больше данных, чтобы поисследовать длительность интервью среди инвайтов и 
-- остальных (не успешных) откликов. В наших данных всего 10 инвайтов с интервью. Метрики, посчитанные 
-- на таком маленьком множестве могут не отражать действительность.