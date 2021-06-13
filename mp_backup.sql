--
-- PostgreSQL database dump
--

-- Dumped from database version 13.1
-- Dumped by pg_dump version 13.3

-- Started on 2021-06-13 11:41:28

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 16406)
-- Name: catalogue; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA catalogue;


ALTER SCHEMA catalogue OWNER TO postgres;

--
-- TOC entry 3523 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA catalogue; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA catalogue IS 'Catalogs, lists, ...';


--
-- TOC entry 2 (class 3079 OID 126850)
-- Name: pageinspect; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pageinspect WITH SCHEMA public;


--
-- TOC entry 3524 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pageinspect; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pageinspect IS 'inspect the contents of database pages at a low level';


--
-- TOC entry 888 (class 1247 OID 135820)
-- Name: pay_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.pay_type AS ENUM (
    'VISA',
    'MasterCard',
    'PayPal',
    'WebMoney',
    'Qiwi',
    'GooglePay'
);


ALTER TYPE public.pay_type OWNER TO postgres;

--
-- TOC entry 906 (class 1247 OID 135733)
-- Name: status_in_cart; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.status_in_cart AS ENUM (
    'waiting for ordering',
    'ordered',
    'delivering',
    'delivered',
    'accepted',
    'comment'
);


ALTER TYPE public.status_in_cart OWNER TO postgres;

--
-- TOC entry 3525 (class 0 OID 0)
-- Dependencies: 906
-- Name: TYPE status_in_cart; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TYPE public.status_in_cart IS 'status of good in the busket of customer ';


