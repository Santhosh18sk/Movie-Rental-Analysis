create database movie;
use movie;

-- New vs Repeat Customers
WITH CustomerFirstRental AS (
    SELECT customer_id,
           MIN(rental_date) AS first_rental_date
    FROM rentat
    GROUP BY customer_id
),
RentalClassified AS (
    SELECT r.rental_id,
           r.customer_id,
           p.amount,
           CASE
               WHEN r.rental_date = cfr.first_rental_date THEN 'New Customer'
               ELSE 'Repeat Customer'
           END AS customer_type
    FROM rentat r
    JOIN payment p ON r.rental_id = p.rental_id
    JOIN CustomerFirstRental cfr ON r.customer_id = cfr.customer_id
)
SELECT customer_type,
       AVG(amount) AS average_rental_value
FROM RentalClassified
GROUP BY customer_type;


-- Films with highest rental rates and most in demandSELECT 
   SELECT 
    f.title,
    f.rental_rate,
    COUNT(r.rental_id) AS total_rentals
FROM film f
JOIN inventory i ON f.film_id = i.film_id
JOIN rentat r ON i.inventory_id = r.inventory_id
GROUP BY f.title, f.rental_rate
ORDER BY total_rentals DESC
LIMIT 10;

-- Are there correlations between staff performance and customer satisfaction?
SELECT 
    s.staff_id,
    CONCAT(s.first_name, ' ', s.last_name) AS staff_name,
    COUNT(p.payment_id) AS total_transactions,
    SUM(p.amount) AS total_revenue
FROM staff s
JOIN payment p ON s.staff_id = p.staff_id
GROUP BY s.staff_id, s.first_name, s.last_name;

-- Are there seasonal trends in customer behavior across different locations?

SELECT 
    ci.city,
    MONTH(p.payment_date) AS month,
    SUM(p.amount) AS revenue
FROM payment p
JOIN rentat r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN store s ON i.store_id = s.store_id
JOIN address a ON s.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
GROUP BY ci.city, MONTH(p.payment_date)
ORDER BY ci.city, month;

-- Are certain language films more popular among specific customer segments?
SELECT 
    l.name AS language,
    COUNT(r.rental_id) AS rentals
FROM language l
JOIN film f ON l.language_id = f.language_id
JOIN inventory i ON f.film_id = i.film_id
JOIN rentat r ON i.inventory_id = r.inventory_id
GROUP BY l.name
ORDER BY rentals DESC;

-- Customer loyalty impact on sales revenue over time
with CustomerLoyalty as(					
select 					
c.customer_id,					
count(p.payment_id) as total_transaction,					
count(distinct  date_format(p.payment_date, '%Y-%m')) as active_months					
from customer c					
join payment p on c.customer_id = p.customer_id					
group by c.customer_id					
),					
loyalty_segment as (					
select					
customer_id,					
case 					
when active_months >= 6 then 'High Loyalty'					
when active_months between 3 and 5 then 'Medium Loyalty'					
else 'Low Loyalty'					
end as loyalty_level					
from CustomerLoyalty					
)					
select					
l.loyalty_level,					
extract(year from p.payment_date) as year,					
extract(month from p.payment_date) as month,					
sum(p.amount) as total_revenue					
from payment p 					
join loyalty_segment l on p.customer_id = l.customer_id					
group by l.loyalty_level,year,month					
order by l.loyalty_level,year,month;					


SELECT 
    t.country,
    t.city,
    t.category,
    t.total_rentals
FROM (
    SELECT 
        cat.name AS category,
        ci.city,
        co.country,
        COUNT(r.rental_id) AS total_rentals,
        ROW_NUMBER() OVER (PARTITION BY ci.city ORDER BY COUNT(r.rental_id) DESC) AS rank_num
    FROM rental r
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category cat ON fc.category_id = cat.category_id
    JOIN customer c ON r.customer_id = c.customer_id
    JOIN address a ON c.address_id = a.address_id
    JOIN city ci ON a.city_id = ci.city_id
    JOIN country co ON ci.country_id = co.country_id
    GROUP BY cat.name, ci.city, co.country
) AS t
WHERE t.rank_num = 1
ORDER BY t.country, t.city;


