--SQL to build schema
CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

-- 1. What is the total amount each customer spent at the restaurant?
SELECT customer_id, SUM(price)
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date) as days_visited
FROM dannys_diner.sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
--Note: The sales table includes dates, not timestamps, so there are cases where we cannot accurately determine the first item purchased.
--In the case where multiple items were purchased on the same day, I did a `listagg` to list all purchased items together

WITH first_order AS
(
  SELECT customer_id, MIN(order_date) as first_order_date
  FROM dannys_diner.sales
  GROUP BY customer_id
)

--Using `DISTINCT` here because `STRING_AGG` doesn't work with `DISTINCT`
SELECT DISTINCT sales.customer_id
	 , STRING_AGG(product_name, ', ') AS first_products_ordered
FROM dannys_diner.sales
INNER JOIN first_order ON sales.order_date = first_order.first_order_date
INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
GROUP BY sales.customer_id, product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT menu.product_name
     , COUNT(sales.product_id) AS number_of_orders
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
GROUP BY sales.product_id
       , menu.product_name
ORDER BY number_of_orders DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?
WITH customer_product_orders AS
(
  SELECT sales.customer_id
       , menu.product_name
       , COUNT(sales.product_id) AS number_of_orders
       , DENSE_RANK() OVER (PARTITION BY sales.customer_id 
			    ORDER BY COUNT(sales.customer_id) DESC) AS rank 
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
  GROUP BY sales.customer_id
         , menu.product_name
 )
 
 SELECT DISTINCT customer_id
      --If there is a tie, then list all the top products
      , STRING_AGG(product_name, ', ') AS most_ordered_products
      , number_of_orders
 FROM customer_product_orders
 WHERE rank = 1
 GROUP BY customer_id
        , number_of_orders
;

-- 6. Which item was purchased first by the customer after they became a member?
WITH orders_after_signup AS
(
  SELECT sales.customer_id
       , members.join_date
       , sales.order_date
       , menu.product_name
       , DENSE_RANK() OVER (PARTITION BY sales.customer_id 
			    ORDER BY order_date) AS rank 
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.members ON sales.customer_id = members.customer_id
  INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
  WHERE members.join_date < sales.order_date --Only pull orders after join date
  GROUP BY sales.customer_id
  	 , members.join_date
  	 , sales.order_date
         , menu.product_name
)

SELECT customer_id
     , product_name
FROM orders_after_signup
WHERE rank = 1;

-- 7. Which item was purchased just before the customer became a member?
WITH orders_before_signup AS
(
  SELECT sales.customer_id
       , members.join_date
       , sales.order_date
       , menu.product_name
       , DENSE_RANK() OVER (PARTITION BY sales.customer_id 
			    ORDER BY order_date DESC) AS rank 
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.members ON sales.customer_id = members.customer_id
  INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
  WHERE members.join_date > sales.order_date --Only pull orders before join date
  GROUP BY sales.customer_id
  	 , members.join_date
  	 , sales.order_date
         , menu.product_name
)

SELECT customer_id
     , STRING_AGG(product_name, ', ') as products_ordered_before_joining
FROM orders_before_signup
WHERE rank = 1
GROUP BY customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT sales.customer_id
     , COUNT(sales.product_id) AS number_of_orders
     , SUM(menu.price) AS total_spent
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
INNER JOIN dannys_diner.members ON sales.customer_id = members.customer_id
WHERE sales.order_date < members.join_date
GROUP BY sales.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH order_type AS
(
  SELECT sales.customer_id
       , SUM(CASE WHEN menu.product_name != 'sushi' THEN price ELSE 0 END) AS num_non_sushi_orders
       , SUM(CASE WHEN menu.product_name = 'sushi' THEN price ELSE 0 END) AS num_sushi_orders
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
  GROUP BY sales.customer_id
         , menu.product_name
)

SELECT customer_id
     , (SUM(num_non_sushi_orders) * 10) + (SUM(num_sushi_orders) * 20) AS points_earned
FROM order_type
GROUP BY customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January? 
WITH double_rewards_week AS
(
  SELECT members.customer_id
  , join_date
  , join_date + INTERVAL '6 day' AS end_of_double_rewards
  , order_date
  , menu.product_name
  , menu.price
  FROM dannys_diner.members
  INNER JOIN dannys_diner.sales ON members.customer_id = sales.customer_id
  INNER JOIN dannys_diner.menu ON sales.product_id = menu.product_id
  WHERE sales.order_date <= '2021-01-31'
  AND order_date >= join_date
)


SELECT customer_id
     , SUM(CASE WHEN product_name = 'sushi' THEN price * 20
                WHEN order_date BETWEEN join_date AND end_of_double_rewards
                THEN price * 20
           ELSE price * 10 END) AS points_earned
FROM double_rewards_week
GROUP BY customer_id