--
-- TOC entry 278 (class 1255 OID 126729)
-- Name: check_purchase(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_purchase(id_purch integer) RETURNS integer
    LANGUAGE sql
    AS $$  
 SELECT accepted FROM purchase_bills
 where id = id_purch; 
;
$$;


ALTER FUNCTION public.check_purchase(id_purch integer) OWNER TO postgres;

--
-- TOC entry 279 (class 1255 OID 126757)
-- Name: check_sale(integer, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_sale(id_check integer, date_check timestamp without time zone) RETURNS integer
    LANGUAGE sql
    AS $$  
 SELECT written_off FROM sale_checks
 where id = id_check and saledate = date_check; 
;
$$;


ALTER FUNCTION public.check_sale(id_check integer, date_check timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 308 (class 1255 OID 126730)
-- Name: goods_arrival(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.goods_arrival(id_stock integer, id_purch integer)
    LANGUAGE plpgsql
    AS $$
declare r record; it decimal;
begin
-- оприходована ли накладная?
IF check_purchase(id_purch)<>0
THEN raise notice 'str = %', 'Отказ: накладная '||id_purch||' уже оприходована';
     RETURN; -- =exit from procedure
END IF;
-- insert/update availability:
FOR r IN select g1,g2,g3,g4,g5,g6,g7,g8 from purchases_goods(id_stock,id_purch)
LOOP
	CASE 
	       WHEN r.g6 IS NULL THEN
		              EXECUTE 'insert into availability values
		              ('|| '''' || id_stock || '''' ||','|| '''' || r.g1 || '''' ||','
	                	|| '''' || CAST(r.g3 as text) || '''' ||','|| '''' || r.g4 || '''' ||')';
						----
					   EXECUTE 'update goods set purchase_price = '|| '''' || r.g2 || '''' ||'
                       where id = '|| '''' || r.g1 || '''' ||'';	
		   ELSE 	
	                  EXECUTE 'update availability set amount = amount+'|| '''' || r.g4 || '''' ||'
                      where id_stockroom = '|| '''' || id_stock || '''' ||'
                      and id_good= '|| '''' || r.g1 || '''' ||'';
					  it:=ROUND((r.g2*r.g4+r.g7*r.g8)/(r.g4+r.g7),2);
					  EXECUTE 'update goods set purchase_price = '|| '''' || it || '''' ||'
                      where id = '|| '''' || r.g1 || '''' ||'';
	END CASE;	
			
END LOOP;
--------Update purchase_bills.accepted:= id_stock:
EXECUTE 'update purchase_bills set accepted = '|| '''' || id_stock || '''' ||'
where id = '|| '''' || id_purch || '''' ||'';
                     

end
$$;


ALTER PROCEDURE public.goods_arrival(id_stock integer, id_purch integer) OWNER TO postgres;

--
-- TOC entry 275 (class 1255 OID 126713)
-- Name: goods_for_insert(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.goods_for_insert(id_stock integer, id_purch integer, OUT g1 integer, OUT g2 numeric, OUT g3 character varying[], OUT g4 integer) RETURNS SETOF record
    LANGUAGE sql
    AS $$
--выборка товаров из приходной накладной, отсутствующих на складе:
WITH newp AS (
         SELECT purchases.id_good,
	     purchases.purchase_price, purchases.size_amount, purchases.amount
           FROM purchases
           LEFT JOIN purchase_bills USING (id)
           WHERE purchase_bills.accepted =0 and purchase_bills.id=id_purch),
        a1 AS (
         SELECT purchases.id_good,
         purchases.purchase_price, purchases.size_amount, purchases.amount
          FROM purchases
	      LEFT JOIN availability USING (id_good)		
          WHERE availability.id_stockroom = id_stock)
 SELECT newp.id_good, newp.purchase_price, newp.size_amount, newp.amount  as goo FROM newp
 EXCEPT
 SELECT a1.id_good, a1.purchase_price,a1.size_amount, a1.amount  as goo FROM a1; 
;
$$;


ALTER FUNCTION public.goods_for_insert(id_stock integer, id_purch integer, OUT g1 integer, OUT g2 numeric, OUT g3 character varying[], OUT g4 integer) OWNER TO postgres;

--
-- TOC entry 274 (class 1255 OID 126722)
-- Name: goods_for_update(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.goods_for_update(id_stock integer, id_purch integer, OUT g1 integer, OUT g2 numeric, OUT g3 character varying[], OUT g4 integer) RETURNS SETOF record
    LANGUAGE sql
    AS $$  --выборка товаров из приходной накладной, уже имеющихся на складе:
  WITH newp AS (
         SELECT purchases.id_good,
	     purchases.purchase_price, purchases.size_amount, purchases.amount
           FROM purchases
           LEFT JOIN purchase_bills USING (id)
           WHERE purchase_bills.accepted =0 and purchase_bills.id=id_purch),
        a1 AS (
         SELECT purchases.id_good,
         purchases.purchase_price, purchases.size_amount, purchases.amount
          FROM purchases
	      LEFT JOIN availability USING (id_good)		
          WHERE availability.id_stockroom = id_stock)
 SELECT newp.id_good, newp.purchase_price, newp.size_amount, newp.amount  as goo FROM newp
 INTERSECT
 SELECT a1.id_good, a1.purchase_price,a1.size_amount, a1.amount  as goo FROM a1; 
;
$$;


ALTER FUNCTION public.goods_for_update(id_stock integer, id_purch integer, OUT g1 integer, OUT g2 numeric, OUT g3 character varying[], OUT g4 integer) OWNER TO postgres;

--
-- TOC entry 309 (class 1255 OID 135731)
-- Name: goods_ordering(integer, integer, integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.goods_ordering(id_stock integer, id_cust integer, id_addr integer, id_del integer, id_pay integer)
    LANGUAGE plpgsql
    AS $$
DECLARE r record; ra record; currid bigint; sdate timestamp without time zone;
begin
------- создание чека на отпуск:
EXECUTE 'INSERT into sale_checks(id_customer,id_delivery,id_paymethod,
		 saledate,id_address,id_stockroom,status)
         values ('|| '''' || id_cust || '''' ||','||
		           '''' || id_del || '''' ||','|| 
				   '''' || id_pay || '''' ||','|| 
				  'now(),'||
				   '''' || id_addr || '''' ||','|| 
				   '''' || id_stock || '''' ||',1)';
------- эти значения нужны ниже для вставки в sales:				   
currid = (select currval(pg_get_serial_sequence('sale_checks','id')));
sdate = (select saledate from sale_checks where id=currid);	
-- резервирование на  указанном складе:
FOR r IN SELECT id_good, amount, saleprice, size_amount
FROM buskets where id_customer = id_cust AND status = 1
	LOOP
-------- Проверка наличия достаточного кол-ва на складе:
FOR ra IN SELECT amount from availability 
		where id_stockroom=id_stock and id_good=r.id_good
		LOOP
		  IF ra.amount<r.amount
		  THEN raise notice 'str = %', 'Отказ: Товара '||r.id_good||' недостаточно. 
		  Имеется только '||ra.amount||'.';
		  ROLLBACK;-- 
          RETURN; -- =exit from procedure
		  END IF;
		END LOOP;
-------- Проверка наличия этого товара на складе:
FOR ra IN SELECT count(*) av from availability 
		where id_stockroom=id_stock and id_good=r.id_good
		LOOP
		  IF ra.av<=0
		  THEN raise notice 'str = %', 'Отказ: Товара '||r.id_good||' нет на складе '
		  ||''''||id_stock||'''';
		  ROLLBACK;-- 
          RETURN; -- =exit from procedure
		  END IF;
		END LOOP;
-------- Списание:
EXECUTE 'UPDATE availability SET amount=amount-'|| '''' || r.amount || '''' ||
        ', reserved=reserved+'|| '''' || r.amount || '''' ||
		'where id_good ='|| '''' ||r.id_good|| '''' ||
		'AND id_stockroom ='||''''||id_stock||'''';
--------- и создание списка товаров на отпуск:
EXECUTE 'INSERT into sales values(
                 '|| '' || currid || '' ||','||
		           '''' || sdate || '''' ||','|| 
				   '''' || r.id_good || '''' ||','|| 
				   '''' || r.saleprice || '''' ||','|| 
				   '''' || r.amount || '''' ||',null)';		
	END LOOP;
-----смена статуса в корзине на "зарезервировано":
EXECUTE 'UPDATE buskets set status = 2
         where status=1 and id_customer='||''''||id_cust||'''';	
----------здесь надо проверить оплату,
----------если она не поступила, выйти из процедуры с сообщением и rollback.
RAISE NOTICE 'Ваш заказ оплачен и готов к отправке';
end
$$;


ALTER PROCEDURE public.goods_ordering(id_stock integer, id_cust integer, id_addr integer, id_del integer, id_pay integer) OWNER TO postgres;

--
-- TOC entry 277 (class 1255 OID 126758)
-- Name: goods_reservation(integer, integer, timestamp without time zone); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.goods_reservation(id_stock integer, id_check integer, date_check timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
DECLARE r record; ra record;
begin
-- может накладную уже зарегистрировали?
IF check_sale(id_check,date_check)<>0 
     THEN raise notice 'str = %', 'Отказ: накладная '||id_check||' уже зарегистрирована';
     RETURN; -- =exit from procedure
END IF;
-- резервирование на  указанном складе:
FOR r IN SELECT id_good, amount FROM sales where id = id_check and saledate = date_check
	LOOP
-------- Проверка наличия достаточного кол-ва на складе:
FOR ra IN SELECT amount from availability 
		where id_stockroom=id_stock and id_good=r.id_good
		LOOP
		  IF ra.amount<r.amount
		  THEN raise notice 'str = %', 'Отказ: Товара '||r.id_good||' недостаточно. 
		  Имеется только '||ra.amount||'.';
          RETURN; -- =exit from procedure
		  END IF;
		END LOOP;
-------- Проверка наличия этого товара на складе:
FOR ra IN SELECT count(*) av from availability 
		where id_stockroom=id_stock and id_good=r.id_good
		LOOP
		  IF ra.av<=0
		  THEN raise notice 'str = %', 'Отказ: Товара '||r.id_good||' нет на складе '
		  ||''''||id_stock||'''';
          RETURN; -- =exit from procedure
		  END IF;
		END LOOP;
-------- Списание:
EXECUTE 'UPDATE availability SET amount=amount-'|| '''' || r.amount || '''' ||
        ', rezerved=rezerved+'|| '''' || r.amount || '''' ||
		'where availability.id_good ='|| '''' ||r.id_good|| '''' ||
		'AND availability.id_stockroom ='||''''||id_stock||'''';
	END LOOP;
------- маркер регистрации:
EXECUTE 'UPDATE sale_checks SET id_stockroom='|| '''' || id_stock || '''' ||
        ', status = 1
		where id ='|| '''' ||id_check|| '''' ||
		'AND saledate ='||''''||date_check||'''';
end
$$;


ALTER PROCEDURE public.goods_reservation(id_stock integer, id_check integer, date_check timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 276 (class 1255 OID 126725)
-- Name: purchases_goods(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.purchases_goods(id_stock integer, id_purch integer, OUT g1 integer, OUT g2 numeric, OUT g3 character varying[], OUT g4 integer, OUT g5 character varying[], OUT g6 integer, OUT g7 integer, OUT g8 numeric) RETURNS SETOF record
    LANGUAGE sql
    AS $$  --выборка товаров из приходной накладной:
  WITH av_on_stock AS 
      (select availability.id_good, availability.size_amount, availability.amount
       from availability where id_stockroom=id_stock)
select purchases.id_good, purchases.purchase_price, purchases.size_amount,
purchases.amount, av_on_stock.size_amount, av_on_stock.amount, SUM(av.amount),
goods.purchase_price
from purchases 
LEFT JOIN availability av USING(id_good)
LEFT JOIN av_on_stock USING(id_good)
LEFT JOIN goods ON purchases.id_good = goods.id
where purchases.id=id_purch 
GROUP BY purchases.id_good, purchases.purchase_price, purchases.size_amount,
purchases.amount, av_on_stock.size_amount, av_on_stock.amount, goods.purchase_price 
;
$$;


ALTER FUNCTION public.purchases_goods(id_stock integer, id_purch integer, OUT g1 integer, OUT g2 numeric, OUT g3 character varying[], OUT g4 integer, OUT g5 character varying[], OUT g6 integer, OUT g7 integer, OUT g8 numeric) OWNER TO postgres;

--
-- TOC entry 307 (class 1255 OID 135725)
-- Name: test(bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.test(INOUT maxid bigint)
    LANGUAGE plpgsql
    AS $$
begin
EXECUTE 'select * from sales';
IF 5>0
THEN 
    maxid = (select currval(pg_get_serial_sequence('sale_checks', 'id')));
     raise notice 'str = %', maxid;
     RETURN; -- =exit from procedure
END IF;
end
$$;


ALTER PROCEDURE public.test(INOUT maxid bigint) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 211 (class 1259 OID 16554)
-- Name: categories; Type: TABLE; Schema: catalogue; Owner: postgres
--

CREATE TABLE catalogue.categories (
    id smallint NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE catalogue.categories OWNER TO postgres;

--
-- TOC entry 3526 (class 0 OID 0)
-- Dependencies: 211
-- Name: TABLE categories; Type: COMMENT; Schema: catalogue; Owner: postgres
--

COMMENT ON TABLE catalogue.categories IS 'Categories of goods';


--
-- TOC entry 210 (class 1259 OID 16552)
-- Name: Categories_ID_seq; Type: SEQUENCE; Schema: catalogue; Owner: postgres
--

CREATE SEQUENCE catalogue."Categories_ID_seq"
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE catalogue."Categories_ID_seq" OWNER TO postgres;

--
-- TOC entry 3528 (class 0 OID 0)
-- Dependencies: 210
-- Name: Categories_ID_seq; Type: SEQUENCE OWNED BY; Schema: catalogue; Owner: postgres
--

ALTER SEQUENCE catalogue."Categories_ID_seq" OWNED BY catalogue.categories.id;


--
-- TOC entry 203 (class 1259 OID 16410)
-- Name: countries; Type: TABLE; Schema: catalogue; Owner: postgres
--

CREATE TABLE catalogue.countries (
    id smallint NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE catalogue.countries OWNER TO postgres;

--
-- TOC entry 3529 (class 0 OID 0)
-- Dependencies: 203
-- Name: TABLE countries; Type: COMMENT; Schema: catalogue; Owner: postgres
--

COMMENT ON TABLE catalogue.countries IS 'The list of countries';


--
-- TOC entry 3530 (class 0 OID 0)
-- Dependencies: 203
-- Name: COLUMN countries.name; Type: COMMENT; Schema: catalogue; Owner: postgres
--

COMMENT ON COLUMN catalogue.countries.name IS 'Name of country';


--
-- TOC entry 202 (class 1259 OID 16408)
-- Name: Countries_ID_Country_seq; Type: SEQUENCE; Schema: catalogue; Owner: postgres
--

CREATE SEQUENCE catalogue."Countries_ID_Country_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE catalogue."Countries_ID_Country_seq" OWNER TO postgres;

--
-- TOC entry 3532 (class 0 OID 0)
-- Dependencies: 202
-- Name: Countries_ID_Country_seq; Type: SEQUENCE OWNED BY; Schema: catalogue; Owner: postgres
--

ALTER SEQUENCE catalogue."Countries_ID_Country_seq" OWNED BY catalogue.countries.id;


--
-- TOC entry 213 (class 1259 OID 16573)
-- Name: customers; Type: TABLE; Schema: catalogue; Owner: postgres
--

CREATE TABLE catalogue.customers (
    id integer NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    email character varying NOT NULL,
    discount smallint,
    id_address bigint[],
    birthday date,
    joindate date NOT NULL
);


ALTER TABLE catalogue.customers OWNER TO postgres;

--
-- TOC entry 212 (class 1259 OID 16571)
-- Name: Customers_ID_seq; Type: SEQUENCE; Schema: catalogue; Owner: postgres
--

CREATE SEQUENCE catalogue."Customers_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE catalogue."Customers_ID_seq" OWNER TO postgres;

--
-- TOC entry 3534 (class 0 OID 0)
-- Dependencies: 212
-- Name: Customers_ID_seq; Type: SEQUENCE OWNED BY; Schema: catalogue; Owner: postgres
--

ALTER SEQUENCE catalogue."Customers_ID_seq" OWNED BY catalogue.customers.id;


--
-- TOC entry 215 (class 1259 OID 16586)
-- Name: deliveries; Type: TABLE; Schema: catalogue; Owner: postgres
--

CREATE TABLE catalogue.deliveries (
    id smallint NOT NULL,
    name character varying NOT NULL,
    rate numeric,
    id_region smallint NOT NULL
);


ALTER TABLE catalogue.deliveries OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 16584)
-- Name: Deliveries_ID_seq; Type: SEQUENCE; Schema: catalogue; Owner: postgres
--

CREATE SEQUENCE catalogue."Deliveries_ID_seq"
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE catalogue."Deliveries_ID_seq" OWNER TO postgres;

--
-- TOC entry 3536 (class 0 OID 0)
-- Dependencies: 214
-- Name: Deliveries_ID_seq; Type: SEQUENCE OWNED BY; Schema: catalogue; Owner: postgres
--

ALTER SEQUENCE catalogue."Deliveries_ID_seq" OWNED BY catalogue.deliveries.id;


SET default_tablespace = "SpaceForSupplies";

--
-- TOC entry 205 (class 1259 OID 16418)
-- Name: suppliers; Type: TABLE; Schema: catalogue; Owner: postgres; Tablespace: SpaceForSupplies
--

CREATE TABLE catalogue.suppliers (
    id integer NOT NULL,
    name character varying NOT NULL,
    id_country smallint NOT NULL,
    phone numeric(11,0)
);


ALTER TABLE catalogue.suppliers OWNER TO postgres;

--
-- TOC entry 3537 (class 0 OID 0)
-- Dependencies: 205
-- Name: TABLE suppliers; Type: COMMENT; Schema: catalogue; Owner: postgres
--

COMMENT ON TABLE catalogue.suppliers IS 'The list of Suppliers';


--
-- TOC entry 204 (class 1259 OID 16416)
-- Name: Suppliers_ID_seq; Type: SEQUENCE; Schema: catalogue; Owner: postgres
--

CREATE SEQUENCE catalogue."Suppliers_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE catalogue."Suppliers_ID_seq" OWNER TO postgres;

--
-- TOC entry 3539 (class 0 OID 0)
-- Dependencies: 204
-- Name: Suppliers_ID_seq; Type: SEQUENCE OWNED BY; Schema: catalogue; Owner: postgres
--

ALTER SEQUENCE catalogue."Suppliers_ID_seq" OWNED BY catalogue.suppliers.id;


SET default_tablespace = '';

--
-- TOC entry 249 (class 1259 OID 18127)
-- Name: addresses; Type: TABLE; Schema: catalogue; Owner: postgres
--

CREATE TABLE catalogue.addresses (
    id bigint NOT NULL,
    address jsonb NOT NULL,
    id_region smallint NOT NULL
);


ALTER TABLE catalogue.addresses OWNER TO postgres;

--
-- TOC entry 3540 (class 0 OID 0)
-- Dependencies: 249
-- Name: TABLE addresses; Type: COMMENT; Schema: catalogue; Owner: postgres
--

COMMENT ON TABLE catalogue.addresses IS 'the list of addresses';


--
-- TOC entry 207 (class 1259 OID 16429)
-- Name: brands; Type: TABLE; Schema: catalogue; Owner: postgres
--

CREATE TABLE catalogue.brands (
    id integer NOT NULL,
    name character varying NOT NULL,
    id_country smallint NOT NULL
);


ALTER TABLE catalogue.brands OWNER TO postgres;

--
-- TOC entry 3541 (class 0 OID 0)
-- Dependencies: 207
-- Name: TABLE brands; Type: COMMENT; Schema: catalogue; Owner: postgres
--

COMMENT ON TABLE catalogue.brands IS 'The list of Brends';


--
-- TOC entry 206 (class 1259 OID 16427)
-- Name: brends_id_seq; Type: SEQUENCE; Schema: catalogue; Owner: postgres
--

CREATE SEQUENCE catalogue.brends_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE catalogue.brends_id_seq OWNER TO postgres;

--
-- TOC entry 3543 (class 0 OID 0)
-- Dependencies: 206
-- Name: brends_id_seq; Type: SEQUENCE OWNED BY; Schema: catalogue; Owner: postgres
--

ALTER SEQUENCE catalogue.brends_id_seq OWNED BY catalogue.brands.id;


--
-- TOC entry 250 (class 1259 OID 18149)
-- Name: regions; Type: TABLE; Schema: catalogue; Owner: postgres
--

CREATE TABLE catalogue.regions (
    id integer NOT NULL,
    id_country smallint NOT NULL,
    region character varying NOT NULL
);


ALTER TABLE catalogue.regions OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 16675)
-- Name: staffs; Type: TABLE; Schema: catalogue; Owner: postgres
--

CREATE TABLE catalogue.staffs (
    "ID" smallint NOT NULL,
    "FirstName" character varying NOT NULL,
    "LastName" character varying NOT NULL,
    "Position" character varying NOT NULL
);


ALTER TABLE catalogue.staffs OWNER TO postgres;

--
-- TOC entry 3544 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE staffs; Type: COMMENT; Schema: catalogue; Owner: postgres
--

COMMENT ON TABLE catalogue.staffs IS 'The list of staffs';


--
-- TOC entry 219 (class 1259 OID 16981)
-- Name: stockrooms; Type: TABLE; Schema: catalogue; Owner: postgres
--

CREATE TABLE catalogue.stockrooms (
    id smallint NOT NULL,
    id_region smallint NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE catalogue.stockrooms OWNER TO postgres;

SET default_tablespace = "SpaceForSupplies";

--
-- TOC entry 208 (class 1259 OID 16458)
-- Name: purchase_bills; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSupplies
--

CREATE TABLE public.purchase_bills (
    id integer NOT NULL,
    id_supplier integer NOT NULL,
    date date NOT NULL,
    "NumberFromSupplier" character varying NOT NULL,
    "DateFromSupplier" date NOT NULL,
    accepted integer NOT NULL
);


ALTER TABLE public.purchase_bills OWNER TO postgres;

--
-- TOC entry 3547 (class 0 OID 0)
-- Dependencies: 208
-- Name: TABLE purchase_bills; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.purchase_bills IS 'Bills from Suppliers';


--
-- TOC entry 209 (class 1259 OID 16461)
-- Name: Bills_ID_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Bills_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."Bills_ID_seq" OWNER TO postgres;

--
-- TOC entry 3549 (class 0 OID 0)
-- Dependencies: 209
-- Name: Bills_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Bills_ID_seq" OWNED BY public.purchase_bills.id;


SET default_tablespace = '';

--
-- TOC entry 217 (class 1259 OID 16611)
-- Name: goods; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goods (
    id integer NOT NULL,
    name character varying NOT NULL,
    id_category smallint NOT NULL,
    id_brand integer NOT NULL,
    discription text,
    purchase_price numeric NOT NULL,
    sale_price numeric NOT NULL,
    discount smallint,
    attributes jsonb NOT NULL
);


ALTER TABLE public.goods OWNER TO postgres;

--
-- TOC entry 3550 (class 0 OID 0)
-- Dependencies: 217
-- Name: TABLE goods; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.goods IS 'The list of goods of the FirstStore';


--
-- TOC entry 216 (class 1259 OID 16609)
-- Name: Goods_ID_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Goods_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."Goods_ID_seq" OWNER TO postgres;

--
-- TOC entry 3552 (class 0 OID 0)
-- Dependencies: 216
-- Name: Goods_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Goods_ID_seq" OWNED BY public.goods.id;


SET default_tablespace = "SpaceForSales";

--
-- TOC entry 221 (class 1259 OID 17081)
-- Name: sale_checks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_checks (
    id bigint NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
)
PARTITION BY RANGE (date_part('month'::text, saledate));


ALTER TABLE public.sale_checks OWNER TO postgres;

--
-- TOC entry 3553 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE sale_checks; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.sale_checks IS 'Sales Checks';


--
-- TOC entry 220 (class 1259 OID 17079)
-- Name: SaleChecks_ID_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."SaleChecks_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."SaleChecks_ID_seq" OWNER TO postgres;

--
-- TOC entry 3555 (class 0 OID 0)
-- Dependencies: 220
-- Name: SaleChecks_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."SaleChecks_ID_seq" OWNED BY public.sale_checks.id;


SET default_tablespace = '';

--
-- TOC entry 248 (class 1259 OID 17675)
-- Name: availability; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.availability (
    id_stockroom smallint NOT NULL,
    id_good integer NOT NULL,
    size_amount character varying[],
    amount numeric NOT NULL,
    reserved numeric,
    reserved_size_amount character varying[]
);


ALTER TABLE public.availability OWNER TO postgres;

--
-- TOC entry 3556 (class 0 OID 0)
-- Dependencies: 248
-- Name: TABLE availability; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.availability IS 'amount - общее кол-во товара
size_amount - расшифровка';


--
-- TOC entry 253 (class 1259 OID 135686)
-- Name: buskets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buskets (
    id_customer integer NOT NULL,
    id_good integer NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    status smallint NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    global_status public.status_in_cart,
    CONSTRAINT "AmountMustBePositive" CHECK ((amount > (0)::numeric))
);


ALTER TABLE public.buskets OWNER TO postgres;

SET default_tablespace = "SpaceForSales";

--
-- TOC entry 256 (class 1259 OID 135851)
-- Name: carts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.carts (
    id_customer integer NOT NULL,
    id_good integer NOT NULL,
    id_check bigint NOT NULL,
    price numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    status public.status_in_cart NOT NULL
)
PARTITION BY RANGE (id_customer);


ALTER TABLE public.carts OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 135856)
-- Name: cart01; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.cart01 (
    id_customer integer NOT NULL,
    id_good integer NOT NULL,
    id_check bigint NOT NULL,
    price numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    status public.status_in_cart NOT NULL
);
ALTER TABLE ONLY public.carts ATTACH PARTITION public.cart01 FOR VALUES FROM (1) TO (10000);


ALTER TABLE public.cart01 OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 135864)
-- Name: cart02; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.cart02 (
    id_customer integer NOT NULL,
    id_good integer NOT NULL,
    id_check bigint NOT NULL,
    price numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    status public.status_in_cart NOT NULL
);
ALTER TABLE ONLY public.carts ATTACH PARTITION public.cart02 FOR VALUES FROM (10001) TO (20000);


ALTER TABLE public.cart02 OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 135872)
-- Name: cart03; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.cart03 (
    id_customer integer NOT NULL,
    id_good integer NOT NULL,
    id_check bigint NOT NULL,
    price numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    status public.status_in_cart NOT NULL
);
ALTER TABLE ONLY public.carts ATTACH PARTITION public.cart03 FOR VALUES FROM (20001) TO (30000);


ALTER TABLE public.cart03 OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 135835)
-- Name: cust_checks01; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.cust_checks01 (
    id bigint NOT NULL,
    date time with time zone NOT NULL,
    id_delivery smallint NOT NULL,
    id_paytype public.pay_type NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint NOT NULL
);


ALTER TABLE public.cust_checks01 OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 135833)
-- Name: cust_checks01_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cust_checks01_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cust_checks01_id_seq OWNER TO postgres;

--
-- TOC entry 3557 (class 0 OID 0)
-- Dependencies: 254
-- Name: cust_checks01_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cust_checks01_id_seq OWNED BY public.cust_checks01.id;


--
-- TOC entry 260 (class 1259 OID 135890)
-- Name: cust_checks02; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.cust_checks02 (
)
INHERITS (public.cust_checks01);


ALTER TABLE public.cust_checks02 OWNER TO postgres;

--
-- TOC entry 261 (class 1259 OID 135901)
-- Name: cust_checks03; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.cust_checks03 (
)
INHERITS (public.cust_checks01);


ALTER TABLE public.cust_checks03 OWNER TO postgres;

SET default_tablespace = '';

--
-- TOC entry 262 (class 1259 OID 135912)
-- Name: goods_ratings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goods_ratings (
    id_good integer NOT NULL,
    id_customer integer NOT NULL,
    date date NOT NULL,
    comment text,
    rating smallint NOT NULL
);


ALTER TABLE public.goods_ratings OWNER TO postgres;

--
-- TOC entry 3558 (class 0 OID 0)
-- Dependencies: 262
-- Name: TABLE goods_ratings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.goods_ratings IS 'comments&ratings about goods from customers (if they did it)';


--
-- TOC entry 252 (class 1259 OID 126893)
-- Name: mine; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mine (
    info jsonb
);


ALTER TABLE public.mine OWNER TO postgres;

--
-- TOC entry 3559 (class 0 OID 0)
-- Dependencies: 252
-- Name: TABLE mine; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.mine IS 'the mine for information';


SET default_tablespace = "SpaceForSupplies";

--
-- TOC entry 247 (class 1259 OID 17647)
-- Name: purchases; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSupplies
--

CREATE TABLE public.purchases (
    id integer NOT NULL,
    id_good integer NOT NULL,
    purchase_price numeric(15,2) NOT NULL,
    size_amount character varying[],
    amount numeric NOT NULL,
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((purchase_price >= (0)::numeric))
);


ALTER TABLE public.purchases OWNER TO postgres;

--
-- TOC entry 3560 (class 0 OID 0)
-- Dependencies: 247
-- Name: TABLE purchases; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.purchases IS 'Поставки (тело счетов)
amount - общее кол-во товара
size_amount - расшифровка';


SET default_tablespace = "SpaceForSales";

--
-- TOC entry 222 (class 1259 OID 17085)
-- Name: sale_check01; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check01 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check01 FOR VALUES FROM ('1') TO ('2');


ALTER TABLE public.sale_check01 OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 17089)
-- Name: sale_check02; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check02 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check02 FOR VALUES FROM ('2') TO ('3');


ALTER TABLE public.sale_check02 OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 17093)
-- Name: sale_check03; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check03 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check03 FOR VALUES FROM ('3') TO ('4');


ALTER TABLE public.sale_check03 OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 17097)
-- Name: sale_check04; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check04 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check04 FOR VALUES FROM ('4') TO ('5');


ALTER TABLE public.sale_check04 OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 17101)
-- Name: sale_check05; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check05 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check05 FOR VALUES FROM ('5') TO ('6');


ALTER TABLE public.sale_check05 OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 17105)
-- Name: sale_check06; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check06 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check06 FOR VALUES FROM ('6') TO ('7');


