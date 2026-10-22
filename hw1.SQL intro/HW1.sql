-- ============================================================
-- Домашнее задание к лекции «SQL. Введение»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Алишева Азалия Равилевна
-- ============================================================
-- Формат: задания по порядку, каждое начинается с комментария
-- с номером; под каждым запросом — вывод (2–3 предложения).
-- Запрос без вывода не засчитывается.
-- ============================================================

SET search_path TO hh_school;


-- ============================================================
-- БЛОК А. Разминка: термины и структура (текстом)
-- ============================================================

-- ЗАДАНИЕ А1
-- 1. Категория и конкретный тип колонок:
--    vacancies.salary_from        — категория: числовые        тип: INTEGER
--    vacancies.vacancy_name       — категория: строковые       тип: TEXT
--    vacancies.published_at       — категория: дата и время    тип: TIMESTAMP
--    employers.is_accredited_it   — категория: логические      тип: BOOLEAN
--    responses.created_at         — категория: дата и время    тип: TIMESTAMP
--
-- 2. Первичные ключи таблиц:
--    areas: area_id
--    employers: employer_id
--    vacancies: vacancy_id
--    vacancy_details: vacancy_id (чем особенный: является внешним ключем)
--    responses: response_id
--
-- 3. Почему vacancy_name не может быть первичным ключом:
--    Значения этого поля повторяются. Например, "Стажёр: аналитик данных" встречается 6 раз.
--    Запрос для подтверждения числом:
--
-- запрос: 
SELECT vacancy_name, COUNT(*) 
FROM vacancies 
GROUP BY vacancy_name 
ORDER BY 2 DESC 
LIMIT 5;
--
-- Вывод:
-- Самое частое наименование вакансии - "Стажёр: аналитик данных".
-- Скорее всего вакансий связанных с аналитикой данных больше всего:
-- 3 из топ 5 самых встречающихся вакансий связаны именно с ней.
-- Стажерская позиция на аналитика не сильно обгоняет сеньорскую 
-- на аналитика, на разработчика и стажерскую на разработчика.
-- Если выбирать область для своего образования, рекомендуется 
-- обратить внимание на аналитику данных и разработку.
--
-- 4. Что произойдёт при записи строки «по договорённости» в salary_from:
-- ОШИБКА:  неверный синтаксис для типа integer: "по договоренности"
-- То, что типы данных строго определены для каждого столбца это хорошо,
-- потому что шанс вставить в таблицу ошибочные данные или значения полей 
-- не в правильном порядке становится меньше. Причем зарплату лучше
-- хранить в численном формате, ведь так можно к столбцу применять 
-- агрегирующие функции.
-- Запрос:
-- INSERT INTO vacancies (employer_id, area_id, vacancy_name, professional_role, experience, employment, salary_from, salary_to, currency, published_at, closed_at) VALUES (101, 1, 'Стажёр: аналитик данных', 'Аналитик данных', 'Нет опыта', 'Стажировка', 'по договоренности', 45000, 'RUR', TIMESTAMP '2026-05-14 06:00:00', NULL);

-- ============================================================
-- БЛОК Б. Первые запросы: SELECT, WHERE, ORDER BY
-- ============================================================

-- ЗАДАНИЕ Б1
-- Запрос: experience
SELECT DISTINCT experience FROM vacancies LIMIT 10;

-- Запрос: employment
SELECT DISTINCT employment FROM vacancies LIMIT 10;


-- Запрос: professional_role
SELECT DISTINCT professional_role FROM vacancies LIMIT 10;

-- Вывод:
-- В рассмотренных полях нулевых значений нет, как и 
-- повторяющихся значений. В колонке experience 3 различных 
-- значения, в колонке employment - 3, в professional_role - 5.
-- Однако строк с опытом более 6 лет в таблице нет: либо нет
-- вакансий требующих более 6 лет опыта работы, либо данные 
-- были утеряны.


-- ЗАДАНИЕ Б2
-- Запрос 1: стажировки в Москве без опыта, вакансия открыта
SELECT vacancy_id, vacancy_name, salary_from, published_at
FROM vacancies
JOIN areas
USING(area_id)
WHERE experience = 'Нет опыта' 
AND employment = 'Стажировка'
AND closed_at IS NULL
AND area_name = 'Москва'
ORDER BY published_at DESC;