-- How does the availability and knowledge of staff affect customer ratings?
WITH StaffPerformance AS (
    SELECT 
        s.staff_id,
        ANY_VALUE(s.first_name) AS first_name,
        ANY_VALUE(s.last_name) AS last_name,
        COUNT(r.rental_id) AS total_rentals,
        AVG(f.rental_rate) AS avg_film_price,
        AVG(f.length) AS avg_film_length
    FROM staff s
    JOIN rentat r ON s.staff_id = r.staff_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    GROUP BY s.staff_id
),
CustomerRatings AS (
    SELECT
        r.staff_id,
        AVG(p.amount) AS avg_payment,
        COUNT(DISTINCT r.customer_id) AS unique_customers,
        COUNT(r.rental_id) / COUNT(DISTINCT r.customer_id) AS repeat_ratio
    FROM rentat r
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY r.staff_id
)
SELECT
    sp.staff_id,
    sp.first_name,
    sp.last_name,
    sp.total_rentals,
    sp.avg_film_price,
    sp.avg_film_length,
    cr.avg_payment,
    cr.repeat_ratio
FROM StaffPerformance sp
JOIN CustomerRatings cr ON sp.staff_id = cr.staff_id
ORDER BY cr.repeat_ratio DESC;

--  How does the proximity of stores to customers impact rental frequency?
WITH CustomerProximity AS (
    SELECT 
        r.customer_id,
        CASE 
            WHEN s.store_id = c.store_id THEN 'High Proximity'
            ELSE 'Low Proximity'
        END AS proximity_level
    FROM rentat r
    JOIN customer c ON r.customer_id = c.customer_id
    JOIN staff s ON r.staff_id = s.staff_id
),
RentalFrequency AS (
    SELECT 
        customer_id,
        COUNT(rental_id) AS total_rentals
    FROM rentat
    GROUP BY customer_id
)
SELECT 
    rf.customer_id,
    cp.proximity_level,
    rf.total_rentals
FROM RentalFrequency rf
JOIN CustomerProximity cp ON rf.customer_id = cp.customer_id
ORDER BY rf.total_rentals DESC;
								
-- Do specific film categories attract different age groups of customers?								
WITH FilmCategoryAge AS (
    SELECT 
        r.customer_id,
        CASE
            WHEN f.rating = 'G' THEN 'Kids'
            WHEN f.rating = 'PG' THEN 'Pre-Teens'
            WHEN f.rating = 'PG-13' THEN 'Teens'
            WHEN f.rating = 'R' THEN 'Adults'
            WHEN f.rating = 'NC-17' THEN 'Mature Adults'
            ELSE 'Unknown'
        END AS age_group,
        cat.name AS category
    FROM rentat r
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category cat ON fc.category_id = cat.category_id
)
SELECT 
    age_group,
    category,
    COUNT(*) AS rental_count
FROM FilmCategoryAge
GROUP BY age_group, category
ORDER BY age_group, rental_count DESC;

-- 11. What are the demographics and preferences of the highest-spending customers?
WITH CustomerSpending AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
       round( SUM(p.amount),2) AS total_spent
    FROM customer c
    JOIN payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
),
TopSpenders AS (
    SELECT *
    FROM CustomerSpending
    ORDER BY total_spent DESC
    LIMIT 10
),
CategoryPreference AS (
    SELECT 
        r.customer_id,
        fc.category_id,
        COUNT(r.rental_id) AS rentals_count,
       round( SUM(p.amount),2) AS amount_spent
    FROM rentat r
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film_category fc ON i.film_id = fc.film_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY r.customer_id, fc.category_id
),
RatingPreference AS (
    SELECT
        r.customer_id,
        f.rating,
        COUNT(r.rental_id) AS rentals_count,
       round( SUM(p.amount),2) AS amount_spent
    FROM rentat r
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY r.customer_id, f.rating
)
SELECT 
    ts.customer_id,
    ts.first_name,
    ts.last_name,
    ts.total_spent,
    ci.city,
    co.country,
    cat.name AS category_name,
    cp.rentals_count AS category_rentals,
    cp.amount_spent AS category_amount,
    rp.rating AS film_rating,
    rp.rentals_count AS rating_rentals,
    rp.amount_spent AS rating_amount
