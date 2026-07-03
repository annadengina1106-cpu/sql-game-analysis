/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Деньгина Анна
 * Дата: 28.06.2026
*/
--БЫЛА ПРОВЕДЕНА КОРРЕКТИРОВКА ПО КОММЕНТАРИЯМ, СПАСИБО ЗА ОБРАТНУЮ СВЯЗЬ
-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
WITH count_users AS(
	SELECT 
		COUNT(*) AS total_count_users,
		SUM(payer) AS count_paying_users
	FROM fantasy.users)
SELECT total_count_users,
	count_paying_users,
	ROUND(count_paying_users/total_count_users::numeric, 2) AS paying_users_share
FROM count_users;
--Альтернативный метод с функцией AVG()
SELECT 
	COUNT(*) AS total_count_users,
	SUM(payer) AS count_paying_users,
	ROUND(AVG(payer)::numeric, 2) AS paying_users_share
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH count_users AS(
	SELECT r.race,
		COUNT(*) AS total_count_users,
		SUM(u.payer) AS count_paying_users
	FROM fantasy.users AS u
	JOIN fantasy.race AS r ON u.race_id=r.race_id
	GROUP BY r.race)	
SELECT race,
	count_paying_users,
	total_count_users,
	ROUND(count_paying_users/total_count_users::numeric, 2) AS paying_users_share
FROM count_users
ORDER BY paying_users_share DESC;
--Альтернативный метод с функцией AVG()
SELECT r.race,
	COUNT(*) AS total_count_users,
	SUM(u.payer) AS count_paying_users,
	ROUND(AVG(payer)::numeric, 2) AS paying_users_share
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id=r.race_id
GROUP BY r.race
ORDER BY paying_users_share DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Расчет с нулевыми покупками
SELECT 
	COUNT(*) AS count_transaction,
	SUM(amount) AS sum_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	ROUND(AVG(amount)::NUMERIC, 2) AS avg_amount,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
	STDDEV(amount) AS stand_dev
FROM fantasy.events
UNION 
-- Расчет без нулевых покупок
SELECT 
	COUNT(*) AS count_transaction,
	SUM(amount) AS sum_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	ROUND(AVG(amount)::NUMERIC, 2) AS avg_amount,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
	STDDEV(amount) AS stand_dev
FROM fantasy.events
WHERE amount>0;
	
-- 2.2: Аномальные нулевые покупки:
-- Подзапрос для вычисления кол-ва нулевых покупок
WITH zero AS (
	SELECT 
		COUNT(*) AS zero_transaction
	FROM fantasy.events
	WHERE amount = 0 OR amount IS NULL),
-- Подзапрос для вычисления общего кол-ва покупок
total AS (SELECT COUNT(*) AS count_transaction
	FROM fantasy.events)
SELECT zero_transaction,
	zero_transaction::float/count_transaction AS zero_transaction_share
FROM zero, total;
-- Расчет кол-ва игроков, совершивших только нулевые покупки
SELECT 
		COUNT(*) AS count_user_zero_tr
FROM (SELECT id
	FROM fantasy.events
	EXCEPT
	SELECT id
	FROM fantasy.events
	WHERE amount > 0) AS only_zero_users;

-- 2.3: Популярные эпические предметы:
-- Абсолютное кол-во продаж и покупателей для каждого предмета:
WITH abs_count AS (
SELECT DISTINCT i.game_items,
	COUNT(e.transaction_id) AS count_transaction,
	COUNT(DISTINCT e.id) AS count_users
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i ON e.item_code=i.item_code
WHERE e.amount > 0
GROUP BY i.game_items),
total_count AS (
SELECT COUNT(*) AS total_transaction,
	COUNT(DISTINCT id) AS total_users
FROM fantasy.events
WHERE amount > 0)
SELECT game_items,
	count_transaction,
	ROUND(count_transaction::numeric/total_transaction*100, 2) AS percentage_transaction,
	ROUND(count_users::numeric/total_users*100, 2) AS percentage_users
FROM abs_count
CROSS JOIN total_count
ORDER BY count_transaction DESC
LIMIT 5;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- 1) Расчет общего кол-ва игроков:
WITH total_users AS(
SELECT r.race,
	COUNT(*) AS count_users
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id=r.race_id
GROUP BY r.race),
-- 2) Расчет кол-ва игроков, которые совершают игровые покупки, и доли платящих среди них
buying_users AS (SELECT r.race,
	COUNT(DISTINCT u.id) AS buying_users,
	ROUND(SUM(u.payer)::numeric/COUNT(DISTINCT u.id), 2) AS paying_users_share
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id=r.race_id
WHERE u.id IN (SELECT id
FROM fantasy.events
WHERE amount >0)
GROUP BY r.race),
-- 3) Расчет общего кол-ва и суммы покупок в разрезе на расы:
total_transaction AS (SELECT r.race,
	COUNT(*) AS count_transaction,
	SUM(e.amount) AS sum_amount
FROM fantasy.events AS e
JOIN fantasy.users AS u ON u.id=e.id
JOIN fantasy.race AS r ON u.race_id=r.race_id
WHERE e.amount >0
GROUP BY r.race
)
--Общий запрос:
SELECT r.race,
	tu.count_users,
	bu.buying_users,
	-- Расчет доли покупателей относительно зарегистрированных пользователей
	ROUND(bu.buying_users::numeric/tu.count_users, 2) AS buying_users_share,
	bu.paying_users_share,
	-- Расчет среднего кол-ва покупок на одного игрока, совершившего внутриигровые покупки
	ROUND(tt.count_transaction::numeric/bu.buying_users, 2) AS avg_buys_per_player,
	-- Расчет средней стоимости одной покупки на одного игрока, совершившего внутриигровые покупки
	ROUND(tt.sum_amount::numeric/tt.count_transaction, 2) AS avg_amount_per_purchase,
	-- Расчет средней суммарной стоимости всех покупок на одного игрока, совершившего внутриигровые покупки
	ROUND(tt.sum_amount::numeric/bu.buying_users, 2) AS avg_total_amount
FROM fantasy.race AS r
JOIN total_users AS tu ON r.race=tu.race
JOIN buying_users AS bu ON r.race=bu.race
JOIN total_transaction AS tt ON tt.race = r.race
ORDER BY tu.count_users DESC;

