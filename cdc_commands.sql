ALTER TABLE transactions
    REPLICA IDENTITY FULL;
-- DEFAULT relies on primary key or unique constraints, however,
-- for the purpose of Change Data Capture, we need to use REPLICA IDENTITY FULL, to capture all changes

--{ "name": "postgres-connector", "config": { "connector.class": "io.debezium.connector.postgresql.PostgresConnector", "database.hostname": "postgres", "database.port": "5432", "database.user": "postgres", "database.password": "postgres", "database.dbname": "financial_db", "database.server.name": "postgres", "table.whitelist": "public.transactions", "database.history.kafka.bootstrap.servers": "kafka:9092", "database.history.kafka.topic": "schema-changes.financial_db" } }
-- The above configuration is for the Debezium Postgres connector,
-- which will capture changes from the transactions table in the financial_db database
-- By the nature of Debezium, decimal columns are converted into logical strings, which is not ideal for the amount column
-- to show "amount" column as string in KAFKA control centre, we need to adjust the debezium postgres connector
-- ("decimal.handling.mode": "string" in the connector configuration)

ALTER TABLE transactions
    ADD COLUMN modified_by TEXT;
-- Add a new column to the transactions table to capture the user who made the change

ALTER TABLE transactions
    ADD COLUMN modified_at TIMESTAMP;
-- Add a new column to the transactions table to capture the time when the change was made

CREATE OR REPLACE FUNCTION record_transaction_changes()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.modified_by = current_user;
    NEW.modified_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Create a new function to capture the user and time when a change is made to the transactions table

CREATE TRIGGER record_transaction_changes
    BEFORE UPDATE
    ON transactions
    FOR EACH ROW
EXECUTE FUNCTION record_transaction_changes();
-- Create a new trigger to call the function when a change is made to the transactions table


CREATE OR REPLACE FUNCTION record_transaction_changed_columns()
    RETURNS TRIGGER AS
$$
DECLARE
    change_data JSONB;
BEGIN
    change_data := '{}'::JSONB;
    IF OLD.amount IS DISTINCT FROM NEW.amount THEN
        change_data := jsonb_insert(change_data, '{amount}', jsonb_build_object('old', OLD.amount, 'new', NEW.amount));
    END IF;

    -- adding modified_by and modified_at to the change_data
    change_data := change_data || jsonb_build_object('modified_by', current_user, 'modified_at', now());

    -- adding the change_data to the NEW record
    NEW.change_data = change_data;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Create a new function to capture the changes made to the transactions table

ALTER TABLE transactions ADD COLUMN change_data JSONB;
-- Add a new column to the transactions table to capture the changes made to the table

CREATE TRIGGER record_transaction_changed_columns
    BEFORE UPDATE
    ON transactions
    FOR EACH ROW
EXECUTE FUNCTION record_transaction_changed_columns();
-- Create a new trigger to call the function when a change is made to the transactions table