ALTER TABLE public.sale_check06 OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 17109)
-- Name: sale_check07; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check07 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check07 FOR VALUES FROM ('7') TO ('8');


ALTER TABLE public.sale_check07 OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 17113)
-- Name: sale_check08; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check08 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check08 FOR VALUES FROM ('8') TO ('9');


ALTER TABLE public.sale_check08 OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 17117)
-- Name: sale_check09; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check09 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check09 FOR VALUES FROM ('9') TO ('10');


ALTER TABLE public.sale_check09 OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 17121)
-- Name: sale_check10; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check10 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check10 FOR VALUES FROM ('10') TO ('11');


ALTER TABLE public.sale_check10 OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 17125)
-- Name: sale_check11; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check11 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check11 FOR VALUES FROM ('11') TO ('12');


ALTER TABLE public.sale_check11 OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 17129)
-- Name: sale_check12; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sale_check12 (
    id bigint DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass) NOT NULL,
    id_customer integer NOT NULL,
    id_delivery smallint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_address bigint NOT NULL,
    id_stockroom smallint,
    status smallint NOT NULL,
    id_paytype public.pay_type NOT NULL
);
ALTER TABLE ONLY public.sale_checks ATTACH PARTITION public.sale_check12 FOR VALUES FROM ('12') TO ('13');


