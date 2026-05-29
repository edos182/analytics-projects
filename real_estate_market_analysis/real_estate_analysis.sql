/* Анализ данных для агентства недвижимости
 * Решаем ad hoc задачи
 *
 * Автор: Эдуард Путылин
 * Дата: 13 марта 2026
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),

-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:

filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
    
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных

prepared_data as (
	SELECT 
	f.id,
	last_price / total_area AS price_m2,
	total_area,
	rooms,
	balcony,
	floors_total,
	CASE 
    	WHEN days_exposition <= 30 THEN 'от 0 до 1 месяца'
    	WHEN days_exposition BETWEEN 31 AND 90 THEN 'от 1 до 3 месяцев'
    	WHEN days_exposition BETWEEN 91 AND 180 THEN 'от 3 до 6 месяцев'
    	WHEN days_exposition >= 181 THEN 'от 6 месяцев'
    ELSE 'non category'
	END as category,
	CASE 
    	WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
    ELSE 'ЛенОбл'
	end as region
FROM real_estate.flats as f
join real_estate.advertisement as a on f.id = a.id
join real_estate.city as c on f.city_id = c.city_id
join real_estate.type as t on f.type_id = t.type_id
where type = 'город' and first_day_exposition between '2015-01-01' and '2018-12-31' and f.id IN (SELECT id FROM filtered_id))
select COUNT(*),
	category,
	region,
	AVG(price_m2) as avg_price_m2,
	AVG(total_area) as avg_total_area,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) as prc_rooms,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) as prc_balcony,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) as prc_floors_total
from prepared_data
group by category, region
order by region

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
	),

-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
	
	filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),

-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
    
    base_data as (
	SELECT a.id,
		EXTRACT(MONTH FROM first_day_exposition) as month_publication,
		EXTRACT(MONTH FROM (first_day_exposition + days_exposition * interval '1 day')) as sell_month,
		last_price / total_area AS price_m2,
		total_area
	FROM real_estate.advertisement as a
	join real_estate.flats as f on f.id = a.id
	join real_estate.city as c on f.city_id = c.city_id
	join real_estate.type as t ON f.type_id = t.type_id
	where type = 'город' and first_day_exposition between '2015-01-01' and '2018-12-31' and f.id IN (SELECT id FROM filtered_id)
	),

	-- по месяцам публикациии:
	
publication_stats as (
	SELECT 
		month_publication as month,
		COUNT(id) as count_pub,
		AVG(price_m2) AS publication_avg_price_m2,
		AVG(total_area) as publication_avg_total_area
	FROM base_data
	group by month_publication
	),
	
	-- по месяцам продажи:
	
sell_stats as (
	SELECT 
		sell_month as month,
		COUNT(id) as count_sell,
		AVG(price_m2) AS sell_avg_price_m2,
		AVG(total_area) as sell_avg_total_area
	FROM base_data
	where sell_month is not null
	group by sell_month
	)
	
SELECT p.month,
	count_pub,
	count_sell,
	publication_avg_price_m2,
	sell_avg_price_m2,
	publication_avg_total_area,
	sell_avg_total_area
from publication_stats as p
join sell_stats as s on s.month = p.month
order by p.month
