/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 

*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
	COUNT(id) AS users_count,
	SUM(payer) AS paying_players,
	ROUND (AVG(payer), 2) AS paying_part
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
	race,
	SUM(payer) AS payer_players,
	COUNT(u.id) AS players,
	ROUND (SUM(payer) / COUNT(u.id)::numeric, 2) AS paying_part
FROM fantasy.race AS r
JOIN fantasy.users AS u ON r.race_id = u.race_id
GROUP BY race;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
	COUNT (transaction_id) AS transaction_count,
	SUM (amount) AS amount_sum,
	MIN(amount) AS amount_min,
	MAX(amount) AS amount_max,
	AVG(amount) AS amount_avg,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS amount_mediana,
	STDDEV(amount) AS stand_dev
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT 
	COUNT (amount) AS amount_count,
	SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END) AS zero_transaction_count,
	SUM(CASE WHEN amount = 0 THEN 1 ELSE 0 END) / COUNT (amount)::NUMERIC * 100 AS zero_part
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:
SELECT 
	i.game_items,
	COUNT(transaction_id) AS transaction_count,
	ROUND (COUNT(transaction_id)::numeric / 
		(SELECT 
			COUNT(transaction_id) AS total_count
		FROM fantasy.events
		WHERE amount != 0 ), 4) * 100 AS items_part,
    ROUND (COUNT (DISTINCT e.id)::numeric /
    	(SELECT 
    		COUNT(DISTINCT id)
         FROM fantasy.events
         WHERE amount != 0)* 100, 2) AS buyers_share
FROM fantasy.items AS i
JOIN fantasy.events AS e ON i.item_code = e.item_code
JOIN fantasy.users AS u ON e.id = u.id
WHERE amount != 0
GROUP BY i.game_items
ORDER BY COUNT(transaction_id) DESC
LIMIT 20 

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH players_by_race AS (
    SELECT 
        r.race,
        COUNT(DISTINCT u.id) AS total_players,
        COUNT(DISTINCT e.id) AS buying_players,
        ROUND(
            COUNT(DISTINCT e.id)::numeric 
            / COUNT(DISTINCT u.id), 
            4
        ) AS buying_share
    FROM fantasy.race r
    JOIN fantasy.users u 
        ON r.race_id = u.race_id
    LEFT JOIN fantasy.events e 
        ON e.id = u.id
       AND e.amount > 0
    GROUP BY r.race
),
payers_among_buyers AS (
    SELECT 
        r.race,
        ROUND(
            COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END)::numeric
            / COUNT(DISTINCT e.id),
            4
        ) AS paying_share
    FROM fantasy.race r
    JOIN fantasy.users u 
        ON r.race_id = u.race_id
    JOIN fantasy.events e 
        ON e.id = u.id
    WHERE e.amount > 0
    GROUP BY r.race
),
purchase_metrics AS (
    SELECT
        r.race,
        ROUND(
            COUNT(e.transaction_id)::numeric 
            / COUNT(DISTINCT e.id), 
            2
        ) AS avg_purchases_per_buyer,
        ROUND(AVG(e.amount)::numeric, 2) AS avg_purchase_amount,
        ROUND(
            SUM(e.amount)::numeric 
            / COUNT(DISTINCT e.id), 
            2
        ) AS avg_total_spent_per_buyer
    FROM fantasy.race r
    JOIN fantasy.users u
        ON r.race_id = u.race_id
    JOIN fantasy.events e
        ON e.id = u.id
    WHERE e.amount > 0
    GROUP BY r.race
)
SELECT
    p.race,
    p.total_players,
    p.buying_players,
    p.buying_share,
    pa.paying_share,
    pm.avg_purchases_per_buyer,
    pm.avg_purchase_amount,
    pm.avg_total_spent_per_buyer
FROM players_by_race p
JOIN payers_among_buyers pa
    ON pa.race = p.race
JOIN purchase_metrics pm
    ON pm.race = p.race
ORDER BY p.race;
