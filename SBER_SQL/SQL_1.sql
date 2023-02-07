WITH 

-- SBER_DEBIT - это таблица, которая хранит в себе накопительную сумму проводок по дебиту счёта 
SBER_DEBIT AS
(SELECT 
    ACCOUNT_DEBIT_ID, 
    BUSINESS_DT,
    SUM(POSTING_AMT) OVER (PARTITION BY -- Для накопительной суммы используется оконная функция SUM с группировкой по счетам и сортировкой по датам
                                ACCOUNT_DEBIT_ID 
                            ORDER BY 
                                BUSINESS_DT) AS SUM_POST
FROM 
    SBER),



-- SBER_CREDIT - это таблица, которая хранит в себе накопительную сумму проводок по кредиту счёта 
SBER_CREDIT AS
(SELECT 
    ACCOUNT_CREDIT_ID, 
    BUSINESS_DT,
    SUM(POSTING_AMT) OVER (PARTITION BY -- Для накопительной суммы используется оконная функция SUM с группировкой по счетам и сортировкой по датам
                                ACCOUNT_CREDIT_ID 
                            ORDER BY 
                                BUSINESS_DT) AS SUM_POST
FROM 
    SBER),



-- ACCOUNTS - это множество всех используемых счетов
ACCOUNTS AS
(SELECT 
    DISTINCT ACCOUNT_DEBIT_ID AS ACCOUNT_ID 
FROM 
    SBER
UNION -- Используется UNION, так как существует возможность, что счёт использовался только по дебиту или только по кредиту 
SELECT 
    DISTINCT ACCOUNT_CREDIT_ID AS ACCOUNT_ID 
FROM 
    SBER),



-- DATES - это множество уникальных дат, в которые были совершены проводки по различным счетам
DATES AS
(SELECT 
    DISTINCT BUSINESS_DT AS BUSINESS_DATE 
FROM 
    SBER)




SELECT
    ACCOUNT_ID AS "Account_ID",
    BUSINESS_DATE AS "Current_Date",
    -- Баланс счёта рассчитывается как разница между накопительными суммами проводок по кредиту и дебиту

    -- Подзапрос ищет накопительную сумму проводок по кредиту для счета ACCOUNT_ID на дату, соответствующую BUSINESS_DATE
    -- (наиболее близкую к BUSINESS_DATE, но не превосходящую её)
    -- Если на текущую дату нет никакой информации о счёте, то по умолчанию используется ноль
    NVL((SELECT 
            SUM_POST
        FROM
            SBER_CREDIT
        -- Отбор строки по номеру счёта и по непревосходящей дате
        WHERE
            BUSINESS_DT <= BUSINESS_DATE
        AND
            ACCOUNT_CREDIT_ID = ACCOUNT_ID
        -- Отбор строки с наиболее близкой к BUSINESS_DATE дате
        ORDER BY
            BUSINESS_DT DESC
        FETCH FIRST 1 ROWS ONLY), 0) 
    -   
    -- Подзапрос ищет накопительную сумму проводок по дебиту для счета ACCOUNT_ID на дату, соответствующую BUSINESS_DATE
    -- (наиболее близкую к BUSINESS_DATE, но не превосходящую её)
    -- Если на текущую дату нет никакой информации о счёте, то по умолчанию используется ноль
    NVL((SELECT
            SUM_POST
        FROM
            SBER_DEBIT
        -- Отбор строки по номеру счёта и по непревосходящей дате
        WHERE
            BUSINESS_DT <= BUSINESS_DATE
        AND
            ACCOUNT_DEBIT_ID = ACCOUNTS.ACCOUNT_ID
        -- Отбор строки с наиболее близкой к BUSINESS_DATE дате
        ORDER BY
            BUSINESS_DT DESC
        FETCH FIRST 1 ROWS ONLY), 0) AS "Account_Balance"
FROM
    ACCOUNTS, DATES
ORDER BY
    BUSINESS_DATE, ACCOUNT_ID