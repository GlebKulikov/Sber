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


-- DATES - это объединение множества уникальных дат и всех счетов
DATES AS
(SELECT 
    DISTINCT ACCOUNT_DEBIT_ID AS ACCOUNT_ID, BUSINESS_DT 
FROM 
    SBER_DEBIT
UNION -- Используется UNION, так как существует возможность, что счёт использовался только по дебиту или только по кредиту
SELECT 
    DISTINCT ACCOUNT_CREDIT_ID AS ACCOUNT_ID, BUSINESS_DT 
FROM 
    SBER_CREDIT)


SELECT
    DT.ACCOUNT_ID AS "Account_ID",
    DT.BUSINESS_DT AS "Business_From_DT",
    -- Business_To_DT - это дата, по которую (включительно) на счете находится указанный остаток 
    -- Подзапрос выбирает следущую дату после изменения счёта, отнимает от нее один день и при помощи отбора подставляет в нужную строку Business_To_DT
    -- Если остаток действует по текущий момент (дата следующего изменения остатка не известна), то по умолчанию в Business_To_DT вставляется дата 31-12-9999
    NVL((SELECT 
            DATES.BUSINESS_DT - NUMTODSINTERVAL(1, 'day') 
        FROM 
            DATES
        -- Отбор строки по номеру счёта и по превосходящей дате
        WHERE
            DATES.BUSINESS_DT > DT.BUSINESS_DT 
        AND 
            DATES.ACCOUNT_ID = DT.ACCOUNT_ID
        -- Отбор строки с наиболее близкой к BUSINESS_DT дате
        ORDER BY 
            BUSINESS_DT
        FETCH FIRST 1 ROWS ONLY), TO_DATE('9999-12-31','YYYY-MM-DD')) AS "Business_To_DT" ,

    -- Баланс счёта рассчитывается как разница между накопительными суммами проводок по кредиту и дебиту

    -- Подзапрос ищет накопительную сумму проводок по кредиту для счета ACCOUNT_ID на дату, соответствующую BUSINESS_DT
    -- (наиболее близкую к BUSINESS_DT, но не превосходящую её)
    -- Если на текущую дату нет никакой информации о счёте, то по умолчанию используется ноль
    NVL((SELECT
            SBER_CREDIT.SUM_POST
        FROM
            SBER_CREDIT
        -- Отбор строки по номеру счёта и по непревосходящей дате
        WHERE
            SBER_CREDIT.BUSINESS_DT <= DT.BUSINESS_DT
        AND
            SBER_CREDIT.ACCOUNT_CREDIT_ID = DT.ACCOUNT_ID
        -- Отбор строки с наиболее близкой к BUSINESS_DT дате
        ORDER BY
            SBER_CREDIT.BUSINESS_DT DESC
        FETCH FIRST 1 ROWS ONLY), 0)
    -
    -- Подзапрос ищет накопительную сумму проводок по дебиту для счета ACCOUNT_ID на дату, соответствующую BUSINESS_DT
    -- (наиболее близкую к BUSINESS_DT, но не превосходящую её)
    -- Если на текущую дату нет никакой информации о счёте, то по умолчанию используется ноль
    NVL((SELECT
            SBER_DEBIT.SUM_POST
        FROM
            SBER_DEBIT
        WHERE
        -- Отбор строки по номеру счёта и по непревосходящей дате
            SBER_DEBIT.BUSINESS_DT <= DT.BUSINESS_DT
        AND
            SBER_DEBIT.ACCOUNT_DEBIT_ID = DT.ACCOUNT_ID
        -- Отбор строки с наиболее близкой к BUSINESS_DT дате
        ORDER BY
            SBER_DEBIT.BUSINESS_DT DESC
        FETCH FIRST 1 ROWS ONLY), 0) AS "Account_Balance"
FROM
    DATES DT
ORDER BY
    BUSINESS_DT, ACCOUNT_ID