-- Запрос 2: топ-10 вакансий по salary_from
SELECT vacancy_name, professional_role, salary_from
FROM vacancies
ORDER BY salary_from DESC
NULLS LAST
LIMIT 10;

-- Вывод:
-- 8 открытых вакансий в Москве, которые не требуют опыта работы.
-- Если убрать условие про Москву, найдутся 10 вакансий.
-- Можно рассчитывать на зп от 30000.
--
-- Senior разработчик и Senior дата-инженер - позиции с самой 
-- высокой гарантированной зарплатой, 195000 и 190000 соответственно.
-- В Топ-10 в основном Senior позиции и разработчики.


-- ЗАДАНИЕ Б3
-- Ловушка 1. NULL — выполнить и объяснить результат
SELECT count(*) FROM vacancies WHERE closed_at = NULL;
SELECT count(*) FROM vacancies WHERE closed_at IS NULL;

-- Ловушка 2. AND / OR — выполнить и объяснить результат
SELECT count(*) FROM vacancies
WHERE area_id = 1 OR area_id = 2 AND experience = 'Нет опыта';

SELECT count(*) FROM vacancies
WHERE (area_id = 1 OR area_id = 2) AND experience = 'Нет опыта';

-- Вывод:
-- Операция сравнения NULL с NULL всегда возвращает NULL (ошибки нет), 
-- чтобы определить является ли значение NULL используется IS, 
-- поэтому запрос "SELECT count(*) FROM vacancies WHERE closed_at = NULL;" 
-- возвращает 0, а "SELECT count(*) FROM vacancies WHERE closed_at IS NULL;" 
-- возвращает 33. Это опаснее ошибки, так как если не помнить про сравнение
-- с NULL, выполнив первый запрос, можно подумать, что открытых вакансий нет.
--
-- В логике оператор AND приоритетнее OR, поэтому в первый запрос 
-- попадают все строки второго и дополительно вакансии с area_id = 1 
-- и требующих опыта. Таких(требующих опыта с area_id = 1) 11 вакансий.
-- Второй запрос выводит только вакансии не требующих опыта, где 
-- area_id 1 или 2. Их всего 20.
-- "Вакансии из Москвы или Санкт-Петербурга, но обязательно без опыта"
-- выдаются во втором запросе.


-- ============================================================
-- БЛОК В. Агрегации и метрики
-- ============================================================

-- ЗАДАНИЕ В1
-- Запрос 1: счётчики (строки, зарплата указана, направления, работодатели)
SELECT COUNT(*) AS total, 
COUNT(salary_from) AS with_salary, 
COUNT(DISTINCT professional_role) AS professions_num, 
COUNT(DISTINCT employer_id) AS employers_num
FROM vacancies;

-- Запрос 2: доля активных вакансий (без JOIN)
SELECT SUM(CASE WHEN closed_at IS NULL THEN 1 ELSE 0 END) AS open,
SUM(CASE WHEN closed_at IS NULL THEN 0 ELSE 1 END) AS closed,
ROUND(100.0 * AVG(CASE WHEN closed_at IS NULL THEN 1 ELSE 0 END), 1) AS ratio
FROM vacancies;

-- Вывод:
-- Всего в таблице - 52 вакансии. COUNT(*) подсчитал количество строк.
-- COUNT(salary_from) считает вакансии, где нижняя граница зарплаты не 
-- NULL, их 44. COUNT(DISTINCT professional_role) и COUNT(DISTINCT employer_id)
-- считает различные направления и работодателей, игнорируя пустые значения.
-- Всего направлений 5, а работодателей 12.
--
-- 33 вакансии открыты, что составляет 63.5% от общего числа вакансий.


-- ЗАДАНИЕ В2
-- Запрос 1: направления — вакансии, работодатели, средняя зарплата
SELECT professional_role,
COUNT(*) AS total,
COUNT(DISTINCT employer_id) AS employers_num,
ROUND(AVG(salary_from)) AS avg_salary_from
FROM vacancies
GROUP BY professional_role
ORDER BY total DESC;

-- Запрос 2: то же, только направления с ≥ 5 открытыми вакансиями (WHERE + HAVING)
SELECT professional_role,
COUNT(*) AS total,
COUNT(DISTINCT employer_id) AS employers_num,
ROUND(AVG(salary_from)) AS avg_salary_from
FROM vacancies
WHERE closed_at IS NULL
GROUP BY professional_role
HAVING COUNT(*) >= 5
ORDER BY total DESC;

