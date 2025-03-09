--Section A: Pizza Metrics--

--How many pizzas were ordered?

--We know each row in customer_orders represents one pizza, so count the number of rows
SELECT  COUNT(*) AS number_of_pizzas
FROM pizza_runner.customer_orders;

--How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id) AS number_of_orders
FROM pizza_runner.customer_orders;

--How many successful orders were delivered by each runner?
SELECT COUNT(DISTINCT order_id) AS number_of_orders
FROM pizza_runner.runner_orders
WHERE COALESCE(cancellation, '') IN ('', 'null');

--How many of each type of pizza was delivered?
SELECT customer_orders.pizza_id
     , COUNT(customer_orders.*) AS number_of_pizzas_delivered
FROM pizza_runner.runner_orders
INNER JOIN pizza_runner.customer_orders ON runner_orders.order_id = customer_orders.order_id
WHERE COALESCE(cancellation, '') IN ('', 'null')
GROUP BY customer_orders.pizza_id;

--How many Vegetarian and Meatlovers were ordered by each customer?
SELECT pizza_name
     , COUNT(customer_orders.*) AS number_of_pizzas_ordered
FROM pizza_runner.customer_orders
INNER JOIN pizza_runner.pizza_names ON customer_orders.pizza_id = pizza_names.pizza_id
GROUP BY pizza_name;

--What was the maximum number of pizzas delivered in a single order?
SELECT runner_orders.order_id
     , COUNT(customer_orders.*) AS number_of_pizzas_delivered
FROM pizza_runner.runner_orders
INNER JOIN pizza_runner.customer_orders ON runner_orders.order_id = customer_orders.order_id
WHERE COALESCE(cancellation, '') IN ('', 'null')
GROUP BY runner_orders.order_id
ORDER BY number_of_pizzas_delivered DESC
LIMIT 1;
