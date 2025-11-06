### Select Qualified Foreign Key Names (SQL Server vs. Snowflake)

Source: https://docs.snowflake.com/en/migrations/snowconvert-docs/translation-references/transact/transact-system-tables

Retrieves the qualified names of foreign keys. Both examples use table aliases for clarity. SQL Server uses `sys.foreign_keys`, and Snowflake uses `INFORMATION_SCHEMA.TABLE_CONSTRAINTS`.

```sql
SELECT
    fk.name
FROM sys.foreign_keys AS fk;
```

```sql
SELECT
    fk.CONSTRAINT_NAME
FROM
    INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS fk
WHERE
    CONSTRAINT_TYPE = 'FOREIGN KEY';
```

--------------------------------

### USING Parameter Syntax and Examples

Source: https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-services

Explains the syntax and provides examples for the `USING` parameter used to pass values to specification variables.

```APIDOC
## USING Parameter for Specification Variables

### Description
Details the `USING` parameter in the `CREATE SERVICE` command for providing values to specification template variables. It covers the general syntax and various data types for variable values.

### Method
CREATE SERVICE (USING Parameter)

### Endpoint
N/A (SQL Command Syntax)

### Parameters
#### Path Parameters
None

#### Query Parameters
None

#### Request Body
General Syntax:
```sql
USING( var_name=>var_value, [var_name=>var_value, ... ] );
```

### Request Example
```sql
-- Alphanumeric string and literal values
USING(some_alphanumeric_var=>'blah123',
      some_int_var=>111,
      some_bool_var=>true,
      some_float_var=>-1.2)

-- JSON string
USING(some_json_var=>' "/path/file.txt" ')

-- JSON map
USING(env_values=>'{"SERVER_PORT": 8000, "CHARACTER_NAME": "Bob"}' );

-- JSON list
USING (ARGS='["-n", 2]' );
```

### Response
#### Success Response (200)
Indicates successful parameter parsing. Errors occur if values are missing for non-defaulted variables.

#### Response Example
N/A
```

--------------------------------

### Providing Values for Specification Variables (USING Parameter)

Source: https://docs.snowflake.com/en/developer-guide/snowpark-container-services/working-with-services

Shows the general syntax and various examples of using the `USING` parameter in a `CREATE SERVICE` command to pass values for specification variables, including alphanumeric, literal, JSON string, JSON map, and JSON list.

```sql
-- Alphanumeric string and literal values
USING(some_alphanumeric_var=>'blah123',
      some_int_var=>111,
      some_bool_var=>true,
      some_float_var=>-1.2)

-- JSON string
USING(some_json_var=>' "/path/file.txt" ') 

-- JSON map
USING(env_values=>'{"SERVER_PORT": 8000, "CHARACTER_NAME": "Bob"}' );

-- JSON list
USING (ARGS='["-n", 2]' );
```

--------------------------------

### USE DATABASE Command

Source: https://docs.snowflake.com/en/sql-reference/sql/use-database

Sets the active database for the current session. If no database is specified, objects must be fully qualified. If a database is specified but no schema, objects must be qualified by schema.

```APIDOC
## USE DATABASE Command

### Description
Specifies the active/current database for the session. This affects how objects are referenced in queries and SQL statements.

### Method
SQL Command

### Endpoint
N/A (SQL Command)

### Parameters
#### Path Parameters
None

#### Query Parameters
None

#### Request Body
None

### Request Example
```sql
USE DATABASE mydb;
```

### Response
#### Success Response (N/A)
This command modifies the session state and does not return a specific response body in the typical API sense.

#### Response Example
(No direct response body for the command itself, but subsequent queries will reflect the new database context.)

Example of checking the current database:
```sql
SELECT CURRENT_DATABASE();
```

### Usage Notes
- The `DATABASE` keyword is optional.
- `USE DATABASE` sets `PUBLIC` as the default schema unless it doesn't exist.
- Use `USE SCHEMA` to specify a different schema.
```