-- Вывод:
-- Направления "аналитик данных" и "разработчик" составляют 
-- (16 + 15) / 52 ~ 60% рынка нашей бд. Можно сделать вывод,
-- что возможность устроиться на эти два направления выше
-- всего. Но мы не учитывали, что мы считаем закрытые вакансии
-- тоже. 
-- 
-- ОШИБКА:  агрегатные функции нельзя применять в конструкции WHERE.
-- Агрегация происходит после группировки, а фильтрация до.
--
-- Первый запрос смотрит среднюю зарплату по всем вакансиям, а второй
-- только по открытым. Второе значение для моих одногрупников 
-- репрезентативнее. 


-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)
SELECT vacancy_name, employer_name, area_name, salary_from
FROM vacancies v
LEFT JOIN areas a
ON v.area_id = a.area_id 
LEFT JOIN employers e
ON v.employer_id = e.employer_id
ORDER BY salary_from DESC
NULLS LAST
LIMIT 5;

-- Вывод:
-- Можно убрать псевдонимы, но тогда в условии для JOIN нужно будет прописать 
-- полное название таблицы. Так же можно использовать ключевое слово USING:
-- SELECT vacancy_name, employer_name, area_name, salary_from
-- FROM vacancies v
-- LEFT JOIN areas a
-- USING(area_id)
-- LEFT JOIN employers e
-- USING(employer_id)
-- ORDER BY salary_from DESC
-- NULLS LAST
-- LIMIT 5;
-- Использовать колонку area_id без псевдонима не получится, так как у нас
-- 2 колонки с таким названием.


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT employer_name, 
COUNT(DISTINCT vacancy_id) AS vacancy_num, 
COUNT(response_id) AS response_num
FROM employers
LEFT JOIN vacancies
USING(employer_id)
LEFT JOIN responses
USING(vacancy_id)
GROUP BY employer_id, employer_name
ORDER BY response_num DESC;

-- Запрос 2: тот же запрос с INNER JOIN
SELECT employer_name, 
COUNT(DISTINCT vacancy_id) AS vacancy_num, 
COUNT(response_id) AS response_num
FROM employers
JOIN vacancies
USING(employer_id)
JOIN responses
USING(vacancy_id)
GROUP BY employer_id, employer_name
ORDER BY response_num DESC;

-- Вывод:
-- Группировка по работодателю и COUNT(*) даст количество 
-- откликов + вакансии без откликов. Тогда как 
-- COUNT(DISTINCT vacancy_id) минует пропущенные значения
-- и подсчитает количество различных вакансий у каждого работодателя.
--
-- ГринЭнерго - компания с одной вакансией без откликов - потерялась.
-- Это именно та компания, которую стоит спросить, на встрече с 
-- работодателями-партнёрами, почему у нее нет интереса размещать новые
-- вакансии. Ее единственная вакансия на стажера-разработчика держалась 
-- открытой всего месяц с апреля по май. Можно узнать, почему вакансия 
-- закрылась спустя такой маленький срок и предложить разместить новые 
-- вакансии с указанием зарплаты. Возможно стоит опубликовать сразу 
-- несколько вакансий, чтобы повысить узнаваемость компании.
--
-- INNER помогает игнорировать объекты, информация про которые отсутствует
-- в одной из таблиц. Например, если бы у нас содержалась таблица с премиум
-- работодателями и мы бы хотели посмотреть все вакансии/их количество
-- наших премиум работодателей. Тогда INNER JOIN помог бы отфильтровать такие
-- вакансии, не добавляя лишних строк.
-- LEFT JOIN позволяет сохранить все объекты упоминаемые в левой границе.
-- Это может быть полезно для анализа общей картины, особенно когда используем
-- подсчет, где могут появлятся нулевые значения. Например, для каждого месяца 
-- 2026 года нужно подсчитать число опубликованных вакансий.


-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)
SELECT date_trunc('month', created_at)::date AS month,
COUNT(*) AS total,
COUNT(*) FILTER (WHERE status = 'invited') AS invites,
ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'invited')/NULLIF(COUNT(*), 0), 1) AS conversion
FROM responses
GROUP BY date_trunc('month', created_at)::date
ORDER BY month;