ALTER TABLE public.sale_check12 OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 17397)
-- Name: sales; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
)
PARTITION BY RANGE (date_part('month'::text, saledate));


ALTER TABLE public.sales OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 17402)
-- Name: sales01; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales01 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales01 FOR VALUES FROM ('1') TO ('2');


ALTER TABLE public.sales01 OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 17410)
-- Name: sales02; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales02 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales02 FOR VALUES FROM ('2') TO ('3');


ALTER TABLE public.sales02 OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 17418)
-- Name: sales03; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales03 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales03 FOR VALUES FROM ('3') TO ('4');


ALTER TABLE public.sales03 OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 17426)
-- Name: sales04; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales04 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales04 FOR VALUES FROM ('4') TO ('5');


ALTER TABLE public.sales04 OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 17434)
-- Name: sales05; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales05 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales05 FOR VALUES FROM ('5') TO ('6');


ALTER TABLE public.sales05 OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 17442)
-- Name: sales06; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales06 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales06 FOR VALUES FROM ('6') TO ('7');


ALTER TABLE public.sales06 OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 17450)
-- Name: sales07; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales07 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales07 FOR VALUES FROM ('7') TO ('8');


ALTER TABLE public.sales07 OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 17458)
-- Name: sales08; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales08 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales08 FOR VALUES FROM ('8') TO ('9');


ALTER TABLE public.sales08 OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 17466)
-- Name: sales09; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales09 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales09 FOR VALUES FROM ('9') TO ('10');


ALTER TABLE public.sales09 OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 17474)
-- Name: sales10; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales10 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales10 FOR VALUES FROM ('10') TO ('11');


ALTER TABLE public.sales10 OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 17482)
-- Name: sales11; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales11 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales11 FOR VALUES FROM ('11') TO ('12');


ALTER TABLE public.sales11 OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 17490)
-- Name: sales12; Type: TABLE; Schema: public; Owner: postgres; Tablespace: SpaceForSales
--

CREATE TABLE public.sales12 (
    id bigint NOT NULL,
    saledate timestamp without time zone NOT NULL,
    id_good integer NOT NULL,
    saleprice numeric(15,2) NOT NULL,
    amount numeric NOT NULL,
    size_amount character varying[],
    CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((saleprice >= (0)::numeric))
);
ALTER TABLE ONLY public.sales ATTACH PARTITION public.sales12 FOR VALUES FROM ('12') TO ('13');


