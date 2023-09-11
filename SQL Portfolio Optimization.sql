-- use invest; 
    SELECT c.full_name, 
        p.ticker, 
        p.value, 
        p.date, 
        p.price_type, 
        SUM(h.value * h.quantity) AS market_value, 
        s.major_asset_class, 
        s.minor_asset_class
    FROM 
        customer_details c 
    INNER JOIN 
        account_dim a ON c.customer_id = a.client_id
    INNER JOIN 
        holdings_current h ON a.account_id = h.account_id
    INNER JOIN 
        security_masterlist s ON h.ticker = s.ticker
    INNER JOIN 
        pricing_daily_new p ON s.ticker = p.ticker
    WHERE 
        c.customer_id = 78 
        AND p.price_type = 'adjusted' 
        AND p.date > '2016-09-01'
        ;

-- Create a view for Christina Gyllner's financial data
CREATE VIEW christina_gyllner_FIN AS
SELECT 
    q.ticker, 
    q.date, 
    q.value, 
    q.price_type
FROM
(
SELECT 
	c.full_name, 
	p.ticker, 
    a.account_id, 
    p.value, 
    p.date, 
    p.price_type
FROM 
	customer_details c 
INNER JOIN 
	account_dim a ON c.customer_id = a.client_id
INNER JOIN 
	holdings_current h ON a.account_id = h.account_id
INNER JOIN 
	security_masterlist s ON h.ticker = s.ticker
INNER JOIN 
	pricing_daily_new p ON s.ticker = p.ticker
WHERE 
	c.customer_id = 78 
    AND p.price_type = 'adjusted' 
    AND p.date > '2016-09-01') q; 

-- Create views for different portfolio returns (12M, 18M, 24M)
-- calculate 12M return 
CREATE VIEW christinag12m_return AS
SELECT 
	z.ticker, 
    z.date, (z.p1-z.p0)/z.p0 as discrete_returns
FROM
(
SELECT 
	ticker, 
    date, 
    value as p1, LAG(value,250) OVER (PARTITION BY ticker
                                                    ORDER BY date) as p0
FROM 
	christina_gyllner_FIN
WHERE 
	date > '2021-09-01'
	) z;

-- calculate 18M return 
CREATE VIEW christinag18m_return AS
SELECT 
	z.ticker, 
	z.date, ((z.p1-z.p0)/z.p0)*(12/18) as discrete_returns18
FROM
(
SELECT 
	ticker, 
    date, 
    value as p1, LAG(value,375) OVER (PARTITION BY ticker
                                                    ORDER BY date) as p0
FROM 
	christina_gyllner_FIN
WHERE 
	date > '2021-03-01'
	) z 
;

-- calculate 24M return 
CREATE VIEW christinag24m_return AS
SELECT 
	z.ticker, 
	z.date, 
    ((z.p1-z.p0)/z.p0)*(12/24) as discrete_returns24
FROM
(
SELECT 
	ticker, 
    date, 
    value as p1, LAG(value,500) OVER (PARTITION BY ticker
                                                    ORDER BY date) as p0
FROM 
	christina_gyllner_FIN
WHERE 
	date > '2020-09-01'
	) z 
;

-- Create a view for portfolio weights
CREATE VIEW CG_portfolio_weights AS
SELECT 
	a.account_id, 
    h.ticker, 
    AVG(h.value) as avg_value, 
    SUM(h.quantity) as sum_quant                                   
FROM 
	customer_details c 
INNER JOIN 
	account_dim a ON c.customer_id = a.client_id
INNER JOIN 
	holdings_current h ON a.account_id = h.account_id
INNER JOIN 
	security_masterlist s ON h.ticker = s.ticker
INNER JOIN 
	pricing_daily_new p ON s.ticker = p.ticker
WHERE 
	p.price_type = 'adjusted' 
    AND p.date > '2022-09-01' 
    AND c.customer_id = 78
GROUP BY p.ticker
; 

-- Calculate market value per ticker
CREATE VIEW market_value as 
SELECT 
	ticker, 
    avg_value*sum_quant AS market_value
FROM 
	CG_portfolio_weights
GROUP BY 
	ticker;

-- Create a view for total market value
CREATE VIEW total_market_value AS 
SELECT 
	SUM(market_value) as total_value
FROM 
	market_value;

-- Create a view for portfolio weights
CREATE VIEW portfolio_weights AS 
SELECT 
	m.ticker, 
    m.market_value/t.total_value as port_weights
FROM 
	market_value m, 
    total_market_value t
GROUP BY 
	m.ticker; 

-- Check if portfolio weights equal 1
SELECT 
	SUM((m.market_value)/t.total_value) as total_weight
FROM 
	market_value m, 
	total_market_value t;

-- Create views for portfolio returns (12M, 18M, 24M)
CREATE VIEW 12mreturnsforpret_CG AS
SELECT *
FROM 
	christinag12m_return
WHERE 
	date = '2022-09-09'
GROUP BY 
	ticker;

-- portfolio return 12M
SELECT *
FROM 12mreturnsforpret_CG;

CREATE VIEW CG_12Mpret AS
SELECT 
	p.ticker, 
    p.port_weights*t.discrete_returns AS 12port_return
FROM 
	portfolio_weights p, 
	12mreturnsforpret_CG t
WHERE 
	p.ticker = t.ticker
GROUP BY 
	ticker;

SELECT 	
	sum(12port_return)
FROM 
	CG_12Mpret;
    
-- 18M Portfolio Return
CREATE VIEW 18mreturnsforpret_CG AS
SELECT *
FROM 
	christinag18m_return