FROM TopSpenders ts
JOIN customer c ON ts.customer_id = c.customer_id
JOIN address a ON c.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
JOIN country co ON ci.country_id = co.country_id
JOIN CategoryPreference cp ON ts.customer_id = cp.customer_id
JOIN category cat ON cp.category_id = cat.category_id
JOIN RatingPreference rp ON ts.customer_id = rp.customer_id
ORDER BY ts.total_spent DESC, cp.amount_spent DESC, rp.amount_spent DESC;

-- 12 How does the availability of inventory impact customer satisfaction and repeat business?
WITH InventoryAvailability AS (
    SELECT 
        i.film_id,
        COUNT(i.inventory_id) AS available_copies
    FROM inventory i
    GROUP BY i.film_id
),
AvailabilityLevel AS (
    SELECT 
        film_id,
        CASE
            WHEN available_copies >= 8 THEN 'High Availability'
            WHEN available_copies BETWEEN 4 AND 7 THEN 'Medium Availability'
            ELSE 'Low Availability'
        END AS availability_level
    FROM InventoryAvailability
),
CustomerBehavior AS (
    SELECT 
        r.customer_id,
        al.availability_level,
        COUNT(r.rental_id) AS total_rentals,
        SUM(p.amount) AS total_spent
    FROM rentat r
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN AvailabilityLevel al ON i.film_id = al.film_id
    JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY r.customer_id, al.availability_level
)
SELECT 
    availability_level,
    round(AVG(total_rentals),2) AS avg_repeat_rentals,
   round( AVG(total_spent),2)AS avg_spending,
    COUNT(DISTINCT customer_id) AS total_customers
FROM CustomerBehavior
GROUP BY availability_level
ORDER BY avg_repeat_rentals DESC;

-- 13 What are the busiest hours or days for each store location, and how does it impact staffing requirements?

SELECT 
    s.store_id,
    EXTRACT(HOUR FROM p.payment_date) AS hour,
    COUNT(p.rental_id) AS num_sales
FROM payment p
JOIN staff s ON p.staff_id = s.staff_id
GROUP BY s.store_id, hour
ORDER BY s.store_id, num_sales DESC;

-- 14 What are the cultural or demographic factors that influence customer preferences in different locations?

SELECT                 
    s.store_id,                
    c.city,                
    f.rating AS film_rating,                
    COUNT(r.rental_id) AS rentals,                
    round(SUM(p.amount),2) AS total_revenue                
FROM rentat r
JOIN payment p ON r.rental_id = p.rental_id                
JOIN inventory i ON r.inventory_id = i.inventory_id                
JOIN film f ON i.film_id = f.film_id                
JOIN store s ON i.store_id = s.store_id                
JOIN address a ON s.address_id = a.address_id                
JOIN city c ON a.city_id = c.city_id                
GROUP BY s.store_id, c.city, f.rating                
ORDER BY s.store_id, total_revenue DESC;

-- 15 How does the availability of films in different languages impact customer satisfaction and rental frequency?

SELECT                
    s.store_id,                
    c.city,                
    f.language_id,                
    l.name AS language,                
    COUNT(r.rental_id) AS total_rentals,                
    round(SUM(p.amount),2) AS total_revenue                
FROM rentat r
JOIN payment p ON r.rental_id = p.rental_id                
JOIN inventory i ON r.inventory_id = i.inventory_id                
JOIN film f ON i.film_id = f.film_id                
JOIN language l ON f.language_id = l.language_id                
JOIN store s ON i.store_id = s.store_id                
JOIN address a ON s.address_id = a.address_id                
JOIN city c ON a.city_id = c.city_id                
GROUP BY s.store_id, c.city, f.language_id, l.name                
ORDER BY total_rentals DESC;