ALTER TABLE public.sales12 OWNER TO postgres;

SET default_tablespace = '';

--
-- TOC entry 251 (class 1259 OID 18341)
-- Name: suppliers_price; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suppliers_price (
    id_good integer NOT NULL,
    id_supplier integer NOT NULL,
    date date NOT NULL,
    price numeric(15,2) NOT NULL,
    amount numeric NOT NULL
);


ALTER TABLE public.suppliers_price OWNER TO postgres;

--
-- TOC entry 3586 (class 0 OID 0)
-- Dependencies: 251
-- Name: TABLE suppliers_price; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.suppliers_price IS 'The prices from suppliers
';


--
-- TOC entry 3147 (class 2604 OID 16432)
-- Name: brands id; Type: DEFAULT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.brands ALTER COLUMN id SET DEFAULT nextval('catalogue.brends_id_seq'::regclass);


--
-- TOC entry 3149 (class 2604 OID 16557)
-- Name: categories id; Type: DEFAULT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.categories ALTER COLUMN id SET DEFAULT nextval('catalogue."Categories_ID_seq"'::regclass);


--
-- TOC entry 3145 (class 2604 OID 18086)
-- Name: countries id; Type: DEFAULT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.countries ALTER COLUMN id SET DEFAULT nextval('catalogue."Countries_ID_Country_seq"'::regclass);


--
-- TOC entry 3150 (class 2604 OID 16576)
-- Name: customers id; Type: DEFAULT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.customers ALTER COLUMN id SET DEFAULT nextval('catalogue."Customers_ID_seq"'::regclass);


--
-- TOC entry 3152 (class 2604 OID 16589)
-- Name: deliveries id; Type: DEFAULT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.deliveries ALTER COLUMN id SET DEFAULT nextval('catalogue."Deliveries_ID_seq"'::regclass);


--
-- TOC entry 3146 (class 2604 OID 16421)
-- Name: suppliers id; Type: DEFAULT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.suppliers ALTER COLUMN id SET DEFAULT nextval('catalogue."Suppliers_ID_seq"'::regclass);


--
-- TOC entry 3196 (class 2604 OID 135838)
-- Name: cust_checks01 id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cust_checks01 ALTER COLUMN id SET DEFAULT nextval('public.cust_checks01_id_seq'::regclass);


--
-- TOC entry 3197 (class 2604 OID 135893)
-- Name: cust_checks02 id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cust_checks02 ALTER COLUMN id SET DEFAULT nextval('public.cust_checks01_id_seq'::regclass);


--
-- TOC entry 3198 (class 2604 OID 135904)
-- Name: cust_checks03 id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cust_checks03 ALTER COLUMN id SET DEFAULT nextval('public.cust_checks01_id_seq'::regclass);


--
-- TOC entry 3153 (class 2604 OID 16614)
-- Name: goods id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods ALTER COLUMN id SET DEFAULT nextval('public."Goods_ID_seq"'::regclass);


--
-- TOC entry 3148 (class 2604 OID 16463)
-- Name: purchase_bills id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_bills ALTER COLUMN id SET DEFAULT nextval('public."Bills_ID_seq"'::regclass);


--
-- TOC entry 3155 (class 2604 OID 17084)
-- Name: sale_checks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_checks ALTER COLUMN id SET DEFAULT nextval('public."SaleChecks_ID_seq"'::regclass);


--
-- TOC entry 3208 (class 2606 OID 16442)
-- Name: brands BrendMustBeUnique; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.brands
    ADD CONSTRAINT "BrendMustBeUnique" UNIQUE (name);


--
-- TOC entry 3210 (class 2606 OID 16440)
-- Name: brands Brends_PK; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.brands
    ADD CONSTRAINT "Brends_PK" PRIMARY KEY (id);


--
-- TOC entry 3216 (class 2606 OID 16562)
-- Name: categories Categories_PK; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.categories
    ADD CONSTRAINT "Categories_PK" PRIMARY KEY (id);


--
-- TOC entry 3200 (class 2606 OID 18088)
-- Name: countries Countries_PK; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.countries
    ADD CONSTRAINT "Countries_PK" PRIMARY KEY (id);


--
-- TOC entry 3202 (class 2606 OID 18335)
-- Name: countries CountryMustBeUnigue; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.countries
    ADD CONSTRAINT "CountryMustBeUnigue" UNIQUE (name);


--
-- TOC entry 3312 (class 2606 OID 18163)
-- Name: regions CountryRegionUnique; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.regions
    ADD CONSTRAINT "CountryRegionUnique" UNIQUE (region, id_country);


--
-- TOC entry 3221 (class 2606 OID 16581)
-- Name: customers Customers_PK; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.customers
    ADD CONSTRAINT "Customers_PK" PRIMARY KEY (id);


--
-- TOC entry 3225 (class 2606 OID 16594)
-- Name: deliveries Deliveries_PK; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.deliveries
    ADD CONSTRAINT "Deliveries_PK" PRIMARY KEY (id);


--
-- TOC entry 3151 (class 2606 OID 17369)
-- Name: customers DiscountMustBePercent; Type: CHECK CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE catalogue.customers
    ADD CONSTRAINT "DiscountMustBePercent" CHECK ((((discount)::numeric >= (0)::numeric) AND ((discount)::numeric <= (100)::numeric))) NOT VALID;


--
-- TOC entry 3223 (class 2606 OID 16583)
-- Name: customers EmailMustBeUnique; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.customers
    ADD CONSTRAINT "EmailMustBeUnique" UNIQUE (email);


--
-- TOC entry 3238 (class 2606 OID 17690)
-- Name: stockrooms NameMustBeUnique; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.stockrooms
    ADD CONSTRAINT "NameMustBeUnique" UNIQUE (name);


--
-- TOC entry 3218 (class 2606 OID 16564)
-- Name: categories NameOfCategoryMustBeUnique; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.categories
    ADD CONSTRAINT "NameOfCategoryMustBeUnique" UNIQUE (name);


--
-- TOC entry 3233 (class 2606 OID 16684)
-- Name: staffs NamePositionMastBeUnique; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.staffs
    ADD CONSTRAINT "NamePositionMastBeUnique" UNIQUE ("FirstName", "LastName", "Position");


--
-- TOC entry 3235 (class 2606 OID 16682)
-- Name: staffs Staffs_pkey; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.staffs
    ADD CONSTRAINT "Staffs_pkey" PRIMARY KEY ("ID");


--
-- TOC entry 3240 (class 2606 OID 17692)
-- Name: stockrooms Stockroom_PK; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.stockrooms
    ADD CONSTRAINT "Stockroom_PK" PRIMARY KEY (id);


--
-- TOC entry 3204 (class 2606 OID 16446)
-- Name: suppliers SupplierMustBeUnigue; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.suppliers
    ADD CONSTRAINT "SupplierMustBeUnigue" UNIQUE (name);


--
-- TOC entry 3206 (class 2606 OID 16426)
-- Name: suppliers Suppliers_pkey; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.suppliers
    ADD CONSTRAINT "Suppliers_pkey" PRIMARY KEY (id);


--
-- TOC entry 3309 (class 2606 OID 18134)
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- TOC entry 3314 (class 2606 OID 18156)
-- Name: regions regions_pkey; Type: CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.regions
    ADD CONSTRAINT regions_pkey PRIMARY KEY (id);


--
-- TOC entry 3168 (class 2606 OID 126744)
-- Name: sales AmountMustBePositiveOrZero; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.sales
    ADD CONSTRAINT "AmountMustBePositiveOrZero" CHECK ((amount >= (0)::numeric)) NOT VALID;


--
-- TOC entry 3316 (class 2606 OID 135601)
-- Name: suppliers_price GSDP_Fk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suppliers_price
    ADD CONSTRAINT "GSDP_Fk" PRIMARY KEY (id_good, id_supplier, date, price);


--
-- TOC entry 3587 (class 0 OID 0)
-- Dependencies: 3316
-- Name: CONSTRAINT "GSDP_Fk" ON suppliers_price; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON CONSTRAINT "GSDP_Fk" ON public.suppliers_price IS 'уникальный ключ по товару, поставщику, дате и цене';


