with

    customer_orders as (select * from {{ ref("customers") }}),

    orders as (select * from {{ ref("stg_orders") }}),

    payment as (select * from {{ source("payment", "payment") }}),

    successful_payment as (
        select
            orderid as order_id,
            row_number() over (order by orderid) as transaction_seq,
            max(created) as payment_finalized_date,
            sum(amount) / 100.0 as total_amount_paid
        from payment
        where status <> 'fail'
        group by 1
    ),

    paid_orders as (
        select
            orders.order_id,
            orders.customer_id,
            orders.order_date as order_placed_at,
            orders.status as order_status,
            p.total_amount_paid,
            p.payment_finalized_date,
            p.transaction_seq,
            c.first_order as fdos,
            c.first_name as customer_first_name,
            c.last_name as customer_last_name,
            row_number() over (
                partition by orders.customer_id order by orders.order_id
            ) as customer_sales_seq,
            case
                when c.first_order = orders.order_date
                then 'new'
                else 'return'
            end as nvsr,
            SUM(total_amount_paid) OVER (PARTITION BY orders.customer_id ORDER BY orders.order_id) AS customer_lifetime_value
        from orders
        left join successful_payment p on orders.order_id = p.order_id
        left join customer_orders c on orders.customer_id = c.customer_id
    )

select *
from paid_orders p
order by order_id