-- Вывод:
-- В июне максимальная конверсия (количество приглашений / количество 
-- откликов) - 19.5%. Откликов 118 - достаточное количество  (больше только в июле),
-- поэтому значение можно считать надежным. В августе количество 
-- откликов резко падает, по сравнению с предыдущим месяцем. 
-- Причем август - последний месяц, присутствующий в таблице.
-- Данные могли быть выгружены до оканчания месяца.
-- Запрос
-- "SELECT created_at,
-- date_trunc('month', created_at)::date AS month
-- FROM responses
-- WHERE date_trunc('month', created_at)::date = '2026-08-01'
-- ORDER BY created_at DESC;"
-- не опровергает нашу догадку, последний отклик 15 числа.
-- Этот месяц стоит исключить из вывода.


-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)
SELECT professional_role,
COUNT(DISTINCT vacancy_id) AS vacancy_num, 
COUNT(response_id) AS response_num,
COUNT(*) FILTER (WHERE status = 'invited') AS invited,
ROUND(1.0 * COUNT(response_id)/NULLIF(COUNT(DISTINCT vacancy_id), 0), 1) AS responses_by_vacancy,
ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'invited')/NULLIF(COUNT(response_id), 0), 1) AS conversion
FROM vacancies
LEFT JOIN responses
USING(vacancy_id)
GROUP BY professional_role
ORDER BY vacancy_num DESC;

-- Письменные ответы:
-- 1. Совпадает ли направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
-- Направления не совпадают: у направлений "Аналитик данных" и "Разработчик" 
-- заметно бОльшее число вакансий, а у "Тестировщика" максимальная 
-- конверсия отклика в приглашение.
-- 2. Какое направление выбрать и почему (опираясь на два столбца):
-- Рекомендуется выбрать направление "Разработчик", так как у него высокая 
-- конверсия - 16.8, и достаточное число откликов - 139. У "Тестировщика" слишком мало 
-- откликов, чтобы делать вывод (всего 39): при малом числе откликов конверсия очень шумная.
-- У "Аналитика данных" очень высокая конкуренция, количество откликов на 
-- вакансию (19.6) заметно выше.
-- 3. Оговорка к выводу:
-- У нас нет доверительных интервалов для нашей оценки, поэтому не понятно
-- насколько конверсия отражает действительную вероятность получить 
-- приглашение, если откликнуться.


-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
-- SELECT v.professional_role,
-- count(*) AS vacancies,
-- sum(v.salary_from) AS total_salary,
-- count(r.response_id) / count(*) AS responses_per_vacancy
-- FROM vacancies v
-- JOIN responses r ON v.vacancy_id = r.vacancy_id
-- WHERE v.closed_at = NULL
-- GROUP BY 1;
--
-- Ошибки (минимум четыре):
-- 1. Оператор сравнения с NULL
-- 2. total_salary учитывает зарплату каждой вакансии
-- несколько раз (число равное количество откликов)
-- 3. Деление count на count целочисленное
-- 4. count(*) возвращает число откликов, а не вакансий
-- 5. Чтобы учитывать все вакансии, а не только те, 
-- у которых есть отклики, стоит использовать LEFT JOIN, а 
-- не INNER
-- 6. Сумма зарплат вакансий по направлениям не позволяет 
-- сравнить направления между собой, так как сильно зависит
-- от количества вакансий. Поэтому используем среднюю зарплату.
--
-- Исправленный запрос:
SELECT professional_role,
count(*) AS vacancies,
ROUND(AVG(vacancy_salary), 2) AS mean_salary,
ROUND(1.0 * sum(vacancy_responses) / count(*), 2) AS responses_per_vacancy
FROM 
	(SELECT 
	v.vacancy_id,
	v.professional_role,
	MIN(v.salary_from) AS vacancy_salary,
	count(r.response_id) AS vacancy_responses
	FROM vacancies v
	LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
	WHERE v.closed_at IS NULL
	GROUP BY v.vacancy_id, v.professional_role)
GROUP BY 1;

-- Исправленный запрос помогает сравнить направления и заметить, что
-- лучше рассматривать направление "Разработчик" с самой высокой 
-- средней зарплатой, достаточным количеством открытых вакансий 
-- (больше 20% от всех открытых вакансий по всем 5 направлениям)
-- и средней конкуренцией - всего 8 откликов на вакансию.

-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. Использовать IS для определения пустых значений (NULL)
-- 2. Нужно использовать LEFT JOIN, когда нельзя терять строки основной таблицы