--
-- TOC entry 3279 (class 2606 OID 17544)
-- Name: sales01 GoodMustBeUniqueInTheCheck1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales01
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck1" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3297 (class 2606 OID 17562)
-- Name: sales10 GoodMustBeUniqueInTheCheck10; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales10
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck10" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3299 (class 2606 OID 17564)
-- Name: sales11 GoodMustBeUniqueInTheCheck11; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales11
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck11" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3301 (class 2606 OID 17570)
-- Name: sales12 GoodMustBeUniqueInTheCheck12; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales12
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck12" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3281 (class 2606 OID 17546)
-- Name: sales02 GoodMustBeUniqueInTheCheck2; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales02
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck2" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3283 (class 2606 OID 17548)
-- Name: sales03 GoodMustBeUniqueInTheCheck3; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales03
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck3" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3285 (class 2606 OID 17550)
-- Name: sales04 GoodMustBeUniqueInTheCheck4; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales04
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck4" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3287 (class 2606 OID 17552)
-- Name: sales05 GoodMustBeUniqueInTheCheck5; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales05
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck5" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3289 (class 2606 OID 17554)
-- Name: sales06 GoodMustBeUniqueInTheCheck6; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales06
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck6" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3291 (class 2606 OID 17556)
-- Name: sales07 GoodMustBeUniqueInTheCheck7; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales07
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck7" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3293 (class 2606 OID 17558)
-- Name: sales08 GoodMustBeUniqueInTheCheck8; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales08
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck8" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3295 (class 2606 OID 17560)
-- Name: sales09 GoodMustBeUniqueInTheCheck9; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales09
    ADD CONSTRAINT "GoodMustBeUniqueInTheCheck9" UNIQUE (id, saledate, id_good);


--
-- TOC entry 3228 (class 2606 OID 16619)
-- Name: goods Goods_PK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods
    ADD CONSTRAINT "Goods_PK" PRIMARY KEY (id);


--
-- TOC entry 3212 (class 2606 OID 17639)
-- Name: purchase_bills ID_PK; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_bills
    ADD CONSTRAINT "ID_PK" PRIMARY KEY (id);


--
-- TOC entry 3270 (class 2606 OID 17392)
-- Name: sale_check10 ID_SaleCheck10_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check10
    ADD CONSTRAINT "ID_SaleCheck10_PKey" PRIMARY KEY (id);


--
-- TOC entry 3273 (class 2606 OID 17394)
-- Name: sale_check11 ID_SaleCheck11_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check11
    ADD CONSTRAINT "ID_SaleCheck11_PKey" PRIMARY KEY (id);


--
-- TOC entry 3276 (class 2606 OID 17396)
-- Name: sale_check12 ID_SaleCheck12_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check12
    ADD CONSTRAINT "ID_SaleCheck12_PKey" PRIMARY KEY (id);


--
-- TOC entry 3243 (class 2606 OID 17372)
-- Name: sale_check01 ID_SaleCheck1_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check01
    ADD CONSTRAINT "ID_SaleCheck1_PKey" PRIMARY KEY (id);


--
-- TOC entry 3246 (class 2606 OID 17376)
-- Name: sale_check02 ID_SaleCheck2_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check02
    ADD CONSTRAINT "ID_SaleCheck2_PKey" PRIMARY KEY (id);


--
-- TOC entry 3249 (class 2606 OID 17378)
-- Name: sale_check03 ID_SaleCheck3_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check03
    ADD CONSTRAINT "ID_SaleCheck3_PKey" PRIMARY KEY (id);


--
-- TOC entry 3252 (class 2606 OID 17380)
-- Name: sale_check04 ID_SaleCheck4_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check04
    ADD CONSTRAINT "ID_SaleCheck4_PKey" PRIMARY KEY (id);


--
-- TOC entry 3255 (class 2606 OID 17382)
-- Name: sale_check05 ID_SaleCheck5_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check05
    ADD CONSTRAINT "ID_SaleCheck5_PKey" PRIMARY KEY (id);


--
-- TOC entry 3258 (class 2606 OID 17384)
-- Name: sale_check06 ID_SaleCheck6_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check06
    ADD CONSTRAINT "ID_SaleCheck6_PKey" PRIMARY KEY (id);


--
-- TOC entry 3261 (class 2606 OID 17386)
-- Name: sale_check07 ID_SaleCheck7_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check07
    ADD CONSTRAINT "ID_SaleCheck7_PKey" PRIMARY KEY (id);


--
-- TOC entry 3264 (class 2606 OID 17388)
-- Name: sale_check08 ID_SaleCheck8_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check08
    ADD CONSTRAINT "ID_SaleCheck8_PKey" PRIMARY KEY (id);


--
-- TOC entry 3267 (class 2606 OID 17390)
-- Name: sale_check09 ID_SaleCheck9_PKey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_check09
    ADD CONSTRAINT "ID_SaleCheck9_PKey" PRIMARY KEY (id);


--
-- TOC entry 3154 (class 2606 OID 126731)
-- Name: goods PriceMustBePositiveOrZero; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.goods
    ADD CONSTRAINT "PriceMustBePositiveOrZero" CHECK ((purchase_price >= (0)::numeric)) NOT VALID;


--
-- TOC entry 3307 (class 2606 OID 135488)
-- Name: availability StockGood_Pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.availability
    ADD CONSTRAINT "StockGood_Pk" PRIMARY KEY (id_stockroom, id_good);


--
-- TOC entry 3214 (class 2606 OID 18186)
-- Name: purchase_bills SuppliersDateNumberMustBeUnique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_bills
    ADD CONSTRAINT "SuppliersDateNumberMustBeUnique" UNIQUE (id_supplier, "NumberFromSupplier", "DateFromSupplier");


--
-- TOC entry 3319 (class 2606 OID 135694)
-- Name: buskets buskets_Pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buskets
    ADD CONSTRAINT "buskets_Pk" PRIMARY KEY (id_customer, id_good);


--
-- TOC entry 3323 (class 2606 OID 135855)
-- Name: carts carts_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.carts
    ADD CONSTRAINT carts_pkey1 PRIMARY KEY (id_customer, id_good, id_check);


--
-- TOC entry 3325 (class 2606 OID 135860)
-- Name: cart01 cart01_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart01
    ADD CONSTRAINT cart01_pkey PRIMARY KEY (id_customer, id_good, id_check);


--
-- TOC entry 3327 (class 2606 OID 135868)
-- Name: cart02 cart02_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart02
    ADD CONSTRAINT cart02_pkey PRIMARY KEY (id_customer, id_good, id_check);


--
-- TOC entry 3329 (class 2606 OID 135876)
-- Name: cart03 cart03_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart03
    ADD CONSTRAINT cart03_pkey PRIMARY KEY (id_customer, id_good, id_check);


--
-- TOC entry 3230 (class 2606 OID 126724)
-- Name: goods categ_brand_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods
    ADD CONSTRAINT categ_brand_name UNIQUE (id_category, id_brand, name);


--
-- TOC entry 3321 (class 2606 OID 135840)
-- Name: cust_checks01 cust_checks01_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cust_checks01
    ADD CONSTRAINT cust_checks01_pkey PRIMARY KEY (id);


--
-- TOC entry 3331 (class 2606 OID 135895)
-- Name: cust_checks02 cust_checks02_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cust_checks02
    ADD CONSTRAINT cust_checks02_pkey PRIMARY KEY (id);


--
-- TOC entry 3333 (class 2606 OID 135906)
-- Name: cust_checks03 cust_checks03_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cust_checks03
    ADD CONSTRAINT cust_checks03_pkey PRIMARY KEY (id);


--
-- TOC entry 3335 (class 2606 OID 135919)
-- Name: goods_ratings goods_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_ratings
    ADD CONSTRAINT goods_comments_pkey PRIMARY KEY (id_good);


--
-- TOC entry 3304 (class 2606 OID 126715)
-- Name: purchases id_idgood_Pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchases
    ADD CONSTRAINT "id_idgood_Pk" PRIMARY KEY (id, id_good);


--
-- TOC entry 3236 (class 1259 OID 135423)
-- Name: ID_stock_Index; Type: INDEX; Schema: catalogue; Owner: postgres
--

CREATE INDEX "ID_stock_Index" ON catalogue.stockrooms USING btree (id);


--
-- TOC entry 3310 (class 1259 OID 18179)
-- Name: fki_regionFk; Type: INDEX; Schema: catalogue; Owner: postgres
--

CREATE INDEX "fki_regionFk" ON catalogue.addresses USING btree (id_region);


--
-- TOC entry 3219 (class 1259 OID 135452)
-- Name: id_Index; Type: INDEX; Schema: catalogue; Owner: postgres
--

CREATE INDEX "id_Index" ON catalogue.categories USING btree (id);


--
-- TOC entry 3226 (class 1259 OID 17672)
-- Name: Categ_Name_Brend_Index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Categ_Name_Brend_Index" ON public.goods USING btree (id_category, name, id_brand);


--
-- TOC entry 3305 (class 1259 OID 17703)
-- Name: Goods_Index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "Goods_Index" ON public.availability USING btree (id_good);


--
-- TOC entry 3241 (class 1259 OID 126837)
-- Name: fki_Address_Fk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "fki_Address_Fk" ON ONLY public.sale_checks USING btree (id_address);


--
-- TOC entry 3317 (class 1259 OID 126892)
-- Name: fki_Good_FK; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "fki_Good_FK" ON public.suppliers_price USING btree (id_good);


--
-- TOC entry 3302 (class 1259 OID 126721)
-- Name: fki_goodsFk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "fki_goodsFk" ON public.purchases USING btree (id_good);