WHERE 
	date = '2022-09-09'
GROUP BY 
	ticker;

-- portfolio return 18M
SELECT *
FROM 
	18mreturnsforpret_CG;

CREATE VIEW CG_18Mpret AS
SELECT 
	p.ticker, 
    p.port_weights*t.discrete_returns18 AS 18port_return
FROM 
	portfolio_weights p, 
    18mreturnsforpret_CG t
WHERE 
	p.ticker = t.ticker
GROUP BY 
	ticker;

SELECT 
	sum(18port_return)
FROM 
	CG_18Mpret;

-- 24M Portfolio Return
CREATE VIEW 24mreturnsforpret_CG AS
SELECT *
FROM 
	christinag24m_return
WHERE 
	date = '2022-09-09'
GROUP BY 
	ticker;

-- portfolio return 24M
SELECT *
FROM 
	24mreturnsforpret_CG;

CREATE VIEW CG_24Mpret AS
SELECT 
	p.ticker, 
    p.port_weights*t.discrete_returns24 AS 24port_return
FROM 
	portfolio_weights p, 
	24mreturnsforpret_CG t
WHERE 
	p.ticker = t.ticker
GROUP BY
	ticker;

SELECT 
	sum(24port_return)
FROM 
	CG_24Mpret;


-- Market value for client
SELECT 
	account_id, 
    count(distinct ticker), 
    SUM(value*quantity) as market_value
FROM 
	holdings_current
WHERE 
	account_id IN (374,37401,37402);
    
-- SIGMA
CREATE VIEW christina_gyllner_daily AS
SELECT 
	z.account_id, 
    z.ticker, 
    z.date, (z.p1-z.p0)/z.p0 as discrete_returns12
FROM
(
SELECT 
	h.account_id, 
    p.ticker, 
    p.date, 
    p.value as p1, LAG(p.value,1) OVER (PARTITION BY p.ticker
                                                    ORDER BY p.date) as p0
FROM 
	customer_details c 
INNER JOIN 
	account_dim a ON c.customer_id = a.client_id
INNER JOIN 
	holdings_current h ON a.account_id = h.account_id
INNER JOIN 
	security_masterlist s ON h.ticker = s.ticker
INNER JOIN 
	pricing_daily_new p ON s.ticker = p.ticker
WHERE
	p.price_type = 'adjusted' 
    AND p.date > '2021-09-01' 
    AND c.customer_id = 78
) z ;
-- calculating average return and st dev for 12M
SELECT 
	ticker, 
    AVG(discrete_returns12) AS mu, 
    STD(discrete_returns12) as sigma12,
	AVG(discrete_returns12)/STD(discrete_returns12) as risk_adj_returns12
FROM 
	christina_gyllner_daily 
GROUP BY 
	ticker
ORDER BY 
	risk_adj_returns12 DESC;

------------------------------------------------------------------------------------
SELECT *
FROM 
	security_masterlist
WHERE 
	ticker IN ('COST', 'AMP', 'ANSS', 'FLT', 'TTWO','NOW', 'SHV', 'GLD', 'SNOW')
GROUP BY 
	ticker;

-- Look at lowest risk-adj returns, top 5
SELECT *
FROM security_masterlist
WHERE ticker in ('THCX', 'YOLO', 'CNBS', 'UPAR', 'MUB')
GROUP BY  ticker;

-- Look at highest risk-adj returns, top 5
SELECT *
FROM 
	security_masterlist
WHERE 
	ticker in ('MPC', 'DBMF', 'KMLM', 'VLO', 'GSG')
GROUP BY  
	ticker;

------------------------------------------------------------------------------------
-- Look at market value DESC
SELECT 
	c.ticker, 
    s.major_asset_class, 
    avg_value*s.quantity AS market_value
FROM 
	CG_portfolio_weights c, 
    security_masterlist s
GROUP BY 
	c.ticker
ORDER BY 
	market_value DESC
LIMIT 
	10;

-- creating a view with returns for all assets based on prices
CREATE VIEW all_tickers_cg AS
SELECT 
	y.ticker, 
    y.date, (y.p1-y.p0)/y.p0 as discrete_returns
FROM
(
SELECT 
	p.ticker, 
    p.date, 
	p.value as p1, LAG(p.value,1) OVER (PARTITION BY p.ticker
                                                    ORDER BY p.date) as p0
FROM 
	customer_details c 
INNER JOIN 
	account_dim a ON c.customer_id = a.client_id
INNER JOIN 
	holdings_current h ON a.account_id = h.account_id
INNER JOIN 
	security_masterlist s ON h.ticker = s.ticker
INNER JOIN 
	pricing_daily_new p ON s.ticker = p.ticker
WHERE 
	p.price_type = 'adjusted' 
    AND p.date > '2021-09-01'
	) y;
;

-- calculating average return and st dev of all tickers
SELECT 
	a.ticker, 
    AVG(discrete_returns) AS mu, 
    STD(discrete_returns) as sigma,
	AVG(discrete_returns)/STD(discrete_returns) as risk_adj_returns12
FROM 
	all_tickers_cg a
GROUP BY 
	a.ticker
ORDER BY 
	risk_adj_returns12 DESC;

-- calculating average return and st dev for 12M portfolio
SELECT 
	AVG(g.12port_return) AS mu, 
    STD(g.12port_return) as sigma12,
	AVG(g.12port_return)/STD(g.12port_return) as risk_adj_returns12
FROM 
	CG_portfolio_weights c, CG_12Mpret g;