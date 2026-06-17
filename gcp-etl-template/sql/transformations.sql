-- ===========================================
-- STG → TRG TRANSFORMATION (MERGE BASED)
-- ===========================================

MERGE `project-24a83cf8-3efa-4d50-afd.purchase_etl_dataset.trg_purchase_data` T
USING (

  -- ===========================================
  -- CLEAN + TRANSFORM DATA
  -- ===========================================
  WITH cleaned AS (
    SELECT
      TRIM(CAST(order_id AS STRING)) AS order_id,
      TRIM(customer_id) AS customer_id,

      NULLIF(TRIM(customer_name), "") AS customer_name,
      NULLIF(TRIM(product), "") AS product,
      NULLIF(TRIM(category), "") AS category,
      NULLIF(TRIM(city), "") AS city,
      NULLIF(TRIM(payment_method), "") AS payment_method,

      SAFE_CAST(price AS FLOAT64) AS price,
      SAFE_CAST(quantity AS INT64) AS quantity,
      SAFE_CAST(discount AS FLOAT64) AS discount,
      SAFE_CAST(gst AS FLOAT64) AS gst,
      SAFE_CAST(shipping_cost AS FLOAT64) AS shipping_cost,

      CASE
        WHEN SAFE.PARSE_DATE('%Y-%m-%d', order_date) IS NOT NULL
          THEN PARSE_DATE('%Y-%m-%d', order_date)
        WHEN SAFE.PARSE_DATE('%d-%m-%Y', order_date) IS NOT NULL
          THEN PARSE_DATE('%d-%m-%Y', order_date)
        ELSE NULL
      END AS order_date

    FROM `project-24a83cf8-3efa-4d50-afd.purchase_etl_dataset.stg_purchase_data`
  ),

  filtered AS (
    SELECT *
    FROM cleaned
    WHERE
      order_id IS NOT NULL
      AND price IS NOT NULL
      AND quantity IS NOT NULL
      AND price > 0
      AND quantity > 0
  ),

  dedup AS (
    SELECT *,
      ROW_NUMBER() OVER (
        PARTITION BY order_id
        ORDER BY order_date DESC
      ) AS rn
    FROM filtered
  )

  SELECT
    order_id,
    customer_id,
    customer_name,
    product,
    category,
    price,
    quantity,
    (price * quantity) AS total_amount,
    order_date,
    city,
    payment_method,
    COALESCE(discount, 0) AS discount,
    COALESCE(gst, 0) AS gst,
    COALESCE(shipping_cost, 0) AS shipping_cost,

    (
      (price * quantity)
      + COALESCE(shipping_cost, 0)
      - COALESCE(discount, 0)
      + ((price * quantity) * COALESCE(gst, 0) / 100)
    ) AS net_amount,

    CURRENT_TIMESTAMP() AS load_timestamp

  FROM dedup
  WHERE rn = 1

) S

ON T.order_id = S.order_id

-- ✅ UPDATE EXISTING RECORDS
WHEN MATCHED THEN
  UPDATE SET
    customer_id     = S.customer_id,
    customer_name   = S.customer_name,
    product         = S.product,
    category        = S.category,
    price           = S.price,
    quantity        = S.quantity,
    total_amount    = S.total_amount,
    order_date      = S.order_date,
    city            = S.city,
    payment_method  = S.payment_method,
    discount        = S.discount,
    gst             = S.gst,
    shipping_cost   = S.shipping_cost,
    net_amount      = S.net_amount,
    load_timestamp  = CURRENT_TIMESTAMP()

-- ✅ INSERT NEW RECORDS
WHEN NOT MATCHED THEN
  INSERT (
    order_id,
    customer_id,
    customer_name,
    product,
    category,
    price,
    quantity,
    total_amount,
    order_date,
    city,
    payment_method,
    discount,
    gst,
    shipping_cost,
    net_amount,
    load_timestamp
  )
  VALUES (
    S.order_id,
    S.customer_id,
    S.customer_name,
    S.product,
    S.category,
    S.price,
    S.quantity,
    S.total_amount,
    S.order_date,
    S.city,
    S.payment_method,
    S.discount,
    S.gst,
    S.shipping_cost,
    S.net_amount,
    CURRENT_TIMESTAMP()
  );