--
-- TOC entry 3231 (class 1259 OID 18351)
-- Name: goods_attr_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX goods_attr_gin ON public.goods USING gin (attributes);


--
-- TOC entry 3244 (class 1259 OID 126838)
-- Name: sale_check01_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check01_id_address_idx ON public.sale_check01 USING btree (id_address);


--
-- TOC entry 3247 (class 1259 OID 126839)
-- Name: sale_check02_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check02_id_address_idx ON public.sale_check02 USING btree (id_address);


--
-- TOC entry 3250 (class 1259 OID 126840)
-- Name: sale_check03_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check03_id_address_idx ON public.sale_check03 USING btree (id_address);


--
-- TOC entry 3253 (class 1259 OID 126841)
-- Name: sale_check04_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check04_id_address_idx ON public.sale_check04 USING btree (id_address);


--
-- TOC entry 3256 (class 1259 OID 126842)
-- Name: sale_check05_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check05_id_address_idx ON public.sale_check05 USING btree (id_address);


--
-- TOC entry 3259 (class 1259 OID 126843)
-- Name: sale_check06_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check06_id_address_idx ON public.sale_check06 USING btree (id_address);


--
-- TOC entry 3262 (class 1259 OID 126844)
-- Name: sale_check07_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check07_id_address_idx ON public.sale_check07 USING btree (id_address);


--
-- TOC entry 3265 (class 1259 OID 126845)
-- Name: sale_check08_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check08_id_address_idx ON public.sale_check08 USING btree (id_address);


--
-- TOC entry 3268 (class 1259 OID 126846)
-- Name: sale_check09_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check09_id_address_idx ON public.sale_check09 USING btree (id_address);


--
-- TOC entry 3271 (class 1259 OID 126847)
-- Name: sale_check10_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check10_id_address_idx ON public.sale_check10 USING btree (id_address);


--
-- TOC entry 3274 (class 1259 OID 126848)
-- Name: sale_check11_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check11_id_address_idx ON public.sale_check11 USING btree (id_address);


--
-- TOC entry 3277 (class 1259 OID 126849)
-- Name: sale_check12_id_address_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX sale_check12_id_address_idx ON public.sale_check12 USING btree (id_address);


--
-- TOC entry 3348 (class 0 OID 0)
-- Name: cart01_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.carts_pkey1 ATTACH PARTITION public.cart01_pkey;


--
-- TOC entry 3349 (class 0 OID 0)
-- Name: cart02_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.carts_pkey1 ATTACH PARTITION public.cart02_pkey;


--
-- TOC entry 3350 (class 0 OID 0)
-- Name: cart03_pkey; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public.carts_pkey1 ATTACH PARTITION public.cart03_pkey;


--
-- TOC entry 3336 (class 0 OID 0)
-- Name: sale_check01_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check01_id_address_idx;


--
-- TOC entry 3337 (class 0 OID 0)
-- Name: sale_check02_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check02_id_address_idx;


--
-- TOC entry 3338 (class 0 OID 0)
-- Name: sale_check03_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check03_id_address_idx;


--
-- TOC entry 3339 (class 0 OID 0)
-- Name: sale_check04_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check04_id_address_idx;


--
-- TOC entry 3340 (class 0 OID 0)
-- Name: sale_check05_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check05_id_address_idx;


--
-- TOC entry 3341 (class 0 OID 0)
-- Name: sale_check06_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check06_id_address_idx;


--
-- TOC entry 3342 (class 0 OID 0)
-- Name: sale_check07_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check07_id_address_idx;


--
-- TOC entry 3343 (class 0 OID 0)
-- Name: sale_check08_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check08_id_address_idx;


--
-- TOC entry 3344 (class 0 OID 0)
-- Name: sale_check09_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check09_id_address_idx;


--
-- TOC entry 3345 (class 0 OID 0)
-- Name: sale_check10_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check10_id_address_idx;


--
-- TOC entry 3346 (class 0 OID 0)
-- Name: sale_check11_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check11_id_address_idx;


--
-- TOC entry 3347 (class 0 OID 0)
-- Name: sale_check12_id_address_idx; Type: INDEX ATTACH; Schema: public; Owner: postgres
--

ALTER INDEX public."fki_Address_Fk" ATTACH PARTITION public.sale_check12_id_address_idx;


--
-- TOC entry 3379 (class 2606 OID 18157)
-- Name: regions CountryFKey; Type: FK CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.regions
    ADD CONSTRAINT "CountryFKey" FOREIGN KEY (id_country) REFERENCES catalogue.countries(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3351 (class 2606 OID 135469)
-- Name: suppliers CountryFKey; Type: FK CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.suppliers
    ADD CONSTRAINT "CountryFKey" FOREIGN KEY (id_country) REFERENCES catalogue.countries(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3352 (class 2606 OID 18109)
-- Name: brands Country_FK; Type: FK CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.brands
    ADD CONSTRAINT "Country_FK" FOREIGN KEY (id_country) REFERENCES catalogue.countries(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3354 (class 2606 OID 135930)
-- Name: deliveries RegionFK; Type: FK CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.deliveries
    ADD CONSTRAINT "RegionFK" FOREIGN KEY (id_region) REFERENCES catalogue.regions(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3357 (class 2606 OID 135482)
-- Name: stockrooms Region_FK; Type: FK CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.stockrooms
    ADD CONSTRAINT "Region_FK" FOREIGN KEY (id) REFERENCES catalogue.regions(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3378 (class 2606 OID 18174)
-- Name: addresses regionFk; Type: FK CONSTRAINT; Schema: catalogue; Owner: postgres
--

ALTER TABLE ONLY catalogue.addresses
    ADD CONSTRAINT "regionFk" FOREIGN KEY (id_region) REFERENCES catalogue.regions(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3360 (class 2606 OID 126798)
-- Name: sale_checks Address_Fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.sale_checks
    ADD CONSTRAINT "Address_Fk" FOREIGN KEY (id_address) REFERENCES catalogue.addresses(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3355 (class 2606 OID 16650)
-- Name: goods Brend_FK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods
    ADD CONSTRAINT "Brend_FK" FOREIGN KEY (id_brand) REFERENCES catalogue.brands(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3356 (class 2606 OID 16645)
-- Name: goods Category_FK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods
    ADD CONSTRAINT "Category_FK" FOREIGN KEY (id_category) REFERENCES catalogue.categories(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3359 (class 2606 OID 17212)
-- Name: sale_checks Customer_FK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.sale_checks
    ADD CONSTRAINT "Customer_FK" FOREIGN KEY (id_customer) REFERENCES catalogue.customers(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3358 (class 2606 OID 17329)
-- Name: sale_checks Delivery_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.sale_checks
    ADD CONSTRAINT "Delivery_FKey" FOREIGN KEY (id_delivery) REFERENCES catalogue.deliveries(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3377 (class 2606 OID 17733)
-- Name: availability Good_FK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.availability
    ADD CONSTRAINT "Good_FK" FOREIGN KEY (id_good) REFERENCES public.goods(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3381 (class 2606 OID 126887)
-- Name: suppliers_price Good_FK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suppliers_price
    ADD CONSTRAINT "Good_FK" FOREIGN KEY (id_good) REFERENCES public.goods(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3382 (class 2606 OID 135695)
-- Name: buskets GoodsFk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buskets
    ADD CONSTRAINT "GoodsFk" FOREIGN KEY (id_good) REFERENCES public.goods(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3361 (class 2606 OID 17504)
-- Name: sales Goods_FK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.sales
    ADD CONSTRAINT "Goods_FK" FOREIGN KEY (id_good) REFERENCES public.goods(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3371 (class 2606 OID 17616)
-- Name: sales10 ID_Sale10_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales10
    ADD CONSTRAINT "ID_Sale10_FKey" FOREIGN KEY (id) REFERENCES public.sale_check10(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3372 (class 2606 OID 17621)
-- Name: sales11 ID_Sale11_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales11
    ADD CONSTRAINT "ID_Sale11_FKey" FOREIGN KEY (id) REFERENCES public.sale_check11(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3373 (class 2606 OID 17626)
-- Name: sales12 ID_Sale12_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales12
    ADD CONSTRAINT "ID_Sale12_FKey" FOREIGN KEY (id) REFERENCES public.sale_check12(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3362 (class 2606 OID 17571)
-- Name: sales01 ID_Sale1_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales01
    ADD CONSTRAINT "ID_Sale1_FKey" FOREIGN KEY (id) REFERENCES public.sale_check01(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3363 (class 2606 OID 17576)
-- Name: sales02 ID_Sale2_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales02
    ADD CONSTRAINT "ID_Sale2_FKey" FOREIGN KEY (id) REFERENCES public.sale_check02(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3364 (class 2606 OID 17581)
-- Name: sales03 ID_Sale3_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales03
    ADD CONSTRAINT "ID_Sale3_FKey" FOREIGN KEY (id) REFERENCES public.sale_check03(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3365 (class 2606 OID 17586)
-- Name: sales04 ID_Sale4_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales04
    ADD CONSTRAINT "ID_Sale4_FKey" FOREIGN KEY (id) REFERENCES public.sale_check04(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3366 (class 2606 OID 17591)
-- Name: sales05 ID_Sale5_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales05
    ADD CONSTRAINT "ID_Sale5_FKey" FOREIGN KEY (id) REFERENCES public.sale_check05(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3367 (class 2606 OID 17596)
-- Name: sales06 ID_Sale6_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales06
    ADD CONSTRAINT "ID_Sale6_FKey" FOREIGN KEY (id) REFERENCES public.sale_check06(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3368 (class 2606 OID 17601)
-- Name: sales07 ID_Sale7_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales07
    ADD CONSTRAINT "ID_Sale7_FKey" FOREIGN KEY (id) REFERENCES public.sale_check07(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3369 (class 2606 OID 17606)
-- Name: sales08 ID_Sale8_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales08
    ADD CONSTRAINT "ID_Sale8_FKey" FOREIGN KEY (id) REFERENCES public.sale_check08(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3370 (class 2606 OID 17611)
-- Name: sales09 ID_Sale9_FKey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales09
    ADD CONSTRAINT "ID_Sale9_FKey" FOREIGN KEY (id) REFERENCES public.sale_check09(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3375 (class 2606 OID 18137)
-- Name: purchases PurchaseBill_FK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchases
    ADD CONSTRAINT "PurchaseBill_FK" FOREIGN KEY (id) REFERENCES public.purchase_bills(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3376 (class 2606 OID 135489)
-- Name: availability Stockroom_FK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.availability
    ADD CONSTRAINT "Stockroom_FK" FOREIGN KEY (id_stockroom) REFERENCES catalogue.stockrooms(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3353 (class 2606 OID 18336)
-- Name: purchase_bills SupplierFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_bills
    ADD CONSTRAINT "SupplierFK" FOREIGN KEY (id_supplier) REFERENCES catalogue.suppliers(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3380 (class 2606 OID 126882)
-- Name: suppliers_price SupplierFK; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suppliers_price
    ADD CONSTRAINT "SupplierFK" FOREIGN KEY (id_supplier) REFERENCES catalogue.suppliers(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3383 (class 2606 OID 135881)
-- Name: cart01 check01Fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart01
    ADD CONSTRAINT "check01Fk" FOREIGN KEY (id_check) REFERENCES public.cust_checks01(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3384 (class 2606 OID 135896)
-- Name: cart02 check02Fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart02
    ADD CONSTRAINT "check02Fk" FOREIGN KEY (id_check) REFERENCES public.cust_checks02(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3385 (class 2606 OID 135907)
-- Name: cart03 check03Fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart03
    ADD CONSTRAINT "check03Fk" FOREIGN KEY (id_check) REFERENCES public.cust_checks03(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3387 (class 2606 OID 135925)
-- Name: goods_ratings customerFk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_ratings
    ADD CONSTRAINT "customerFk" FOREIGN KEY (id_customer) REFERENCES catalogue.customers(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3374 (class 2606 OID 126716)
-- Name: purchases goodsFk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchases
    ADD CONSTRAINT "goodsFk" FOREIGN KEY (id_good) REFERENCES public.goods(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3386 (class 2606 OID 135920)
-- Name: goods_ratings goodsFk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_ratings
    ADD CONSTRAINT "goodsFk" FOREIGN KEY (id_good) REFERENCES public.goods(id) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3527 (class 0 OID 0)
-- Dependencies: 211
-- Name: TABLE categories; Type: ACL; Schema: catalogue; Owner: postgres
--

GRANT SELECT ON TABLE catalogue.categories TO analysts;
GRANT ALL ON TABLE catalogue.categories TO former;


--
-- TOC entry 3531 (class 0 OID 0)
-- Dependencies: 203
-- Name: TABLE countries; Type: ACL; Schema: catalogue; Owner: postgres
--

GRANT SELECT ON TABLE catalogue.countries TO analysts;
GRANT ALL ON TABLE catalogue.countries TO former;


--
-- TOC entry 3533 (class 0 OID 0)
-- Dependencies: 213
-- Name: TABLE customers; Type: ACL; Schema: catalogue; Owner: postgres
--

GRANT SELECT ON TABLE catalogue.customers TO analysts;
GRANT ALL ON TABLE catalogue.customers TO former;


--
-- TOC entry 3535 (class 0 OID 0)
-- Dependencies: 215
-- Name: TABLE deliveries; Type: ACL; Schema: catalogue; Owner: postgres
--

GRANT SELECT ON TABLE catalogue.deliveries TO analysts;
GRANT ALL ON TABLE catalogue.deliveries TO former;


--
-- TOC entry 3538 (class 0 OID 0)
-- Dependencies: 205
-- Name: TABLE suppliers; Type: ACL; Schema: catalogue; Owner: postgres
--

GRANT SELECT ON TABLE catalogue.suppliers TO analysts;
GRANT ALL ON TABLE catalogue.suppliers TO former;


--
-- TOC entry 3542 (class 0 OID 0)
-- Dependencies: 207
-- Name: TABLE brands; Type: ACL; Schema: catalogue; Owner: postgres
--

GRANT SELECT ON TABLE catalogue.brands TO analysts;
GRANT ALL ON TABLE catalogue.brands TO former;


--
-- TOC entry 3545 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE staffs; Type: ACL; Schema: catalogue; Owner: postgres
--

GRANT SELECT ON TABLE catalogue.staffs TO analysts;
GRANT ALL ON TABLE catalogue.staffs TO former;


--
-- TOC entry 3546 (class 0 OID 0)
-- Dependencies: 219
-- Name: TABLE stockrooms; Type: ACL; Schema: catalogue; Owner: postgres
--

GRANT SELECT ON TABLE catalogue.stockrooms TO analysts;
GRANT ALL ON TABLE catalogue.stockrooms TO former;


--
-- TOC entry 3548 (class 0 OID 0)
-- Dependencies: 208
-- Name: TABLE purchase_bills; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.purchase_bills TO analysts;
GRANT ALL ON TABLE public.purchase_bills TO former;


--
-- TOC entry 3551 (class 0 OID 0)
-- Dependencies: 217
-- Name: TABLE goods; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.goods TO analysts;


--
-- TOC entry 3554 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE sale_checks; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_checks TO analysts;


--
-- TOC entry 3561 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE sale_check01; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check01 TO analysts;


--
-- TOC entry 3562 (class 0 OID 0)
-- Dependencies: 223
-- Name: TABLE sale_check02; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check02 TO analysts;


--
-- TOC entry 3563 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE sale_check03; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check03 TO analysts;


--
-- TOC entry 3564 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE sale_check04; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check04 TO analysts;


--
-- TOC entry 3565 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE sale_check05; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check05 TO analysts;


--
-- TOC entry 3566 (class 0 OID 0)
-- Dependencies: 227
-- Name: TABLE sale_check06; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check06 TO analysts;


--
-- TOC entry 3567 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE sale_check07; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check07 TO analysts;


--
-- TOC entry 3568 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE sale_check08; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check08 TO analysts;


--
-- TOC entry 3569 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE sale_check09; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check09 TO analysts;


--
-- TOC entry 3570 (class 0 OID 0)
-- Dependencies: 231
-- Name: TABLE sale_check10; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check10 TO analysts;


--
-- TOC entry 3571 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE sale_check11; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check11 TO analysts;


--
-- TOC entry 3572 (class 0 OID 0)
-- Dependencies: 233
-- Name: TABLE sale_check12; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sale_check12 TO analysts;


--
-- TOC entry 3573 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE sales; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales TO analysts;


--
-- TOC entry 3574 (class 0 OID 0)
-- Dependencies: 235
-- Name: TABLE sales01; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales01 TO analysts;


--
-- TOC entry 3575 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE sales02; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales02 TO analysts;


--
-- TOC entry 3576 (class 0 OID 0)
-- Dependencies: 237
-- Name: TABLE sales03; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales03 TO analysts;


--
-- TOC entry 3577 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE sales04; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales04 TO analysts;


--
-- TOC entry 3578 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE sales05; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales05 TO analysts;


--
-- TOC entry 3579 (class 0 OID 0)
-- Dependencies: 240
-- Name: TABLE sales06; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales06 TO analysts;


--
-- TOC entry 3580 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE sales07; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales07 TO analysts;


--
-- TOC entry 3581 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE sales08; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales08 TO analysts;


--
-- TOC entry 3582 (class 0 OID 0)
-- Dependencies: 243
-- Name: TABLE sales09; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales09 TO analysts;


--
-- TOC entry 3583 (class 0 OID 0)
-- Dependencies: 244
-- Name: TABLE sales10; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales10 TO analysts;


--
-- TOC entry 3584 (class 0 OID 0)
-- Dependencies: 245
-- Name: TABLE sales11; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales11 TO analysts;


--
-- TOC entry 3585 (class 0 OID 0)
-- Dependencies: 246
-- Name: TABLE sales12; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.sales12 TO analysts;


-- Completed on 2021-06-13 11:41:30

--
-- PostgreSQL database dump complete
--

